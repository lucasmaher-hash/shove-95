# QA — Windows 95 Skin (TASK-041/042)

## Prohibited-list sweep (design.md §9) — ✅ clean 2026-08-04

Automated grep across `shove95/shove95/`:

| Prohibited | Result |
|---|---|
| SF Symbols (`systemName` / `systemImage`) | none — checkbox, gear and menu glyphs are hand-drawn `Shape`s |
| Corner radii, `RoundedRectangle`, `.shadow`, `.blur`, materials | none |
| System tint / accent colours | none |
| Fade, scale, dissolve transitions | none |
| Non-token colours (`Color.gray`, `.primary`, …) | none — every colour comes from `Win95` |

**Two known exceptions, both intentional and temporary:**

1. **The debug bar** (`#if DEBUG` only) uses stock SwiftUI buttons. Never ships.
2. **The Settings placeholder** is a `.sheet`, which has rounded corners and a
   drag indicator. It is a stub — Phase 5 (TASK-052) replaces it with a real
   Win95 window.

## Rendered checks — ✅ verified on simulator 2026-08-04

- [x] Title bar: 18px navy→`#1084D0` gradient, W95FA white title `Today - shove.95`, raised gear control
- [x] List well: sunken bevel, white, no row separators
- [x] Rows: W95FA single size, red only for Important, grey + strikethrough for completed
- [x] Checkbox: 12px sunken box, hand-drawn pixel checkmark, ≥44pt tap target
- [x] Date chip: sunken mini-panel, right-aligned column (`Mon`)
- [x] Add row: sunken field
- [x] Status bar: sunken panel + compact raised `Undo`, shows `{task} → {destination}`
- [x] Taskbar: four buttons, active one pressed with the dotted hatch, sunken clock well, silver into the safe area
- [x] Context menu: raised silver panel, Win95 separators, red Delete, drops from the row
- [x] `(empty)` state
- [x] Stepped Dynamic Type at 2× and 4× — whole UI scales as one unit

### Fixed during the 4× pass

- Row height was a fixed 44pt, which clipped the 48pt checkbox at 4×. It is now
  a **floor**: `max(44, (checkbox + 2·grid) × pixel)`.
- The taskbar clipped its four buttons at 4×; the clock well is now dropped at
  that scale (decoration yields to navigation).

## Still to verify on device

- [ ] Long-press menu contents per tab, and Important-jumps-to-top
- [ ] Hold-and-drag reorder feel (works on simulator; haptics unverifiable there)
- [ ] Haptics: light impact on menu open and swipe commit, selection feedback on drag
- [ ] 3× scale (only 2× and 4× were checked)
