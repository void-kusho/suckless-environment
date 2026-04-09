# See LICENSE file for copyright and license details
# utils - suckless environment utilities

include config.mk

# Common objects (linked into utility binaries)
COMMON_OBJ = common/util.o
DMENU_OBJ  = common/dmenu.o

# Utility binaries - populated as phases add utilities
BINS =

all: $(COMMON_OBJ) $(DMENU_OBJ) $(BINS)

# Compilation rules for common/ subdirectory
common/util.o: common/util.c common/util.h
	$(CC) -o $@ -c $(CFLAGS) $<

common/dmenu.o: common/dmenu.c common/dmenu.h common/util.h
	$(CC) -o $@ -c $(CFLAGS) $<

clean:
	rm -f $(COMMON_OBJ) $(DMENU_OBJ)
	rm -f $(BINS)

install: all
	mkdir -p "$(DESTDIR)$(PREFIX)/bin"
	@for bin in $(BINS); do \
		cp -f "$$bin" "$(DESTDIR)$(PREFIX)/bin/$$(basename $$bin)"; \
		chmod 755 "$(DESTDIR)$(PREFIX)/bin/$$(basename $$bin)"; \
	done

uninstall:
	@for bin in $(BINS); do \
		rm -f "$(DESTDIR)$(PREFIX)/bin/$$(basename $$bin)"; \
	done

.PHONY: all clean install uninstall
