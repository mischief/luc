module("adventure", package.seeall)

local status, apr = pcall(require, 'apr')
if not status then
  pcall(require, 'luarocks.loader')
  apr = require 'apr'
end

local posix = require 'posix'

local ADVENTURE_BIN = '/home/mischief/code/lua/apr/bsdgames-2.17/adventure/adventure'

-- irc object handle
local irch
local sendcb = function() end

-- child process handle
local child
-- child process pipe handles
local pio = {}

-- poll objects for async io with child
local pset

-- we have to make a socket object out of the pipe to use apr.pollset
local insock

-- SIGCHLD handler
local sigchild = function()
  -- wait here.
  print('Caught SIGCHLD') os.exit(1)
end

-- write a newline terminated string command to the child process
write = function(str)
  local done, why, code = child:wait(false)
  if done == false then
    pio.pin:write(str, '\n')
    pio.pin:flush()
  end
end

init = function(irc, sendfunc)

  irch = irc
  sendcb = sendfunc

  apr.signal('SIGCHLD', sigchild)

  child = assert(apr.proc_create(ADVENTURE_BIN) )

  child:cmdtype_set('program')
  child:io_set('child-block', 'parent-block', 'parent-block')
  child:exec{}

  pio = { 
    pin = child:in_get(),
    pout = child:out_get(),
    perr = child:err_get()
  }

  insock = apr.socket_create()
  insock:fd_set(pio.pout:fd_get())

  pset = apr.pollset(1)
  pset:add(insock, 'input')

  -- avoid intro
  write('n')

end

loop = function()

  local r, w = pset:poll(100000)

  if not r and w then
    print('poll error: ', w)
  else
    for k,v in pairs(r) do
      v:timeout_set(1000000)
      for l in v:lines() do
        if irch then
          -- write to irc
          --irch:sendChat("#adventure", l:gsub('\n', ''))
          l = l:gsub('\n', '')
          sendcb("#adventure", l)
        else
          print(l)
        end
      end
    end

  end
end

