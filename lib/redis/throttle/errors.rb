# frozen_string_literal: true

class Redis
  class Throttle
    class Error < StandardError; end
    class ScriptError < Error; end

    class FrozenError < RuntimeError; end if RUBY_VERSION < "2.5"
  end
end
