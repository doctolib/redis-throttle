local usage = {}

for i=1, #ARGV, 4 do
  local strategy = ARGV[i]
  local key = table.concat({ KEYS[1], strategy, ARGV[i + 1], ARGV[i + 2], ARGV[i + 3] }, ":")

  if "concurrency" == strategy then
    table.insert(usage, redis.call("ZCARD", key))
  elseif "rate_limit" == strategy then
    table.insert(usage, redis.call("LLEN", key))
  end
end

return usage
