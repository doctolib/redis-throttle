# frozen_string_literal: true

require "support/timecop"
require "redis/throttle/concurrency"
require "redis/throttle/lock"
require "redis/throttle/threshold"

RSpec.describe Redis::Throttle::Lock, :frozen_time do
  subject(:lock) { described_class.new([concurrency, threshold], :token => "xxx") }

  let(:concurrency) { Redis::Throttle::Concurrency.new(:abc, :limit => 1, :ttl => 10) }
  let(:threshold)   { Redis::Throttle::Threshold.new(:xyz, :limit => 1, :period => 10) }

  before do
    concurrency.acquire(Redis.current, :token => "xxx")
    threshold.acquire(Redis.current)
  end

  describe "#release" do
    before { lock.release(Redis.current) }

    it "releases acquired concurrency locks" do
      expect(concurrency.acquire(Redis.current, :token => "deadbeef")).to be true
    end

    it "keeps qcquired threshold locks" do
      expect(threshold.acquire(Redis.current)).to be false
    end
  end
end
