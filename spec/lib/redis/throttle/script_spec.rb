# frozen_string_literal: true

require "redis/throttle/script"

RSpec.describe Redis::Throttle::Script do
  describe ".eval" do
    it "calls EVALSHA when possible" do
      allow(Redis.current).to receive(:eval).and_call_original
      allow(Redis.current).to receive(:evalsha).and_call_original

      (Redis.current.respond_to?(:namespace) ? Redis.current.redis : Redis.current).script("flush")

      3.times { described_class.eval(Redis.current) }

      aggregate_failures do
        expect(Redis.current).to have_received(:eval).once
        expect(Redis.current).to have_received(:evalsha).thrice
      end
    end

    it "raises ScriptError upon Lua runtime error" do
      expect { described_class.eval(Redis.current, ["xxx"], ["yyy"]) }
        .to raise_error(Redis::Throttle::ScriptError, %r{Error running script})
    end
  end
end
