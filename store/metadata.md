# App Store Connect — metadata for shove.95

Copy each block into the matching field. Character limits are Apple's; the
counts in brackets are what these drafts actually use.

---

## Name  *(30 max)*

```
shove.95
```
[8]

## Subtitle  *(30 max)*

```
A to-do list from 1995
```
[22]

Alternatives, if that one reads as too flippant:

- `Four places. One swipe.` [23]
- `Tasks that shove sideways` [25]

## Category

- **Primary:** Productivity
- **Secondary:** Utilities

## Age rating

4+ — no objectionable content, no web access, no user-generated content shared
with anyone.

---

## Promotional text  *(170 max — editable without a new build)*

```
Four tabs, one gesture. Shove a task to tomorrow, to this week, or out of the way entirely — and let the ones that matter shout at you in red.
```
[141]

---

## Description  *(4000 max)*

```
shove.95 is a to-do list that looks like it came free with a beige computer.

Everything lives in four places: Today, Tomorrow, Week, and General. A task is always in exactly one of them, so nothing can quietly disappear into a list you forgot you made.

MOVE THINGS WITH ONE GESTURE

Swipe a task right and it shoves forward — Today becomes Tomorrow, Tomorrow becomes this Week. Swipe left and it comes back. No date pickers, no menus, no dragging a card across a board. The whole app is built around that one motion.

WHAT ELSE IT DOES

• Mark a task important and it turns red, so the thing you're avoiding is the thing you see first
• Attach photos — a parcel label, a whiteboard, a receipt — and open them in a proper little window
• Zoom into a photo, and select text inside it: phone numbers, addresses, opening hours
• Overdue tasks roll forward to Today by themselves, instead of rotting in the past
• Completed tasks tidy themselves into an Archive at the end of the day
• Separate workspaces, so work and home don't share a list
• Five colour schemes, and a switch to the normal iOS font if the pixel type is hard to read
• Rename the tabs to whatever you actually call them

IT SYNCS, AND IT COLLECTS NOTHING

Turn on iCloud and your tasks and photos follow you between your iPhone and iPad, through your own private iCloud account. There is no account to make, no email to hand over, no analytics, no advertising, and no server belonging to us — because there is no us. Your data is on your device and in your iCloud, and nowhere else.

WHY IT LOOKS LIKE THAT

Because software used to tell you what it was doing. A button looked pressable. A window had edges. Nothing faded politely into the background hoping you wouldn't notice it. shove.95 is a small argument that the old interface was clearer, on a device that could use some clarity.
```
[~1730]

---

## Keywords  *(100 max, comma-separated, no spaces after commas)*

```
todo,task,list,retro,win95,windows,pixel,90s,nostalgia,productivity,reminders,swipe,simple,offline
```
[97]

Notes on the choices:
- No "shove" or "95" — your own app name is already indexed, spending
  characters on it is waste.
- No plurals where the singular already matches ("task" also matches "tasks").
- "offline" and "simple" are what people search when they're sick of
  subscription to-do apps, which is the audience for this.

---

## URLs

| Field | Value |
|---|---|
| Privacy Policy URL *(required)* | `https://lucasmaher-hash.github.io/shove-95/privacy.html` |
| Support URL *(required)* | `https://github.com/lucasmaher-hash/shove-95/issues` |
| Marketing URL *(optional)* | `https://lucasmaher-hash.github.io/shove-95/` |

---

## App Privacy  *(the questionnaire, not the policy)*

Answer **"No, we do not collect data from this app."**

That is the honest answer and it is worth double-checking before you submit,
because it is the one claim Apple actively verifies. It holds because:

- there are no third-party SDKs of any kind in the project
- CloudKit writes to the user's own private database, which the developer
  cannot read — Apple does not count this as collection
- nothing is sent anywhere else

If you ever add analytics or a crash reporter, this answer changes and the
privacy policy needs updating with it.

---

## Screenshots

Six are in `store/screenshots/`, all 1320 × 2868 (6.9", iPhone 17 Pro Max),
which is the only size App Store Connect now requires — it scales them down
for smaller devices itself.

| File | Shows |
|---|---|
| `01-today.png` | Today, with an overdue task, two important ones and one ticked off |
| `02-week.png` | The Week tab |
| `03-photo.png` | A task with a photo attached |
| `04-viewer.png` | The photo open in its own window |
| `05-settings.png` | Colour schemes, typeface switch, renamed tabs, workspaces |
| `06-scheme.png` | The same list in a different colour scheme |

Upload at least `01`, `04` and `06` — first, a clear look at the actual list;
then the one feature nobody expects; then proof it isn't only blue.

⚠️ `05-settings.png` reads "iCloud: not signed in" along the bottom, because
the screenshots were taken on a clean simulator deliberately kept away from a
real account. Either skip that one, or retake it on a signed-in device.

---

## Build & review notes

- **Review notes field:** no demo account needed — the app has no login. Worth
  saying so explicitly, since a reviewer who expects one may reject for a
  missing account.
- **Export compliance:** the app uses no encryption beyond HTTPS/iCloud, so the
  answer to "does your app use encryption?" is the standard exempt path.
- **Copyright:** `2026 Lucas Maher`
