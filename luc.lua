package.path = "./deps/?/init.lua;./deps/?.lua;" .. package.path
print(package.path)
irc = assert(require "irc", "can't find irc.lua")
pcall(function() return require'jit' end)

local sleep = require "socket".sleep
local cfg = arg[1] or "config.lua"
local sleep = assert(require "socket".sleep, "can't find socket.sleep")

local info = assert(dofile(cfg), "can't load '" .. cfg .. "'")

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

-- sandbox a functional call by limiting its execution time and environment.
-- does not help with lua code like ("."):rep(10^10).
local function sandbox(fn, env, sec)
  local result

  setfenv(fn, env)
  setquota(sec)

  if jit then jit.off() end

  result = {pcall(fn)}

  if jit then jit.on() end

  -- unset hook
  setquota(0)

  return result
end

local envs = {}

s = irc.new(info)

local create_env

local commands = {}

-- help: list all irc bot commands
commands.help = function(target, from)
  local c = {}

  for k,v in pairs(commands) do
    c[#c+1] = k
  end

  s:sendNotice(from, ": commands: " .. table.concat(c, ", "))
end

-- clear: wipes user's lua environment
commands.clear = function(target, from)
  envs[from] = create_env()
  s:sendNotice(from, "environment cleared")
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

-- print system uname
commands.uname = function(t, f)
  local h = io.popen('/usr/bin/env uname -a')
  s:sendChat(t, h:read())
  h:close()

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

-- sandbox stuff
local printq = {}

local resetq = function() printq = {} end
local checkq = function() return #printq > 20 end
local getq = function(target) 
   if #printq > 0 then
      return table.concat(printq, ' ')
   else
      return ''
   end
end

create_env = function()

   -- override of print for sandbox
   local newprint = function(...)
      for n=1,select('#',...) do
	 if checkq() then break end
	 local e = select(n,...)
	 local estr = tostring(e):gsub('\n', '\\n '):sub(1,24)
	 printq[#printq+1] = estr
      end
   end

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
      print =          newprint,
   }
end

-- run some lua code in a sandbox
commands.eval = function(target, from, code)
  code = code:gsub("^=", "return ")
  local fn, err = loadstring(code)
  if not fn then
    s:sendChat(target, from .. ": Error loading code: " .. code .. err:match(".*(:.-)$"))
    return
  end

	envs[from] = envs[from] or create_env()

  local result = sandbox(fn, envs[from], 1)
	local success = table.remove(result, 1)
	if not success then
	  local err = result[1]:match(".*: (.-)$")
	  s:sendChat(target, from .. ": Error running code: " .. code .. ": " .. err)
	else
	  for i=1,#result do
	    if not result[i] then result[i] = 'nil' end
	  end

--	if result[1] == nil then s:sendChat(target, from .. ": nil")
--	else
	  for i,v in ipairs(result) do
		  result[i] = tostring(v)
	  end
	  s:sendChat(target, from .. ": " .. getq() .. " ret: " .. table.concat(result, ", "):gsub('\n', '\\n '))
--	end
	end
	resetq()
end

-- irc callbacks
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

  msg = msg:gsub("^" .. info.nick .. "[:,>] ", info.char .. "a ")

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

print("loading config '" .. cfg .. "'")
--print(unpack(info))

s:connect(info.server)

for k,v in pairs(info.channels) do
  s:join(v)
end

a = require 'adventure'

local sendAdventure = function(target, str)
  s:sendChat(target, str)
end

a.init(s, sendAdventure)

commands.a = function(target, from, msg)
  a.loop()
  a.write(msg)
  a.loop()
end

while true do
  s:think()
  sleep(0.1)
end

