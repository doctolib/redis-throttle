# frozen_string_literal: true

class Redis
  class Throttle
    class Threshold
      # @!attribute [r] bucket
      #   @return [String] Throttling group name
      attr_reader :bucket

      # @!attribute [r] limit
      #   @return [Integer] Max allowed units per {#period}
      attr_reader :limit

      # @!attribute [r] period
      #   @return [Integer] Period in seconds
      attr_reader :period

      # @param bucket [#to_s] Throttling group name
      # @param limit [#to_i] Max allowed units per `period`
      # @param period [#to_i] Period in seconds
      def initialize(bucket, limit:, period:)
        @bucket = -bucket.to_s
        @limit  = limit.to_i
        @period = period.to_i
      end

      # @api private
      def key
        "throttle:#{@bucket}:t:#{@limit}:#{@period}"
      end

      # @api private
      def payload
        ["threshold", @limit, @period]
      end

      # @api private
      #
      # Returns `true` if `other` is a {Threshold} instance with the same
      # {#bucket}, {#limit}, and {#period}.
      #
      # @see https://docs.ruby-lang.org/en/master/Object.html#method-i-eql-3F
      # @param other [Object]
      # @return [Boolean]
      def ==(other)
        equal?(other) || (other.is_a?(self.class) && key == other.key)
      end

      alias eql? ==

      # @api private
      #
      # Compare `self` with `other` strategy:
      #
      # - Returns `nil` if `other` is neither {Concurrency} nor {Threshold}
      # - Returns `-1` if `other` is a {Concurrency}
      # - Returns `1` if `other` is a {Threshold} with lower {#limit}
      # - Returns `0` if `other` is a {Threshold} with the same {#limit}
      # - Returns `-1` if `other` is a {Threshold} with bigger {#limit}
      #
      # @return [-1, 0, 1, nil]
      def <=>(other)
        complexity <=> other.complexity if other.respond_to? :complexity
      end

      # @api private
      #
      # Generates an Integer hash value for this object.
      #
      # @see https://docs.ruby-lang.org/en/master/Object.html#method-i-hash
      # @return [Integer]
      def hash
        key.hash
      end

      # @api private
      #
      # @return [Array(Integer, Integer)] Strategy complexity pseudo-score
      def complexity
        [0, @limit]
      end
    end
  end
end
