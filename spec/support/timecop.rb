# frozen_string_literal: true

require "timecop"

Timecop.safe_mode = true

RSpec.configure do |config|
  config.around(:each, :frozen_time) { |example| Timecop.freeze(Time.now.utc, &example) }
end
