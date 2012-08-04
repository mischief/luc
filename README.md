luc: lua irc bot
================

check me out
------------

    git://github.com/mischief/luc.git

fetch my submodules
-------------------

    cd luc
    git submodule init
    git submodule update

configure me
------------

write a config.lua script like this

    
    local info = {
      nick = "luc",
      username = "luc",
      realname = "luc",
      server = "chat.freenode.net",
      port = "7000",
      secure = true,
      channels = { "#noisebridge" },

      char = ".",

      version = "luc - https://github.com/mischief/luc"
    }

    return info

then run me with

    lua luc.lua config.lua

enjoy.
------

