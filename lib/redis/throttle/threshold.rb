# frozen_string_literal: true

require_relative "./script"

class Redis
  module Throttle
    class Threshold
      SCRIPT = Script.new(File.read("#{__dir__}/threshold.lua"))
      private_constant :SCRIPT

      NOOP = ->(_) { nil }
      private_constant :NOOP

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
        SCRIPT
          .call(redis, :keys => [@bucket], :argv => [@limit, @period, Time.now.to_i])
          .zero?
      end

      # @param redis [Redis, Redis::Namespace]
      # @return [void]
      def reset(redis)
        redis.del(@bucket)
      end
    end
  end
end
