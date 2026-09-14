# Wheel Filter

A small native macOS menu bar utility implementing the experimentally validated v3b wheel filter. It uses AppKit, Objective-C, and `CGEventTap`; no full Xcode installation is required.

It filters only when all of these are true:

- the master switch is on;
- the foreground app was explicitly added as a game;
- Accessibility permission is granted;
- the event tap is running.

All other applications receive the original scroll events unchanged.

## Filter behavior

- `delta == 0`: block the scroll tail;
- same direction within the selected 30/40/50/75 ms interval: block;
- direction reversal: pass immediately;
- passed events are returned unchanged; no delta, pointDelta, or fixedDelta field is modified.

## Build

From this folder:

```sh
./Scripts/build-app.sh
```

The app is created at `outputs/Wheel Filter.app`.

Run it with:

```sh
open "outputs/Wheel Filter.app"
```

## First run

1. Open `outputs/Wheel Filter.app`.
2. Approve the Accessibility prompt. If needed, use the menu bar item and choose **Grant Accessibility Permission…**.
3. Bring the game to the foreground, then open the Wheel Filter menu bar item.
4. Choose **Add This App as a Game**.
5. Return to the game. The menu icon fills in while filtering is active.

The menu shows the remembered foreground app, current filter state, master switch, debounce threshold, and configured games. Settings persist between launches.

Version 0.1.1 fixes a preferences-domain bug that caused **Enable Wheel Filter** and **Add This App as a Game** to silently do nothing in version 0.1.0.

After rebuilding, macOS may require the old Wheel Filter entry to be removed and the rebuilt app to be enabled again in **System Settings → Privacy & Security → Accessibility**.
