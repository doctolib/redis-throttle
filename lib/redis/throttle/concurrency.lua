local bucket, token, limit, ttl, now =
  KEYS[1], ARGV[1], tonumber(ARGV[2]), tonumber(ARGV[3]), tonumber(ARGV[4])

redis.call("ZREMRANGEBYSCORE", bucket, "-inf", "(" .. now)

if limit <= redis.call("ZCARD", bucket) and not redis.call("ZSCORE", bucket, token) then
  return 1
end

redis.call("ZADD", bucket, now + ttl, token)
redis.call("EXPIRE", bucket, ttl)

return 0
