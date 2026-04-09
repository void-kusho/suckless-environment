---
status: complete
phase: 04-clipboard-daemon
source: [04-01-SUMMARY.md, 04-02-SUMMARY.md]
started: 2026-04-09T20:00:00Z
updated: 2026-04-09T20:10:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Single Instance Enforcement
expected: Start `dmenu-clipd &`, then start another. Second should fail with "already running" and exit.
result: pass

### 2. Clipboard Capture
expected: With daemon running, copy text to clipboard. New file appears in ~/.cache/dmenu-clipboard/.
result: pass

### 3. Dedup
expected: Copy same text again. File count does not increase — FNV-1a dedup works.
result: pass

### 4. SIGTERM Clean Shutdown
expected: Send kill to daemon. Exits cleanly within 1 second.
result: pass

### 5. Full Clipboard Workflow
expected: Start daemon, copy text, run dmenu-clip — entries appear, select one, paste — full content restored.
result: pass

### 6. No PRIMARY Monitoring
expected: Select text with mouse. Cache count does not increase — CLIPBOARD only.
result: pass

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none]
