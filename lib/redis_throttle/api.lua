if 1 ~= #KEYS or 0 == #ARGV then
  return redis.error_reply("syntax error")
end

local commands = {}

commands.ACQUIRE = {
  params = { "strategies", "token", "timestamp" },
  handler = function (params)
    local now   = params.timestamp
    local token = params.token
    local locks = {}

    local acquire = {
      rate_limit = function (strategy)
        local key, limit, period = strategy.key, strategy.limit, strategy.period

        if redis.call("LLEN", key) < limit or tonumber(redis.call("LINDEX", key, -1)) < now then
          return function ()
            redis.call("LPUSH", key, now + period)
            redis.call("LTRIM", key, 0, limit - 1)
            redis.call("EXPIRE", key, period)
          end
        end
      end,

      concurrency = function (strategy)
        local key, limit, ttl = strategy.key, strategy.limit, strategy.ttl

        redis.call("ZREMRANGEBYSCORE", key, "-inf", "(" .. now)

        if redis.call("ZCARD", key) < limit or redis.call("ZSCORE", key, token) then
          return function ()
            redis.call("ZADD", key, now + ttl, token)
            redis.call("EXPIRE", key, ttl)
          end
        end
      end
    }

    for _, strategy in ipairs(params.strategies) do
      local lock = acquire[strategy.name](strategy)

      if lock then
        table.insert(locks, lock)
      else
        return 1
      end
    end

    for _, lock in ipairs(locks) do
      lock()
    end

    return 0
  end
}

commands.RELEASE = {
  params = { "strategies", "token" },
  handler = function (params)
    for _, strategy in ipairs(params.strategies) do
      if "concurrency" == strategy.name then
        redis.call("ZREM", strategy.key, params.token)
      end
    end

    return redis.status_reply("ok")
  end
}

commands.RESET = {
  params = { "strategies" },
  handler = function (params)
    for _, strategy in ipairs(params.strategies) do
      redis.call("DEL", strategy.key)
    end

    return redis.status_reply("ok")
  end
}

commands.INFO = {
  params = { "strategies", "timestamp" },
  handler = function (params)
    local usage, now = {}, params.timestamp

    for _, strategy in ipairs(params.strategies) do
      local key = strategy.key

      if "concurrency" == strategy.name then
        redis.call("ZREMRANGEBYSCORE", key, "-inf", "(" .. now)
        table.insert(usage, redis.call("ZCARD", key))
      elseif "rate_limit" == strategy.name then
        local last = tonumber(redis.call("LINDEX", key, -1) or now)

        while last < now do
          redis.call("RPOP", key)
          last = tonumber(redis.call("LINDEX", key, -1) or now)
        end

        table.insert(usage, redis.call("LLEN", key))
      end
    end

    return usage
  end
}

local function parse_params (parts)
  local parse = {}

  function parse.strategies (pos)
    local strategies = {}

    while pos + 3 <= #ARGV do
      local name, strategy = string.lower(ARGV[pos]), nil
      local bucket, limit, ttl_or_period = ARGV[pos + 1], tonumber(ARGV[pos + 2]), tonumber(ARGV[pos + 3])

      if "concurrency" == name then
        strategy = { name = name, bucket = bucket, limit = limit, ttl = ttl_or_period }
      elseif "rate_limit" == name then
        strategy = { name = name, bucket = bucket, limit = limit, period = ttl_or_period }
      else
        break
      end

      if bucket and 0 < limit and 0 < ttl_or_period then
        strategy.key = table.concat({ KEYS[1], name, bucket }, ":")
        table.insert(strategies, strategy)

        pos = pos + 4
      else
        return { err = "invalid " .. name .. " options" }
      end
    end

    if 0 == #strategies then
      return { err = "missing strategies" }
    end

    return { val = strategies, pos = pos }
  end

  function parse.token (pos)
    if ARGV[pos] and ARGV[pos + 1] and "TOKEN" == string.upper(ARGV[pos]) then
      return { val = ARGV[pos + 1], pos = pos + 2 }
    end

    return { err = "missing or invalid token" }
  end

  function parse.timestamp (pos)
    if ARGV[pos] and ARGV[pos + 1] and "TS" == string.upper(ARGV[pos]) then
      local timestamp = tonumber(ARGV[pos + 1])

      if 0 < timestamp then
        return { val = timestamp, pos = pos + 2 }
      end
    end

    return { err = "missing or invalid timestamp" }
  end

  local params, pos = {}, 2

  for _, part in ipairs(parts) do
    local out = parse[part](pos)

    if out.err then
      return out
    end

    params[part] = out.val
    pos = out.pos
  end

  if pos < #ARGV then
    return { err = "wrong number of arguments" }
  end

  return { val = params }
end

local command = commands[string.upper(ARGV[1])]
if not command then
  return redis.error_reply("invalid command")
end

local params = parse_params(command.params)
if params.err then
  return redis.error_reply(params.err)
end

return command.handler(params.val)
