# DriveBar

Version 1.1 adds a custom app icon and a persistent “Show only ejectable drives” switch, enabled by default. It hides internal and non-ejectable volumes, while mounted network shares remain visible. Turn it off to see all mounted volumes.

Version 1.0.1 fixes the drive panel's scroll area sizing and keeps volumes listed when optional metadata is unavailable. Adds startup-volume and Finder mount-root discovery fallbacks. SMB shares already mounted in Finder are supported; browsing a server without mounting a share does not add a volume. macOS may request Network Volumes or Removable Volumes access; Full Disk Access is not required for normal operation.

A native macOS 13+ menu bar app. Lists Finder-visible mounted volumes, including internal storage, external drives, disk images, and network shares. Unmounted physical disks and hidden system volumes are not listed.

## Run

Unzip the download, drag `DriveBar.app` to Applications, and open it. Click the external-drive icon in the menu bar. The app has no Dock icon. Use Quit at the bottom of its panel to exit.

The supplied app is built for Apple silicon and signed locally, not notarized. macOS may require you to approve it in System Settings → Privacy & Security after attempting to open it. For a trusted local build, run the build script below.

## Features

- Automatic updates when volumes mount, unmount, or change name.
- Free space, capacity, volume icons, and Finder shortcuts.
- Eject external volumes using macOS's standard unmount-and-eject API; network shares use the same system request.
- Internal and non-ejectable volumes have disabled eject buttons.
- Eject operations run off the UI thread, one at a time. Failure messages stay visible, and the app never force-unmounts a busy disk.

Ejecting one partition can affect other volumes on the same physical device, according to macOS behavior. Wait for successful ejection before unplugging. This version has no eject-all action or launch-at-login setting.

## Build or edit

Install Xcode (or compatible Swift command-line tools), then run:

```sh
bash scripts/build.sh
open dist/DriveBar.app
```

Open `Package.swift` in Xcode to edit the source. The script builds for the current Mac architecture and creates a locally signed app bundle. No third-party dependencies, network requests, or administrator privileges are required by the app.

## Validation

Release compilation and bundle signature verification are performed on the supplied build. Actual ejection must be verified with a spare external drive; no connected drives were ejected during development.
