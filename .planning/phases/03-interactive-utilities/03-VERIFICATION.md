---
phase: 03-interactive-utilities
verified: 2026-04-09T19:30:00Z
status: human_needed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Run dmenu-session, select lock, verify betterlockscreen activates with blur effect"
    expected: "Screen locks with blur 0.8 visual effect, no duplicate instances if run twice"
    why_human: "Requires running X11 session with betterlockscreen installed to verify visual behavior"
  - test: "Run dmenu-session, select logout, verify confirmation dialog appears with no/yes"
    expected: "Second dmenu opens with no (default) and yes; selecting yes kills slstatus, dmenu-clipd, dunst, dwm in order"
    why_human: "Destructive action kills the window manager session; requires manual session testing"
  - test: "Run dmenu-cpupower, verify current profile shown in prompt and profile switch works"
    expected: "Prompt shows cpu: {current_profile}, selecting a different profile changes it via powerprofilesctl"
    why_human: "Requires powerprofilesctl running on hardware with power-profiles-daemon"
  - test: "Populate ~/.cache/dmenu-clipboard/ with test files, run dmenu-clip, verify previews shown newest-first and selection restores clipboard"
    expected: "Entries sorted by mtime descending, 80-char previews with newlines as spaces, selecting entry copies full content to clipboard"
    why_human: "Requires X11 clipboard interaction and visual dmenu verification"
---

# Phase 3: Interactive Utilities Verification Report

**Phase Goal:** Users can manage sessions, power profiles, and clipboard history through dmenu-driven C utilities that replace the existing shell scripts
**Verified:** 2026-04-09T19:30:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can lock the screen via dmenu-session and betterlockscreen activates with blur effect (no duplicate instances spawned) | VERIFIED | dmenu-session.c:29-52 -- action_lock() validates DISPLAY, checks pgrep -f for duplicates, spawns betterlockscreen -l --display 1 --blur 0.8 via exec_detach |
| 2 | User can logout, reboot, or shutdown via dmenu-session with a confirmation dialog preventing accidental execution | VERIFIED | dmenu-session.c:10-26 -- confirm() helper opens second dmenu with no/yes; action_logout (line 55), action_reboot (line 75), action_shutdown (line 87) all call confirm() before executing. Logout kills slstatus, dmenu-clipd, dunst, dwm in correct order. Reboot/shutdown use exec_detach with systemctl. |
| 3 | User can see the current power profile in the dmenu prompt and switch between performance/balanced/power-saver | VERIFIED | dmenu-cpupower.c:12-51 -- capture_stdout() reads powerprofilesctl get output; line 71 builds "cpu: %s" prompt; lines 74-77 write 3 profiles; lines 85-90 validate selection against whitelist; line 93 calls powerprofilesctl set |
| 4 | User can browse clipboard history newest-first in dmenu, see truncated previews, and select an entry to restore it to the clipboard | VERIFIED | dmenu-clip.c:24-34 -- cmp_mtime_desc qsort comparator; lines 37-57 build_preview reads 80 bytes, replaces newlines/tabs with spaces; lines 59-80 restore_clipboard via fork+dup2+execlp xclip; main scans cache dir, sorts, pipes through dmenu, matches selection, restores |
| 5 | All three utilities accept extra arguments that are passed through to dmenu (e.g., custom font, color overrides) | VERIFIED | dmenu-session.c:108 argv+1, dmenu-cpupower.c:73 argv+1, dmenu-clip.c:161 argv+1 -- all pass extra argv to dmenu_open. dmenu-session also forwards to confirm() calls (lines 122, 124, 126 pass argv+1 to action functions which pass to confirm) |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `utils/dmenu-session/dmenu-session.c` | Session manager with lock/logout/reboot/shutdown, min 80 lines, contains "confirm" | VERIFIED | 130 lines, 4 confirm occurrences (1 def + 3 calls), all 4 actions implemented with real exec calls |
| `utils/dmenu-cpupower/dmenu-cpupower.c` | Power profile switcher via powerprofilesctl, min 60 lines, contains "capture_stdout" | VERIFIED | 98 lines, capture_stdout helper with fork+pipe+dup2+execvp, whitelist validation |
| `utils/dmenu-clip/dmenu-clip.c` | Clipboard history picker with directory scan, sort, preview, restore, min 100 lines, contains "cmp_mtime_desc" | VERIFIED | 184 lines, cmp_mtime_desc qsort comparator, build_preview, restore_clipboard via xclip, lstat symlink protection |
| `utils/dmenu-clip/config.def.h` | Compile-time config for cache dir name, max entries, preview length, contains "MAX_ENTRIES" | VERIFIED | Defines CACHE_DIR_NAME "dmenu-clipboard", MAX_ENTRIES 50, MAX_PREVIEW 80 |
| `utils/dmenu-clip/config.h` | User copy of config.def.h, contains "MAX_PREVIEW" | VERIFIED | Identical to config.def.h (suckless pattern) |
| `utils/Makefile` | BINS includes all three new utilities | VERIFIED | BINS contains dmenu-session/dmenu-session, dmenu-cpupower/dmenu-cpupower, dmenu-clip/dmenu-clip; build, compile, and clean rules present for all |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| dmenu-session.c | common/dmenu.h | dmenu_open/dmenu_write/dmenu_read/dmenu_close | WIRED | Line 108: dmenu_open("session", argv+1); lines 109-112: dmenu_write for 4 items; line 113: dmenu_read; line 114: dmenu_close |
| dmenu-session.c | common/util.h | exec_wait, exec_detach | WIRED | Lines 48, 68-71: exec_wait for pgrep and pkill; lines 51, 83, 95: exec_detach for lock, reboot, shutdown |
| dmenu-cpupower.c | common/dmenu.h | dmenu_open/dmenu_write/dmenu_read/dmenu_close | WIRED | Line 73: dmenu_open(prompt, argv+1); lines 74-76: dmenu_write for 3 profiles; line 77: dmenu_read; line 78: dmenu_close |
| dmenu-clip.c | common/dmenu.h | dmenu_open/dmenu_write/dmenu_read/dmenu_close | WIRED | Line 161: dmenu_open("clipboard", argv+1); lines 165-166: dmenu_write in loop; line 168: dmenu_read; line 169: dmenu_close |
| dmenu-clip.c | ~/.cache/dmenu-clipboard/ | opendir + readdir + stat | WIRED | Line 88: getenv XDG_CACHE_HOME; line 122: opendir(cache_dir); line 127: readdir loop; line 138: lstat for each entry |
| dmenu-clip.c | xclip | fork+dup2+execlp | WIRED | Lines 65-77: fork, open file O_RDONLY, dup2 to STDIN_FILENO, execlp("xclip", "xclip", "-selection", "clipboard", NULL) |
| Makefile | dmenu-session.c | BINS variable | WIRED | Line 12: dmenu-session/dmenu-session in BINS; lines 39-43: build and compile rules |
| Makefile | dmenu-cpupower.c | BINS variable | WIRED | Line 12: dmenu-cpupower/dmenu-cpupower in BINS; lines 46-50: build and compile rules |
| Makefile | dmenu-clip.c | BINS variable | WIRED | Line 13: dmenu-clip/dmenu-clip in BINS; lines 53-57: build and compile rules with config.h dependency |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| dmenu-cpupower.c | current (profile name) | capture_stdout -> powerprofilesctl get | Yes -- fork+pipe+execvp reads live stdout | FLOWING |
| dmenu-clip.c | entries[].preview | build_preview -> fread from cache files | Yes -- reads actual file content from disk | FLOWING |
| dmenu-clip.c | entries[].mtime | lstat() on cache directory files | Yes -- reads real filesystem metadata | FLOWING |
| dmenu-session.c | N/A (static menu items) | Hardcoded strings | N/A -- no dynamic data to trace | N/A |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| All utilities compile cleanly | make -C utils clean all 2>&1 | Zero warnings, all 5 binaries produced (battery-notify, screenshot-notify, dmenu-session, dmenu-cpupower, dmenu-clip) | PASS |
| All 3 new binaries exist | ls utils/dmenu-session/dmenu-session utils/dmenu-cpupower/dmenu-cpupower utils/dmenu-clip/dmenu-clip | All present (14688, 14632, 14688 bytes respectively) | PASS |
| confirm() used for destructive actions | grep -c confirm dmenu-session.c | 4 (1 definition + 3 calls for logout/reboot/shutdown) | PASS |
| exec_detach for non-returning commands | grep -c exec_detach dmenu-session.c | 5 (lock, reboot x2 comments+call, shutdown x2 comments+call) | PASS |
| Profile whitelist validation | grep strcmp dmenu-cpupower.c | 3 strcmp checks against performance/balanced/power-saver before exec | PASS |
| Symlink protection in dmenu-clip | grep lstat dmenu-clip.c | lstat + S_ISLNK + S_ISREG checks present | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SESS-01 | 03-01 | Lock screen via betterlockscreen with blur 0.8 and DISPLAY export | SATISFIED | action_lock() validates DISPLAY, spawns betterlockscreen -l --display 1 --blur 0.8 |
| SESS-02 | 03-01 | Lock prevents duplicate betterlockscreen instances (pgrep check) | SATISFIED | pgrep -f betterlockscreen check before spawning; returns silently if already running |
| SESS-03 | 03-01 | Logout with confirmation dialog (kills slstatus, dmenu-clipd, dwm) | SATISFIED | confirm("logout?") then pkill -x slstatus, dmenu-clipd, dunst, dwm in order (exceeds req -- also kills dunst) |
| SESS-04 | 03-01 | Reboot with confirmation dialog (systemctl reboot) | SATISFIED | confirm("reboot?") then exec_detach systemctl reboot |
| SESS-05 | 03-01 | Shutdown with confirmation dialog (systemctl poweroff) | SATISFIED | confirm("shutdown?") then exec_detach systemctl poweroff |
| POWER-01 | 03-01 | See current power profile in dmenu prompt | SATISFIED | capture_stdout(powerprofilesctl get) then snprintf "cpu: %s" prompt |
| POWER-02 | 03-01 | Select from available profiles (performance/balanced/power-saver) | SATISFIED | 3 profiles written as dmenu items, whitelist validation before set |
| POWER-03 | 03-01 | Selected profile applied via powerprofilesctl set | SATISFIED | exec_wait(powerprofilesctl set {selection}) after validation |
| POWER-04 | 03-01 | dmenu-cpupower passes extra arguments through to dmenu | SATISFIED | dmenu_open(prompt, argv + 1) at line 73 |
| CLIP-01 | 03-02 | Browse clipboard history newest-first via dmenu | SATISFIED | opendir + readdir + qsort(cmp_mtime_desc) + dmenu pipe |
| CLIP-02 | 03-02 | Each entry shows 80-char truncated preview with newlines as spaces | SATISFIED | build_preview reads MAX_PREVIEW (80) bytes, replaces \n and \t with spaces |
| CLIP-03 | 03-02 | Selecting entry copies full content to clipboard via xclip | SATISFIED | restore_clipboard: fork+open(O_RDONLY)+dup2(STDIN)+execlp xclip -selection clipboard |
| CLIP-04 | 03-02 | dmenu-clip passes extra arguments through to dmenu | SATISFIED | dmenu_open("clipboard", argv + 1) at line 161 |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | - | No TODO/FIXME/PLACEHOLDER/stub patterns found | - | - |

No anti-patterns detected across all three utilities. No empty implementations, no console.log, no hardcoded empty returns.

### Human Verification Required

### 1. Lock Screen Visual Behavior

**Test:** Run `dmenu-session`, select "lock" from the menu
**Expected:** betterlockscreen activates with blur 0.8 effect on display 1. Running dmenu-session again and selecting "lock" while locked should not spawn a second instance.
**Why human:** Requires active X11 session with betterlockscreen installed; visual blur effect cannot be verified programmatically

### 2. Session Management Destructive Actions

**Test:** Run `dmenu-session`, select "logout"; verify confirmation dialog appears
**Expected:** Second dmenu opens with "no" (first/default) and "yes". Selecting "no" cancels. Selecting "yes" kills slstatus, dmenu-clipd, dunst, dwm in order (session terminates).
**Why human:** Logout/reboot/shutdown are destructive session-level actions that cannot be safely tested programmatically

### 3. Power Profile Switching

**Test:** Run `dmenu-cpupower`, verify current profile in prompt, select different profile
**Expected:** Prompt shows "cpu: balanced" (or current profile). Selecting "performance" changes profile. Verify with `powerprofilesctl get` after selection.
**Why human:** Requires power-profiles-daemon running on real hardware; profile switching has hardware-dependent behavior

### 4. Clipboard History Browsing and Restore

**Test:** Create test files in `~/.cache/dmenu-clipboard/` with known content and different mtimes, run `dmenu-clip`
**Expected:** Entries appear newest-first with 80-char truncated previews (newlines shown as spaces). Selecting an entry copies the full file content to the X11 clipboard (verify with `xclip -selection clipboard -o`).
**Why human:** Requires X11 clipboard interaction; visual dmenu inspection for sort order and preview formatting

### Gaps Summary

No code-level gaps found. All 5 roadmap success criteria verified at code level. All 13 requirements (SESS-01 through SESS-05, POWER-01 through POWER-04, CLIP-01 through CLIP-04) have satisfactory implementations with real data sources, proper wiring to Phase 1 common libraries, and Makefile integration.

Status is `human_needed` because the utilities involve interactive X11 dmenu sessions, destructive system actions (lock/logout/reboot/shutdown), hardware-dependent power profile switching, and clipboard I/O -- all of which require human testing in a live environment.

---

_Verified: 2026-04-09T19:30:00Z_
_Verifier: Claude (gsd-verifier)_
