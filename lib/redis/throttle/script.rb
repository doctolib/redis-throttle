# frozen_string_literal: true

require "digest"
require "singleton"
require "redis/errors"

require_relative "./errors"

class Redis
  class Throttle
    # Simple helper to run script by it's sha1 digest with fallbak to script
    # load if it was not loaded yet.
    class Script
      include Singleton

      # Redis error fired when script ID is unkown.
      NOSCRIPT = "NOSCRIPT"
      private_constant :NOSCRIPT

      LUA_ERROR_MESSAGE = %r{
        ERR\s
        (?<message>Error\s(?:compiling|running)\sscript\s\(.*?\)):\s
        (?:[^:]+:\d+:\s)+
        (?<details>.+)
      }x.freeze
      private_constant :LUA_ERROR_MESSAGE

      def initialize
        @source = File.read("#{__dir__}/script.lua").freeze
        @digest = Digest::SHA1.hexdigest(@source)
      end

      def call(redis, keys: [], argv: [])
        __call__(redis, :keys => keys, :argv => argv)
      rescue Redis::CommandError => e
        md = LUA_ERROR_MESSAGE.match(e.message.to_s)
        raise unless md

        raise ScriptError, [md[:message], md[:details]].compact.join(": ")
      end

      private

      def __call__(redis, keys:, argv:)
        redis.evalsha(@digest, keys, argv)
      rescue Redis::CommandError => e
        raise unless e.message.include?(NOSCRIPT)

        redis.eval(@source, keys, argv)
      end
    end
  end
end
