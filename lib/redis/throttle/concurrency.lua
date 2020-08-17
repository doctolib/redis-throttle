local bucket, token, limit, ttl, now =
  KEYS[1], ARGV[1], tonumber(ARGV[2]), tonumber(ARGV[3]), tonumber(ARGV[4])

redis.call("ZREMRANGEBYSCORE", bucket, "-inf", "(" .. now)

if redis.call("ZCARD", bucket) < limit or redis.call("ZSCORE", bucket, token) then
  redis.call("ZADD", bucket, now + ttl, token)
  redis.call("EXPIRE", bucket, ttl)

  return 0
end

return 1
