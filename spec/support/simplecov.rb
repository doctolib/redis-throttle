# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  enable_coverage :branch

  add_filter "/gemfiles/"
  add_filter "/spec/"
  add_filter "/vendor/"
end
