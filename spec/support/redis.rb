# frozen_string_literal: true

REDIS_URL = ENV.fetch("REDIS_URL", "redis://localhost:6379")
REDIS_GEM = ENV.fetch("REDIS_GEM", "redis")

case REDIS_GEM
when "redis"
  require "redis"

  REDIS = Redis.new(url: REDIS_URL)

  RSpec.configure do |config|
    config.before do
      REDIS.script("FLUSH")
      REDIS.flushdb
    end
  end
when "redis-namespace"
  require "redis/namespace"

  REDIS = Redis::Namespace.new("redis-prescription", redis: Redis.new(url: REDIS_URL))

  RSpec.configure do |config|
    config.before do
      REDIS.redis.script("FLUSH")
      REDIS.redis.flushdb
    end
  end
else
  raise "Invalid REDIS_GEM"
end
