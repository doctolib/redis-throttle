# frozen_string_literal: true

require "redis/throttle/script"

RSpec.describe Redis::Throttle::Script do
  subject(:script) { described_class.new(lua_script) }

  let(:lua_script) { "return redis.call('GET', KEYS[1]) * ARGV[1]" }

  describe "#call" do
    before do
      REDIS.set("abc", 2)
    end

    it "executes Lua script" do
      expect(script.call(REDIS, :keys => ["abc"], :argv => [656])).to eq 1312
    end

    context "when script was not loaded yet" do
      it "runs EVAL to run the script" do
        allow(REDIS).to receive(:eval).and_call_original
        allow(REDIS).to receive(:evalsha).and_call_original

        script.call(REDIS, :keys => ["abc"], :argv => [656])

        aggregate_failures do
          expect(REDIS).to have_received(:evalsha).ordered
          expect(REDIS).to have_received(:eval).ordered
        end
      end
    end

    context "when script was already loaded" do
      before { script.call(REDIS, :keys => ["abc"], :argv => [1]) }

      it "uses EVALSHA" do
        allow(REDIS).to receive(:evalsha).and_call_original

        script.call(REDIS, :keys => ["abc"], :argv => [656])

        expect(REDIS).to have_received(:evalsha)
      end

      it "avoids EVAL" do
        allow(REDIS).to receive(:eval).and_call_original

        script.call(REDIS, :keys => ["abc"], :argv => [656])

        expect(REDIS).not_to have_received(:eval)
      end
    end

    context "when script execution fails" do
      let(:lua_script) { "return non_existing_variable" }

      it "raises LuaError" do
        expect { script.call(REDIS) }
          .to raise_error(Redis::Throttle::LuaError, %r{Error running script})
      end
    end

    context "when script comilation fails" do
      let(:lua_script) { "!!!" }

      it "raises LuaError" do
        expect { script.call(REDIS) }
          .to raise_error(Redis::Throttle::LuaError, %r{Error compiling script})
      end
    end
  end
end
