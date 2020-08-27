# frozen_string_literal: true

class Redis
  class Throttle
    module ClassMethods
      # Syntax sugar for {Throttle#concurrency}.
      #
      # @see #concurrency
      # @param (see Throttle#initialize)
      # @param (see Throttle#concurrency)
      # @return (see Throttle#concurrency)
      def concurrency(bucket, redis: nil, limit:, ttl:)
        new(:redis => redis).concurrency(bucket, :limit => limit, :ttl => ttl)
      end

      # Syntax sugar for {Throttle#threshold}.
      #
      # @see #concurrency
      # @param (see Throttle#initialize)
      # @param (see Throttle#threshold)
      # @return (see Throttle#threshold)
      def threshold(bucket, redis: nil, limit:, period:)
        new(:redis => redis).threshold(bucket, :limit => limit, :period => period)
      end
    end
  end
end
