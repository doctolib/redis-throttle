# frozen_string_literal: true

require "redis"
require "terminal-table"

REDIS =
  if ENV["REDIS_NAMESPACE"].to_s.strip.empty?
    Redis.current
  else
    require "redis-namespace"

    Redis::Namespace.new(ENV["REDIS_NAMESPACE"].to_s.strip, :redis => Redis.current)
  end

RSpec.configure do |config|
  config.before :suite do
    options = REDIS._client.options.slice(:url, :scheme, :host, :port, :db)
    options[:namespace] = REDIS.namespace if REDIS.respond_to?(:namespace)

    puts Terminal::Table.new({ :title => "REDIS", :rows => options })
  end

  config.before do
    Redis.current.flushdb
    Redis.current.script("flush")
  end
end
