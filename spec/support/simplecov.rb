# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  command_name "REDIS_NAMESPACE=#{ENV['REDIS_NAMESPACE']}"
end
