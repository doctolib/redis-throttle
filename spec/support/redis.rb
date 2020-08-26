# frozen_string_literal: true

require "redis"
require "terminal-table"

REDIS_NAMESPACE = ENV["REDIS_NAMESPACE"].to_s.strip
REDIS =
  if REDIS_NAMESPACE.empty?
    Redis.new
  else
    require "redis-namespace"

    Redis::Namespace.new(REDIS_NAMESPACE, :redis => Redis.new)
  end

RSpec.configure do |config|
  config.before :suite do
    options = REDIS._client.options.slice(:url, :scheme, :host, :port, :db)
    options[:namespace] = REDIS.namespace if REDIS.respond_to?(:namespace)

    puts Terminal::Table.new({ :title => "REDIS", :rows => options })
  end

  config.before do
    (REDIS.respond_to?(:namespace) ? REDIS.redis : REDIS).flushdb

    Redis.current = REDIS
  end
end
