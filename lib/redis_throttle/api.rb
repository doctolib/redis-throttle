# frozen_string_literal: true

require "redis"
require "redis-prescription"

require_relative "./concurrency"
require_relative "./rate_limit"

class RedisThrottle
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

    SCRIPT = RedisPrescription.new(File.read("#{__dir__}/api.lua"))
    private_constant :SCRIPT

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
      execute(:ACQUIRE, to_params(strategies.sort_by(&:itself)) << :TOKEN << token << :TS << Time.now.to_i).zero?
    end

    # @param strategies [Enumerable<Concurrency, RateLimit>]
    # @param token [String]
    # @return [void]
    def release(strategies:, token:)
      execute(:RELEASE, to_params(strategies.grep(Concurrency)) << :TOKEN << token)
    end

    # @param strategies [Enumerable<Concurrency, RateLimit>]
    # @return [void]
    def reset(strategies:)
      execute(:RESET, to_params(strategies))
    end

    # @param match [String]
    # @return [Array<Concurrency, RateLimit>]
    def strategies(match:)
      results = []

      @redis.call do |redis|
        redis.scan_each(match: "#{NAMESPACE}:*:#{match}:*:*") do |key|
          strategy = from_key(key)
          results << strategy if strategy
        end
      end

      results
    end

    # @param strategies [Enumerable<Concurrency, RateLimit>]
    # @return [Hash{Concurrency => Integer, RateLimit => Integer}]
    def info(strategies:)
      strategies.zip(execute(:INFO, to_params(strategies) << :TS << Time.now.to_i)).to_h
    end

    # @note Used for specs only.
    # @return [void]
    def ping
      @redis.call(&:ping)
    end

    private

    def execute(command, argv)
      @redis.call { |redis| SCRIPT.call(redis, keys: [NAMESPACE], argv: [command, *argv]) }
    end

    def from_key(key)
      md = KEYS_PATTERN.match(key)

      case md && md[:strategy]
      when "concurrency"
        Concurrency.new(md[:bucket], limit: md[:limit], ttl: md[:ttl_or_period])
      when "rate_limit"
        RateLimit.new(md[:bucket], limit: md[:limit], period: md[:ttl_or_period])
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
