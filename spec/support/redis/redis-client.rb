# frozen_string_literal: true

require "redis_client"

require "rspec/core/shared_context"

REDIS = RedisClient.new(url: REDIS_URL)

module RedisPrescriptionSharedContext
  extend RSpec::Core::SharedContext

  before do
    REDIS.call("SCRIPT", "FLUSH")
    REDIS.call("FLUSHDB")
  end
end
