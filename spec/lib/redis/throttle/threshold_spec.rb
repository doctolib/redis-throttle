# frozen_string_literal: true

require "support/timecop"
require "redis/throttle/threshold"

RSpec.describe Redis::Throttle::Threshold, :frozen_time do
  subject(:threshold) { described_class.new(:styx, :limit => 2, :period => 10) }

  describe "#acquire" do
    it "returns true when slot can be acquired" do
      expect(threshold.acquire(REDIS)).to be true
    end

    context "when bucket is full" do
      before do
        2.times do
          Timecop.travel(1)
          threshold.acquire(REDIS)
        end
      end

      it "returns false" do
        expect(threshold.acquire(REDIS)).to be false
      end

      it "returns true when bucket period passed" do
        Timecop.travel(9)
        expect(threshold.acquire(REDIS)).to be true
      end
    end
  end

  describe "#reset" do
    it "releases all locks" do
      2.times { threshold.acquire(REDIS) }

      threshold.reset(REDIS)

      expect(threshold.acquire(REDIS)).to be true
    end
  end
end