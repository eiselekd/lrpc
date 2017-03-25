local lrpc = require"lrpc.core";

local isserv = 1

--- pack an  argument list into a table.
if not table.pack then
   function table.pack (...)
      return {n=select('#',...); ...}
   end
end

--- python style % format
getmetatable("").__mod = function(f, p)
   local r = {};
   local l = #f
   if not p then
      return format
   end
   if not type(p) == "table" then
      p = table.pack(p)
   end
   local i = 0;
   while i <= l do
      local c = f:sub(i,i);
      if c == '%' and i+1 <= l then
         local o = f:sub(i,l):match("^%%%d*[dsp]")
         --print("o:" .. o);
         local d = o:sub(#o,#o)
         i = i + #o - 1
         local a = table.remove(p,1)
         if d == 'd' or d == 's' then
            table.insert(r, string.format(o,a));
         elseif d == 'p' then
            table.insert(r,lrpc.pprint2str(a));
         else
            table.insert(r,"<undef>");
         end
      else
         table.insert(r, c);
      end
      i = i + 1;
   end
   return table.concat(r);
end

function lrpc.pprint_(o,ind,vis)
   local typ = type(o)
   if (typ == "nil") then
      return "nil"
   elseif (typ == "boolean") then
      if o then
         return "true"
      else
         return "false"
      end
   elseif typ == "number" then
      return string.format("%d (0x%x)", o, o);
   elseif typ == "string" then
      return string.format("%q",o)
   elseif typ == "function" then
      return tostring(o)
   elseif typ == "thread" then
      return string.format("thread (%s)",o:status())
   elseif typ == "table" then
      local keys = {}
      for k,_ in pairs(o) do
         table.insert(keys, k)
      end
      local c = function(a,b)
         local na = tonumber(a)
         local nb = tonumber(b)
         if na and nb then
            return na < nb
         else
            return tostring(a) < tostring(b)
         end
      end
      table.sort(keys, c);
      vis[o] = 1
      local ind_ = ind .. "  "
      local r = {"{\n"}
      for j=1,#keys do
         local k = keys[j]
         local v = o[k]
         table.insert(r, ind_)
         if (type(v) == "table") and vis[v] then
            if type(k) == "number" then
               table.insert(r, string.format("[%d] = {...}\n",k))
            else
               table.insert(r, tostring(key))
               table.insert(r, " = {...}\n")
            end
         elseif type(k) == "number" then
            table.insert(r, string.format("[%d] = ",k))
            table.insert(r, lrpc.pprint_(v, ind_, vis))
            table.insert(r, "\n")
         else
            table.insert(r, tostring(k))
            table.insert(r, " = ")
            table.insert(r, lrpc.pprint_(v, ind_, vis))
            table.insert(r, "\n")
         end
      end
      table.insert(r, ind)
      table.insert(r, "}")
      return table.concat(r)
   else
      --error("Unsupported type ".. typ)
   end
   return ""
end

function lrpc.pprint2str(...)
   p = table.pack(...)
   local v = {}
   local r = {}
   for i=1,p.n do
      r[i] = lrpc.pprint_(p[i], "", v)
   end
   return (table.concat(r, " "))
end

function lrpc.pprint(...)
   print(lrpc.pprint2str(...))
end

function lrpc.debug(...)
   print(...)
end

function lrpc.ser(self,...)
   local r = {}
   local args = table.pack(...)
   --lrpc.debug("[?] %p" % {args})
   for i=1,args.n do
      local a = args[i]
      --lrpc.debug("[=] %p" % {a})
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
            table.insert(r,lrpc.ser(self,k))
            table.insert(r,lrpc.ser(self,v))
         end
         table.insert(r,"}");
      elseif typ == "userdata" then
         local m = getmetatable(a)
         table.insert(r,"@");
         table.insert(r,m.getid(a));
      else
         --print(".");
         local id
         local o = self.objs;
         if not self.objs[a] == nil then
            self.objs[a][2] = self.objs[a][2] + 1 ;
            id = self.objs[a][1]
         else
            id = self.nextid;
            self.nextid = self.nextid + 1
            self.objs[a] = { id, 1 };
            self.objs[id] = a;

            --print (":"..id);
            --print (a);

         end
         table.insert(r,"@");
         table.insert(r,id);
      end
   end
   return table.concat(r);
end




function lrpc.deser(self, str, idx, isserv)
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
            v = self.objs[v]
         else
            v = getmetatable(self).new(self,v)
         end
         i = b+1;
      elseif c == '{' then
         i,g = lrpc.deser(self, str, i, isserv)
         v = {}
         for j=1,#g,2 do
            v[g[j]] = g[j+1]
         end
      elseif c == '}' then
         break;
      elseif c == 'e' then
         i,g = lrpc.deser(self, str, i, isserv)
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

   m.ids = setmetatable({}, { __mode = "k" })
   m.ids[o] = "2"
   m.defer_cleanup = {};

   function rcall_send(self, l)
      local m = getmetatable(self)
      repeat
         -- executed locally, send cmd to target and read reply 
         conn:send(l);
         s,c = pcall(function (...) return conn:recv(); end);
         if not s then
            c = nil
         end
      until c
      local lm, r = lrpc.deser(self, c, 1, false)
      return table.unpack(r,1,r.n)
   end

   function rcall(self, c, ...)
      if #m.defer_cleanup > 0 then
         rcall_send(self, "~" .. table.concat(m.defer_cleanup, "#"))
         meta.need_cleanup = {}
      end
      return rcall_send(self, c .. m.getid(self) .. lrpc.ser(self,...));
   end

   m.getid = function (self, k)
      local m = getmetatable(self)
      return m.ids[self]
   end
   m.new = function (self, k)
      local o = lrpc.proxy(self)
      m.ids[o] = tostring(k)
      return o
   end
   m.__index = function (self, k)
      return rcall(self, "[", k)
   end
   m.__newindex = function (self, k, v)
      return rcall(self, "=", k, v)
   end
   m.__len  = function (self)
      return rcall(self, "#")
   end
   m.__call = function (self,...)
      return rcall(self, "c", ...)
   end
   m.__gc = function (self,...)
      local id = m.ids[self]
      table.insert(m.defer_cleanup, id)
      m.ids[self] = nil
   end
   m.__pairs = function (self,...)
      local g = m.new(self, 0);
      local p = rcall(g, "[", "pairs");
      return rcall(p, "c", self);
   end
   m.__ipairs = function (self,...)
      local g = m.new(self, 0);
      local p = rcall(g, "[", "ipairs");
      return rcall(p, "c", self);
   end
   return o
end

function lrpc.lrpc_server_one(self,c)
   d = c:sub(1,1)
   o = c:match("^%d+",2)
   al = c:sub(#o + 2)
   local o = tonumber(o)
   --lrpc.pprint(self.objs);
   --print(self);
   --print(o);
   o = self.objs[o]
   --print(o);

   local _, args = lrpc.deser(self,al,1,true)
   r = {}
   r.n = 0
   if d == "c" then
      r = table.pack(o(table.unpack(args, 1, args.n)))
   elseif d == "[" then
      print(args[1]);
      --print(o);
      r[1] = o[args[1]]
      r.n = 1
   elseif d == "=" then
      o[args[1]] = args[2]
   elseif d == "#" then
      r[1] = #o
      r.n = 1
   elseif d == "~" then

   else
      error ("Unknown command:" .. d .. ":" .. c);
   end
   return r
end

function lrpc.lrpc_server(tgt,conn)
   local o, d, obj, al, e
   repeat
      -- executed remotely, read command and send reply 
      local s,c = pcall(function (...) return conn:recv(); end);
      if (s and c) then
         --lrpc.debug("[>] %p" % {c})
         r = lrpc.lrpc_server_one(tgt,c);
         --lrpc.pprint(r);
         r = lrpc.ser(tgt,table.unpack(r, 1, r.n));
         conn:send(r)
      end
   until false;
end

function lrpc.tgtlocal(root)
   local o = {
      r = root,
      nextid = 3,
      objs = { } };
   o.objs[0] = _ENV;
   o.objs[_ENV] = {0, 1};
   o.objs[2] = root;
   o.objs[root] = {2, 1}
   return setmetatable(o, lrpc);
   --local o = lrpc.proxy(nil)
end

function lrpc.tgtproxy(conn,testmode)

   if testmode then
      -- in testmode conn is the target object and is called directly by overriding send and recv
      local ret = "";
      local m = getmetatable(conn);
      function m.send(self,c)
         lrpc.debug("[<] %p" % {c})
         local r = conn.lrpc_server_one(conn,c)
         ret = lrpc.ser(conn,table.unpack(r, 1, r.n))
         return r;
      end
      function m.recv (self,...)
         lrpc.debug("[>] %p" % {ret})
         return ret;
      end
   end
   return lrpc.connect(conn)
end

return lrpc

--  Local Variables:
--  c-basic-offset:4
--  c-file-style:"bsd"
--  indent-tabs-mode:nil
--  End:
