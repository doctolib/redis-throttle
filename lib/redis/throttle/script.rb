# frozen_string_literal: true

require "digest"
require "redis/errors"

require_relative "./errors"

class Redis
  class Throttle
    # @api private
    #
    # Lazy-compile and run acquire script by it's sha1 digest.
    class Script
      # Redis error fired when script ID is unkown.
      NOSCRIPT = "NOSCRIPT"
      private_constant :NOSCRIPT

      LUA_ERROR_MESSAGE = %r{
        ERR\s
        (?<message>Error\s(?:compiling|running)\sscript)
        \s\([^()]+\):\s
        (?:@[^:]+:\d+:\s)?
        [^:]+:(?<loc>\d+):\s
        (?<details>.+)
      }x.freeze
      private_constant :LUA_ERROR_MESSAGE

      def initialize(source)
        @source = -source.to_s
        @digest = Digest::SHA1.hexdigest(@source).freeze
      end

      def call(redis, keys: [], argv: [])
        __eval__(redis, keys, argv)
      rescue Redis::CommandError => e
        md = LUA_ERROR_MESSAGE.match(e.message.to_s)
        raise unless md

        raise ScriptError, "#{md[:message]} @#{md[:loc]}: #{md[:details]}"
      end

      private

      def __eval__(redis, keys, argv)
        redis.evalsha(@digest, keys, argv)
      rescue Redis::CommandError => e
        raise unless e.message.include?(NOSCRIPT)

        redis.eval(@source, keys, argv)
      end
    end
  end
end
