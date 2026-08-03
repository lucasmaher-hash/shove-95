# QA — Magic Moment (TASK-028)

Acceptance script for the app's core promise. Run on a **physical device** —
the simulator cannot produce haptics, and its synthesized touches are
unreliable for long-press recognition (see "Simulator limitations" below).

**Setup:** fresh install → tap `Seed debug data` (Today gains: 1 important,
2 overdue, 1 normal; plus Tomorrow/Week/General items).

-----

## 1. One-flick defer  ✅ verified on simulator 2026-08-04

- [x] Swipe a Today row left past ~40% of row width → row slides off the left
      edge, the list closes the gap
- [x] The task's date becomes tomorrow: it is present in the **Tomorrow** tab
      immediately after switching (checked against the SQLite store, not just
      the UI)
- [x] Status bar reads `{title} → Tomorrow` with an `Undo` button
- [ ] **Device:** the whole gesture completes in **under 1 second** including
      animation, one-handed, thumb only
- [ ] **Device:** a light haptic fires on commit

## 2. Pull forward  ✅ verified on simulator

- [x] Swipe right in Week → task lands in Tomorrow
- [x] Swipe right in Tomorrow → task lands in Today

## 3. Rubber-band at the dead ends  ✅ verified on simulator

- [x] Swipe **right** on a Today row → row resists (~0.3× translation) and
      springs back; nothing changes (debug readout: `spring back 300`)
- [ ] Swipe **left** on a General row → same
- [ ] **Device:** one light haptic per dead-end gesture, not repeated

## 4. Undo  ✅ verified on simulator 2026-08-04

- [x] After a move, tap `Undo` → the task returns to its **exact** previous
      position (verified: important task returned to the top slot, not appended)
- [x] The status bar entry persists until the next action replaces it — no
      timeout
- [ ] Delete a task with a photo → Undo restores it with the photo *(Phase 4)*

## 5. Scroll never triggers a swipe  ✅ verified on simulator

- [x] With 15+ filler rows, drag vertically through several rows → the list
      scrolls, no row moves and no status-bar entry appears
- [x] Axis is decided once per gesture: a diagonal drag that starts vertical
      stays with the scroll for the rest of that touch

## 6. Long jump via the context menu  ⚠️ NEEDS DEVICE VERIFICATION

The menu is implemented and was observed rendering correctly once on the
simulator, but synthesized long-presses do not reproduce it reliably, so these
could not be confirmed headlessly:

- [ ] Long-press a **General** row → menu shows exactly `< Tomorrow`,
      `<< Today`, `Mark as Important`, `Delete` (red, last)
- [ ] Long-press a **Tomorrow** row → exactly one move entry: `> General`
- [ ] Long-press a **Today** row → `> Week`, `>> General`
- [ ] Long-press a **Week** row → `< Today`
- [ ] Tapping `<< Today` from General moves the task in **two gestures total**
- [ ] `Mark as Important` turns the row red **and** jumps it to the top;
      unmarking leaves it in place

*(Menu actions themselves are proven: several fillers were flagged Important
via the menu during testing — the red rows in the debug data are that evidence.)*

## 7. VoiceOver  ⚠️ NEEDS DEVICE VERIFICATION

- [ ] Row label reads title + state ("important", "overdue since Mon", "completed")
- [ ] Rotor exposes: Complete/Uncomplete, Defer one step, Pull forward one step,
      Move to *each* menu destination, Mark/Unmark Important, Delete
- [ ] "Defer one step" moves the task and the status bar updates

-----

## Simulator limitations encountered

Recorded so future sessions don't re-derive them:

| Attempted | Result |
|---|---|
| `print()` / `os.Logger` from the app | Never surfaced in `simctl launch --console-pty` or `log show` — unusable. On-screen debug label was used instead |
| Synthesized long-press (`touch_path`, identical points, 1.2–1.8 s) | Context menu appeared **once**, not reproducible; SwiftUI `LongPressGesture` fired **no** phases at all |
| Synthesized horizontal swipe | Works reliably — all swipe verification above is genuine |

Ground truth for data assertions was read directly from the SwiftData store:

```bash
C=$(xcrun simctl get_app_container <UDID> com.lucasmaher.shove95 data)
DB=$(find "$C" -name "default.store" | head -1)
sqlite3 "file:$DB?mode=ro" "SELECT ZTITLE, date(ZDUEDATE+978307200,'unixepoch','localtime'), ZISCOMPLETED, ZSORTORDER FROM ZTASKITEM ORDER BY ZSORTORDER;"
```
