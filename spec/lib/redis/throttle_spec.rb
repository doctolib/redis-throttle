# frozen_string_literal: true

require "support/timecop"
require "redis/throttle"

RSpec.describe Redis::Throttle, :frozen_time do
  subject(:throttle) { described_class.new }

  before { stub_const("FrozenError", described_class::FrozenError) } if RUBY_VERSION < "2.5"

  describe ".new" do
    it "proxies redis to Api as is" do
      allow(described_class::Api).to receive(:new).and_call_original

      redis = Redis.new
      described_class.new(:redis => redis)

      expect(described_class::Api).to have_received(:new).with(:redis => redis)
    end
  end

  describe ".concurrency" do
    it "is a syntax sugar for #concurrency" do
      redis    = instance_double(Redis)
      throttle = instance_double(described_class)

      allow(described_class).to receive(:new).with(:redis => redis).and_return(throttle)
      allow(throttle).to receive(:concurrency).with(:example, :limit => 1, :ttl => 60)

      described_class.concurrency(:example, :redis => redis, :limit => 1, :ttl => 60)

      aggregate_failures do
        expect(described_class).to have_received(:new).with(:redis => redis)
        expect(throttle).to have_received(:concurrency).with(:example, :limit => 1, :ttl => 60)
      end
    end
  end

  describe ".rate_limit" do
    it "is a syntax sugar for #rate_limit" do
      redis    = instance_double(Redis)
      throttle = instance_double(described_class)

      allow(described_class).to receive(:new).with(:redis => redis).and_return(throttle)
      allow(throttle).to receive(:rate_limit).with(:example, :limit => 1, :period => 60)

      described_class.rate_limit(:example, :redis => redis, :limit => 1, :period => 60)

      aggregate_failures do
        expect(described_class).to have_received(:new).with(:redis => redis)
        expect(throttle).to have_received(:rate_limit).with(:example, :limit => 1, :period => 60)
      end
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
    subject(:concurrency) { throttle.concurrency(:example, :limit => 1, :ttl => 60) }

    it "returns Redis::Throttle instance itself" do
      expect(concurrency).to be throttle
    end

    it "fails with FrozenError when throttle is frozen" do
      throttle.freeze

      expect { concurrency }.to raise_error(FrozenError, "can't modify frozen Redis::Throttle")
    end

    it "allows max LIMIT concurrent units" do
      aggregate_failures do
        expect(concurrency.acquire).to be_truthy
        expect(concurrency.acquire).to be_falsey
      end
    end

    it "allows re-acquire execution lock for the same token" do
      aggregate_failures do
        expect(concurrency.acquire(:token => "xxx")).to be_truthy
        expect(concurrency.acquire(:token => "xxx")).to be_truthy
      end
    end
  end

  describe "#rate_limit" do
    subject(:rate_limit) { throttle.rate_limit(:example, :limit => 2, :period => 60) }

    it "returns Redis::Throttle instance itself" do
      expect(rate_limit).to be throttle
    end

    it "fails with FrozenError when throttle is frozen" do
      throttle.freeze

      expect { rate_limit }.to raise_error(FrozenError, "can't modify frozen Redis::Throttle")
    end

    it "allows max LIMIT units per PERIOD" do
      aggregate_failures do
        expect(rate_limit.acquire).to be_truthy

        Timecop.travel(30)
        expect(rate_limit.acquire).to be_truthy

        Timecop.travel(1)
        expect(rate_limit.acquire).to be_falsey

        Timecop.travel(30)
        expect(rate_limit.acquire).to be_truthy
      end
    end

    it "disallows re-acquire execution lock for the same token" do
      aggregate_failures do
        expect(rate_limit.acquire(:token => "xxx")).to be_truthy
        expect(rate_limit.acquire(:token => "xxx")).to be_truthy
        expect(rate_limit.acquire(:token => "xxx")).to be_falsey
      end
    end
  end

  describe "#merge!" do
    let(:throttle) { described_class.concurrency(:abc, :limit => 1, :ttl => 60) }
    let(:other)    { described_class.concurrency(:xyz, :limit => 1, :ttl => 60) }

    it "merges other throttle strategies in" do
      expect(throttle.merge!(other)).to eq(
        described_class
          .concurrency(:abc, :limit => 1, :ttl => 60)
          .concurrency(:xyz, :limit => 1, :ttl => 60)
      )
    end

    it "returns Redis::Throttle instance itself" do
      expect(throttle.merge!(other)).to be throttle
    end

    it "fails with FrozenError when throttle is frozen" do
      throttle.freeze

      expect { throttle.merge! other }
        .to raise_error(FrozenError, "can't modify frozen Redis::Throttle")
    end
  end

  describe "#<<" do
    it "is an alias of #merge!" do
      expect(throttle.method(:<<).original_name).to eq :merge!
    end
  end

  describe "#merge" do
    let(:throttle) { described_class.concurrency(:abc, :limit => 1, :ttl => 60) }
    let(:other)    { described_class.concurrency(:xyz, :limit => 1, :ttl => 60) }

    it "merges strategies" do
      expect(throttle.merge(other)).to eq(
        described_class
          .concurrency(:abc, :limit => 1, :ttl => 60)
          .concurrency(:xyz, :limit => 1, :ttl => 60)
      )
    end

    it "returns new Redis::Throttle instance" do
      expect(throttle.merge(other)).not_to be throttle
    end

    it "returns unfrozen instance" do
      expect(throttle.merge(other)).not_to be_frozen
    end
  end

  describe "#|" do
    it "is an alias of #merge" do
      expect(throttle.method(:|).original_name).to eq :merge
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

    let(:a) { described_class.concurrency(:a, :limit => 1, :ttl => 60) }
    let(:b) { described_class.concurrency(:b, :limit => 1, :ttl => 60) }
    let(:c) { described_class.rate_limit(:c, :limit => 1, :period => 60) }

    context "when other has same strategies" do
      let(:throttle) { a | b | c }
      let(:other)    { c | a | b }

      it { is_expected.to be true }
    end

    context "when other has different strategies" do
      let(:throttle) { a | c }
      let(:other)    { a | b }

      it { is_expected.to be false }
    end
  end

  describe "#eql?" do
    it "is an alias of #==" do
      expect(throttle.method(:eql?).original_name).to eq :==
    end
  end

  describe "#call" do
    let(:throttle) { solo | minutely | hourly }

    let(:solo)     { described_class.concurrency(:solo, :limit => 1, :ttl => 60) }
    let(:minutely) { described_class.rate_limit(:minutely, :limit => 1, :period => 60) }
    let(:hourly)   { described_class.rate_limit(:hourly, :limit => 1, :period => 3660) }

    it "yields control to the given block" do
      expect { |b| throttle.call(&b) }.to yield_control
    end

    it "returns last statement of the block" do
      expect(throttle.call { 42 }).to eq 42
    end

    it "releases concurrency locks after the block" do
      throttle.call { 42 }

      expect(solo.acquire).to be_truthy
    end

    it "keeps rate_limit locks after the block" do
      throttle.call { 42 }

      aggregate_failures do
        expect(minutely.acquire).to be_falsey
        expect(hourly.acquire).to be_falsey
      end
    end

    context "when not all locks can be acquired" do
      before { hourly.acquire }

      it "rejects partially acquired locks" do
        throttle.call(:token => "nay") { 42 }

        aggregate_failures do
          expect(solo.acquire).to be_truthy
          expect(minutely.acquire).to be_truthy
        end
      end

      it "does not yields control if block given" do
        expect { |b| throttle.call(&b) }.not_to yield_control
      end
    end
  end

  describe "#acquire" do
    let(:throttle) { solo | minutely | hourly }

    let(:solo)     { described_class.concurrency(:solo, :limit => 1, :ttl => 60) }
    let(:minutely) { described_class.rate_limit(:minutely, :limit => 1, :period => 60) }
    let(:hourly)   { described_class.rate_limit(:hourly, :limit => 1, :period => 3660) }

    it "returns token when all strategies were resolved" do
      expect(throttle.acquire(:token => "aye")).to eq "aye"
    end

    it "generates token if no token given" do
      allow(SecureRandom).to receive(:uuid).and_return("00000000-0000-0000-0000-000000000000")

      expect(throttle.acquire).to eq("00000000-0000-0000-0000-000000000000")
    end

    context "when not all strategies can be resolved" do
      before { hourly.acquire }

      it "rejects partially acquired locks" do
        throttle.acquire

        aggregate_failures do
          expect(solo.acquire).to be_truthy
          expect(minutely.acquire).to be_truthy
        end
      end

      it "returns nil when no block given" do
        expect(throttle.acquire).to be_falsey
      end
    end
  end

  describe "#release" do
    let(:throttle)    { concurrency | rate_limit }
    let(:concurrency) { described_class.concurrency(:concurrency, :limit => 1, :ttl => 60) }
    let(:rate_limit)  { described_class.rate_limit(:rate_limit, :limit => 1, :period => 60) }

    it "releases concurrency locks" do
      throttle.acquire(:token => "xxx")
      throttle.release(:token => "xxx")

      expect(concurrency.acquire).to be_truthy
    end

    it "keeps rate_limit locks" do
      throttle.acquire(:token => "xxx")
      throttle.release(:token => "xxx")

      expect(rate_limit.acquire).to be_falsey
    end
  end

  describe "#reset" do
    let(:throttle)    { concurrency | rate_limit }
    let(:concurrency) { described_class.concurrency(:concurrency, :limit => 1, :ttl => 60) }
    let(:rate_limit)  { described_class.rate_limit(:rate_limit, :limit => 1, :period => 60) }

    it "flushes buckets of all strategies" do
      throttle.acquire
      throttle.reset

      aggregate_failures do
        expect(concurrency.acquire).to be_truthy
        expect(rate_limit.acquire).to be_truthy
      end
    end
  end
end
