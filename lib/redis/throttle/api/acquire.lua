local now = tonumber(ARGV[#ARGV])
local token = ARGV[#ARGV - 1]
local locks = {}
local strategies = {
  rate_limit = function (bucket, limit, period)
    if limit <= redis.call("LLEN", bucket) and now - redis.call("LINDEX", bucket, -1) < period then
      return false
    end

    table.insert(locks, function ()
      redis.call("LPUSH", bucket, now)
      redis.call("LTRIM", bucket, 0, limit - 1)
      redis.call("EXPIRE", bucket, period)
    end)

    return true
  end,

  concurrency = function (bucket, limit, ttl)
    redis.call("ZREMRANGEBYSCORE", bucket, "-inf", "(" .. now)

    if redis.call("ZCARD", bucket) < limit or redis.call("ZSCORE", bucket, token) then
      table.insert(locks, function ()
        redis.call("ZADD", bucket, now + ttl, token)
        redis.call("EXPIRE", bucket, ttl)
      end)

      return true
    end

    return false
  end
}

for i, bucket in ipairs(KEYS) do
  local offset = (i - 1) * 3

  if not strategies[ARGV[offset + 1]](bucket, tonumber(ARGV[offset + 2]), tonumber(ARGV[offset + 3])) then
    return 1
  end
end

for _, lock in ipairs(locks) do
  lock()
end

return 0
