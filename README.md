# Pomotimer

Pomotimer is a minimal macOS stopwatch and countdown timer that lives on the right edge of the display. It is built with SwiftUI and AppKit and targets macOS 14 or later.

## Run

From Terminal:

```sh
make run
```

This builds the app locally and launches it. Other useful commands are `make build`, `make test`, and `make clean`.

Alternatively, from Xcode:

1. Open `StopwatchUtility.xcodeproj` in Xcode.
2. Select the **StopwatchUtility** scheme and **My Mac** destination.
3. Press **Run**.

The app launches as a compact edge tab. Hover over or click the tab to expand it. Clicking the Dock icon also opens the panel.

In Timer mode, click the large countdown value to type a duration as `MM:SS` or `HH:MM:SS`. Press Return to save or Escape to cancel. The `−5m`, `−1m`, `+1m`, and `+5m` buttons provide quick adjustments while the timer is stopped.

Enable **Hide countdown when idle** to hide the elapsed time or countdown when either mode is collapsed. The collapsed tab shows only a stopwatch icon; hovering or clicking it restores the complete active panel.
This option starts turned off each time the app launches.

## Behavior modes

- **Auto Hide** expands on hover and collapses shortly after the pointer leaves.
- **Stay Active** remains expanded until manually collapsed.
- **Always on Top** remains expanded above other apps and follows across Spaces.

Only one mode can be active at a time. Stopwatch state, countdown state, the selected section, and the behavior mode are stored in `UserDefaults` and restored at launch.

## Verify

```sh
make test
```

The tests cover stopwatch accuracy, countdown completion, relaunch restoration, and behavior-mode exclusivity.
