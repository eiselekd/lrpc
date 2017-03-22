#include "lua.h"
#include "lauxlib.h"
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <poll.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/socket.h>
#include <resolv.h>
#include <sys/time.h>
#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netinet/tcp.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/time.h>
#include <event.h>

static const char *hex = "0123456789abcdef";
#define MYNAME "lrpc"
#define MYVERSION MYNAME " library for " LUA_VERSION
#define MYTYPE "lrpc.remote"
#define TIMEOUT 10000

typedef struct {
    lua_State* loop_L;
    struct event_base* base;
    int errorMessage;
} le_base;

static int
strpack(lua_State *L)
{
    size_t l; int i;
    const char *b = luaL_checklstring(L, 1, &l);
    luaL_Buffer o;
#if LUA_VERSION_NUM < 502
    luaL_buffinit(L, &o);
#else
    luaL_buffinitsize(L, &o, l*2);
#endif
    luaL_addchar(&o, '"');
    for (i = 0; i < l; i++) {
        int v = b[i] & 0xff;
        if ((v<32 ||v>126)||v==34||v==92) {
            luaL_addchar(&o, '\\');
            luaL_addchar(&o, hex[v>>4]);
            luaL_addchar(&o, hex[v&0xf]);
        } else
            luaL_addchar(&o, v);
    }
    luaL_addchar(&o, '"');
    luaL_pushresult(&o);
    return 1;
}

static int
strunpack(lua_State *L)
{
    size_t l; char c, ch0, ch1; int j;
    size_t i = luaL_checkinteger(L ,1)-1 ;
    const char *b = luaL_checklstring(L, 2, &l);
    luaL_Buffer o;
    luaL_buffinit(L, &o);
    for (; i < l; i++) {
        switch((c=b[i])) {
        case '\\':
            if (1 != sscanf(b+i+1,"%02x", &j))
                return luaL_error(L, "Expecting escape string");
            luaL_addchar(&o,j);
            i+=2;
            break;
        case '"':
            lua_pushnumber(L, i+2);
            luaL_pushresult(&o);
            return 2;
        default:
            luaL_addchar(&o,c);
        }
    }
    return luaL_error(L, "Cannot unescape string");
}

static uint8_t
checksum(const char *b, size_t l)
{
    uint8_t c = 0;
    while (l--)
        c += *b++;
    return c;
}


static int
conn(lua_State* L)
{
    const char *f = luaL_checkstring(L, 1);
    const char *ptr = strchr(f, ':');
    if (ptr)
    {
        char n[ptr - f + 1];
        int port = atoi(ptr + 1);
        strncpy(n, f, ptr - f);
        n[ptr - f] = 0;

        struct hostent *host_info = gethostbyname(n);
        if (!host_info)
            return luaL_error(L, "Hostnamelookup failed\n");

        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));

        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = ((struct in_addr *)(host_info->h_addr))->s_addr;
        addr.sin_port = htons(port);

        printf("Start connect\n");

        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd == -1)
            return luaL_error(L, strerror(errno));

        int i=1;
        setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &i, 4);
        int status = connect(fd, (struct sockaddr *)&addr, sizeof(addr));
        if (status == -1)
        {
            close(fd);
            return luaL_error(L, strerror(errno));
        }
        lua_pushinteger(L, fd);
        printf("Connected %d\n", fd);
        return 1;
    }
    int fd = open(f, O_RDWR);
    if (fd<0)
        return luaL_error(L, strerror(errno));
    lua_pushinteger(L, fd);
    return 1;
}

typedef struct t_tcp_ {
    int sock;
} t_tcp;

static int
serv_create(lua_State *L)
{
    int servfd, intarg,fd;
    struct sockaddr_in server = {0};
    int portno = luaL_checkinteger(L ,1);

    servfd = socket(AF_INET, SOCK_STREAM, 0);
    if (servfd < 0)
        goto err;
    intarg = 1;
    if (setsockopt(servfd, SOL_SOCKET, SO_REUSEADDR, (char *)&intarg, sizeof(intarg)) < 0);
    intarg = 1;
    if (setsockopt(servfd, SOL_SOCKET, SO_BROADCAST, (const void *)&intarg, sizeof(intarg)) < 0);
    intarg = 1;
    if (setsockopt(servfd, IPPROTO_TCP, TCP_NODELAY, &intarg, sizeof(intarg)) < 0);

    server.sin_family = AF_INET;
    server.sin_addr.s_addr = INADDR_ANY;
    server.sin_port =  htons((unsigned short)portno);

    if (bind(servfd, (struct sockaddr *)&server, sizeof(server)) < 0)
        goto errc;

    if (listen(servfd, 5) < 0) ;

    lua_pushinteger(L, servfd);
    return 1;

errc:
    close(servfd);
err:
    return luaL_error(L, strerror(errno));

}

static int
serv_waitconn(lua_State *L)
{
    int intarg,fd; socklen_t len;
    struct sockaddr_in server = {0};
    int servfd = luaL_checkinteger(L ,1);
    fd = accept(servfd, (struct sockaddr *) &server,
                (socklen_t *)&len);
    if (fd < 0)
        goto errc;

    lua_pushinteger(L, fd);
    return 1;

errc:
    close(servfd);
err:
    return luaL_error(L, strerror(errno));

}

static const char LRPCBEGIN = 0xb0;
static const char LRPCEND = 0xb1;

static int
rec_msg(lua_State* L)
{
    enum {
        SCANB,
        SCANC,
        SCANE,
    } state = SCANB;
    int i = 0; uint8_t gcsum = 0;
    luaL_Buffer o;
    luaL_buffinit(L, &o);
    int fd = luaL_checkinteger(L, 1);
    if (fd == -1)
        fd = 0;
retry:
    i = 0;
    gcsum = 0;
    while (1) {
        struct pollfd fds;
        char c;
        fds.fd = fd;
        fds.events = POLLIN;
        fds.revents = 0;
        int status = poll(&fds, 1, TIMEOUT);
        if (status < 0)
            return luaL_error(L, strerror(errno));
        else if (status == 0)
            return luaL_error(L, "Timeout on read");
        else if (status != 1)
            return luaL_error(L, "Failed poll()");
        if (read(fd, &c, 1) != 1)
            return luaL_error(L, strerror(errno));

        switch (state) {
        case SCANB:
            if (c == LRPCBEGIN) {
                state = SCANC;
                i = 0;
            } else {
            }
            break;
        case SCANC:
            if (((c >= '0') && (c <= '9')) || ((c >= 'a') && (c <= 'f'))) {
                gcsum <<= 4;
                gcsum |= ((c >= '0') && (c <= '9')) ? (c - '0') : (c - 'a' + 10);
                i++;
                if (i >= 2) {
                    state = SCANE;
                    i = 0;
                }
            } else {
                state = SCANB;
                i = 0;
            }
            break;
        case SCANE:
            if (c == LRPCEND) {
                /* Done */
                i = 0;
                goto done;
            } else {
                luaL_addchar(&o, c);
            }
            break;
        }
    }
done:
    luaL_pushresult(&o);
    size_t l;
    const char *b = luaL_checklstring(L, -1, &l);
    if (gcsum != checksum(b, l)) {
        state = SCANB;
        lua_pop(L, 1);
        luaL_buffinit(L, &o);
        goto retry;
    }

    return 1;
}

static int
send_msg(lua_State* L)
{
    size_t l;
    int fd = luaL_checkinteger(L, 1);
    const char *i = luaL_checklstring(L, 2, &l);
    if (fd == -1) {
        fflush(stdout);
        fd = 1;
    }
    uint8_t c = checksum(i, l);
    char csum[4];
    snprintf(csum, sizeof(csum), "%c%02x", (char)LRPCBEGIN, c);
    size_t cnt = write(fd, csum, 3);
    cnt += write(fd, i, l);
    cnt += write(fd, &LRPCEND, 1);
    if (cnt != l + 4)
        return luaL_error(L, "Write failed");
    return 0;
}

static const luaL_Reg lrpclib[] = {
    {"strunpack", strunpack},
    {"strpack", strpack},
    {"rec_msg", rec_msg},
    {"send_msg", send_msg},
    {"clnt_conn", conn},
    {"serv_create", serv_create},
    {"serv_waitconn", serv_waitconn},
    {NULL, NULL}
};

#if !defined LUA_VERSION_NUM || LUA_VERSION_NUM==501
/*** Adapted from Lua 5.2.0 */
static void luaL_setfuncs (lua_State *L, const luaL_Reg *l, int nup) {
    luaL_checkstack(L, nup+1, "too many upvalues");
    for (; l->name != NULL; l++) {  /* fill the table with given functions */
        int i;
        lua_pushstring(L, l->name);
        for (i = 0; i < nup; i++)  /* copy upvalues to the top */
            lua_pushvalue(L, -(nup+1));
        lua_pushcclosure(L, l->func, nup);  /* closure with those upvalues */
        lua_settable(L, -(nup + 3));
    }
    lua_pop(L, nup);  /* remove upvalues */
}
#endif

LUALIB_API int luaopen_lrpc_core (lua_State *L) {

    luaL_newmetatable(L,MYTYPE);
    luaL_setfuncs(L,lrpclib,0);
    lua_pushliteral(L,"version");/** version */
    lua_pushliteral(L,MYVERSION);
    lua_settable(L,-3);
    lua_pushliteral(L,"__index");
    lua_pushvalue(L,-2);
    lua_settable(L,-3);
    return 1;
}

/*
  Local Variables:
  c-basic-offset:4
  c-file-style:"bsd"
  indent-tabs-mode:nil
  End:
*/
