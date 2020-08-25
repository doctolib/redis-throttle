# frozen_string_literal: true

require "redis"
require "terminal-table"

if ENV["Redis.current_NAMESPACE"].to_s.strip.empty?
  Redis.current = Redis.new
else
  require "redis-namespace"

  Redis.current = Redis::Namespace.new(ENV["Redis.current_NAMESPACE"].to_s.strip, :redis => Redis.new)
end

RSpec.configure do |config|
  config.before :suite do
    options = Redis.current._client.options.slice(:url, :scheme, :host, :port, :db)
    options[:namespace] = Redis.current.namespace if Redis.current.respond_to?(:namespace)

    puts Terminal::Table.new({ :title => "Redis.current", :rows => options })
  end

  config.before do
    redis = Redis.current.respond_to?(:namespace) ? Redis.current.redis : Redis.current

    redis.flushdb
    redis.script("flush")
  end
end
