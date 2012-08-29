module(..., package.seeall)

verbose = true
host = "foo.com"
port = 23

-- can be channel or user.
-- make sure to set channels to join list as well as here.
logtarget = "#channel"

-- data to send on connect. lua table key-value pairs are sent line by line,
-- in 'key: value' format.
authdata = {
  Action = "login",
  ActionID = 1,
  Username = "john",
  Secret = "password"
}

-- event matchers. the key is the 'Event' to match, and
-- the value is a table of strings, which represent the
-- fields from the event to print.
eventmatchers = {
  Cdr = { "Destination", "CallerID" },
  MeetmeJoin = { "Usernum", "CallerIDnum", "CallerIDname" }
}

