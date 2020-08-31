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

      # Syntax sugar for {Throttle#rate_limit}.
      #
      # @see #concurrency
      # @param (see Throttle#initialize)
      # @param (see Throttle#rate_limit)
      # @return (see Throttle#rate_limit)
      def rate_limit(bucket, redis: nil, limit:, period:)
        new(:redis => redis).rate_limit(bucket, :limit => limit, :period => period)
      end
    end
  end
end
