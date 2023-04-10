# frozen_string_literal: true

require "redis"

require "rspec/core/shared_context"

REDIS = Redis.new(url: REDIS_URL)

module RedisPrescriptionSharedContext
  extend RSpec::Core::SharedContext

  before do
    REDIS.script("FLUSH")
    REDIS.flushdb
  end
end
