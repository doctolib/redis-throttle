# frozen_string_literal: true

require "redis"
require "set"
require "securerandom"

require_relative "./throttle/errors"
require_relative "./throttle/class_methods"
require_relative "./throttle/concurrency"
require_relative "./throttle/rate_limit"
require_relative "./throttle/script"
require_relative "./throttle/version"

# @see https://github.com/redis/redis-rb
class Redis
  # Distributed rate limit and concurrency throttling.
  class Throttle
    extend ClassMethods

    # @param redis [Redis, Redis::Namespace, #to_proc]
    def initialize(redis: nil)
      @redis      = redis.respond_to?(:to_proc) ? redis.to_proc : redis
      @strategies = SortedSet.new
    end

    # @api private
    #
    # Dup internal strategies plan.
    #
    # @return [void]
    def initialize_dup(original)
      super

      @strategies = original.strategies.dup
    end

    # @api private
    #
    # Clone internal strategies plan.
    #
    # @return [void]
    def initialize_clone(original)
      super

      @strategies = original.strategies.clone
    end

    # Add *concurrency* strategy to the throttle. Use it to guarantee `limit`
    # amount of concurrently running code blocks.
    #
    # @example
    #   throttle = Redis::Throttle.new
    #
    #   # Allow max 2 concurrent execution units
    #   throttle.concurrency(:xxx, :limit => 2, :ttl => 10)
    #
    #   throttle.acquire(:token => "a") && :aye || :nay # => :aye
    #   throttle.acquire(:token => "b") && :aye || :nay # => :aye
    #   throttle.acquire(:token => "c") && :aye || :nay # => :nay
    #
    #   throttle.release(:token => "a")
    #
    #   throttle.acquire(:token => "c") && :aye || :nay # => :aye
    #
    #
    # @param (see Concurrency#initialize)
    # @return [Throttle] self
    def concurrency(bucket, limit:, ttl:)
      raise FrozenError, "can't modify frozen #{self.class}" if frozen?

      @strategies << Concurrency.new(bucket, :limit => limit, :ttl => ttl)

      self
    end

    # Add *rate limit* strategy to the throttle. Use it to guarantee `limit`
    # amount of units in `period` of time.
    #
    # @example
    #   throttle = Redis::Throttle.new
    #
    #   # Allow 2 execution units per 10 seconds
    #   throttle.rate_limit(:xxx, :limit => 2, :period => 10)
    #
    #   throttle.acquire && :aye || :nay # => :aye
    #   sleep 5
    #
    #   throttle.acquire && :aye || :nay # => :aye
    #   throttle.acquire && :aye || :nay # => :nay
    #
    #   sleep 6
    #   throttle.acquire && :aye || :nay # => :aye
    #   throttle.acquire && :aye || :nay # => :nay
    #
    # @param (see RateLimit#initialize)
    # @return [Throttle] self
    def rate_limit(bucket, limit:, period:)
      raise FrozenError, "can't modify frozen #{self.class}" if frozen?

      @strategies << RateLimit.new(bucket, :limit => limit, :period => period)

      self
    end

    # Merge in strategies of the `other` throttle.
    #
    # @example
    #   a = Redis::Throttle.concurrency(:a, :limit => 1, :ttl => 2)
    #   b = Redis::Throttle.rate_limit(:b, :limit => 3, :period => 4)
    #   c = Redis::Throttle
    #     .concurrency(:a, :limit => 1, :ttl => 2)
    #     .rate_limit(:b, :limit => 3, :period => 4)
    #
    #   a.merge!(b)
    #
    #   a == c # => true
    #
    # @return [Throttle] self
    def merge!(other)
      raise FrozenError, "can't modify frozen #{self.class}" if frozen?

      @strategies.merge(other.strategies)

      self
    end

    alias << merge!

    # Non-destructive version of {#merge!}. Returns new {Throttle} instance with
    # union of `self` and `other` strategies.
    #
    # @example
    #   a = Redis::Throttle.concurrency(:a, :limit => 1, :ttl => 2)
    #   b = Redis::Throttle.rate_limit(:b, :limit => 3, :period => 4)
    #   c = Redis::Throttle
    #     .concurrency(:a, :limit => 1, :ttl => 2)
    #     .rate_limit(:b, :limit => 3, :period => 4)
    #
    #   a.merge(b) == c # => true
    #   a == c          # => false
    #
    # @return [Throttle] new throttle
    def merge(other)
      dup.merge!(other)
    end

    alias | merge

    # Prevents further modifications to the throttle instance.
    #
    # @see https://docs.ruby-lang.org/en/master/Object.html#method-i-freeze
    # @return [Throttle] self
    def freeze
      @strategies.freeze

      super
    end

    # Returns `true` if the `other` is an instance of {Throttle} with the same
    # set of strategies.
    #
    # @example
    #   a = Redis::Throttle
    #     .concurrency(:a, :limit => 1, :ttl => 2)
    #     .rate_limit(:b, :limit => 3, :period => 4)
    #
    #   b = Redis::Throttle
    #     .rate_limit(:b, :limit => 3, :period => 4)
    #     .concurrency(:a, :limit => 1, :ttl => 2)
    #
    #   a == b # => true
    #
    # @return [Boolean]
    def ==(other)
      other.is_a?(self.class) && @strategies == other.strategies
    end

    alias eql? ==

    # Calls given block execution lock was acquired, and ensures to {#release}
    # it after the block.
    #
    # @example
    #   throttle = Redis::Throttle.concurrency(:xxx, :limit => 1, :ttl => 10)
    #
    #   throttle.call { :aye } # => :aye
    #   throttle.call { :aye } # => :aye
    #
    #   throttle.acquire
    #
    #   throttle.call { :aye } # => nil
    #
    # @param (see #acquire)
    # @return [Object] last satement of the block if execution lock was acquired.
    # @return [nil] otherwise
    def call(token: SecureRandom.uuid)
      return unless acquire(:token => token)

      begin
        yield
      ensure
        release(:token => token)
      end
    end

    # Acquire execution lock.
    #
    # @example
    #   throttle = Redis::Throttle.concurrency(:xxx, :limit => 1, :ttl => 10)
    #
    #   if (token = throttle.acquire)
    #     # ... do something
    #   end
    #
    #   throttle.release(:token => token) if token
    #
    # @see #call
    # @see #release
    # @param token [#to_s] Unit of work ID
    # @return [#to_s] `token` as is if lock was acquired
    # @return [nil] otherwise
    def acquire(token: SecureRandom.uuid)
      with_redis do |redis|
        keys = @strategies.map(&:key)
        argv = @strategies.flat_map(&:payload) << token.to_s << Time.now.to_i

        token if Script.eval(redis, keys, argv).zero?
      end
    end

    # Release acquired execution lock. Notice that this affects {#concurrency}
    # locks only.
    #
    # @example
    #   concurrency = Redis::Throttle.concurrency(:xxx, :limit => 1, :ttl => 60)
    #   rate_limit   = Redis::Throttle.rate_limit(:xxx, :limit => 1, :period => 60)
    #   throttle    = concurrency | rate_limit
    #
    #   throttle.acquire(:token => "uno")
    #   throttle.release(:token => "uno")
    #
    #   concurrency.acquire(:token => "dos") => "dos"
    #   rate_limit.acquire(:token => "dos")   => nil
    #
    # @see #acquire
    # @see #reset
    # @see #call
    # @param token [#to_s] Unit of work ID
    # @return [void]
    def release(token:)
      token = token.to_s

      with_redis do |redis|
        @strategies.each do |strategy|
          redis.zrem(strategy.key, token) if strategy.is_a?(Concurrency)
        end
      end

      nil
    end

    # Flush all counters.
    #
    # @example
    #   throttle = Redis::Throttle.concurrency(:xxx, :limit => 2, :ttl => 60)
    #
    #   thottle.acquire(:token => "a") # => "a"
    #   thottle.acquire(:token => "b") # => "b"
    #   thottle.acquire(:token => "c") # => nil
    #
    #   throttle.reset
    #
    #   thottle.acquire(:token => "c") # => "c"
    #   thottle.acquire(:token => "d") # => "d"
    #
    # @return [void]
    def reset
      with_redis { |redis| redis.del(*@strategies.map(&:key)) }

      nil
    end

    protected

    attr_accessor :strategies

    private

    # @yield [redis] Gives redis client to the block.
    # @return [Object] result of the block
    def with_redis
      return yield(@redis || Redis.current) unless @redis.is_a?(Proc)

      @redis.call { |redis| break yield redis }
    end
  end
end
