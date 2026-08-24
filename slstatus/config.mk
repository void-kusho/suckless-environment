# slstatus version
VERSION = 1.1

# customize below to fit your system

# paths
PREFIX = /usr/local
MANPREFIX = $(PREFIX)/share/man

PKG_CONFIG = pkg-config

X11INC = $(shell $(PKG_CONFIG) --variable=includedir xorg-server 2>/dev/null || echo /usr/X11R6/include)
X11LIB = $(shell $(PKG_CONFIG) --variable=libdir xorg-server 2>/dev/null || echo /usr/X11R6/lib)

# flags
CPPFLAGS = -I$(X11INC) -D_DEFAULT_SOURCE -DVERSION=\"${VERSION}\"
CFLAGS   = -std=c99 -pedantic -Wall -Wextra -Wno-unused-parameter -Os
LDFLAGS  = -L$(X11LIB) -s
# OpenBSD: add -lsndio
# FreeBSD: add -lkvm -lsndio
LDLIBS   = -lX11

# compiler and linker
CC = cc
