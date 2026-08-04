# Turning on iCloud sync (TASK-050)

Everything in the code is ready. What's left needs your Apple Account, so it
has to happen in Xcode on your machine — it's about two minutes.

## Why it isn't already on

With `cloudKitDatabase: .private(…)` and no iCloud entitlement, CoreData's
mirroring layer constructs a `CKContainer` the app isn't entitled to. That
raises an **Objective-C exception on a background queue**, which Swift's
`try/catch` cannot intercept — the app dies on launch with no usable error.
Verified 2026-08-04 by doing exactly that.

So the CloudKit path is behind a flag (`ShoveCloudKitEnabled` in Info.plist),
and until it's set the app runs on a local store. Nothing is lost either way —
same schema, same data, only the mirroring is absent.

## Steps

1. **Open the project** in Xcode → select the `shove95` target → **Signing &
   Capabilities**.
2. **Team:** pick your Apple Developer team. Leave *Automatically manage
   signing* ticked.
3. **+ Capability → iCloud.** Tick **CloudKit**.
   *The capability list is alphabetical and long — iCloud sits between HomeKit
   and In-App Purchase, well below the visible first screen. If it is genuinely
   absent: you are on PROJECT rather than the shove95 TARGET (capabilities are
   per-target), or no Team is selected yet — iCloud is paid-membership-only and
   Xcode hides it until a paid team is picked, which is why step 2 comes first.* Under Containers press **+**
   and enter:
   ```
   iCloud.com.lucasmaher.shove95
   ```
   Xcode creates the container in the developer portal and points the
   entitlements file at it.
4. **+ Capability → Background Modes.** Tick **Remote notifications** (this is
   how a change on one device wakes the other).
5. **Set the flag.** In `shove95/Info.plist` add:
   ```xml
   <key>ShoveCloudKitEnabled</key>
   <true/>
   ```
6. **Run on a device.** The simulator can sync, but two simulators signed into
   the same account is a poor test — use your iPhone.

`shove95/shove95.entitlements` is already written with the right container and
services; step 3 should simply adopt it. If Xcode creates a second entitlements
file, point **Build Settings → Code Signing Entitlements** back at this one.

## Verifying (TASK-051)

1. Install on two devices signed into the same Apple Account.
2. Add a task on device A. It should appear on B within a few seconds — with
   the app foregrounded on B, since that's when it processes changes.
3. Attach a photo on A; confirm the image (not just the row) arrives on B.
   Photos are separate records with CKAsset payloads, so they travel
   independently of the task and may land a moment later.
4. Turn off Wi-Fi on A, add a task, turn Wi-Fi back on. It should sync when the
   connection returns, with no prompt and no error.
5. Sign out of iCloud on A. The app must keep working, showing
   `iCloud: not signed in` in Settings and nothing else. **No alert is
   acceptable here** (FR-013).

## Things that will bite

- **First sync is slow.** CloudKit provisions the schema on first write; give
  it a minute before deciding it's broken.
- **The schema must be promoted to production** before any TestFlight or App
  Store build, in the CloudKit Console → Schema → *Deploy Schema Changes*.
  Development and production schemas are separate, and a build against
  production with an unpromoted schema silently syncs nothing.
- **Model changes after promotion are additive only.** You can add optional
  fields; you cannot rename or retype an existing one. This is why photos moved
  to their own entity now rather than later.
