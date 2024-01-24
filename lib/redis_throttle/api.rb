# frozen_string_literal: true

require "redis_prescription"

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
      (?<bucket>.+)
    \z
    }x
    private_constant :KEYS_PATTERN

    SCRIPT = RedisPrescription.new(File.read("#{__dir__}/api.lua"))
    private_constant :SCRIPT

    # @param redis [Redis, Redis::Namespace, RedisClient, RedisClient::Decorator::Client]
    def initialize(redis)
      @redis = redis
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
      execute(:RELEASE, to_params(strategies) << :TOKEN << token)
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
      block   = ->(key) { from_key(key)&.then { |strategy| results << strategy } }

      if redis_client?
        @redis.scan("MATCH", "#{NAMESPACE}:*:#{match}:*:*", &block)
      else
        @redis.scan_each(match: "#{NAMESPACE}:*:#{match}:*:*", &block)
      end

      results
    end

    private

    def redis_client?
      return true if defined?(::RedisClient) && @redis.is_a?(::RedisClient)
      return true if defined?(::RedisClient::Decorator::Client) && @redis.is_a?(::RedisClient::Decorator::Client)

      false
    end

    def execute(command, argv)
      SCRIPT.call(@redis, keys: [NAMESPACE], argv: [command, *argv])
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

    def to_params(strategies) # rubocop:disable Metrics/MethodLength
      params = []

      strategies.each do |strategy|
        case strategy
        when Concurrency
          params.push("concurrency", strategy.bucket, strategy.limit, strategy.ttl)
        when RateLimit
          params.push("rate_limit", strategy.bucket, strategy.limit, strategy.period)
        else
          raise TypeError, "invalid startegy: #{strategy.inspect}"
        end
      end

      raise ArgumentError, "missing strategies" if params.empty?

      params
    end
  end
end
