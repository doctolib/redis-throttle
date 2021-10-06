# frozen_string_literal: true

class Redis
  class Throttle
    class Error < StandardError; end

    class ScriptError < Error; end
  end
end
