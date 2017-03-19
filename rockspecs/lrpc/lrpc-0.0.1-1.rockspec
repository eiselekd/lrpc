package="lrpc"
version="0.0.1-1"
source = {
   url = "https://github.com/eiselekd/lrpc/archive/v0.4.3.tar.gz",
   dir = "lrpc-0.0.1",
}
description = {
   summary = "rpc lib",
   detailed = [[
       Call functions remotely using lua
   ]],
   homepage = "https://github.com/eiselekd/lrpc",
   license = "MIT"
}
external_dependencies = {
   EVENT = {
      header = "event.h",
      library = "event",
   }
}
build = {
   type = "builtin",
   modules = {
      ["lrpc.core"] = {
         sources = { "lrpc.c" }
      },
      ["lrpc"] = "lrpc.lua",
   },
   copy_directories = { "doc", "t" },
}
