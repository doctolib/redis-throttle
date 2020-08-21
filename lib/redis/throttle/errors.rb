# frozen_string_literal: true

class Redis
  class Throttle
    class Error < StandardError; end
    class LuaError < Error; end
  end
end
