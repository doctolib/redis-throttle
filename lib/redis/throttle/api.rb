# frozen_string_literal: true

require "redis"

require_relative "./script"

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
        keys = strategies.map(&:key)
        argv = strategies.flat_map(&:payload) << token.to_s << Time.now.to_i

        @redis.call { |redis| ACQUIRE.call(redis, :keys => keys, :argv => argv).zero? }
      end

      # @param strategies [Enumerable<Concurrency, RateLimit>]
      # @param token [String]
      # @return [void]
      def release(strategies:, token:)
        @redis.call do |redis|
          redis.multi do
            strategies.each do |strategy|
              redis.zrem(strategy.key, token.to_s) if strategy.is_a?(Concurrency)
            end
          end
        end
      end

      # @param strategies [Enumerable<Concurrency, RateLimit>]
      # @return [void]
      def reset(strategies:)
        @redis.call { |redis| redis.del(*strategies.map(&:key)) }
      end

      # Ping server.
      #
      # @note Used for specs only.
      # @return [void]
      def ping
        @redis.call(&:ping)
      end
    end
  end
end
