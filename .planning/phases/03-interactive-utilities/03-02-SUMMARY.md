---
phase: 03-interactive-utilities
plan: 02
subsystem: interactive-utilities
tags: [dmenu, clipboard, c-utility, xclip]
dependency_graph:
  requires: [01-01, 01-02, 03-01]
  provides: [dmenu-clip]
  affects: [utils/Makefile]
tech_stack:
  added: [xclip]
  patterns: [dmenu-pipe-api, directory-scan, mtime-sort, fork-dup2-execlp, lstat-symlink-check]
key_files:
  created:
    - utils/dmenu-clip/dmenu-clip.c
    - utils/dmenu-clip/config.def.h
    - utils/dmenu-clip/config.h
  modified:
    - utils/Makefile
decisions:
  - "lstat() instead of stat() to detect and skip symlinks in cache directory (T-03-06 mitigation)"
  - "fork+dup2+execlp for xclip restore -- feeds full file content to xclip stdin without shell interpretation"
  - "First-match-wins on duplicate previews -- newest-first sort order means most recent entry is selected"
  - "snprintf bounds check on path construction -- skip entries that would truncate"
metrics:
  duration: "2 minutes"
  completed: "2026-04-09T19:12:00Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 1
---

# Phase 3 Plan 2: Clipboard History Picker Summary

Native C dmenu-clip that scans ~/.cache/dmenu-clipboard, sorts entries by mtime descending, displays 80-char truncated previews in dmenu, and restores the selected entry to clipboard via xclip -- all using the Phase 1 dmenu pipe library.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create dmenu-clip config.def.h and dmenu-clip.c with directory scan, sort, preview, and restore | 9f50d72 | utils/dmenu-clip/config.def.h, utils/dmenu-clip/config.h, utils/dmenu-clip/dmenu-clip.c |
| 2 | Integrate dmenu-clip into Makefile and verify full build | cb71d71 | utils/Makefile |

## Implementation Details

### dmenu-clip.c (184 lines)

- **get_cache_dir():** Resolves cache directory from XDG_CACHE_HOME (non-empty check per Pitfall 5) with ~/.cache fallback. Dies if HOME unset.
- **build_preview():** Reads first MAX_PREVIEW (80) bytes from cache file, replaces newlines and tabs with spaces for single-line dmenu display.
- **cmp_mtime_desc():** qsort comparator for newest-first ordering by file modification time.
- **restore_clipboard():** fork + open(O_RDONLY) + dup2(STDIN_FILENO) + execlp("xclip") -- feeds full file content to xclip's stdin without any shell interpretation.
- **main():** Opens cache directory, scans entries (skipping hidden files and symlinks via lstat), builds preview array, sorts by mtime, pipes previews through dmenu, matches selection back to entry, restores clipboard. Extra argv forwarded to dmenu.

### config.def.h / config.h

- CACHE_DIR_NAME: "dmenu-clipboard" (subdirectory name within XDG_CACHE_HOME)
- MAX_ENTRIES: 50 (caps memory allocation from directory scan)
- MAX_PREVIEW: 80 (chars per preview line, matching shell script behavior)

### Makefile Integration

- BINS extended with dmenu-clip/dmenu-clip (now 5 total utilities)
- Linking rule includes COMMON_OBJ and DMENU_OBJ (Phase 1 foundation)
- Compilation rule lists dmenu-clip/config.h as dependency
- Clean target removes dmenu-clip/*.o
- `make clean all` builds all 5 utilities (battery-notify, screenshot-notify, dmenu-session, dmenu-cpupower, dmenu-clip) with zero warnings

## Decisions Made

1. **lstat() over stat():** Detects and skips symlinks in cache directory, preventing an attacker from planting symlinks to sensitive files (T-03-06, T-03-07 mitigations).
2. **fork+dup2+execlp for xclip:** Direct file-to-stdin pipe without shell interpretation. Cleaner than exec_wait since we need the stdin redirect via dup2.
3. **First-match-wins for duplicate previews:** Since entries are sorted newest-first, duplicate preview strings naturally select the most recent entry (Pitfall 4).
4. **snprintf bounds checking on path construction:** Entries with paths exceeding PATH_MAX are silently skipped rather than truncated.
5. **S_ISREG check after lstat:** Only regular files are processed -- directories, sockets, FIFOs, and device nodes in the cache directory are skipped.

## Verification Results

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| make clean all | Zero warnings | Zero warnings | PASS |
| All 5 binaries exist | Yes | Yes | PASS |
| lstat in dmenu-clip.c | Present | Present | PASS |
| MAX_ENTRIES in config.def.h | 50 | 50 | PASS |
| MAX_PREVIEW in config.def.h | 80 | 80 | PASS |
| XDG_CACHE_HOME in dmenu-clip.c | Present | Present | PASS |
| execlp xclip in dmenu-clip.c | Present | Present | PASS |
| dmenu_open "clipboard" prompt | Present | Present | PASS |
| dmenu-clip.c min_lines (100) | >= 100 | 184 | PASS |
| cmp_mtime_desc in dmenu-clip.c | Present | Present | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed -Wformat-truncation warning on path snprintf**
- **Found during:** Task 1
- **Issue:** snprintf for path construction triggered -Wformat-truncation warning because NAME_MAX + cache_dir could exceed PATH_MAX
- **Fix:** Added explicit return value check with bounds validation; entries with paths that would truncate are skipped
- **Files modified:** utils/dmenu-clip/dmenu-clip.c
- **Commit:** 9f50d72

## Known Stubs

None -- dmenu-clip is fully implemented with real cache directory scanning, preview building, and clipboard restoration via xclip.

## Security Notes

- No shell interpretation anywhere: all process spawning via fork+execlp (CERT C ENV33-C compliant)
- lstat() symlink detection prevents reading arbitrary files via planted symlinks (T-03-06)
- MAX_PREVIEW (80 bytes) limits information exposure from file reads (T-03-07)
- MAX_ENTRIES (50) caps memory allocation from directory scan (T-03-08)
- PATH_MAX bounds on all path construction via snprintf with explicit overflow check
- S_ISREG check ensures only regular files are processed

## Self-Check: PASSED

- [x] utils/dmenu-clip/dmenu-clip.c exists
- [x] utils/dmenu-clip/config.def.h exists
- [x] utils/dmenu-clip/config.h exists
- [x] utils/Makefile updated
- [x] 03-02-SUMMARY.md exists
- [x] Commit 9f50d72 exists
- [x] Commit cb71d71 exists
