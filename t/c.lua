

remote = lrpc.connect("localhost:8081");
remote.root.o1.call1(1);
o = remote.root.o2.getobj();
o.func();

--  Local Variables:
--  c-basic-offset:4
--  c-file-style:"bsd"
--  indent-tabs-mode:nil
--  End:
