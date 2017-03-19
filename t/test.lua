inspect = require("t.inspect");
lrpc = require("lrpc");
print(lrpc.ser(nil,1,2,3,4));
local _,a = lrpc.deser(nil, "" ..
                     lrpc.ser(nil,{
                        one=0,
                        two=true,
                        tree=false,
                        four="str"
                     }), 1);
print(inspect(a));

--a = lrpc.connect(0)
--lrpc.pprint(getmetatable(a));
--lrpc.pprint(a);
--lrpc.pprint(getmetatable(lrpc));
--lrpc.pprint(lrpc);

tgtroot = {
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
   end
};

tgt = lrpc.tgtlocal(tgtroot);

tgtwrap = lrpc.tgtproxy(tgt,1);

print("---");
tgtwrap.getnum();
--tgtwrap.gettab();
--tgtwrap.getstr();
--tgtwrap.getnil();

--tgtwrap.getobj.c();



--  Local Variables:
--  c-basic-offset:4
--  c-file-style:"bsd"
--  indent-tabs-mode:nil
--  End:
