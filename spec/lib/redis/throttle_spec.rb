# frozen_string_literal: true

require "support/timecop"
require "redis/throttle"

RSpec.describe Redis::Throttle, :frozen_time do
  subject(:throttle) { described_class.new << db << api_minutely << api_hourly }

  let(:db)           { described_class::Concurrency.new(:db, :limit => 1, :ttl => 60) }
  let(:api_minutely) { described_class::Threshold.new(:api_minutely, :limit => 1, :period => 60) }
  let(:api_hourly)   { described_class::Threshold.new(:api_hourly,   :limit => 1, :period => 3600) }

  describe "#call" do
    it "returns lock when all strategies were resolved" do
      expect(throttle.call(Redis.current, :token => "aye")).to be_a described_class::Lock
    end

    context "with block" do
      it "yields control to the given block" do
        expect { |b| throttle.call(Redis.current, :token => "aye", &b) }.to yield_control
      end

      it "returns last statement of the block" do
        expect(throttle.call(Redis.current, :token => "aye") { 42 }).to eq 42
      end

      it "releases concurrency locks after the block" do
        throttle.call(Redis.current, :token => "aye") { 42 }

        expect(db.acquire(Redis.current, :token => "xxx")).to be true
      end

      it "keeps threshold locks after the block" do
        throttle.call(Redis.current, :token => "aye") { 42 }

        aggregate_failures do
          expect(api_minutely.acquire(Redis.current)).to be false
          expect(api_hourly.acquire(Redis.current)).to be false
        end
      end
    end

    context "when not all locks can be acquired" do
      before { api_hourly.acquire(Redis.current) }

      it "rejects partially acquired locks" do
        throttle.call(Redis.current, :token => "nay")

        aggregate_failures do
          expect(db.acquire(Redis.current, :token => "aye")).to be true
          expect(api_minutely.acquire(Redis.current)).to be true
        end
      end

      it "returns nil when no block given" do
        expect(throttle.call(Redis.current, :token => "nay")).to be_nil
      end

      it "does not yields control if block given" do
        expect { |b| throttle.call(Redis.current, :token => "nay", &b) }.not_to yield_control
      end
    end
  end
end
