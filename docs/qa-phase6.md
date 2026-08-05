# QA: Phase 6 (TASK-054, 057, 058, 060, 061)

Status key: ✅ passed · ⚠️ passed with a note · ⛔ not run, and why

## Date & time edges (TASK-060) — automated

Nine cases in `DateEdgeTests.swift`, all green. Every one pins `now` and
`calendar` explicitly, so none of it depends on when or where the suite runs.

| Case | Result |
|---|---|
| Task due today is Today at 23:59 and still Today at 00:01 the next day | ✅ |
| Tomorrow becomes Today the moment the day turns | ✅ |
| Spring-forward (23-hour day, Berlin 29 Mar 2026) | ✅ |
| Fall-back (25-hour day, Berlin 25 Oct 2026) | ✅ |
| Same instant buckets by LOCAL day, not UTC | ✅ |
| Date line: Kiritimati / Midway / Kathmandu / LA / Sydney, ±30 days | ✅ |
| Week horizon is always a future Sunday, across a fortnight | ✅ |
| Week assignment round-trips, every day of 2026 | ✅ |
| Every bucket's assigned date round-trips, every day of 2026 | ✅ |

The last two are the ones that matter: they assert the core invariant — a task
put in a tab appears in that tab — on all 365 days rather than on a lucky one.

## Auto-archive (TASK-054)

| Case | Result |
|---|---|
| Completed today stays visible in its tab | ✅ |
| Completed on a past day leaves the tab and appears in Archive | ✅ (verified by backdating) |
| Archive groups by completion day, newest first | ✅ |
| Unticking restores the exact former position | ✅ (covered by Placement tests) |
| Archive delete removes the task | ✅ |

## Performance (TASK-061)

| Case | Result |
|---|---|
| 309 tasks in one tab: flick scrolling | ✅ smooth, no stalls |
| 309 tasks: tab switch | ✅ instant |
| 309 tasks: app launch | ✅ no visible delay |
| Instruments profiling (allocations, frame timing) | ⛔ not run — needs a device and Instruments |

⚠️ **Known scaling shape, not currently a problem.** Every query goes through
`allTasksSorted()`, which fetches all tasks and filters in memory. At 309 that
is imperceptible. It is O(n) per query rather than a predicate on the store, so
somewhere in the low thousands it would start to show. Deliberately not
optimised: a personal to-do list does not reach that, and a cache keyed on
`revision` is exactly the kind of change that introduces staleness bugs.

## Accessibility (TASK-058)

| Case | Result |
|---|---|
| Every task row has a label naming its state (important, overdue, completed) | ✅ |
| Every swipe/menu action also exists as a named VoiceOver action | ✅ — the swipe is custom, so this is the only way it is reachable without sight |
| Taskbar tabs labelled and marked selected | ✅ |
| Title bar, workspace menu, gear/✕ labelled | ✅ |
| Menu rows carry the button trait | ✅ (added during this audit) |
| Photos labelled with their position | ✅ |
| Checkbox hidden from VoiceOver; the row carries it | ✅ intentional — one element per row, not two |
| Tap targets ≥44pt | ✅ `Win95.rowHeight` floors at 44 and grows with scale |
| Live VoiceOver navigation on device | ⛔ not run — needs a device with VoiceOver on |

## Stepped type (TASK-059)

3× and 4× both audited. One real bug found and fixed: taskbar labels only
abbreviated at 4×, so "Tomorrow" was clipped at both ends at 3×.

## Sync failure modes (TASK-057)

| Case | Result |
|---|---|
| No iCloud account: app fully usable, Settings says "not signed in", no alert | ✅ |
| CloudKit unavailable at launch: falls back to local, never crashes | ✅ by construction, and verified |
| No entitlement: gated off, local store, no crash | ✅ verified the hard way — it crashed first |
| Task created on one device appears on the other | ✅ |
| Photo created on one device appears on the other | ✅ |
| Offline edit, then reconnect | ⛔ not run — needs two devices and airplane mode |
| Account signed out mid-session | ⛔ not run |

## What still needs a device

Camera capture, both permission-denial paths, the 48MP downscale budget,
VoiceOver navigation, Instruments profiling, offline sync recovery. All are
marked ⛔ above rather than assumed.
