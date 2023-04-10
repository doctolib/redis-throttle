# frozen_string_literal: true

RSpec.describe RedisThrottle::Api do
  describe ".new" do
    it "works with :redis given as #to_proc" do
      require "connection_pool"

      redis           = Redis.new
      connection_pool = ConnectionPool.new { redis }

      allow(redis).to receive(:ping)

      described_class.new(redis: connection_pool.method(:with)).ping

      expect(redis).to have_received(:ping)
    end

    it "works with explicitly given :redis client" do
      redis = Redis.new

      allow(redis).to receive(:ping)

      described_class.new(redis: redis).ping

      expect(redis).to have_received(:ping)
    end

    it "uses up-to-date Redis.current if :redis was given as `nil`" do
      Redis.current = nil

      api   = described_class.new(redis: nil)
      redis = Redis.current = Redis.new

      allow(redis).to receive(:ping)

      api.ping

      expect(redis).to have_received(:ping)
    end
  end
end
