local now = tonumber(ARGV[#ARGV])
local usage = {}

for i=1, #ARGV - 1, 4 do
  local strategy = ARGV[i]
  local key = table.concat({ KEYS[1], strategy, ARGV[i + 1], ARGV[i + 2], ARGV[i + 3] }, ":")

  if "concurrency" == strategy then
    redis.call("ZREMRANGEBYSCORE", key, "-inf", "(" .. now)
    table.insert(usage, redis.call("ZCARD", key))
  elseif "rate_limit" == strategy then
    local cutoff = now - tonumber(ARGV[i + 3])
    local last   = tonumber(redis.call("LINDEX", key, -1) or now)

    while last < cutoff do
      redis.call("RPOP", key)
      last = tonumber(redis.call("LINDEX", key, -1) or now)
    end

    table.insert(usage, redis.call("LLEN", key))
  end
end

return usage
