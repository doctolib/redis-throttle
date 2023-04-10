# frozen_string_literal: true

require "redis"
require "redis/namespace"

require "rspec/core/shared_context"

REDIS = Redis::Namespace.new("redis-throttle", redis: Redis.new(url: REDIS_URL))

module RedisPrescriptionSharedContext
  extend RSpec::Core::SharedContext

  before do
    REDIS.redis.script("FLUSH")
    REDIS.redis.flushdb
  end
end
