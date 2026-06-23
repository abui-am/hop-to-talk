# Hop to Talk

**Komunikasi suara untuk hiking** — walkie-talkie style voice chat for small hiking groups, using direct WiFi between iPhones when there is no cellular signal.

Hop to Talk is an iOS app for recreational hikers (typically 3–6 people) who want backup voice communication on the trail without carrying a separate radio. Phones talk to each other over **WiFi Aware P2P** — no cell tower, no internet, no server.

> **Not** an emergency/SOS tool, satellite messenger, or PMR radio replacement. Best used in **foreground (Hiking Mode)** with the app active.

## What it does

- **Pair at basecamp** — connect crew iPhones via WiFi Aware before entering the trail
- **Trail formation** — assign positions (Depan / Tengah / Belakang) for range and relay expectations
- **Push-to-talk (PTT)** — hold to talk; broadcast to the whole party (no private calls)
- **Half-duplex floor control** — one speaker at a time
- **Two radio modes**
  - **Mode Live** — always listening, real-time voice (shorter hikes)
  - **Mode Hemat** — radio on demand when you press PTT, then powers down (longer hikes)
- **Mesh relay** (Mode Live) — middle hikers can forward packets to extend line-of-sight range on a linear trail
- **Battery tiers** — Eco / Balanced / Always On heartbeat and screen policies

## Requirements

| Requirement | Detail |
|-------------|--------|
| Device | iPhone 12 or newer (WiFi Aware hardware) |
| OS | iOS 26.5+ |
| Xcode | 26.5+ to build |
| Testing | **Physical iPhones** — Simulator does not support WiFi Aware pairing |
| Permissions | Microphone |
| Entitlements | WiFi Aware Publish + Subscribe |

## How to build

```bash
# Simulator (UI compile only — no real radio)
xcodebuild -scheme hop-to-talk \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO build

# Device (requires signing + provisioning)
open hop-to-talk.xcodeproj
```

Run on two or more physical iPhones for end-to-end voice tests.

## User flow

1. **Onboarding** — how the app works and its limits
2. **Trailhead setup**
   - Team name and your display name
   - Pair all crew (`DevicePairingView` / `DevicePicker`)
   - Set trail formation
   - Choose hike duration → auto-recommended mode and battery tier
3. **Active hike** — `ActiveHikeView`: status bar, formation bar, hold-to-talk, rest / end hike
4. **Summary** — duration, PTT count, session stats

## Architecture

```
SwiftUI Views
    └── HikingSessionViewModel
            ├── PairingService          (WAPairedDevice monitoring)
            ├── PeerNetworkService      (NetworkListener / NetworkBrowser, UDP)
            ├── OperatingModeService    (Mode Live vs Mode Hemat lifecycle)
            ├── AudioEngineService      (AVAudioEngine capture / playback)
            ├── FloorControlService     (half-duplex floor claim / release)
            ├── MeshRelayService        (TTL + dedup flood forward)
            └── BatteryManager          (tiers, Hiking Mode idle timer)
```

**Transport:** WiFi Aware + Network framework + UDP (`_hop-talk._udp`)

**Packets:** `HopPacket` — audio chunks, floor control, heartbeats; app-layer mesh with TTL for relay in Mode Live.

## Project structure

```
hop-to-talk/
├── hop_to_talkApp.swift
├── ContentView.swift              # RootView navigation
├── Models/                        # Party, packets, floor state, UX enums
├── Services/                      # Network, audio, pairing, mesh, battery
├── ViewModels/
│   └── HikingSessionViewModel.swift
├── Views/
│   ├── Onboarding/
│   ├── Trailhead/
│   ├── Hike/
│   └── Components/
├── Info.plist                     # Mic usage, WiFiAwareServices
└── hop-to-talk.entitlements       # WiFi Aware capabilities
```

## Configuration

- **Bundle ID:** `com.abui.hop-to-talk`
- **Service:** `_hop-talk._udp` (publishable + subscribable in `Info.plist`)
- **Deployment target:** iOS 26.5

## Known limitations

- **Foreground receive** — reliable audio receive requires the app in foreground (Hiking Mode); background offline receive is not supported on iOS
- **Multi-peer connect** — browse logic currently connects to the first discovered peer per session; full 3–6 person mesh needs connecting to all paired crew (planned improvement)
- **Pairing required** — crew must be paired at basecamp; adding members mid-trail without signal is impractical
- **Audio format** — mic capture is resampled to a shared 16 kHz mono wire format so sender and receiver always match; further quality tuning in progress
- **No automated tests** — manual device testing required for radio features

## Manual test checklist

1. Install on 2+ iPhones (iOS 26.5+)
2. Complete onboarding → pair at basecamp
3. Choose **Mode Live** (&lt; 4 hour duration) for easiest first test
4. Start hike on both phones
5. Hold PTT on one phone — other should hear voice
6. Verify floor control: only one person can talk at a time

## License

Private project — see repository owner for terms.
