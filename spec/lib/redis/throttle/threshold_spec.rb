# frozen_string_literal: true

require "support/timecop"
require "redis/throttle/threshold"

RSpec.describe Redis::Throttle::Threshold, :frozen_time do
  subject(:threshold) { described_class.new(:styx, :limit => 2, :period => 10) }

  describe "#acquire" do
    it "returns true when slot can be acquired" do
      expect(threshold.acquire(REDIS, :token => :hades)).to be true
    end

    context "when bucket is full" do
      before do
        2.times do |i|
          Timecop.travel(1)
          threshold.acquire(REDIS, :token => "xxx-#{i}")
        end
      end

      it "returns false" do
        expect(threshold.acquire(REDIS, :token => :hades)).to be false
      end

      it "returns true when bucket period passed" do
        Timecop.travel(9)
        expect(threshold.acquire(REDIS, :token => :hades)).to be true
      end
    end
  end

  describe "#release" do
    it "does nothing when token was not previously acquired" do
      threshold.acquire(REDIS, :token => :hades)
      threshold.acquire(REDIS, :token => :charon)
      threshold.release(REDIS, :token => :heracles)

      expect(threshold.acquire(REDIS, :token => :heracles)).to be false
    end

    it "empties bucket by one" do
      threshold.acquire(REDIS, :token => :hades)
      threshold.acquire(REDIS, :token => :charon)
      threshold.release(REDIS, :token => :charon)

      expect(threshold.acquire(REDIS, :token => :heracles)).to be true
    end
  end

  describe "#reset" do
    it "releases all locks" do
      2.times { |i| threshold.acquire(REDIS, :token => "xxx-#{i}") }

      threshold.reset(REDIS)

      expect(threshold.acquire(REDIS, :token => :hades)).to be true
    end
  end
end
