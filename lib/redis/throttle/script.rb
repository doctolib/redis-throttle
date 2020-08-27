# frozen_string_literal: true

require "digest"
require "redis/errors"

require_relative "./errors"

class Redis
  class Throttle
    # @api private
    #
    # Lazy-compile and run acquire script by it's sha1 digest.
    module Script
      # Redis error fired when script ID is unkown.
      NOSCRIPT = "NOSCRIPT"
      private_constant :NOSCRIPT

      SOURCE = File.read("#{__dir__}/script.lua").freeze
      private_constant :SOURCE

      DIGEST = Digest::SHA1.hexdigest(SOURCE).freeze
      private_constant :DIGEST

      LUA_ERROR_MESSAGE = %r{
        ERR\s
        (?<message>Error\s(?:compiling|running)\sscript\s\(.*?\)):\s
        (?:[^:]+:\d+:\s)+
        (?<details>.+)
      }x.freeze
      private_constant :LUA_ERROR_MESSAGE

      class << self
        def eval(redis, keys = [], argv = [])
          __eval__(redis, keys, argv)
        rescue Redis::CommandError => e
          md = LUA_ERROR_MESSAGE.match(e.message.to_s)
          raise unless md

          raise ScriptError, [md[:message], md[:details]].compact.join(": ")
        end

        private

        def __eval__(redis, keys, argv)
          redis.evalsha(DIGEST, keys, argv)
        rescue Redis::CommandError => e
          raise unless e.message.include?(NOSCRIPT)

          redis.eval(SOURCE, keys, argv)
        end
      end
    end
  end
end
