# frozen_string_literal: true

require "timecop"

Timecop.safe_mode = true

RSpec.configure do |config|
  config.around(:each, :frozen_time) do |example|
    Timecop.freeze(Time.at(Time.now.to_i), &example)
  end
end
