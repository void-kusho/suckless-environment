# See LICENSE file for copyright and license details
# utils - suckless environment utilities

include config.mk

# Common objects (linked into utility binaries)
COMMON_OBJ = common/util.o
DMENU_OBJ  = common/dmenu.o

# dmenu -> wmenu shim (installed alongside the binaries)
DMENU_SHIM = dmenu-shim/dmenu

# Subdirs whose config.h is generated from config.def.h at build time
# (gitignored, unlike the committed config.h in the other subdirs).
GEN_CONFIG_SUBS = dmenu-session dmenu-cpupower
$(addsuffix /config.h,$(GEN_CONFIG_SUBS)): %/config.h: %/config.def.h
	cp $< $@

# Utility binaries - populated as phases add utilities
BINS = battery-notify/battery-notify brightness-notify/brightness-notify \
       dmenu-session/dmenu-session \
       dmenu-cpupower/dmenu-cpupower dmenu-clip/dmenu-clip \
       dmenu-clipd/dmenu-clipd

all: $(COMMON_OBJ) $(DMENU_OBJ) $(BINS)

# Compilation rules for common/ subdirectory
common/util.o: common/util.c common/util.h
	$(CC) -o $@ -c $(CFLAGS) $<

common/dmenu.o: common/dmenu.c common/dmenu.h common/util.h
	$(CC) -o $@ -c $(CFLAGS) $<

# battery-notify
battery-notify/battery-notify: battery-notify/battery-notify.o $(COMMON_OBJ)
	$(CC) -o $@ $(LDFLAGS) $^

battery-notify/battery-notify.o: battery-notify/battery-notify.c battery-notify/config.h common/util.h
	$(CC) -o $@ -c $(CFLAGS) $<

# brightness-notify
brightness-notify/brightness-notify: brightness-notify/brightness-notify.o $(COMMON_OBJ)
	$(CC) -o $@ $(LDFLAGS) $^

brightness-notify/brightness-notify.o: brightness-notify/brightness-notify.c brightness-notify/config.h common/util.h
	$(CC) -o $@ -c $(CFLAGS) $<

# dmenu-session
dmenu-session/dmenu-session: dmenu-session/dmenu-session.o $(COMMON_OBJ) $(DMENU_OBJ)
	$(CC) -o $@ $(LDFLAGS) $^

dmenu-session/dmenu-session.o: dmenu-session/dmenu-session.c dmenu-session/config.h common/util.h common/dmenu.h
	$(CC) -o $@ -c $(CFLAGS) $<

# dmenu-cpupower
dmenu-cpupower/dmenu-cpupower: dmenu-cpupower/dmenu-cpupower.o $(COMMON_OBJ) $(DMENU_OBJ)
	$(CC) -o $@ $(LDFLAGS) $^

dmenu-cpupower/dmenu-cpupower.o: dmenu-cpupower/dmenu-cpupower.c dmenu-cpupower/config.h common/util.h common/dmenu.h
	$(CC) -o $@ -c $(CFLAGS) $<

# dmenu-clip
dmenu-clip/dmenu-clip: dmenu-clip/dmenu-clip.o $(COMMON_OBJ) $(DMENU_OBJ)
	$(CC) -o $@ $(LDFLAGS) $^

dmenu-clip/dmenu-clip.o: dmenu-clip/dmenu-clip.c dmenu-clip/config.h common/util.h common/dmenu.h
	$(CC) -o $@ -c $(CFLAGS) $<

# dmenu-clipd -- clipboard daemon (uses wl-paste --watch, no X11 libs)
dmenu-clipd/dmenu-clipd: dmenu-clipd/dmenu-clipd.o $(COMMON_OBJ)
	$(CC) -o $@ $(LDFLAGS) $^

dmenu-clipd/dmenu-clipd.o: dmenu-clipd/dmenu-clipd.c dmenu-clipd/config.h common/util.h
	$(CC) -o $@ -c $(CFLAGS) $<

clean:
	rm -f $(COMMON_OBJ) $(DMENU_OBJ)
	rm -f $(BINS)
	rm -f battery-notify/*.o
	rm -f brightness-notify/*.o
	rm -f dmenu-session/*.o
	rm -f dmenu-cpupower/*.o
	rm -f dmenu-clip/*.o
	rm -f dmenu-clipd/*.o
	rm -f test-util test-dmenu tests/test-util.o tests/test-dmenu.o

install: all
	mkdir -p "$(DESTDIR)$(PREFIX)/bin"
	@for bin in $(BINS); do \
		cp -f "$$bin" "$(DESTDIR)$(PREFIX)/bin/$$(basename $$bin)"; \
		chmod 755 "$(DESTDIR)$(PREFIX)/bin/$$(basename $$bin)"; \
	done
	@# dmenu -> wmenu shim; needs to shadow the system dmenu on PATH
	cp -f "$(DMENU_SHIM)" "$(DESTDIR)$(PREFIX)/bin/dmenu"
	chmod 755 "$(DESTDIR)$(PREFIX)/bin/dmenu"

uninstall:
	@for bin in $(BINS); do \
		rm -f "$(DESTDIR)$(PREFIX)/bin/$$(basename $$bin)"; \
	done

.PHONY: all clean install uninstall test

# Test targets (not installed)
test-util: tests/test-util.o $(COMMON_OBJ)
	$(CC) -o $@ $(LDFLAGS) $^

tests/test-util.o: tests/test-util.c common/util.h
	$(CC) -o $@ -c $(CFLAGS) $<

test-dmenu: tests/test-dmenu.o $(COMMON_OBJ) $(DMENU_OBJ)
	$(CC) -o $@ $(LDFLAGS) $^

tests/test-dmenu.o: tests/test-dmenu.c common/dmenu.h common/util.h
	$(CC) -o $@ -c $(CFLAGS) $<

test: test-util test-dmenu
	./test-util
	./test-dmenu
