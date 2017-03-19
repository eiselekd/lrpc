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

SimpleClass = {}
SimpleClass_mt = { __index = SimpleClass }
function SimpleClass:create()
   local new_inst = {}    -- the new instance
   setmetatable( new_inst, SimpleClass_mt ) -- all instances share the same metatable
   return new_inst
end
simple = SimpleClass:create()
simple.c = function (...) return 1; end;

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
      return simple
   end
};

tgt = lrpc.tgtlocal(tgtroot);
tgtwrap = lrpc.tgtproxy(tgt,true);

print(tgtwrap.getnum());
print(tgtwrap.gettab());
--print(tgtwrap.getstr());
--print(tgtwrap.getnil());

--tgtwrap.getobj().c();



--  Local Variables:
--  c-basic-offset:4
--  c-file-style:"bsd"
--  indent-tabs-mode:nil
--  End:
