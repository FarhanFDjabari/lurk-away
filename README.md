<div align="center">
  <img src="LurkAway/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" alt="LurkAway icon">
  <h1>LurkAway</h1>
  <p><strong>A macOS menu bar anti-theft watchdog. Step away, and your device watches itself.</strong></p>
</div>

LurkAway is a lightweight menu bar app for macOS. When you walk away, it arms itself, blurs and locks the screen, and — if someone tampers with the device — blasts an alarm and holds a full-screen lock until you return and unlock with Touch ID.

Everything runs on-device. No account, no network, no telemetry.

## Features

- **Walk-away auto-arm** — pulses the front camera (~1 frame/1.5s) and arms when your face is gone for ~5 seconds.
- **Blurred armed overlay** — a full-screen frosted overlay with watching eyes; the camera turns **off** while armed to save power.
- **Tamper alarm** — while armed, unplugging AC power or moving the lid triggers a loud synthesized siren and a black lock screen.
- **Kiosk lockdown** — both the armed and lock overlays suppress the menu bar, Dock, Mission Control, app switching, force-quit, and logout, so the device can't be used or escaped without authenticating.
- **Touch ID unlock** — button-triggered; the only way out.
- **Audible-floor guard** — on lock, output is forced to the built-in speakers and unmuted, and volume can't be dropped below 10% until you unlock. Your prior output device, volume, and mute state are restored afterward.
- **Custom lock message** — shown to whoever holds the device.
- **Start at login** — optional, so protection is always on after boot.

## How it works

```
Idle (auto-watch on)
  └─ camera pulses, looking for your face
       └─ face gone ~5s ──▶ ARMED
                              │  camera OFF, screen blurred (kiosk overlay)
                              │  tamper sensors live: AC power + lid
                              ├─ you return ──▶ Unlock (Touch ID) ──▶ Idle
                              └─ tamper detected ──▶ ALARM
                                                       │  siren + black lock screen
                                                       │  audio forced audible
                                                       └─ Unlock (Touch ID) ──▶ Idle
```

Tamper detection while armed uses documented, near-zero-power signals:

- **Power** — AC adapter unplugged (`IOKit.ps`).
- **Lid** — hinge angle moved beyond a threshold (Apple Silicon lid-angle HID sensor).

At least one sensor must stay enabled.

## Requirements

- macOS 26.5 or later
- A Mac with Touch ID (for unlocking)
- Front camera (for walk-away detection); the lid trigger needs an Apple Silicon laptop

## Build & run

```bash
xcodebuild -project LurkAway.xcodeproj -scheme LurkAway -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/LurkAway-*/Build/Products/Debug/LurkAway.app
```

Open the built `.app` (not the raw binary) so macOS grants camera access through LaunchServices. On first run, grant the camera permission when prompted. "Start at login" and the kiosk overlays may ask for approval in **System Settings › General › Login Items** the first time.

Or open `LurkAway.xcodeproj` in Xcode and Run.

## Settings

Open **Settings** from the menu bar:

- **Protection** — auto-watch on walk-away, start at login.
- **Sensors** — which tamper triggers are active (AC power, lid).
- **Alarm** — the lock-screen message.

## Privacy

- The camera is used **only** to detect whether a face is present, entirely on-device via Apple's Vision framework. No images are stored or transmitted.
- The camera is **off** the whole time the device is armed.
- No network access, accounts, or analytics.

## Project structure

```
LurkAway/
├─ AppState.swift              # State machine: idle → armed → alarm; wires managers
├─ LurkAwayApp.swift           # MenuBarExtra + Settings scenes
├─ Managers/
│  ├─ FaceDetectionManager     # Pulse face detection (walk-away)
│  ├─ MotionMonitor            # Tamper coordinator (power + lid)
│  ├─ PowerMonitor             # AC unplug detection
│  ├─ LidAngleMonitor          # Lid-angle sensor
│  ├─ ArmedOverlayManager      # Blurred kiosk armed overlay
│  ├─ LockScreenManager        # Black kiosk lock overlay
│  ├─ AlarmController          # Siren playback
│  ├─ SirenGenerator           # In-memory WAV siren (no bundled asset)
│  ├─ LockAudioGuard           # Audible-floor enforcement (CoreAudio)
│  ├─ SystemVolume             # CoreAudio volume / mute / output device
│  ├─ BiometricManager         # Touch ID / password (LocalAuthentication)
│  ├─ SleepGuard               # Keeps sensors alive while armed
│  └─ LaunchAtLogin            # SMAppService login item
└─ Views/                      # SwiftUI menu, settings, overlays
```

## Limitations

- **Clamshell sleep** — macOS forces sleep when the lid is fully closed; that's a hardware-level behavior a sandboxed app can't override, so the lid trigger reacts to lid *movement* rather than depending on staying awake closed.
- **Recovery** — while locked, the escape hatches are disabled by design; recovery is Touch ID (or, worst case, a hard power-off).

## License

[MIT](LICENSE) © 2026 Farhan Djabari
