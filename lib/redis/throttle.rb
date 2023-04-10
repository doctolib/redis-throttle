# frozen_string_literal: true

require_relative "../redis_throttle"

class Redis
  # @deprecated Use ::RedisThrottle
  class Throttle < RedisThrottle
    class << self
      attr_accessor :silence_deprecation_warning
    end

    self.silence_deprecation_warning = false

    def initialize(*args, **kwargs, &block)
      super(*args, **kwargs, &block)

      return if self.class.silence_deprecation_warning

      warn "#{self.class} usage was deprecated, please use RedisThrottle instead"
    end
  end
end
