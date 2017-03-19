local lrpc = require"lrpc.core";

local isserv = 1

--- pack an argument list into a table.
if not table.pack then
   function table.pack (...)
      return {n=select('#',...); ...}
   end
end

function lrpc.ser(...)
   local r = {}
   local args = table.pack(...)
   for i=1, args.n do
      local a = args[i]
      local typ = type(a);
      if (a == nil) then
         table.insert(r,"n")
      elseif typ == "boolean" then
         if (a) then
            table.insert(r,"t");
         else
            table.insert(r,"f");
         end
      elseif typ == "number" then
         table.insert(r,'#');
         table.insert(r,a);
      elseif typ == "string" then
         table.insert(r,lrpc.strpack(a));
      elseif typ == "table" then
         table.insert(r,"{");
         for k,v in pairs(a) do
            table.insert(r,lrpc.ser(k))
            table.insert(r,lrpc.ser(v))
         end
         table.insert(r,"}");
      elseif typ == "userdata" then
         local m = getmetatable(a)
         table.insert(r,"@");
         table.insert(r,m.getid(a));
      else
         error("Unsupported type");
      end
   end
   return table.concat(r);
end

function lrpc.deser(e,str,idx)
   local i = idx;
   local g;
   local l = #str;
   local ret = {}
   ret.n = 0;
   while i <= l do
      local v;
      local c = str:sub(i,i);
      i = i + 1;
      if c == "n" then
         v = nil;
      elseif c == "t" then
         v = true;
      elseif c == "f" then
         v = false;
      elseif c == '"' then
         i, v = lrpc.strunpack(i, str)
      elseif c == '#' then
         local a,b = str:find("[0-9]+",i);
         v = tonumber(str:sub(i,b))
         i = b+1;
      elseif c == '@' then
         local a,b = str:find("[0-9]+",i);
         v = tonumber(str:sub(i,b))
         if isserv then
            v = lrpc.objs[v]
         else
            v = getmetatable(e).new(r,v)
         end
         i = b+1;
      elseif c == '{' then
         i,g = lrpc.deser(e, str, i)
         v = {}
         for j=1,#g,2 do
            v[g[j]] = g[j+1]
         end
      elseif c == '}' then
         break;
      elseif c == 'e' then
         i,g = lrpc.deser(e, str, i)
         error(g[1]);
      else
         error('Parse error in "' .. str .. '"')
      end
      ret.n = ret.n + 1;
      ret[ret.n] = v;
   end
   return i, ret
end

function lrpc.proxy(o)
   local r = {}
   if (o == nil) then
      local m = {}
      setmetatable(r,m)
   else
      setmetatable(r,getmetatable(o))
   end
   return r
end

function lrpc.connect(conn)

   local o = lrpc.proxy(nil)
   local m = getmetatable(o)

   function remote(self, c, ...)
      local m = getmetatable(self)
      local line = command .. m.getid(self) .. ser(...)
      repeat
         conn.send(l)
         s,c = pcall(conn.recv)
         if not s then
            c = nil
         end
      until c
      local lm, r = deser(self, 1, c, false)
      return table.unpack(r,1,r.n)
   end

   m.__index = function (self, k)
      return remote(self, "[", k)
   end
   m.__newindex = function (self, k, v)
      return remote(self, "=", k, v)
   end
   m.__len  = function (self)
      return remote(self, "#")
   end
   m.__call = function (self,...)
      return remote(self, "c", ...)
   end
   m.__gc = function (self,...)
   end
   m.__pairs = function (self,...)
      local g = lrpc.new_obj(self, 0);
      local p = remote(self, "[", "pairs");
      return remote(p, "c", self);
   end
   m.__ipairs = function (self,...)
      local g = lrpc.new_obj(self, 0);
      local p = remote(self, "[", "ipairs");
      return remote(p, "c", self);
   end
   return o
end

function lrpc.lrpc_server()
   local o, d, obj, al, e
   repeat
      local s,c = pcall(recvcmd);
      if (s and c) then
         d = c.sub(1,1)
         o = c.match("^%d+",2)
         al = c.sub(#o + 2)
         o = tonumber(o)
         obj = objs[o]
         local _, args = deser(e,1,al)
         r = {}
         r.n = 0
         if c == "c" then
            r = table.pack(o(table.unpack(args, 1, args.n)))
         elseif c == "[" then
            r[1] = o[args[1]]
            r.n = 1
         elseif c == "=" then
            o[args[1]] = args[2]
         elseif c == "#" then
            r[1] = #o
            r.n = 1
         elseif c == "~" then

         else
            error ("Unknown command");
         end
         lrpc.send(ser(table.unpack(r, 1, r.n)))
      end
   until false;
end

return lrpc

--  Local Variables:
--  c-basic-offset:4
--  c-file-style:"bsd"
--  indent-tabs-mode:nil
--  End:
