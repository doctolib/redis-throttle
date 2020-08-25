# frozen_string_literal: true

require_relative "./throttle/errors"
require_relative "./throttle/version"
require_relative "./throttle/concurrency"
require_relative "./throttle/lock"
require_relative "./throttle/script"
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
      keys = []
      argv = []

      @strategies.each do |strategy|
        keys << strategy.bucket
        argv << strategy.lua_payload(token)
      end

      acquired = Script.instance.call(redis, :keys => keys, :argv => argv).zero?
      Lock.new(@strategies, :token => token) if acquired
    end
  end
end
