# Wheel Filter

A small native macOS menu bar utility for games where the mouse wheel feels too sensitive.

## Why this exists

Have you played a game on macOS where a small turn of the mouse wheel zooms the camera in or out far too quickly, or jumps through several weapons or inventory slots? Wheel Filter was written to make that kind of wheel input easier to control in selected games.

It filters extra and closely spaced scroll events, while keeping ordinary applications outside your game list unchanged. You choose which games to filter and how much time to leave between same-direction inputs. It is a standalone menu bar app; no game mod or plug-in installation is needed.

It can help when the problem comes from too many scroll events. If a game zooms too far in response to a single accepted event, Wheel Filter does not reduce that event's magnitude, so it may not solve that case.

[中文说明](README.zh-CN.md)

## Features

- Apply filtering only to selected foreground games.
- Choose a 30, 40, 50, or 75 ms interval (default: 50 ms).
- Switch scroll direction immediately without waiting for the interval.
- Enable or disable filtering from the menu bar.
- Remember your game list and settings locally.

## Requirements

- macOS 13 or later.
- Xcode Command Line Tools to build; a full Xcode installation is not required.
- Accessibility permission to intercept scroll events.

The build targets the Mac's current architecture. This repository does not currently provide a notarized release or universal binary. Compatibility with every mouse, game, and macOS version has not been verified.

## Build and run

Install Apple's command line tools if needed:

```sh
xcode-select --install
```

From the repository directory:

```sh
./Scripts/build-app.sh
open "outputs/Wheel Filter.app"
```

The build runs the debouncer tests, compiles the app, and applies a local ad-hoc signature. Build artifacts are excluded from version control.

For a debug build:

```sh
./Scripts/build-app.sh debug
```

Both configurations write to the same app path. Quit a running copy before rebuilding.

## Setup

Before configuring a game, launch the app and grant **Accessibility** permission when prompted. The mouse icon appears in the menu bar; there is no Dock icon.

1. **Add the game.** Bring the game to the foreground, open Wheel Filter's menu, check **Front app**, and choose **Add This App as a Game**.
2. **Choose the interval.** Open **Debounce** and start with **50 ms**. A longer interval filters more closely spaced inputs; a shorter interval preserves faster intentional scrolling.
3. **Enable filtering.** Make sure **Enable Wheel Filter** is checked. It is checked by default on a fresh installation; clicking an already checked item turns it off.
4. **Try it in the game.** Return to the game. A filled mouse icon indicates active filtering. Test camera zoom or weapon/item selection and adjust the interval if needed.

Use **Configured Games** to remove an application. Applications are identified by bundle ID; an application without one cannot be added.

For automatic startup, add the app in **System Settings → General → Login Items**.

## System permissions

| Permission | Why it is needed | Where to enable it |
| --- | --- | --- |
| Accessibility (required) | Intercept scroll events and allow or suppress them before they reach the game | System Settings → Privacy & Security → Accessibility |

The current implementation explicitly requests Accessibility permission only. It does not request Screen Recording, Automation, Full Disk Access, or a separate Input Monitoring permission. If the event tap is unavailable, check Accessibility and use **Retry Event Tap**. Moving or rebuilding the app may require removing and re-adding its Accessibility entry.

## Signing and downloads

The build script applies an **ad-hoc signature** (`codesign --sign -`). This is a local signature, not a Developer ID certificate, and the app is not notarized by Apple. Building from source requires no Apple Developer account; the resulting app still needs Accessibility permission.

A prebuilt app downloaded from GitHub may be blocked by Gatekeeper as being from an unidentified developer or because Apple cannot verify it. A valid ad-hoc signature does not establish a trusted publisher. The exact alert depends on the macOS version and download's quarantine state. A ZIP or DMG does not change that signing status.

If you trust the downloaded app and macOS provides the override, attempt to open it, then go to **System Settings → Privacy & Security → Open Anyway** and confirm. Follow [Apple's instructions](https://support.apple.com/en-us/102445); do not disable Gatekeeper globally.

For normal distribution under default Gatekeeper settings, a release would need **Developer ID signing and Apple notarization**, including the corresponding Apple Developer Program setup. See [Apple's distribution guidance](https://developer.apple.com/developer-id/).

For now, the supported installation path is building locally with `Scripts/build-app.sh`. There is no prebuilt release attached to this repository yet.

## How filtering works

Filtering is active only when the master switch is enabled, Accessibility permission is available, the event tap is running, and the foreground application is configured.

The filter reads `kCGScrollWheelEventDeltaAxis1` (vertical line delta):

| Input | Result |
| --- | --- |
| Zero vertical line delta | Drop the entire event |
| Nonzero delta with a different direction from the last accepted event | Pass immediately |
| Same direction within the interval since the last accepted event | Drop |
| Same direction at or beyond the interval | Pass |

Dropped events do not extend the interval. Changing the active state or interval resets the debouncer. Other applications receive events unchanged.

This is an event-count filter, not a fixed-distance scroll tool. It does not normalize delta magnitude, remove acceleration, or add smooth scrolling. It does not distinguish mice from trackpads: all scroll events in a selected application follow the same rules. Pure horizontal events and small movements with zero line delta are dropped there, even if another delta field is nonzero. Fast intentional same-direction steps may also be filtered; choose a shorter interval if needed.

## Troubleshooting

- **Standby / waiting for a game:** check the foreground application, configured games, and master switch.
- **Accessibility permission required:** enable the app in Accessibility settings. After moving or rebuilding the app, you may need to remove its old entry and add it again.
- **Event tap unavailable:** grant permission, then choose **Retry Event Tap**.
- **Too many intentional steps are lost:** reduce the debounce interval or disable filtering for that application.
- **The app does not open through Finder or `open`:** for diagnosis, run `"outputs/Wheel Filter.app/Contents/MacOS/WheelFilter"` from the repository directory. Direct execution has worked on the development machine where LaunchServices launch behavior was inconsistent; this does not establish a general fix.

If reporting a problem, include the macOS version, mouse model, game, selected interval, other mouse utilities in use, and steps to reproduce. Avoid posting personal application lists or logs containing private information.

## Development

```text
Sources/WheelFilter/
  main.m               App entry point
  WFAppDelegate.*      Menu bar, application selection, preferences, permissions
  WFEventFilter.*      Event tap lifecycle and event dispatch
  WheelDebouncer.*     Stateful filtering decisions
Tests/
  WheelDebouncerTests.m
Scripts/
  build-app.sh
Resources/
  Info.plist
```

Every build runs the existing tests for zero deltas, same-direction timing, direction changes, and reset behavior. They validate the decision algorithm; they do not exercise Accessibility permissions, the menu, or actual game input. Verify those manually when changing the integration.

The app contains no network code or telemetry. Preferences use the local `com.uroboros.WheelFilter` domain.

This project uses AI coding tools to assist with implementation, refactoring, and documentation. The filtering behavior has been validated through the author’s actual use, and the build script includes tests for the debounce algorithm; not all mice, games, or macOS versions have been verified.

## License

[MIT](LICENSE), copyright © 2026 uroboros.
