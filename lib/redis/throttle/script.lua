local now = tonumber(ARGV[#ARGV])
local locks = {}
local strategies = {
  threshold = function (bucket, limit, period)
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

  concurrency = function (bucket, token, limit, ttl)
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
  local name, payload = unpack(cjson.decode(ARGV[i]))

  if not strategies[name](bucket, unpack(payload)) then
    return 1
  end
end

for _, lock in ipairs(locks) do
  lock()
end

return 0
