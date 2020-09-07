# frozen_string_literal: true

require "redis"

require_relative "./script"
require_relative "./concurrency"
require_relative "./rate_limit"

class Redis
  class Throttle
    # @api private
    class Api
      NAMESPACE = "throttle"
      private_constant :NAMESPACE

      KEYS_PATTERN = %r{
        \A
        #{NAMESPACE}:
        (?<strategy>concurrency|rate_limit):
        (?<bucket>.+):
        (?<limit>\d+):
        (?<ttl_or_period>\d+)
        \z
      }x.freeze
      private_constant :KEYS_PATTERN

      ACQUIRE = Script.new(File.read("#{__dir__}/api/acquire.lua"))
      private_constant :ACQUIRE

      RELEASE = Script.new(File.read("#{__dir__}/api/release.lua"))
      private_constant :RELEASE

      RESET = Script.new(File.read("#{__dir__}/api/reset.lua"))
      private_constant :RESET

      INFO = Script.new(File.read("#{__dir__}/api/info.lua"))
      private_constant :INFO

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
        execute(ACQUIRE, to_params(strategies) << token << Time.now.to_i).zero?
      end

      # @param strategies [Enumerable<Concurrency, RateLimit>]
      # @param token [String]
      # @return [void]
      def release(strategies:, token:)
        execute(RELEASE, to_params(strategies.grep(Concurrency)) << token)
      end

      # @param strategies [Enumerable<Concurrency, RateLimit>]
      # @return [void]
      def reset(strategies:)
        execute(RESET, to_params(strategies))
      end

      # @param match [String]
      # @return [Array<Concurrency, RateLimit>]
      def strategies(match:)
        results = []

        @redis.call do |redis|
          redis.scan_each(:match => "#{NAMESPACE}:*:#{match}:*:*") do |key|
            strategy = from_key(key)
            results << strategy if strategy
          end
        end

        results
      end

      # @param strategies [Enumerable<Concurrency, RateLimit>]
      # @return [Hash{Concurrency => Integer, RateLimit => Integer}]
      def info(strategies:)
        strategies.zip(execute(INFO, to_params(strategies) << Time.now.to_i)).to_h
      end

      # @note Used for specs only.
      # @return [void]
      def ping
        @redis.call(&:ping)
      end

      private

      def execute(script, argv)
        @redis.call { |redis| script.call(redis, :keys => [NAMESPACE], :argv => argv) }
      end

      def from_key(key)
        md = KEYS_PATTERN.match(key)

        case md && md[:strategy]
        when "concurrency"
          Concurrency.new(md[:bucket], :limit => md[:limit], :ttl => md[:ttl_or_period])
        when "rate_limit"
          RateLimit.new(md[:bucket], :limit => md[:limit], :period => md[:ttl_or_period])
        end
      end

      def to_params(strategies)
        result = []

        strategies.each do |strategy|
          case strategy
          when Concurrency
            result << "concurrency" << strategy.bucket << strategy.limit << strategy.ttl
          when RateLimit
            result << "rate_limit" << strategy.bucket << strategy.limit << strategy.period
          end
        end

        result
      end
    end
  end
end
