# frozen_string_literal: true

require "json"

require_relative "./script"

class Redis
  class Throttle
    class Threshold
      attr_reader :bucket

      # @param bucket [#to_s]
      # @param limit [#to_i]
      # @param period [#to_i]
      def initialize(bucket, limit:, period:)
        @bucket = bucket.to_s
        @limit  = limit.to_i
        @period = period.to_i
      end

      # @param redis [Redis, Redis::Namespace]
      # @return [Boolean]
      def acquire(redis)
        Script
          .instance
          .call(redis, :keys => [@bucket], :argv => [lua_payload])
          .zero?
      end

      # @param redis [Redis, Redis::Namespace]
      # @return [void]
      def reset(redis)
        redis.del(@bucket)
      end

      def lua_payload(*)
        JSON.dump(["threshold", [@limit, @period, Time.now.to_i]])
      end
    end
  end
end
