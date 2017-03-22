LUA_VERSION?=5.2
LUA_CFLAGS=-g $(shell pkg-config lua$(LUA_VERSION) --cflags)
LUA_LDFLAGS=-g $(shell pkg-config lua$(LUA_VERSION) --libs)

lrpc/core.so: lrpc.c
	mkdir -p lrpc
	gcc $(LUA_CFLAGS) -Og -fpic -c -o lrpc.o lrpc.c
	gcc $(LUA_LDFLAGS)  -shared -fpic -o lrpc/core.so lrpc.o

luaevent/core.so:
	cd luaevent; $(CC) $(LUA_CFLAGS) -fpic -c -Iinclude  src/*.c
	cd luaevent; $(CC) $(LUA_LDFLAGS) -O -shared -fpic  -o core.so *.o -levent
	if [ ! -h luaevent.lua ]; then ln -s luaevent/lua/luaevent.lua; fi

socket/core.so: $(wildcard luasocket/src/*.c)
	cd luasocket/src; make clean; make LUAV=$(LUA_VERSION) linux
	mkdir -p socket
	cd socket; \
		ln -sf ../luasocket/src/socket-3.0-rc1.so core.so; \
		ln -sf ../luasocket/src/unix.so unix.so; \
		ln -sf ../luasocket/src/mime-1.0.3.so mime.so; \
		ln -sf ../luasocket/src/serial.so serial.so;
	ln -sf luasocket/src/socket.lua socket.lua;



clean:
	rm -rf *.o *.so lrpc/core.so


luarocks:
	luarocks --local make rockspecs/lrpc/lrpc-0.0.1-1.rockspec

test:
	lua5.2 t/test.lua



apt:
	sudo apt-get install liblua5.2-dev
	sudo apt-get build-dep liblua5.2-dev
	mkdir -p b; cd b; apt-get source liblua5.2-dev;

# pip install hererocks
here:
	hererocks env5.1 -r 2.3.0 --lua 5.1
	hererocks env5.2 -r 2.3.0 --lua 5.2
	hererocks env5.3 -r 2.3.0 --lua 5.3

apt-libevent:
	mkdir -p bevent; cd bevent;export DEB_BUILD_OPTIONS="debug nostrip noopt";fakeroot apt-get source -b libevent1-dev

apt-libevent-i:
	cd bevent; sudo dpkg -i *.deb

apt-c5.2:
	-rm -rf b5.2/*
	mkdir -p b5.2; cd b5.2;export DEB_BUILD_OPTIONS="debug nostrip noopt";fakeroot apt-get source -b liblua5.2-dev
	mkdir -p b5.2; cd b5.2;export DEB_BUILD_OPTIONS="debug nostrip noopt";fakeroot apt-get source -b lua5.2

apt-c5.2-i:
	cd b5.2; sudo dpkg -i *.deb

apt-c5.1:
	-rm -rf b5.1/*
	mkdir -p b5.1; cd b5.1;export DEB_BUILD_OPTIONS="debug nostrip noopt";fakeroot apt-get source -b liblua5.1-0-dev
	mkdir -p b5.1; cd b5.1;export DEB_BUILD_OPTIONS="debug nostrip noopt";fakeroot apt-get source -b lua5.1-0

apt-c5.1-i:
	cd b5.1; sudo dpkg -i *.deb
