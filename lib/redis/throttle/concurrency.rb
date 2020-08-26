# frozen_string_literal: true

require_relative "./script"

class Redis
  class Throttle
    class Concurrency
      attr_reader :key

      # @param bucket [#to_s]
      # @param limit [#to_i]
      # @param ttl [#to_i]
      def initialize(bucket, limit:, ttl:)
        @limit = limit.to_i
        @ttl   = ttl.to_i
        @key   = "throttle:#{bucket}:c:#{@limit}:#{@ttl}"
      end

      # @param redis [Redis, Redis::Namespace]
      # @param token [#to_s]
      # @return [Boolean]
      def acquire(redis, token:)
        Script
          .eval(redis, [key], lua_payload << token.to_s << Time.now.to_i)
          .zero?
      end

      # @param redis [Redis, Redis::Namespace]
      # @param token [#to_s]
      # @return [void]
      def release(redis, token:)
        redis.zrem(key, token.to_s)
      end

      # @param redis [Redis, Redis::Namespace]
      # @return [void]
      def reset(redis)
        redis.del(key)
      end

      def lua_payload
        ["concurrency", @limit, @ttl]
      end
    end
  end
end
