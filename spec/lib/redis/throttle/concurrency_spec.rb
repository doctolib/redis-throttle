# frozen_string_literal: true

require "redis/throttle/concurrency"

RSpec.describe Redis::Throttle::Concurrency do
  subject(:concurrency) { described_class.new(:styx, :limit => 2, :ttl => 10) }

  describe "#acquire" do
    before { concurrency.acquire(Redis.current, :token => :hades) }

    it "returns true when bucket allows new tokens" do
      expect(concurrency.acquire(Redis.current, :token => :charon)).to be true
    end

    context "when concurrency bucket is full" do
      before { concurrency.acquire(Redis.current, :token => :charon) }

      it "returns true for the token still holding the lock" do
        expect(concurrency.acquire(Redis.current, :token => :charon)).to be true
      end

      it "returns false" do
        expect(concurrency.acquire(Redis.current, :token => :heracles)).to be false
      end
    end
  end

  describe "#release" do
    it "does nothing when token was not previously acquired" do
      concurrency.acquire(Redis.current, :token => :hades)
      concurrency.acquire(Redis.current, :token => :charon)
      concurrency.release(Redis.current, :token => :heracles)

      expect(concurrency.acquire(Redis.current, :token => :heracles)).to be false
    end

    it "empties bucket by one" do
      concurrency.acquire(Redis.current, :token => :hades)
      concurrency.acquire(Redis.current, :token => :charon)
      concurrency.release(Redis.current, :token => :charon)

      expect(concurrency.acquire(Redis.current, :token => :heracles)).to be true
    end
  end

  describe "#reset" do
    it "releases all locks" do
      concurrency.acquire(Redis.current, :token => :hades)
      concurrency.acquire(Redis.current, :token => :charon)

      concurrency.reset(Redis.current)

      expect(concurrency.acquire(Redis.current, :token => :heracles)).to be true
    end
  end
end
