# frozen_string_literal: true

require_relative "./throttle/errors"
require_relative "./throttle/version"
require_relative "./throttle/concurrency"
require_relative "./throttle/lock"
require_relative "./throttle/threshold"

# @see https://github.com/redis/redis-rb
class Redis
  # Distributed threshold and concurrency throttling.
  class Throttle
    def initialize
      @strategies = []
    end

    def <<(strategy)
      raise TypeError unless strategy.is_a?(Concurrency) || strategy.is_a?(Threshold)

      @strategies << strategy

      self
    end

    def call(redis, token:)
      lock = acquire(redis, :token => token)
      return lock unless block_given?

      begin
        yield if lock
      ensure
        lock&.release(redis)
      end
    end

    private

    def acquire(redis, token:)
      acquired = @strategies.take_while { |strategy| strategy.acquire(redis, :token => token) }
      return Lock.new(acquired, :token => token) if acquired.size == @strategies.size

      acquired.reverse_each { |strategy| strategy.release(redis, :token => token) }
      nil
    end
  end
end
