module(..., package.seeall)

local socket = require"socket"

local config = assert(require("deshicom.config"), "can't load asterisk config")

local telnetsocket
local linebuf = {}
local irccon

init = function(ircc)

  assert(ircc)
  irccon = ircc

  telnetsocket = socket:tcp()
  assert(telnetsocket:connect(config.host, config.port))
  telnetsocket:settimeout(0.001)

  for k,v in pairs(config.authdata) do
    telnetsocket:send(k .. ': ' .. v .. '\n')
  end

  telnetsocket:send('\n')

end

handledat = function(dat)
  local matches = config.eventmatchers

  for k,v in pairs(matches) do
    if dat.Event and dat.Event == k then
      local out = "Asterisk: "
      out = out .. "Event: " .. k

      for _, field in pairs(v) do
        out = out .. " " .. field .. ": " .. dat[field]
      end

      irccon:send("PRIVMSG " .. config.logtarget .. " :\001ACTION " .. out .. "\001")
    end
  end
end

update = function()
  local line, err = telnetsocket:receive()

  if line == nil then
    if err == 'timeout' then
      return
    elseif err == 'close' then
      print('error: telnet server connection close')
    end
  elseif line == "" then
    handledat(linebuf)
    linebuf = {}
    if config.verbose then print('-- Mark --') end
  else
    local k, v = line:match("(.+):%s+(.+)")
    if not k then
    else
      linebuf[k] = v
      if config.verbose then print('Telnet says: "' .. k .. '": "' .. v  .. '"') end
    end
  end

end
