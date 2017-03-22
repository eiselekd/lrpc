lrpc = require("lrpc");

fd  = lrpc.clnt_conn("localhost:8081");
print("[+] connect " .. fd);

mt = {};
mt.send = function (c)
   lrpc.send_msg(fd, c);
   lrpc.debug("[>] %p" % {c})
   return r;
end
mt.recv = function (...)
   local r = lrpc.rec_msg(fd);
   lrpc.debug("[<] %p" % {r})
   return r;
end
c = {sock=fd};
setmetatable(c, {__index= mt});

remote = lrpc.connect(c);
print("[+] start");

remote.getobj().c();

--  Local Variables:
--  c-basic-offset:4
--  c-file-style:"bsd"
--  indent-tabs-mode:nil
--  End:
