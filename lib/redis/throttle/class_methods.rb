# frozen_string_literal: true

require_relative "./api"

class Redis
  class Throttle
    module ClassMethods
      # Syntax sugar for {Throttle#concurrency}.
      #
      # @see #concurrency
      # @param (see Throttle#initialize)
      # @param (see Throttle#concurrency)
      # @return (see Throttle#concurrency)
      def concurrency(bucket, limit:, ttl:, redis: nil)
        new(:redis => redis).concurrency(bucket, :limit => limit, :ttl => ttl)
      end

      # Syntax sugar for {Throttle#rate_limit}.
      #
      # @see #concurrency
      # @param (see Throttle#initialize)
      # @param (see Throttle#rate_limit)
      # @return (see Throttle#rate_limit)
      def rate_limit(bucket, limit:, period:, redis: nil)
        new(:redis => redis).rate_limit(bucket, :limit => limit, :period => period)
      end

      # Return usage info for all known (in use) strategies.
      #
      # @example
      #   Redis::Throttle.info(:match => "*_api").each do |strategy, current_value|
      #     # ...
      #   end
      #
      # @param match [#to_s]
      # @return (see Api#info)
      def info(match: "*", redis: nil)
        api        = Api.new(:redis => redis)
        strategies = api.strategies(:match => match.to_s)

        api.info(:strategies => strategies)
      end
    end
  end
end
