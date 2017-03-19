inspect = require("t.inspect");
lrpc = require("lrpc");
print(lrpc.ser(1,2,3,4));
local _,a = lrpc.deser(nil, "" ..
                     lrpc.ser({
                        one=0,
                        two=true,
                        tree=false,
                        four="str"
                     }), 1);
print(inspect(a));

--  Local Variables:
--  c-basic-offset:4
--  c-file-style:"bsd"
--  indent-tabs-mode:nil
--  End:
