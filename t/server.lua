local luaevent = require("luaevent")
local socket = require("socket")

local function echoHandler(skt)
  while true do
    local data,ret = luaevent.receive(skt, 10)
    if data == "quit" or ret == 'closed' then
      break
    end
    luaevent.send(skt, data)
    collectgarbage()
  end
  skt:close()
  --print("DONE")
end

local server = assert(socket.bind("localhost", 8081))
server:settimeout(0)
local coro = coroutine.create
coroutine.create = function(...)
	local ret = coro(...)
	return ret
end

luaevent.addserver(server, echoHandler)
luaevent.loop()




--  Local Variables:
--  c-basic-offset:4
--  c-file-style:"bsd"
--  indent-tabs-mode:nil
--  End:
