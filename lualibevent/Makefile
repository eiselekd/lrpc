#
# levent: lua libevent binding
# (c) 2009 Javier Guerra G.
#

LUA_VERSION?=5.2
LUA_CFLAGS=-g $(shell pkg-config lua$(LUA_VERSION) --cflags)
LUA_LDFLAGS=-g $(shell pkg-config lua$(LUA_VERSION) --libs)

# Compilation parameters
CC = gcc
CWARNS = -Wall -pedantic \
        -Waggregate-return \
        -Wcast-align \
        -Wmissing-prototypes \
        -Wstrict-prototypes \
        -Wnested-externs \
        -Wpointer-arith \
        -Wshadow \
        -Wwrite-strings


CFLAGS = $(CONFIG) $(CWARNS) -std=gnu99 -g -O2 -fPIC $(LUA_CFLAGS)


all : levent.so

levent.o : levent.c

levent.so : levent.o
	ld -o levent.so -shared levent.o -levent $(LUA_LDFLAGS)

clean:
	rm *.o *.so core core.* a.out


test:
	lua5.2 test.lua
