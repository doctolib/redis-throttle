local token = ARGV[#ARGV]

for i=1, #ARGV - 1, 4 do
  local strategy = ARGV[i]
  local key = table.concat({ KEYS[1], strategy, ARGV[i + 1], ARGV[i + 2], ARGV[i + 3] }, ":")

  if "concurrency" == strategy then
    redis.call("ZREM", key, token)
  end
end
