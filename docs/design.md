# Design System — shove.95

> Windows 95, derived from the original specification and rebuilt at 2× pixel scale.
> Every value in this document is arithmetic, not taste. When something looks wrong,
> check the derivation before changing the number.

**Created:** 2026-08-03

-----

## 1. The Pixel Unit

The entire system is expressed in a single token.

```
pixel = 2pt   (default, "2×")
```

Windows 95 was designed for 1:1 physical pixels. On a retina iPhone, a true 1px bevel is a near-invisible hairline. Everything is therefore rendered at **2× scale**: one 1995 pixel becomes 2 points. Every dimension below is written as `Npx` (the original spec value) with its point value derived.

The pixel unit is **variable** — it is the mechanism for accessibility scaling (§7). Nothing in the app may hard-code a point value; everything multiplies `pixel`.

| Scale | `pixel` | Trigger |
|---|---|---|
| 2× | 2pt | default |
| 3× | 3pt | system text size ≥ large |
| 4× | 4pt | accessibility text sizes |

**Appearance is locked to light.** Windows 95 has no dark mode and a dark bevel system is a different design, not a variant. The app sets `.preferredColorScheme(.light)` and does not respond to the system setting.

-----

## 2. Palette

Six colours carry the entire interface. There are no others.

| Token | Hex | Use |
|---|---|---|
| `surface` | `#C0C0C0` | Every chrome surface — taskbar, title bar area, window body, buttons |
| `highlight` | `#FFFFFF` | Bevel outer top-left (raised); also the list well background |
| `light` | `#DFDFDF` | Bevel inner top-left (raised) |
| `shadow` | `#808080` | Bevel inner bottom-right (raised); secondary/disabled text |
| `darkShadow` | `#0A0A0A` | Bevel outer bottom-right (raised) |
| `text` | `#222222` | All primary text |

**Accents — used for exactly one meaning each:**

| Token | Hex | Meaning — and nothing else |
|---|---|---|
| `important` | `#FF0000` | A task marked Important. No other element in the app is red. |
| `titleActive` | `#000080` → `#1084D0` | Active title bar, 90° linear gradient |
| `titleInactive` | `#808080` → `#B5B5B5` | Inactive title bar (Mac only — iOS windows are always active) |
| `selection` | `#000080` bg / `#FFFFFF` text | A row being dragged or swiped |
| `desktop` | `#008080` | Teal desktop — **macOS only**, not used on iOS |

No other colour may be introduced. Overdue, completed, and dragging states are all expressed through channels other than hue (§5).

-----

## 3. The Bevel

The bevel is the entire visual language. It is always exactly 2 pixels (4pt at 2×), built as two nested 1px frames.

**Raised** — buttons, taskbar, window body, thumbnail frames:

```
outer top-left     highlight   #FFFFFF
inner top-left     light       #DFDFDF
inner bottom-right shadow      #808080
outer bottom-right darkShadow  #0A0A0A
```

**Sunken** — text fields, the list well, status bar panels, date chips, pressed buttons:

```
outer top-left     shadow      #808080
inner top-left     darkShadow  #0A0A0A
inner bottom-right light       #DFDFDF
outer bottom-right highlight   #FFFFFF
```

Sunken is the exact inversion of raised. A pressed button is simply a raised button rendered sunken, with its label shifted 1px (2pt) down and right.

**Absolute rules:** corner radius is always `0`. There are no drop shadows, no blur, no translucency, no gradients anywhere except the title bar. Focus, where shown, is a 1px dotted `#000000` rectangle inset 4px from the content edge.

-----

## 4. Metrics

All derived from the 1995 spec. Point values shown at 2×.

| Element | Spec | @2× | Notes |
|---|---|---|---|
| Bevel | 2px | 4pt | Two 1px frames |
| Grid unit | 4px | 8pt | All spacing is a multiple: 2/4/8/16/24px → 4/8/16/32/48pt |
| Standard button | 75×23px | 150×46pt | Minimum size |
| Checkbox | 12×12px | 24×24pt | Tap target extended invisibly to 44pt |
| Title bar | 18px tall | 36pt | Gear (or ✕ on Settings) at the trailing edge |
| Title bar control | 16×14px | 32×28pt | Raised bevel, pixel glyph |
| Taskbar | 28px tall | 56pt | Extends into the home-indicator safe area. The bar spans edge to edge; buttons are inset one grid unit so they don't run into the bezel |
| Status panel | 12px tall | 24pt | Floats above the taskbar; only present after an action |
| Scrollbar | 16px wide | 32pt | Hidden on iOS; relevant for macOS |
| List row | — | **44pt min** | Spec rows are 14px/28pt — too small for a thumb. Deliberate deviation. |
| Photo thumbnail | 32×32px | 64×64pt | Sunken bevel frame |
| Row with photo | — | ~120pt | Text row + thumbnail + spacing |

**The one deliberate deviation from the spec** is row height: Windows 95 list rows were built for a mouse cursor. 44pt is Apple's minimum touch target and overrides authenticity. Checkboxes keep their authentic 24pt *visual* size with an extended invisible tap area — the look is period-correct, the target is not.

-----

## 5. Components

### Window (each tab)

A maximized Windows 95 window filling the screen.

```
┌─────────────────────────────────────────┐
│ Today - shove.95                    [⚙] │  title bar, 36pt, navy gradient
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────────┐ │
│ │  ☑  Repair bike            [ Mon ]  │ │  sunken white list well
│ │  ☐  Call dentist                    │ │
│ │  ☐  Build portfolio                 │ │
│ │     ┌────────┐                      │ │
│ │     │ photo  │                      │ │  64pt thumbnail, sunken frame
│ │     └────────┘                      │ │
│ │  ☑  B̶u̶y̶ ̶m̶i̶l̶k̶                        │ │
│ │  ─────────────────────────────────  │ │
│ │  [ + new task                     ] │ │  permanent add row
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ Repair bike → Tomorrow         [ Undo ] │  status bar, 24pt, sunken
├─────────────────────────────────────────┤
│ [Today] [Tomorrow] [Week] [General] │12:04│ taskbar, 56pt
└─────────────────────────────────────────┘
```

**Title bar** — 36pt, `#000080 → #1084D0` gradient, white W95FA text reading `{Tab} - shove.95`, left-aligned with 4px (8pt) padding. One title-bar control at the trailing edge: a 32×28pt raised button containing a custom pixel gear glyph, opening Settings. Microsoft's own control glyphs are **not** used.

**List well** — sunken bevel, `#FFFFFF` background, edge to edge. No row separators (Windows 95 list boxes have none).

**Status panel** *(revised 2026-08-04)* — a light panel (`statusBG`, raised bevel) carrying `#222222` text reading `{task} → {destination}`, with a flat `statusAccent` `Undo` block at the trailing edge. **No bevel on the Undo block** — it is a tint, not a button.

It is **not window furniture**. It is absent until an action occurs, floats *over* the list well rather than taking layout space (so rows never shift when it appears), and retires itself after 6 seconds. Any further action restarts that clock. Undo remains single-level and reachable for as long as the panel is up.

Originally this was a permanent silver status bar inset into the window chrome. The founder rejected that on device: standing chrome that is empty most of the time reads as broken, and greying out an always-present Undo advertises a control you cannot use.

**Taskbar** — 56pt, raised, `#C0C0C0`, extending into the safe area with buttons positioned above the home indicator. Four text-only buttons (`Today` `Tomorrow` `Week` `General`) sharing the width. The active tab renders **pressed** (sunken bevel, label offset 1px down-right, dotted-hatch fill). A sunken clock well at the trailing edge shows the current date/time.

### Task row

- **Checkbox** — 24pt sunken white box with a black pixel checkmark when ticked; 44pt tap target.
- **Text** — W95FA, one size, one weight, `#222222`, left aligned, truncating with `…` before the chip.
- **Important** — text in `#FF0000`. Colour only; no weight or size change.
- **Overdue** — a trailing-edge sunken mini-well (a miniature status-bar panel) containing the date in `#808080`: `Mon`, `2d`. Chips align in a fixed right-hand column so they can be scanned vertically. Row text stays `#222222`, undimmed.
- **Completed** — strikethrough **and** text to `#808080`. Both, because strikethrough alone on a pixel font at small size is easy to miss.
- **Dragging / swiping** — the entire row inverts to `#000080` background with `#FFFFFF` text, the Windows 95 list selection state.
- **Photo** — 64×64pt thumbnail beneath the text, inset to align with the **text**, not the checkbox, in a sunken bevel frame.

### Add row

A permanent row at the bottom of the list, visually a sunken text field. Tapping focuses it; return commits the task and **keeps focus** for consecutive entry. A small camera glyph at the trailing edge attaches a photo.

### Photo viewer

A Windows 95 window, near-full-screen, centred: navy gradient title bar, a close (`✕`) control drawn as a pixel glyph, the image in a sunken frame. **Appears instantly, closes instantly** — tapping anywhere outside dismisses it. Not draggable, not resizable.

### Empty state

`(empty)` centred in the list well, `#808080`.

-----

## 6. Typography

**W95FA** — an OpenType recreation of the MS Sans Serif bitmap, licensed **SIL OFL**, which explicitly permits embedding and redistribution inside a commercial application. It is the only typeface in the app: title bar, taskbar, task text, status bar, settings.

| Role | Spec | @2× |
|---|---|---|
| All text | 11px | 22pt |

One size, one weight, everywhere — as specified. Antialiasing is minimised (`.font(.custom(...))` with no dynamic optical adjustments); the font only renders correctly at whole multiples of its design size, which is why scaling is stepped rather than continuous (§7).

**Do not ship** the `Pixelated MS Sans Serif` webfont from 98.css — it is derived directly from Microsoft bitmaps and its licensing is unclear. W95FA is the clean choice.

-----

## 7. Accessibility Scaling

Dynamic Type is supported in **whole-pixel steps**, not continuously. The system text-size setting maps to the `pixel` token:

| System setting | `pixel` | Text size | Bevel | Grid |
|---|---|---|---|---|
| default | 2pt | 22pt | 4pt | 8pt |
| large | 3pt | 33pt | 6pt | 12pt |
| accessibility sizes | 4pt | 44pt | 8pt | 16pt |

The **entire interface** scales as one unit — text, bevels, controls, spacing — exactly like changing display resolution on a CRT. Because every step is an integer multiple, the pixel font stays crisp at all three.

Layouts must be verified at 4×, where fewer rows are visible and taskbar labels may need abbreviation.

**Other accessibility requirements:** all four taskbar buttons, the checkbox, the context menu and the swipe must carry VoiceOver labels and actions. Because the swipe is custom rather than `.swipeActions`, move actions must be exposed explicitly as VoiceOver custom actions — otherwise the app's primary gesture is unreachable without sight. Colour is never the sole carrier of meaning: Important is red *and* placed in the top tier; overdue is a chip, not a tint.

-----

## 8. Motion

> **Motion describes position, never appearance.**
> Anything that moves, moves continuously. Anything that appears or disappears does so instantly.

This governs every animation in the app. Windows 95 had no fades, scales, or dissolves — but it dragged continuously.

**Amendment, 2026-08-04.** The founder's read of the whole product: *"a very static vintage UI, but very responsive with smooth animations."* The frame is 1995; the response is 2026. So the rule above holds for everything **inside** the frame — chrome, labels, bevels, the photo viewer — while two things now carry modern motion, because their job is to answer a gesture rather than to redraw a surface:

- **The long-press menu springs in** (0.26s, bounce 0.38) scaled from its row anchor, the way iOS answers a long press. It leaves flat and fast (0.11s ease-out) — a bouncy dismissal reads as hesitation.
- **Tab changes slide** the list contents in from the side the tab lives on. Everything else holds still.

What did *not* change: appearance is still instant. The title text swaps with no crossfade, the taskbar highlight flips immediately, and the colour scheme repaints with animations explicitly disabled.

| Event | Behaviour |
|---|---|
| Swipe to move | The row **slides off the screen edge** in the swipe direction; rows below close the gap |
| Swipe at a dead end | Rubber-band resistance, spring back, light haptic |
| Drag to reorder | The real row follows the finger, rendered navy/white; other rows part to make space |
| Photo viewer open | **Instant.** No transition. |
| Photo viewer close | **Instant.** No transition. |
| Long-press menu open | **Springs** from the row's bottom-left anchor — scale 0.86 → 1 + fade, 0.26s, bounce 0.38 |
| Long-press menu close | Flat 0.11s ease-out, scaling back toward the anchor |
| Row held | Tints to `light` and scales to 0.97; **the tint outlives the finger** and holds while that row's menu is open |
| Tab change | Contents **slide in from the side the tab lives on** (0.22s ease-out). The sunken well, title bar and taskbar never move — the frame is fixed and the content travels through it. Title text and taskbar highlight swap instantly. |
| Button press | **Instant** bevel inversion |

**All motion is snapped to the pixel grid.** Moving elements travel in whole `pixel` increments (2pt at default scale) rather than at sub-pixel smoothness — smooth but quantised, like a sprite. This preserves the retro texture during movement instead of the illusion breaking the moment anything moves.

**Haptics:** light impact on swipe commit and on rubber-band; selection feedback on drag pickup and drop.

-----

## 9. Prohibited

Things that would break the system, listed so they don't get reintroduced by habit:

- Corner radii, drop shadows, blur, translucency, SF Symbols, system tint colours
- Any gradient other than the title bar
- Any red that isn't Important
- Fade, scale, dissolve, or cross-fade transitions of any kind
- Continuous (non-stepped) Dynamic Type
- Dark mode
- Microsoft's icon artwork, the Windows logo, the Start button, or the word "Windows" in any user-facing string


---

## 12. Colour schemes *(added 2026-08-04)*

Windows 95 shipped named Appearance schemes and swapping them was one of the era's
small pleasures, so the theme picker is period-correct rather than a modern bolt-on.
Five schemes ship: **Windows Standard**, **Desert**, **Eggplant**, **Rose**, **Slate**
(`Win95Scheme.swift`). They are picked from a **single row of window miniatures** —
title bar over body over well — with the selected one drawn pressed (sunken bevel,
nudged one pixel down and right) and named beneath the row. Five stacked rows with
checkboxes was a wall of chrome for one choice; the Win95 Appearance tab showed you
the scheme rather than naming it. Each supplies the full token set — surface, highlight, light,
shadow, darkShadow, text, the two title-bar gradient stops, selection pair, the list
well, and the status-panel pair.

Two rules hold across every scheme:

1. **Bevel structure never changes.** Only the palette moves; the two nested 1px
   frames stay exactly as §3 specifies. A scheme cannot introduce a radius or a shadow.
2. **`important` stays `#FF0000` in every scheme.** Colour carries exactly one meaning
   (§2). Remapping red to fit a palette would break that, so `Win95.important` is the
   one hard-coded `static let` in the theme.

Palettes are read through static accessors (`Win95.surface` etc.), so the chrome
subtree is rebuilt via `.id(scheme.id)` when the scheme changes. That `.id` sits
**inside** the presentation modifiers in `RootView` — rebuilding above them tears down
`showSettings` and slams the Settings window shut on every pick.

**Static accessors are invisible to SwiftUI.** A view whose own inputs haven't
changed is never re-rendered, so it keeps painting the previous palette. `TitleBar`
hit this exactly: its inputs (title, isClose, closure) don't move when the scheme
does, so inside the Settings cover — which sits outside the `.id` rebuild — the
window's own title bar stayed on the old colours while everything around it
repainted. The fix is the `\.win95Scheme` environment value: views that must repaint
on a scheme change read it and paint **from it** rather than from the statics. Any
new chrome that survives a scheme change unchanged needs the same treatment.

### Tab renaming

All four tabs are renamable (`AppSettings`, UserDefaults-backed). Renaming changes the
**label only** — `Bucket` semantics are date-derived and untouched, so a tab called
"Heute" still means today. An empty field restores the built-in name. At 4× the custom
name truncates to three characters, matching the built-in abbreviations.
