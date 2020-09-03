local now = tonumber(ARGV[#ARGV])
local token = ARGV[#ARGV - 1]
local locks = {}
local strategies = {
  rate_limit = function (key, limit, period)
    if limit <= redis.call("LLEN", key) and now - redis.call("LINDEX", key, -1) < period then
      return false
    end

    table.insert(locks, function ()
      redis.call("LPUSH", key, now)
      redis.call("LTRIM", key, 0, limit - 1)
      redis.call("EXPIRE", key, period)
    end)

    return true
  end,

  concurrency = function (key, limit, ttl)
    redis.call("ZREMRANGEBYSCORE", key, "-inf", "(" .. now)

    if redis.call("ZCARD", key) < limit or redis.call("ZSCORE", key, token) then
      table.insert(locks, function ()
        redis.call("ZADD", key, now + ttl, token)
        redis.call("EXPIRE", key, ttl)
      end)

      return true
    end

    return false
  end
}

for i=1, #ARGV - 2, 4 do
  local strategy = ARGV[i]
  local key = table.concat({ KEYS[1], strategy, ARGV[i + 1], ARGV[i + 2], ARGV[i + 3] }, ":")

  if not strategies[strategy](key, tonumber(ARGV[i + 2]), tonumber(ARGV[i + 3])) then
    return 1
  end
end

for _, lock in ipairs(locks) do
  lock()
end

return 0
