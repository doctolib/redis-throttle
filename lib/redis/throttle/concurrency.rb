# frozen_string_literal: true

require_relative "./script"

class Redis
  module Throttle
    class Concurrency
      SCRIPT = Script.new(File.read("#{__dir__}/concurrency.lua"))
      private_constant :SCRIPT

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
        SCRIPT
          .call(redis, :keys => [@bucket], :argv => [token.to_s, @limit, @ttl, Time.now.to_i])
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
    end
  end
end
