# frozen_string_literal: true

require "redis"
require "terminal-table"

REDIS_NAMESPACE = ENV["REDIS_NAMESPACE"].to_s.strip
Redis.current =
  if REDIS_NAMESPACE.empty?
    Redis.new
  else
    require "redis-namespace"

    Redis::Namespace.new(REDIS_NAMESPACE, :redis => Redis.new)
  end

RSpec.configure do |config|
  config.before :suite do
    options = Redis.current._client.options.slice(:url, :scheme, :host, :port, :db)
    options[:namespace] = Redis.current.namespace if Redis.current.respond_to?(:namespace)

    puts Terminal::Table.new({ :title => "REDIS", :rows => options })
  end

  config.before do
    redis = Redis.current.respond_to?(:namespace) ? Redis.current.redis : Redis.current

    redis.flushdb
    redis.script("flush")
  end
end
