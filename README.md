# NotchClone

An original macOS background app that places a black notch-shaped panel over the MacBook display notch. Hovering over the notch expands it into a compact panel with tabbed widgets:

- **Home Tab**:
  - **Now-Playing Media Widget**: Displays the current track and album artwork from Spotify or Apple Music with play/pause, next, and previous track controls (via AppleScript and DistributedNotificationCenter).
  - **Files Tray**: Drag and drop files onto the notch (closed or open) to stage them in memory, drag them out, AirDrop them directly, or clear the tray.
- **Timer Tab**:
  - Countdown timer with quick presets (5m, 10m, 15m, 25m) and +/- 1m adjustments.
  - Stopwatch.
  - Pomodoro timer (25m focus, 5m break, 15m long break every 4 cycles).
  - Plays the system "Glass" sound on completion.
- **Notes Tab**:
  - Quick scratchpad with auto-save.
  - Plain text saved locally to `~/Library/Application Support/NotchClone/notes.txt`.
  - The notch panel automatically stays open while typing notes.
- **Launch Tab**:
  - Pinned app launcher: click to launch, right-click to unpin. Drag any `.app` onto the notch while in the Launch tab to pin it.
  - macOS Shortcuts launcher: lists and executes user Shortcuts via `/usr/bin/shortcuts`.
- **System Tab**:
  - Live CPU utilization graph.
  - Memory usage vs total physical memory.
  - Real-time network download/upload rates.
  - Weather widget: shows current temperature, summary, and weather icon via Open-Meteo. Only the city name is sent for geocoding and forecast queries (no account, no location permissions required). Change city anytime in the input field.
- **Status Strip & Closed Indicators**:
  - Top strip shows battery level / charging state and weather alongside the hardware notch.
  - Closed notch displays mini album art while music is playing and active countdown/stopwatch time alongside the camera notch without opening the full panel.

## Requirements

- macOS 14.0 or later (runs on MacBook with a camera notch).
- Apple Silicon (Apple M-series).

## Building

Run the bundling script to compile the release binary and assemble `NotchClone.app`:

```bash
./scripts/bundle.sh
```

The assembled app bundle will be placed at `build/NotchClone.app`.

## Running

Launch the app:

```bash
open build/NotchClone.app
```

NotchClone runs as an accessory background app without a Dock icon (`LSUIElement = true`).

### Permissions

NotchClone requires **no privacy permissions** (no Location, Accessibility, Screen Recording, Notifications, or Calendar permissions).

On first interaction with media playback controls or polling Spotify / Apple Music, macOS prompts for standard AppleScript Automation permissions (`NSAppleEventsUsageDescription`) to allow controlling playback and reading song metadata.

## Quitting

To quit NotchClone:
Right-click on the notch shape to open the context menu, then select **Quit NotchClone**.
Alternatively, terminate the process via command line:

```bash
pkill -x NotchClone
```
