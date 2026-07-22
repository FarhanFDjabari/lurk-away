<div align="center">
  <img src="LurkAway/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" alt="LurkAway icon">
  <h1>LurkAway</h1>
  <p><strong>A macOS menu bar anti-theft watchdog. Step away, and your device watches itself.</strong></p>
</div>

LurkAway is a lightweight menu bar app for macOS. When you walk away, it arms itself, blurs and locks the screen, and — if someone tampers with the device — blasts an alarm and holds a full-screen lock until you return and unlock with Touch ID.

Everything runs on-device. No account, no network, no telemetry.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/W0B022MCZW)

## Features

- **Walk-away auto-arm** — pulses the front camera (~1 frame/1.5s) and arms when your face is gone for ~5 seconds.
- **Blurred armed overlay** — a full-screen frosted overlay with watching eyes; the camera turns **off** while armed to save power (it powers on briefly only to grab an evidence photo at alarm time, if that option is enabled).
- **Tamper alarm** — while armed, unplugging AC power or moving the lid triggers a loud synthesized siren and a black lock screen.
- **Evidence capture** *(optional)* — on a tamper, LurkAway grabs one compact photo of whoever is at the device and saves it **on this Mac only**. Tuned for a small, readable file (~30–80 KB), optionally geotagged. Reveal or delete stored photos from Settings anytime.
- **Remote alert** *(optional, off by default)* — get notified the moment a tamper fires, via [ntfy](https://ntfy.sh): a push with the photo inline (open a topic URL in a browser, or use the ntfy app) and/or a plain email. No account, no server to run. See the [remote alerts setup guide](docs/ntfy-setup.md).
- **Tunable detection** — set the walk-away delay, lid-movement sensitivity, and siren volume in Settings.
- **Alarm with the lid closed** *(optional)* — normally macOS sleeps the instant the lid shuts, so the siren can't sound until the lid reopens. Enable this to keep the Mac awake **only while armed**, so closing the lid triggers the siren immediately. Sleep returns to normal the moment you unlock or stop watching — and reverts automatically even if the app crashes. Requires a one-time administrator authorization (see [Keep awake with the lid closed](#keep-awake-with-the-lid-closed)).
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

## Install with Homebrew

```bash
brew tap farhanfdjabari/lurkaway https://github.com/FarhanFDjabari/lurk-away
brew trust --cask farhanfdjabari/lurkaway/lurkaway
brew install --cask lurkaway
```

Homebrew refuses to load casks from third-party taps until you trust them, hence the
middle step — it's a one-time confirmation that you've read [the cask](Casks/lurkaway.rb)
and are happy with what it does.

Upgrade later with `brew upgrade --cask lurkaway`; remove with `brew uninstall --cask lurkaway`
(add `--zap` to also delete settings and stored evidence photos).

The cask strips the Gatekeeper quarantine attribute after install, since release builds
aren't notarized (see [Installing a downloaded release](#installing-a-downloaded-release)).

## Build & run

```bash
xcodebuild -project LurkAway.xcodeproj -scheme LurkAway -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/LurkAway-*/Build/Products/Debug/LurkAway.app
```

Open the built `.app` (not the raw binary) so macOS grants camera access through LaunchServices. On first run, grant the camera permission when prompted. "Start at login" and the kiosk overlays may ask for approval in **System Settings › General › Login Items** the first time.

Or open `LurkAway.xcodeproj` in Xcode and Run.

## Installing a downloaded release

Release builds are **not** notarized with an Apple Developer ID, so macOS Gatekeeper
quarantines the downloaded app and shows a blocking prompt like *"Apple could not verify
'LurkAway' is free of malware…"* (no **Open** button).

After moving `LurkAway.app` to `/Applications`, remove the quarantine attribute once and it
opens normally from then on:

```bash
xattr -dr com.apple.quarantine /Applications/LurkAway.app
```

Building from source (above) avoids this entirely — locally built apps aren't quarantined.

## Settings

Open **Settings** from the menu bar:

- **Protection** — auto-watch on walk-away, start at login.
- **Sensors** — which tamper triggers are active (AC power, lid).
- **Detection** — walk-away delay, lid-movement sensitivity, siren volume.
- **Alarm** — the lock-screen message.
- **Alerts** — capture an evidence photo, tag it with location, and opt-in remote alerts via ntfy; plus reveal/delete stored evidence. See the [remote alerts setup guide](docs/ntfy-setup.md).
- **Advanced** — keep the Mac awake with the lid closed while armed (see below).

## Keep awake with the lid closed

By default macOS forces the machine to sleep the moment the lid is fully shut, so the
alarm can only start once the lid is reopened. The optional **"Keep Mac awake with the lid
closed"** setting (Settings › Advanced) removes that gap: while armed, it disables
lid-close sleep so the siren sounds with the lid down, then restores normal sleep as soon
as you unlock or stop watching.

Disabling system sleep requires root, so this is done by a small privileged helper:

- **One-time authorization.** Enabling the setting installs a helper daemon via
  `SMAppService`. macOS asks you to approve it once under **System Settings › General ›
  Login Items & Extensions**. No password prompt on later arms.
- **Least privilege.** The helper (`com.lurkaway.sleepd`) exposes a single XPC operation —
  toggle lid-close sleep — and only accepts connections from LurkAway signed by the same
  Developer ID. It runs `pmset disablesleep` with a fixed argument list; nothing else.
- **Fail-safe by design.** Sleep is only ever disabled while armed, and is restored on
  disarm, unlock, or app quit. If the app **crashes or is force-quit**, the helper detects
  the dropped connection and reverts within seconds; a 30-second heartbeat watchdog and a
  revert-on-launch backstop cover hangs and unclean shutdowns. There is no state where the
  Mac is left unable to sleep after LurkAway is gone.

Turning the setting off unregisters the helper.

> **Notarization:** for distributed builds the helper must be notarized together with the
> app (it's embedded at `Contents/MacOS/com.lurkaway.sleepd` with its launchd plist at
> `Contents/Library/LaunchDaemons/`). Locally built and development-signed apps register
> the helper fine on the same machine.

## Privacy

LurkAway is on-device and silent by default. The optional features are opt-in and clearly labelled:

- **Walk-away detection** uses the camera **only** to check whether a face is present, entirely on-device via Apple's Vision framework. Those frames are never stored or transmitted.
- The camera is **off** while armed. The one exception: if **evidence capture** is enabled, the camera powers on for a fraction of a second at alarm time to grab a single photo, then shuts off.
- **Evidence photos stay on your Mac** (`~/Library/Application Support/LurkAway/Evidence`). They are never uploaded unless you also enable remote alerts. You can delete them anytime from Settings › Alerts.
- **Location tagging** is off by default; when enabled it asks for permission and records a coarse location with the alert.
- **Remote alerts** are off by default and are the only feature that leaves your Mac. When enabled, a tamper sends the notification — and, in topic mode, the photo — to the ntfy server you configure, over HTTPS. With remote alerts off, LurkAway makes **no network connections at all**.
- No accounts, no analytics, no telemetry.

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
│  ├─ SleepGuard               # Prevents idle sleep while armed (IOPMAssertion)
│  ├─ SleepDaemonClient        # Registers/controls the lid-sleep helper over XPC
│  ├─ LaunchAtLogin            # SMAppService login item
│  ├─ EvidenceCaptureManager   # One-shot compact JPEG snapshot at alarm
│  ├─ LocationTagger           # One-shot coarse geotag (CoreLocation)
│  ├─ EvidenceStore            # Saves / counts / deletes evidence on disk
│  ├─ EvidenceReporter         # Orchestrates capture + geotag + remote alert
│  ├─ NotificationSender       # ntfy client (topic photo + optional email)
│  └─ KeychainStore            # Optional ntfy token (Keychain, not UserDefaults)
└─ Views/                      # SwiftUI menu, settings, overlays

docs/
└─ ntfy-setup.md               # Remote alerts setup & troubleshooting guide

Shared/
└─ SleepControlProtocol.swift  # XPC contract, compiled into app + helper

SleepHelper/                   # Privileged LaunchDaemon (runs as root)
├─ main.swift                  # XPC listener + client code-signing check
├─ SleepController.swift       # pmset toggle + watchdog + fail-safe reverts
└─ com.lurkaway.sleepd.plist   # launchd plist (embedded in the app bundle)
```

## Limitations

- **Clamshell sleep** — by default macOS forces sleep when the lid is fully closed, so without the optional [keep-awake helper](#keep-awake-with-the-lid-closed) the lid trigger reacts to lid *movement* and the siren only becomes audible once the lid is reopened. Enabling the helper keeps the Mac awake while armed so the siren sounds with the lid shut.
- **Recovery** — while locked, the escape hatches are disabled by design; recovery is Touch ID (or, worst case, a hard power-off).

## License

[MIT](LICENSE) © 2026 FarhanFDjabari
