# NotchClone

An original macOS background app that places a black notch-shaped panel over the MacBook display notch. Hovering over the notch expands it into a compact panel with tabbed widgets:

- **Home Tab**:
  - **Now-Playing Media Widget**: Displays the current track, artist, and album artwork from any active media source (Chrome, Safari, YouTube, Spotify, Apple Music, VLC, podcasts) with play/pause, next, and previous track controls. Uses a bundled `mediaremote-adapter` child process (`/usr/bin/perl`) for real-time push events, with automatic AppleScript fallback for Spotify and Apple Music.
  - **Files Tray**: Drag and drop files onto the notch (closed or open) to stage them in memory, drag them out, AirDrop them directly, or clear the tray.
- **Agents Tab**:
  - Displays active projects as cards grouped by herdr workspace, with lead (Claude) status and task progress.
  - **Summary Line**: Shows overall status (`⚠ N needs you · ● N working · ✓ N ready to wrap up`).
  - **Project Cards**: Each card displays project/workspace name, status, Lead row (Claude title & status), active tasks with title, progress bar, checkbox ratio (`done/total`), and `Next:` step, followed by aggregated worker counts (`Workers: N working · N idle`).
  - **Focus Navigation**: Click Lead row to focus the lead agent; click any task row to focus that task's waiting or active agent in Ghostty/terminal.
  - **Herdr Map**: Collapsible map showing workspaces, tabs, who runs in them, and linked task titles (`tab N <agent> → <task>`); click any row to focus that tab's lead or first agent.
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
  - Top strip shows tab bar with waiting agent indicators, battery level / charging state, and weather alongside the hardware notch.
  - Closed notch displays mini album art while music is playing, active countdown/stopwatch time, and waiting agent count badge (orange dot + count) alongside the camera notch without opening the full panel.
- **Menu Bar Item & Token Usage Popover**:
  - Adds a menu bar status item showing the terminal icon and count of agents currently waiting for user response (e.g. `" 5"`).
  - Clicking toggles a dark transient popover with:
    - **Agent Status Ring**: Multi-color arc ring (waiting = orange, working = green, idle = grey) with central waiting badge.
    - **Usage History**: 7-day bar chart showing daily token consumption and total cost at API prices.
    - **Today**: Stacked tool-share bar and breakdown for tools (Claude Code, Antigravity, Gemini CLI, OpenCode, Codex).
    - **Claude Usage Window**: 5-hour rolling window reset timer, token usage, and elapsed time progress bar.
    - **Tasks & Agents**: The active task progress rows and live agent list; clicking any item focuses the agent in herdr and closes the popover.
  - **"At API Prices" Note**: All costs are estimated by `ccusage` at public pay-per-token API rates as a measure of workload size, not actual subscription billing.
  - **Requirements & Offline Execution**: Requires `bun` (at `~/.bun/bin/bun`, `/opt/homebrew/bin/bun`, or `/usr/local/bin/bun`) and `ccusage` (at `~/.bun/bin/ccusage`). All invocations use `--offline` with zero network overhead. Usage is refreshed only while the popover is open (every 60 s) and never polled while closed. On screens with heavy menu bar clutter, macOS may hide overflow items behind the notch.

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

### System-Wide Now Playing & MediaRemote

NotchClone detects media playback across all macOS applications (Chrome, Safari, YouTube, Spotify, Apple Music, podcasts, VLC, etc.) by bundling the open-source `mediaremote-adapter`. Because macOS 15.4+ restricts direct calls to the private MediaRemote framework from non-Apple entitled binaries, the adapter runs via `/usr/bin/perl` (a platform-entitled system binary) and streams JSON state updates to NotchClone in real time without background polling. If the private API behavior changes or the adapter exits, NotchClone automatically falls back to AppleScript for Spotify and Apple Music.

### Configuration

Optional settings can be configured using `defaults write com.noxturne.notchclone <key> <value>`:

- **Vault Projects Path** (`vaultProjectsPath`): Root directory where markdown project plans are scanned. Defaults to `~/Projects/my-notes/projects`.
  ```bash
  defaults write com.noxturne.notchclone vaultProjectsPath "/path/to/my-notes/projects"
  ```
- **Terminal Bundle Identifier** (`terminalBundleId`): Bundle ID of the terminal application to focus when clicking an agent row or capsule. Defaults to `com.mitchellh.ghostty`.
  ```bash
  defaults write com.noxturne.notchclone terminalBundleId "com.apple.Terminal"
  ```

## Quitting

To quit NotchClone:
Right-click on the notch shape to open the context menu, then select **Quit NotchClone**.
Alternatively, terminate the process via command line:

```bash
pkill -x NotchClone
```
