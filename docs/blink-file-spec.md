# Blink

**A native macOS app for SCP file transfers.**

Named after the AD&D spell "Blink," because the file just appears on the other side. Built to pair thematically with a server named Gandalf.

An SVG icon is included alongside this spec (`blink-icon.svg`). It depicts a wizard dissolving into particles on the left and reconstituting on the right: a visual representation of the Blink spell. Use `iconutil` and `sips` to generate the full `.icns` asset catalog from this SVG at all required resolutions (16, 32, 128, 256, 512 at 1x and 2x).

## 1. Purpose

This app replaces the workflow of opening Transmit or typing SCP commands by hand. It is a single-purpose, native macOS utility for transferring large files (typically multi-GB movie files) to a remote server via SCP. The goal is Transmit-level convenience (saved destinations, drag and drop, visual progress) with SCP-level transfer speed.

SFTP is measurably slower than SCP for large file transfers due to its request/response overhead per data chunk. This app exists specifically to recapture that speed advantage with a proper GUI.

## 2. Project Summary

| Field | Detail |
|---|---|
| App Name | Blink |
| Platform | macOS 14+ (Sonoma and later) |
| Language | Swift 5.9+ / SwiftUI |
| Transfer Protocol | SCP via the system `scp` binary |
| Deployment | Local build via Xcode; not App Store |
| Target Machines | Apple Silicon Macs (M4 Max Mac Studio, MacBook Pro) |

## 3. Core Workflow

There are two ways to initiate a transfer:

1. Drag one or more files onto the app's Dock icon.
2. Double-click the app to open it, then use the drop target or file picker.

After files are selected, the app displays a confirmation view showing the file list, sizes, and destination. The user clicks "Blink" to begin. A progress view shows real-time transfer status per file, including speed and ETA. On completion, a macOS notification is delivered.

## 4. Architecture

### 4.1 Application Type

Standard macOS Dock application. Not a menu bar app. Can be kept in the Dock permanently for quick drag-and-drop access.

### 4.2 UI Framework

SwiftUI. The app has very few views, making SwiftUI the right choice for simplicity and native macOS feel.

### 4.3 Transfer Engine

Use the system `scp` binary via Swift's `Process` (formerly NSTask). This leverages the user's existing `~/.ssh/config` and keychain-stored SSH credentials with zero additional authentication logic.

**Do not use libssh2 or any third-party SSH library.** The system `scp` binary respects `~/.ssh/config`, handles key negotiation, and is already trusted by the OS. Wrapping it in Process is the right approach.

### 4.4 Parsing SCP Progress Output

This is the key to making the transfer visualization work. When `scp` runs with a TTY (or pseudo-TTY), it writes progress to stderr in this format:

```
filename.mkv    42%  1.8GB  98.2MB/s   00:28 ETA
```

The fields are: filename, percentage complete, bytes transferred so far, current transfer speed, and estimated time remaining. This line is updated in place (carriage return, no newline) as the transfer progresses.

To capture this output:

1. Attach a pseudo-TTY to the `scp` process's stderr. Without a TTY, `scp` suppresses the progress meter entirely. Use `forkpty()` or `openpty()` in Swift to create the PTY.
2. Read from the PTY file descriptor in a background thread or using a DispatchIO channel.
3. Parse each update line with a regex or string scanner. The format is consistent across modern OpenSSH versions: `\s*(\S+)\s+(\d+)%\s+(\S+)\s+(\S+/s)\s+(\S+)`.
4. Feed the parsed values (percentage, speed, ETA, bytes transferred) into an ObservableObject that drives the SwiftUI progress view.

If PTY allocation proves problematic, fall back to running `scp` with the `-v` flag and parsing verbose output for transfer progress. As a last resort, show an indeterminate progress indicator with file-level completion status.

### 4.5 SSH Config Integration

Parse `~/.ssh/config` to populate a host picker in Settings. The parser needs to extract `Host`, `HostName`, `User`, and `Port` entries. This avoids asking the user to re-enter information that already exists in their SSH configuration.

Ignore wildcard Host entries (e.g., `Host *`).

## 5. Views

### 5.1 Main Window (Transfer View)

This is the default view. When files are queued (via drop or picker), it shows:

- A list of files queued for transfer, each with filename and human-readable size (e.g., "2.4 GB").
- The active destination displayed prominently (e.g., "gandalf : /srv/media/movies/").
- A "Blink" button to start the transfer and a "Clear" button to reset the queue.

When no files are queued, show a drop target area with a message like "Drop files here or click to browse" and a file picker button. The drop target should have a clear visual affordance: a dashed border or similar treatment that highlights on drag hover.

### 5.2 Progress View

Replaces the file list after the user clicks Blink. For each file, show:

- Filename and total size.
- A progress bar driven by the percentage parsed from scp output.
- Current transfer speed (e.g., "98.2 MB/s") and ETA (e.g., "00:28 remaining").
- Bytes transferred vs. total (e.g., "1.8 GB / 4.3 GB").

If multiple files are queued, show an overall progress summary at the top (files completed, total data transferred) along with the per-file detail for the active transfer.

Include a "Cancel" button that sends SIGTERM to the scp process.

When all transfers complete, show a summary (files transferred, total size, elapsed time) and a "Done" button that resets the app to the empty drop-target state.

### 5.3 Settings View

Accessible from the app menu bar (Cmd+,). Contains:

**Destinations section:**

- Host selector: a dropdown populated from `~/.ssh/config` entries. Show the resolved hostname, user, and port below the dropdown for the selected entry.
- Remote path: a text field for the target directory.
- Save the combination as a named preset (e.g., "Gandalf Movies," "Gandalf TV Shows"). The user can create, rename, and delete presets.
- One preset is marked as the active default.

**Notifications section:**

- Toggle for post-transfer macOS notifications (on by default).

**About section:**

- App version, a brief description, and the tagline: "Cast Blink. File appears."

## 6. Drag and Drop

The app must register as a drop target at two levels:

1. **Dock icon:** Files dragged onto the Dock icon launch the app (if not running) or bring it to the front, with the dropped files pre-loaded in the transfer queue.
2. **Main window drop target:** The window itself accepts file drops onto the drop-target area.

Both paths feed into the same transfer queue. Accept any file type with no filtering. If the user drops a directory, pass it to `scp -r` automatically.

## 7. Notifications

Use the UserNotifications framework. On transfer completion, deliver a notification with the count of files transferred and total size (e.g., "Blinked 3 files (12.7 GB) to Gandalf"). Tapping the notification brings the app to the front. This matters for large transfers where the user has switched to other work.

Request notification permission on first launch with a contextual prompt explaining why (so the user knows when large background transfers finish).

## 8. Error Handling

Handle these cases with clear, non-technical messaging:

- **SSH connection failure:** "Could not connect to [host]. Verify your SSH config and that the server is reachable." Do not attempt to collect or manage credentials.
- **Transfer interruption (network drop or user cancel):** Clean up and report which files succeeded and which did not.
- **Disk full on remote:** Surface the scp error in a readable format.
- **Permission denied on remote path:** Suggest checking destination directory permissions.
- **scp binary not found:** This should not happen on a standard macOS install, but handle it with a message pointing to the Xcode command line tools.

## 9. Data Persistence

Use UserDefaults or a small JSON file in `~/Library/Application Support/Blink/` for:

- The active destination preset.
- All saved destination presets (name, host, path).
- Window position and size.
- Notification preference.

No database. This is a very lightweight data model.

## 10. Build and Deployment

Standard Xcode project. Bundle identifier: `com.charlie.blink`. The user will build locally; there is no code signing or notarization requirement beyond what Xcode applies by default for local development.

**Include a Makefile** that allows building from the command line:

```
make build    # xcodebuild release
make run      # build and launch
make clean    # clean build artifacts
```

This lets Claude Code iterate on the build without requiring the Xcode GUI.

## 11. What to Skip (v1)

To keep scope tight, the following are explicitly out of scope:

- Browsing remote directories. The user sets the path in Settings.
- Downloading files (remote to local). This is a one-way push tool.
- Resume or retry of partial transfers. SCP does not support resume natively.
- Multiple simultaneous destinations. One active destination at a time.
- Menu bar mode. This is a Dock app.
- App Store distribution, notarization, or entitlements beyond local development.
- Any third-party dependencies. Pure Swift and system frameworks only.

## 12. Default Configuration

The app should work immediately with these defaults:

- Default host: `gandalf` (from SSH config)
- Default remote path: `/srv/media/movies/`
- Default preset name: "Gandalf Movies"

## 13. Nice to Have (v2)

Not required for the initial build, but natural additions for later:

- Transfer history log showing the last N transfers with timestamps, filenames, and sizes.
- Global keyboard shortcut to trigger the file picker from anywhere.
- Automatic retry on transient network failures.
- rsync mode toggle for delta transfers of incrementally changing files.
- Sound effect on transfer completion (the Blink spell should make a sound, after all).
