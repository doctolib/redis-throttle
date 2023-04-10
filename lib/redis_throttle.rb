# frozen_string_literal: true

require "concurrent/set"
require "securerandom"

require_relative "./redis_throttle/api"
require_relative "./redis_throttle/class_methods"
require_relative "./redis_throttle/concurrency"
require_relative "./redis_throttle/rate_limit"
require_relative "./redis_throttle/version"

class RedisThrottle
  extend ClassMethods

  # @param (see Api#initialize)
  def initialize(redis: nil)
    # TODO: fix api cloning/duping
    @api        = Api.new(redis: redis)
    @strategies = Concurrent::Set.new
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
  #   throttle = RedisThrottle.new
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

    @strategies << Concurrency.new(bucket, limit: limit, ttl: ttl)

    self
  end

  # Add *rate limit* strategy to the throttle. Use it to guarantee `limit`
  # amount of units in `period` of time.
  #
  # @example
  #   throttle = RedisThrottle.new
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

    @strategies << RateLimit.new(bucket, limit: limit, period: period)

    self
  end

  # Merge in strategies of the `other` throttle.
  #
  # @example
  #   a = RedisThrottle.concurrency(:a, :limit => 1, :ttl => 2)
  #   b = RedisThrottle.rate_limit(:b, :limit => 3, :period => 4)
  #   c = RedisThrottle
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
  #   a = RedisThrottle.concurrency(:a, :limit => 1, :ttl => 2)
  #   b = RedisThrottle.rate_limit(:b, :limit => 3, :period => 4)
  #   c = RedisThrottle
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

  alias + merge

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
  #   a = RedisThrottle
  #     .concurrency(:a, :limit => 1, :ttl => 2)
  #     .rate_limit(:b, :limit => 3, :period => 4)
  #
  #   b = RedisThrottle
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
  #   throttle = RedisThrottle.concurrency(:xxx, :limit => 1, :ttl => 10)
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
    return unless acquire(token: token)

    begin
      yield
    ensure
      release(token: token)
    end
  end

  # Acquire execution lock.
  #
  # @example
  #   throttle = RedisThrottle.concurrency(:xxx, :limit => 1, :ttl => 10)
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
    token if @api.acquire(strategies: @strategies, token: token.to_s)
  end

  # Release acquired execution lock. Notice that this affects {#concurrency}
  # locks only.
  #
  # @example
  #   concurrency = RedisThrottle.concurrency(:xxx, :limit => 1, :ttl => 60)
  #   rate_limit  = RedisThrottle.rate_limit(:xxx, :limit => 1, :period => 60)
  #   throttle    = concurrency + rate_limit
  #
  #   throttle.acquire(:token => "uno")
  #   throttle.release(:token => "uno")
  #
  #   concurrency.acquire(:token => "dos") # => "dos"
  #   rate_limit.acquire(:token => "dos")  # => nil
  #
  # @see #acquire
  # @see #reset
  # @see #call
  # @param token [#to_s] Unit of work ID
  # @return [void]
  def release(token:)
    @api.release(strategies: @strategies, token: token.to_s)

    nil
  end

  # Flush all counters.
  #
  # @example
  #   throttle = RedisThrottle.concurrency(:xxx, :limit => 2, :ttl => 60)
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
    @api.reset(strategies: @strategies)

    nil
  end

  # Return usage info for all strategies of the throttle.
  #
  # @example
  #   throttle.info.each do |strategy, current_value|
  #     # ...
  #   end
  #
  # @return (see Api#info)
  def info
    @api.info(strategies: @strategies)
  end

  protected

  attr_accessor :strategies
end
