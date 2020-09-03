for i=1, #ARGV, 4 do
  local strategy = ARGV[i]
  local key = table.concat({ KEYS[1], strategy, ARGV[i + 1], ARGV[i + 2], ARGV[i + 3] }, ":")

  redis.call("DEL", key)
end
