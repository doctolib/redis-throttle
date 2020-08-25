# frozen_string_literal: true

require "json"

require_relative "./script"

class Redis
  class Throttle
    class Threshold
      attr_reader :key

      # @param bucket [#to_s]
      # @param limit [#to_i]
      # @param period [#to_i]
      def initialize(bucket, limit:, period:)
        @limit  = limit.to_i
        @period = period.to_i
        @key    = "throttle:#{bucket}:t:#{@limit}:#{@period}"
      end

      # @param redis [Redis, Redis::Namespace]
      # @return [Boolean]
      def acquire(redis)
        Script
          .eval(redis, [key], [lua_payload])
          .zero?
      end

      # @param redis [Redis, Redis::Namespace]
      # @return [void]
      def reset(redis)
        redis.del(key)
      end

      def lua_payload(*)
        JSON.dump(["threshold", [@limit, @period, Time.now.to_i]])
      end
    end
  end
end
