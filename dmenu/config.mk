# dmenu version
VERSION = 5.4

# paths
PREFIX = /usr/local
MANPREFIX = $(PREFIX)/share/man

PKG_CONFIG = pkg-config

X11INC = $(shell $(PKG_CONFIG) --variable=includedir xorg-server 2>/dev/null || echo /usr/X11R6/include)
X11LIB = $(shell $(PKG_CONFIG) --variable=libdir xorg-server 2>/dev/null || echo /usr/X11R6/lib)

# Xinerama, comment if you don't want it
XINERAMALIBS  = -lXinerama
XINERAMAFLAGS = -DXINERAMA

# freetype
FREETYPELIBS = -lfontconfig -lXft
# NOTE: --variable=includedir returns the PARENT of the freetype headers
# (/usr/include), not the directory holding ft2build.h.  Only --cflags
# gets it right, and it is correct on Arch and in the Guix store alike.
FREETYPECFLAGS = $(shell $(PKG_CONFIG) --cflags freetype2 2>/dev/null || echo -I/usr/include/freetype2)
# OpenBSD (uncomment)
#FREETYPEINC = $(X11INC)/freetype2
#MANPREFIX = ${PREFIX}/man

# includes and libs
INCS = -I$(X11INC) $(FREETYPECFLAGS)
LIBS = -L$(X11LIB) -lX11 $(XINERAMALIBS) $(FREETYPELIBS)

# flags
CPPFLAGS = -D_DEFAULT_SOURCE -D_BSD_SOURCE -D_XOPEN_SOURCE=700 -D_POSIX_C_SOURCE=200809L -DVERSION=\"$(VERSION)\" $(XINERAMAFLAGS)
CFLAGS   = -std=c99 -pedantic -Wall -Os $(INCS) $(CPPFLAGS)
LDFLAGS  = $(LIBS)

# compiler and linker
CC = cc
