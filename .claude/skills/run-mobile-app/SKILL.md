---
name: run-mobile-app
description: Launch the LifePilot Finance Flutter app (mobile/) on an Android emulator on this Windows machine, drive its UI, take screenshots, and check for Dart errors. Use this whenever the user asks to run, start, launch, open, screenshot, or manually test the mobile app or the design system showcase, or wants to confirm a Flutter change works in the real app rather than only in `flutter test`. The emulator and adb need non-obvious handling here, so read this before reaching for `flutter run` or `flutter emulators --launch`.
---

# Running LifePilot Finance on an Android emulator

The Flutter app lives in `mobile/`. The repo root is a Python backend; `flutter`
commands only work from `mobile/`.

Two things about this machine will waste your time if you don't know them, and
both are the reason this skill exists. Read "The two traps" before running anything.

## The two traps

**1. `flutter emulators --launch` starts an emulator that dies with its parent.**
The emulator becomes a child of the launching shell. When that command's shell
exits — which it does immediately, and which any background-task wrapper does
too — the emulator goes with it. The failure is delayed and misleading: the APK
builds fine (~2 minutes) and then install fails with
`adb.exe: device 'emulator-5554' not found`.

Launch it detached instead, via PowerShell `Start-Process`:

```powershell
$emu = "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe"
Start-Process -FilePath $emu -ArgumentList '-avd','cag_test','-no-snapshot-save' -WindowStyle Minimized
```

**2. `adb` is not on PATH.** It is at
`%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`. Assign it to a variable
once and call it through that.

Available AVDs: `cag_test` and `foodexpress_test` (both Android 14 / API 34,
1080x2340, density 440). Either works; `cag_test` is the default here. Neither
is project-specific — they're left over from other projects.

## Launch sequence

```bash
# $USER is empty in the Bash tool here — use $HOME, which resolves correctly
ADB="$HOME/AppData/Local/Android/Sdk/platform-tools/adb.exe"
```

1. Start the emulator detached (see trap 1). Skip if `$ADB devices` already
   lists one.
2. Wait for boot — the device appears in `adb devices` well before it can accept
   an install, so poll the property rather than the device list:
   ```bash
   until [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n')" = "1" ]; do sleep 5; done
   ```
   Run this as a background task rather than a foreground sleep loop.
3. `cd mobile && flutter pub get`
4. `flutter run -d emulator-5554 --debug`, as a background task so it stays
   attached and hot reload remains available.

Gradle: ~130s cold, ~8s warm. The build is already configured for offline use
(the repo pins the Gradle `-bin` distribution deliberately — don't change it).

You've succeeded when the log shows `Flutter run key commands` and a Dart VM
Service URL.

## Driving the UI

```bash
# device-side paths need MSYS_NO_PATHCONV=1 from the Bash tool, or Git Bash
# rewrites /sdcard/... into a Windows path and screencap fails
MSYS_NO_PATHCONV=1 "$ADB" shell input tap <x> <y>
MSYS_NO_PATHCONV=1 "$ADB" shell screencap -p /sdcard/s.png

# the host side of `adb pull` needs a real Windows path — adb.exe is a Windows
# binary and will not accept the /c/Users/... form
MSYS_NO_PATHCONV=1 "$ADB" pull /sdcard/s.png 'C:\path\to\scratchpad\s.png'
```

Then read the PNG to actually look at it. A screenshot you don't open proves
nothing.

**Wait 6–8 seconds after any input before capturing.** This emulator is slow —
at startup it averaged ~25s per frame (`app_time_stats avg=24986ms`,
`Skipped 507 frames`) before settling to a usable ~7–20ms. A screenshot taken
2s after a tap shows a stale frame, and stale frames look exactly like bugs:
during one session they made the tab bar appear to change on its own, which
sent the investigation down a false trail. Before reporting any surprising UI
behaviour, capture twice several seconds apart and compare — identical
checksums mean the UI is settled and what you're seeing is real:

```bash
md5sum a.png b.png
```

## Checking for errors

`flutter run`'s own output is noisy with harmless emulator GPU complaints —
`Failed to choose config with EGL_SWAP_BEHAVIOR_PRESERVED`, `Unable to match
the desired swap behavior`, `mapper 4.x is not supported`, `Davey!`, and
`app_time_stats`. These are the emulator, not the app. Ignore them.

For real problems, filter logcat:

```bash
MSYS_NO_PATHCONV=1 "$ADB" logcat -d | grep -Ei "EXCEPTION CAUGHT|FlutterError|RenderFlex|overflowed|Unhandled|FATAL"
```

Emulator Bluetooth noise (`bt_btu_hcif`, `AdapterState`) also matches
`Unhandled` and is unrelated to the app.

## What you should see

As of Phase 02, `main.dart` runs `DesignSystemShowcase` — there are no product
screens yet, and every figure is placeholder data. Five scrollable tabs:
Colour, Type, Components, Finance, Charts. The eye icon in the app bar is a
light/dark theme toggle (not a privacy/hide-amounts control, which is what it
looks like in a finance app).

Phase 03 replaces `main.dart` with the real root widget. When that lands, this
section is the part of this skill that goes stale first.

Process name for `pidof` and `am` commands: `com.lifepilot.lifepilot_finance`.
