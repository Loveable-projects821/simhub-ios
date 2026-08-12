# SimHub — iOS Companion App (Phase 1)

Connects directly to the Android hub's local WebSocket server (`ws://<android-ip>:8765`),
no cloud in between — matches the protocol from the Android `SimHubAndroid` project.

## Why no .xcodeproj is included
Xcode project files are a binary/plist format that's easy to corrupt by hand-editing
outside Xcode. Rather than risk handing you a project that won't open, here are the
5 source files plus exact steps to wire them into a fresh project — takes about 2 minutes.

## Setup steps
1. Open Xcode → **File → New → Project → iOS → App**.
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Name it `SimHub` (or anything you like)
2. Delete the auto-generated `ContentView.swift` and `SimHubApp.swift` (or `<YourName>App.swift`).
3. Drag all 5 files from this `Sources/` folder into the Xcode project navigator
   (check "Copy items if needed").
4. Open **Info.plist** (or the Info tab of your target) and add:
   - `App Transport Security Settings → Allow Arbitrary Loads` = **YES**
     (needed because the hub uses plain `ws://` on the local hotspot, not `wss://`)
   - `Privacy - Local Network Usage Description` = "SimHub connects to your Android hub over WiFi."
5. Open target **Signing & Capabilities** → **+ Capability** → add **Background Modes**
   → check **Voice over IP** (lets the app keep the socket open briefly in the background;
   see the limitation note below).
6. Build & run on a **real iPhone** (CallKit doesn't behave fully on the Simulator).

## What this build does
- Connects to the Android hub over WebSocket and pairs with the 6-digit PIN
- Live dashboard: SIM signal bars per slot, recent call log, SMS log
- When Android reports a call `"ringing"`, this app shows a **real native CallKit
  incoming-call screen** on the iPhone (lock screen style, with Answer/Decline)

## What this build does NOT do yet
- **No call audio.** Answering just fulfills the CallKit action right now — the hooks
  (`CallKitManager.onAnswer` / `onEnd`, and `didActivate`/`didDeactivate audioSession`)
  are already in place with comments showing exactly where to start/stop a WebRTC
  audio session in Phase 2.
- **Background/lock-screen alerting has a real limitation you should know about now:**
  Apple deprecated always-on background VoIP sockets years ago. Reliable "ring even
  if the app was killed" behavior requires **PushKit + a VoIP push certificate**,
  which means Apple's push servers have to be in the loop for that one specific
  piece — it can't be 100% local/no-cloud the way the Android-to-iPhone data path is.
  While the app is open/foregrounded on the same WiFi, everything above works with
  no cloud involved at all. If you want true background ringing later, that's the
  one piece that needs a (free, Apple-provided) push certificate — happy to add it
  when you're ready.

## Protocol reference
Same as documented in the Android project's README — first message sent must be:
```json
{ "type": "pair", "pin": "123456" }
```
Then the app listens for `"signal"`, `"call"`, and `"sms"` events broadcast from the hub.
