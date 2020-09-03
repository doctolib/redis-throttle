# frozen_string_literal: true

require "redis"

require_relative "./script"
require_relative "./concurrency"
require_relative "./rate_limit"

class Redis
  class Throttle
    # @api private
    class Api
      ACQUIRE = Script.new(File.read("#{__dir__}/api/acquire.lua"))
      private_constant :ACQUIRE

      # @param redis [Redis, Redis::Namespace, #to_proc]
      def initialize(redis: nil)
        @redis =
          if redis.respond_to?(:to_proc)
            redis.to_proc
          else
            ->(&b) { b.call(redis || Redis.current) }
          end
      end

      # @param strategies [Enumerable<Concurrency, RateLimit>]
      # @param token [String]
      # @return [Boolean]
      def acquire(strategies:, token:)
        keys = strategies.map(&method(:to_key))
        argv = strategies.flat_map(&method(:to_payload)) << token << Time.now.to_i

        @redis.call { |redis| ACQUIRE.call(redis, :keys => keys, :argv => argv).zero? }
      end

      # @param strategies [Enumerable<Concurrency, RateLimit>]
      # @param token [String]
      # @return [void]
      def release(strategies:, token:)
        @redis.call do |redis|
          redis.multi do
            strategies.each do |strategy|
              redis.zrem(to_key(strategy), token) if strategy.is_a?(Concurrency)
            end
          end
        end
      end

      # @param strategies [Enumerable<Concurrency, RateLimit>]
      # @return [void]
      def reset(strategies:)
        @redis.call { |redis| redis.del(*strategies.map(&method(:to_key))) }
      end

      # Ping server.
      #
      # @note Used for specs only.
      # @return [void]
      def ping
        @redis.call(&:ping)
      end

      private

      def to_key(strategy)
        case strategy
        when Concurrency then "throttle:#{strategy.bucket}:concurrency:#{strategy.limit}:#{strategy.ttl}"
        when RateLimit   then "throttle:#{strategy.bucket}:rate_limit:#{strategy.limit}:#{strategy.period}"
        end
      end

      def to_payload(strategy)
        case strategy
        when Concurrency then ["concurrency", strategy.limit, strategy.ttl]
        when RateLimit   then ["rate_limit", strategy.limit, strategy.period]
        end
      end
    end
  end
end
