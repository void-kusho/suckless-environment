---
status: complete
phase: 03-interactive-utilities
source: [03-01-SUMMARY.md, 03-02-SUMMARY.md]
started: 2026-04-09T19:30:00Z
updated: 2026-04-09T19:45:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Lock Screen
expected: Run `dmenu-session`, select "lock" — betterlockscreen activates with blur. Running again while locked does not spawn duplicate.
result: pass

### 2. Logout Confirmation
expected: Run `dmenu-session`, select "logout" — confirmation dialog appears (no/yes). Selecting "no" cancels.
result: pass

### 3. Reboot/Shutdown Confirmation
expected: Run `dmenu-session`, select "reboot" or "shutdown" — confirmation dialog appears. "no" cancels safely.
result: pass

### 4. Power Profile Display
expected: Run `dmenu-cpupower` — dmenu prompt shows current profile. Three options: performance, balanced, power-saver.
result: pass

### 5. Power Profile Switch
expected: Select a different profile. `powerprofilesctl get` confirms change.
result: pass

### 6. Clipboard History Browse
expected: Copy text, run `dmenu-clip` — entries shown newest-first with truncated previews, Tokyo Night theme.
result: pass

### 7. Clipboard Restore
expected: Select entry in `dmenu-clip`, paste — full original content appears.
result: pass

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none]
