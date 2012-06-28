irc = require "irc"
jit = require "jit"

local sleep = require "socket".sleep

local info = assert(dofile("config.lua"), "can't load config.lua")

local function setquota(sec)
--   print("setquota " .. sec)
   if sec == 0 then debug.sethook(); return end
   local st = os.clock()
   function check(wat)
      if os.clock() - st > sec then
	 debug.sethook() -- disable hook
	 error("time limit exceeded")
      end
   end
   debug.sethook(check, "", 50000)
end

local function runcode(code, sec, env)
   local untrusted, msg = loadstring(code)
   if not untrusted then return nil, msg end
   setfenv(untrusted, env)
   return pcall(untrusted)
end

local envs = {}

s = irc.new(info)

local create_env

local commands = {}

-- help: list all irc bot commands
commands.help = function(target, from)
  local c = {}
  local i = 1

  for k,v in pairs(commands) do
    c[i] = k
    i = i + 1
  end

  s:sendChat(target, from .. ": commands: " .. table.concat(c, ", "))
end

-- run some lua code in a sandbox
commands.eval = function(target, from, code)
    code = code:gsub("^=", "return ")
    local fn, err = loadstring(code)
    if not fn then
      s:sendChat(target, from .. ": Error loading code: " .. code .. err:match(".*(:.-)$"))
      return
    else
	 envs[from] = envs[from] or create_env()
	 setfenv(fn, envs[from])
	 setquota(1) -- set hook
         jit.off()
	 local result = {pcall(fn)}
         jit.on()
	 debug.sethook() -- unset hook
	 local success = table.remove(result, 1)
	 if not success then
	    local err = result[1]:match(".*: (.-)$")
	    s:sendChat(target, from .. ": Error running code: " .. code .. ": " .. err)
	 else
	    if result[1] == nil then s:sendChat(target, from .. ": nil")
	    else
	       for i,v in ipairs(result) do result[i] = tostring(v) end
	       s:sendChat(target, from .. ": " .. table.concat(result, ", "))
	    end
	 end
    end
  end

-- clear: wipes user's lua environment
commands.clear = function(target, from)
  s:sendChat(target, from .. ": Clearing your environment")
  envs[from] = create_env()
end

-- get a fortune
commands.fortune = function(target, from)
  local handle = io.popen('/usr/bin/env fortune -as ')
  local l = handle:read()
  while l ~= nil do
    s:sendChat(target, from .. ": " .. l:gsub('\t', '  '))
    l = handle:read()
  end
  handle:close()
end

-- join
commands.join = function(target, from, arg)
  if arg ~= nil then
    s:sendNotice(from, "Joining " .. arg)
    s:join(arg)
  end
end
-- part
commands.part = function(target, from, arg)
  if arg ~= nil then
    s:sendNotice(from, "Parting " .. arg)
    s:part(arg)
  end
end

create_env = function()
   return {
      s = s,
      co = commands,
      _VERSION =      _VERSION,
      assert =         assert,
      collectgarbage = collectgarbage,
      error =          error,
      getfenv =        getfenv,
      getmetatable =   getmetatable,
      ipairs =         ipairs,
      loadstring =     loadstring,
      next =           next,
      pairs =          pairs,
      pcall =          pcall,
      rawequal =       rawequal,
      rawget =         rawget,
      rawset =         rawset,
      select =         select,
      setfenv =        setfenv,
      setmetatable =   setmetatable,
      tonumber =       tonumber,
      tostring =       tostring,
      type =           type,
      unpack =         unpack,
      xpcall =         xpcall,
      coroutine =      coroutine,
      math =           math,
      string =         string,
      table =          table,
   }
end

local onraw = function(line)
  print(("%q"):format(line))

  if line:match('login wasszup') then return true end

  -- version reply
  local usr = line:match(':(%w+)!')
  local msg = line:match('\001VERSION\001')
  if usr and msg then
    s:sendNotice(usr, ('\001VERSION %s\001'):format(info.version))
  end
end

local onchat = function(user, chan, msg)

  print(("[%s] %s: %s"):format(chan,user.nick,msg))

  msg = msg:gsub("^" .. info.nick .. "[:,>] ", "!eval ")

  local is_cmd, cmd, arg = msg:match("^(%" .. info.char .. ")([%w_]+) ?(.-)$")

  if is_cmd and commands[cmd] then
     res, err = pcall(commands[cmd], chan, user.nick, arg)
     if not res then
	   print("Error calling '" .. cmd .. "' -> " .. err)
	 end
  end

end

s:hook("OnRaw", onraw)
s:hook("OnChat", onchat)

print('connecting with')
print(unpack(info))

s:connect(info.server)

for k,v in pairs(info.channels) do
  s:join(v)
end

while true do
  s:think()
  sleep(0.5)
end

