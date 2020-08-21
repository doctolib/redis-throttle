# frozen_string_literal: true

require_relative "./concurrency"

# @see https://github.com/redis/redis-rb
class Redis
  class Throttle
    class Lock
      def initialize(strategies, token:)
        @strategies = strategies
        @token      = token
      end

      def release(redis)
        @strategies.reverse_each do |strategy|
          strategy.release(redis, :token => @token) if strategy.is_a? Concurrency
        end
      end
    end
  end
end
