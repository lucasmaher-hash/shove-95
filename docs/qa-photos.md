# QA: Photos (TASK-048)

Run before any release that touches photo code. Simulator covers most of it;
the camera rows need a device.

Status key: ✅ passed · ⚠️ passed with a note · ⛔ device-only, not yet run

## Import

| # | Case | Expected | Status |
|---|---|---|---|
| 1 | Attach from library | Thumbnail appears under the title, left-aligned with the text | ✅ |
| 2 | Attach a second photo | Appears to the RIGHT of the first; order preserved | ✅ |
| 3 | Attach a third+ | Strip scrolls horizontally; row height unchanged | ✅ |
| 4 | 48MP HDR photo | Stored blob well under ~1.5MB; orientation upright | ⛔ device |
| 5 | Sideways (EXIF-rotated) photo | Upright in thumbnail and viewer — `ImageImport` bakes orientation into pixels | ⛔ device |
| 6 | Corrupt / undecodable data | `ImageImport.prepare` returns nil; task unchanged; **no alert, no crash** | ✅ (nil path) |
| 7 | Deny photo permission | System picker handles it; app never crashes and shows no error of its own | ⛔ device |
| 8 | Deny camera permission | Same — the OS owns that conversation | ⛔ device |
| 9 | No camera available | Source dialog is skipped entirely; tapping ✚ opens the library directly | ✅ (simulator IS this case) |

## One-per-edit rule

| # | Case | Expected | Status |
|---|---|---|---|
| 10 | Pick a photo while editing | The ✚ disappears for the rest of that edit session | ✅ |
| 11 | Commit, tap the task again | The ✚ is back | ✅ |
| 12 | Cancel the picker | The ✚ stays (nothing was added) | ✅ |

## Viewer

| # | Case | Expected | Status |
|---|---|---|---|
| 13 | Tap a thumbnail | It presses in (~140ms) and *then* the window appears | ✅ |
| 14 | Window size | ~3/4 of the screen, hugging the image; app dimmed but visible behind | ✅ |
| 15 | Tap the image | **Nothing happens** — the image is inert | ✅ |
| 16 | Tap the dimmed background | Closes, instantly | ✅ |
| 17 | Tap ✕ | Closes, instantly | ✅ |
| 18 | Remove (last photo) | Window closes, thumbnail gone, task intact | ✅ |
| 19 | Remove the FIRST of several | Later photos shift down; no gap, no orphan | ✅ |

## Persistence & lifecycle

| # | Case | Expected | Status |
|---|---|---|---|
| 20 | Attach → force-quit → relaunch | Photo still there | ✅ |
| 21 | Delete a task with photos → Undo | Photos restored (snapshot carries `extraPhotos`) | ✅ |
| 22 | Swipe a photo task to another day | Thumbnails intact in the destination | ✅ |
| 23 | 20 photo tasks, scroll hard | No stutter, no memory climb | ⛔ Instruments, device |

## Known gaps

- **Rows 4, 5, 7, 8, 23 need a device.** The simulator has no camera and its
  library holds only small sample images, so the downscale budget and both
  permission-denial paths are untested against reality.
- **Thumbnails decode at full size.** Each strip image is the stored JPEG
  (≤2048px) rendered into ~128×64pt. Fine for a handful; if row 23 shows memory
  climbing on a long list, switch to `CGImageSourceCreateThumbnailAtIndex`.
- **CloudKit (Phase 5):** `extraPhotos` is `[Data]` on the record, which does
  NOT become CKAssets. If records approach the 1MB limit this must become a
  child entity. Flagged in `TaskItem`.
