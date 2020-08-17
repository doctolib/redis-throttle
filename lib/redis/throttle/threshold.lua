local bucket, token, limit, period, now =
  KEYS[1], ARGV[1], tonumber(ARGV[2]), tonumber(ARGV[3]), tonumber(ARGV[4])

redis.call("ZREMRANGEBYSCORE", bucket, "-inf", tostring(now - period))

if redis.call("ZCARD", bucket) < limit then
  redis.call("ZADD", bucket, now, token)
  redis.call("EXPIRE", bucket, period)

  return 0
end

return 1
