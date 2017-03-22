lrpc = require("lrpc");

server = lrpc.serv_create(8081);
print("[+] "..server);
fd = lrpc.serv_waitconn(server);

mt = {};
c = { sock=fd }
setmetatable(c, {__index= mt});
function mt.send(c)
   lrpc.debug("[>] %p" % {c})
   lrpc.send_msg(fd, c);
   return r;
end
function mt.recv (...)
   local r = lrpc.rec_msg(fd);
   lrpc.debug("[<] %p" % {r})
   return r;
end

simple = SimpleClass:create()
simple.c = function (...) return 1; end;

root = {
   getnum = function (...)
      return 2;
   end,
   gettab = function (...)
      return {a=1,b=2 };
   end,
   getstr = function (...)
      return "hello";
   end,
   getnil = function (...)
      return nil;
   end,
   getobj = function (...)
      return simple
   end
};

tgt = lrpc.tgtlocal(root);
lrpc.lrpc_server(tgt,c);

--  Local Variables:
--  c-basic-offset:4
--  c-file-style:"bsd"
--  indent-tabs-mode:nil
--  End:
