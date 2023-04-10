# frozen_string_literal: true

require "support/timecop"

RSpec.describe RedisThrottle do
  subject(:throttle) { described_class.new }

  describe ".concurrency" do
    subject { described_class.concurrency(:example, limit: 1, ttl: 60) }

    it { is_expected.to eq(described_class.new.concurrency(:example, limit: 1, ttl: 60)) }
  end

  describe ".rate_limit" do
    subject { described_class.rate_limit(:example, limit: 1, period: 60) }

    it { is_expected.to eq(described_class.new.rate_limit(:example, limit: 1, period: 60)) }
  end

  describe ".info", :frozen_time do
    before do
      throttle =
        described_class
          .concurrency(:abc, limit: 3, ttl: 60)
          .rate_limit(:xyz, limit: 3, period: 60)

      3.times do
        Timecop.travel(10)
        throttle.acquire(REDIS)
      end
    end

    it "returns usage info for all strategies in use" do
      expect(described_class.info(REDIS)).to eq({
        described_class::Concurrency.new(:abc, limit: 3, ttl: 60)  => 3,
        described_class::RateLimit.new(:xyz, limit: 3, period: 60) => 3
      })
    end

    it "supports filtering" do
      expect(described_class.info(REDIS, match: "a*")).to eq({
        described_class::Concurrency.new(:abc, limit: 3, ttl: 60) => 3
      })
    end

    it "returns actual values" do
      Timecop.travel(60)

      expect(described_class.info(REDIS)).to eq({
        described_class::Concurrency.new(:abc, limit: 3, ttl: 60)  => 1,
        described_class::RateLimit.new(:xyz, limit: 3, period: 60) => 1
      })
    end
  end

  describe "#dup" do
    it "copies strategies" do
      original_strategies = throttle.instance_variable_get(:@strategies)
      copied_strategies   = throttle.dup.instance_variable_get(:@strategies)

      expect(copied_strategies).not_to be original_strategies
    end

    it "resets frozen state" do
      expect(throttle.freeze.dup).not_to be_frozen
    end
  end

  describe "#clone" do
    it "copies strategies" do
      original_strategies = throttle.instance_variable_get(:@strategies)
      copied_strategies   = throttle.clone.instance_variable_get(:@strategies)

      expect(copied_strategies).not_to be original_strategies
    end

    it "keeps frozen state" do
      expect(throttle.freeze.clone).to be_frozen
    end
  end

  describe "#concurrency" do
    subject(:concurrency) { throttle.concurrency(:example, limit: 1, ttl: 60) }

    it "returns Redis::Throttle instance itself" do
      expect(concurrency).to be throttle
    end

    it "fails with FrozenError when throttle is frozen" do
      throttle.freeze

      expect { concurrency }.to raise_error(FrozenError, "can't modify frozen #{described_class}")
    end

    it "allows max LIMIT concurrent units" do
      aggregate_failures do
        expect(concurrency.acquire(REDIS)).to be_truthy
        expect(concurrency.acquire(REDIS)).to be_falsey
      end
    end

    it "allows re-acquire execution lock for the same token" do
      aggregate_failures do
        expect(concurrency.acquire(REDIS, token: "xxx")).to be_truthy
        expect(concurrency.acquire(REDIS, token: "xxx")).to be_truthy
      end
    end
  end

  describe "#rate_limit" do
    subject(:rate_limit) { throttle.rate_limit(:example, limit: 2, period: 60) }

    it "returns Redis::Throttle instance itself" do
      expect(rate_limit).to be throttle
    end

    it "fails with FrozenError when throttle is frozen" do
      throttle.freeze

      expect { rate_limit }.to raise_error(FrozenError, "can't modify frozen #{described_class}")
    end

    it "allows max LIMIT units per PERIOD", :frozen_time do
      aggregate_failures do
        expect(rate_limit.acquire(REDIS)).to be_truthy

        Timecop.travel(30)
        expect(rate_limit.acquire(REDIS)).to be_truthy

        Timecop.travel(1)
        expect(rate_limit.acquire(REDIS)).to be_falsey

        Timecop.travel(30)
        expect(rate_limit.acquire(REDIS)).to be_truthy
      end
    end

    it "disallows re-acquire execution lock for the same token" do
      aggregate_failures do
        expect(rate_limit.acquire(REDIS, token: "xxx")).to be_truthy
        expect(rate_limit.acquire(REDIS, token: "xxx")).to be_truthy
        expect(rate_limit.acquire(REDIS, token: "xxx")).to be_falsey
      end
    end
  end

  describe "#merge!" do
    let(:throttle) { described_class.concurrency(:abc, limit: 1, ttl: 60) }
    let(:other)    { described_class.concurrency(:xyz, limit: 1, ttl: 60) }

    it "merges other throttle strategies in" do
      expect(throttle.merge!(other)).to eq(
        described_class
          .concurrency(:abc, limit: 1, ttl: 60)
          .concurrency(:xyz, limit: 1, ttl: 60)
      )
    end

    it "returns Redis::Throttle instance itself" do
      expect(throttle.merge!(other)).to be throttle
    end

    it "fails with FrozenError when throttle is frozen" do
      throttle.freeze

      expect { throttle.merge! other }
        .to raise_error(FrozenError, "can't modify frozen #{described_class}")
    end
  end

  describe "#merge" do
    let(:throttle) { described_class.concurrency(:abc, limit: 1, ttl: 60) }
    let(:other)    { described_class.concurrency(:xyz, limit: 1, ttl: 60) }

    it "merges strategies" do
      expect(throttle.merge(other)).to eq(
        described_class
          .concurrency(:abc, limit: 1, ttl: 60)
          .concurrency(:xyz, limit: 1, ttl: 60)
      )
    end

    it "returns new Redis::Throttle instance" do
      expect(throttle.merge(other)).not_to be throttle
    end

    it "returns unfrozen instance" do
      expect(throttle.merge(other)).not_to be_frozen
    end
  end

  describe "#+" do
    it "is an alias of #merge" do
      expect(throttle.method(:+).original_name).to eq :merge
    end
  end

  describe "#freeze" do
    it "returns self" do
      expect(throttle.freeze).to be throttle
    end

    it "marks object as frozen" do
      expect(throttle.freeze).to be_frozen
    end
  end

  describe "#==" do
    subject { throttle == other }

    let(:a) { described_class.concurrency(:a, limit: 1, ttl: 60) }
    let(:b) { described_class.concurrency(:b, limit: 1, ttl: 60) }
    let(:c) { described_class.rate_limit(:c, limit: 1, period: 60) }

    context "when other has same strategies" do
      let(:throttle) { a + b + c }
      let(:other)    { c + a + b }

      it { is_expected.to be true }
    end

    context "when other has different strategies" do
      let(:throttle) { a + c }
      let(:other)    { a + b }

      it { is_expected.to be false }
    end
  end

  describe "#eql?" do
    it "is an alias of #==" do
      expect(throttle.method(:eql?).original_name).to eq :==
    end
  end

  describe "#call" do
    let(:throttle) { solo + minutely + hourly }

    let(:solo)     { described_class.concurrency(:solo, limit: 1, ttl: 60) }
    let(:minutely) { described_class.rate_limit(:minutely, limit: 1, period: 60) }
    let(:hourly)   { described_class.rate_limit(:hourly, limit: 1, period: 3660) }

    it "yields control to the given block" do
      expect { |b| throttle.call(REDIS, &b) }.to yield_control
    end

    it "returns last statement of the block" do
      expect(throttle.call(REDIS) { 42 }).to eq 42
    end

    it "releases concurrency locks after the block" do
      throttle.call(REDIS) { 42 }

      expect(solo.acquire(REDIS)).to be_truthy
    end

    it "keeps rate_limit locks after the block" do
      throttle.call(REDIS) { 42 }

      aggregate_failures do
        expect(minutely.acquire(REDIS)).to be_falsey
        expect(hourly.acquire(REDIS)).to be_falsey
      end
    end

    context "when not all locks can be acquired" do
      before { hourly.acquire(REDIS) }

      it "rejects partially acquired locks" do
        throttle.call(REDIS, token: "nay") { 42 }

        aggregate_failures do
          expect(solo.acquire(REDIS)).to be_truthy
          expect(minutely.acquire(REDIS)).to be_truthy
        end
      end

      it "does not yields control if block given" do
        expect { |b| throttle.call(REDIS, &b) }.not_to yield_control
      end
    end
  end

  describe "#acquire" do
    let(:throttle) { solo + minutely + hourly }

    let(:solo)     { described_class.concurrency(:solo, limit: 1, ttl: 60) }
    let(:minutely) { described_class.rate_limit(:minutely, limit: 1, period: 60) }
    let(:hourly)   { described_class.rate_limit(:hourly, limit: 1, period: 3660) }

    it "returns token when all strategies were resolved" do
      expect(throttle.acquire(REDIS, token: "aye")).to eq "aye"
    end

    it "generates token if no token given" do
      allow(SecureRandom).to receive(:uuid).and_return("00000000-0000-0000-0000-000000000000")

      expect(throttle.acquire(REDIS)).to eq("00000000-0000-0000-0000-000000000000")
    end

    context "when not all strategies can be resolved" do
      before { hourly.acquire(REDIS) }

      it "rejects partially acquired locks" do
        throttle.acquire(REDIS)

        aggregate_failures do
          expect(solo.acquire(REDIS)).to be_truthy
          expect(minutely.acquire(REDIS)).to be_truthy
        end
      end

      it "returns nil when no block given" do
        expect(throttle.acquire(REDIS)).to be_falsey
      end
    end
  end

  describe "#release" do
    let(:throttle)    { concurrency + rate_limit }
    let(:concurrency) { described_class.concurrency(:concurrency, limit: 1, ttl: 60) }
    let(:rate_limit)  { described_class.rate_limit(:rate_limit, limit: 1, period: 60) }

    it "releases concurrency locks" do
      throttle.acquire(REDIS, token: "xxx")
      throttle.release(REDIS, token: "xxx")

      expect(concurrency.acquire(REDIS)).to be_truthy
    end

    it "keeps rate_limit locks" do
      throttle.acquire(REDIS, token: "xxx")
      throttle.release(REDIS, token: "xxx")

      expect(rate_limit.acquire(REDIS)).to be_falsey
    end
  end

  describe "#reset" do
    let(:throttle)    { concurrency + rate_limit }
    let(:concurrency) { described_class.concurrency(:concurrency, limit: 1, ttl: 60) }
    let(:rate_limit)  { described_class.rate_limit(:rate_limit, limit: 1, period: 60) }

    it "flushes buckets of all strategies" do
      throttle.acquire(REDIS)
      throttle.reset(REDIS)

      aggregate_failures do
        expect(concurrency.acquire(REDIS)).to be_truthy
        expect(rate_limit.acquire(REDIS)).to be_truthy
      end
    end
  end

  describe "#info" do
    let(:throttle)    { concurrency + rate_limit }
    let(:concurrency) { described_class.concurrency(:abc, limit: 3, ttl: 60) }
    let(:rate_limit)  { described_class.rate_limit(:xyz, limit: 3, period: 60) }

    it "returns usage info for all strategies of the throttle" do
      concurrency.acquire(REDIS)

      expect(throttle.info(REDIS)).to eq({
        described_class::Concurrency.new(:abc, limit: 3, ttl: 60)  => 1,
        described_class::RateLimit.new(:xyz, limit: 3, period: 60) => 0
      })
    end

    it "returns actual values", :frozen_time do
      3.times do
        Timecop.travel(10)
        throttle.acquire(REDIS)
      end

      Timecop.travel(60)

      expect(throttle.info(REDIS)).to eq({
        described_class::Concurrency.new(:abc, limit: 3, ttl: 60)  => 1,
        described_class::RateLimit.new(:xyz, limit: 3, period: 60) => 1
      })
    end
  end
end
