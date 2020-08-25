# frozen_string_literal: true

require "json"

require_relative "./script"

class Redis
  class Throttle
    class Concurrency
      attr_reader :bucket

      # @param bucket [#to_s]
      # @param limit [#to_i]
      # @param ttl [#to_i]
      def initialize(bucket, limit:, ttl:)
        @bucket = bucket.to_s
        @limit  = limit.to_i
        @ttl    = ttl.to_i
      end

      # @param redis [Redis, Redis::Namespace]
      # @param token [#to_s]
      # @return [Boolean]
      def acquire(redis, token:)
        Script
          .instance
          .call(redis, :keys => [@bucket], :argv => [lua_payload(token)])
          .zero?
      end

      # @param redis [Redis, Redis::Namespace]
      # @param token [#to_s]
      # @return [void]
      def release(redis, token:)
        redis.zrem(@bucket, token.to_s)
      end

      # @param redis [Redis, Redis::Namespace]
      # @return [void]
      def reset(redis)
        redis.del(@bucket)
      end

      def lua_payload(token)
        JSON.dump(["concurrency", [token.to_s, @limit, @ttl, Time.now.to_i]])
      end
    end
  end
end
