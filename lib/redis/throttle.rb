# frozen_string_literal: true

require_relative "throttle/errors"
require_relative "throttle/version"
require_relative "throttle/concurrency"
require_relative "throttle/threshold"

# @see https://github.com/redis/redis-rb
class Redis
  # Distributed threshold and concurrency throttling.
  module Throttle; end
end
