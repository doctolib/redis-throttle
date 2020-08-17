local bucket, limit, period, now =
  KEYS[1], tonumber(ARGV[1]), tonumber(ARGV[2]), tonumber(ARGV[3])

if limit <= redis.call("LLEN", bucket) and now - redis.call("LINDEX", bucket, -1) < period then
  return 1
end

redis.call("LPUSH", bucket, now)
redis.call("LTRIM", bucket, 0, limit - 1)
redis.call("EXPIRE", bucket, period)

return 0
