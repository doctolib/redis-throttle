# frozen_string_literal: true

require "redis/throttle/script"

RSpec.describe Redis::Throttle::Script do
  subject(:script) { described_class.instance }

  describe "#call" do
    it "raises ScriptError upon Lua runtime error" do
      expect { script.call(Redis.current, :keys => ["xxx"]) }
        .to raise_error(Redis::Throttle::ScriptError, %r{Error running script})
    end
  end
end
