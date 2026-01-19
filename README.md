# GhostFrame

**GhostFrame** is a premium stealth mode manager for macOS that makes Electron-based applications invisible to screen recording, screen sharing, and screenshots. It also provides advanced features like Dock hiding and background process disguising.

## Features

- **Invisibility Mode**: Makes app windows completely invisible to screen capture software (OBS, Zoom, QuickTime, screenshots) while remaining visible to you
- **Dock Hiding**: Completely hide the application icon from the macOS Dock
- **Background Disguise**: Disguise the process name in Activity Monitor to look like a system process
- **Premium UI**: Native SwiftUI interface with liquid-glass aesthetic and dark/light mode support
- **Menu Bar Access**: Quick toggle controls right from your menu bar

## Installation

1. Download the latest `GhostFrame.dmg` from the [Releases](https://github.com/ghostframer/GhostFrame/releases) page
2. Open the DMG and drag **GhostFrame.app** to your **Applications** folder
3. Launch GhostFrame

## Usage

1. Open GhostFrame from your Applications folder or menu bar
2. The **Available Applications** section lists all compatible Electron apps on your system
3. Click **Add** next to an app (e.g., VS Code, Discord, Slack, Cursor)
4. Configure your protection settings:
   - **INVISIBILITY**: Enable to block screen capture
   - **DOCK**: Enable to hide the app from the Dock (requires app restart)
   - **BACKGROUND**: Enable to disguise the process name
5. Toggle the **STATUS** switch to **ON**
6. Use the **Actions** menu (three dots) to restart the target app

## Supported Applications

GhostFrame works with Electron-based applications including:
- Visual Studio Code
- Cursor
- Discord
- Slack
- Obsidian
- Notion
- Figma
- And many more...

## Important Notes

- **Restart Required**: Most changes require the target application to be fully restarted
- **Electron Only**: GhostFrame supports applications built with the Electron framework
- **macOS Security**: You may need to grant permissions in System Preferences > Privacy & Security

## Building from Source

**Requirements**: macOS 13.0+, Xcode Command Line Tools

```bash
# Clone the repository
git clone https://github.com/ghostframer/GhostFrame.git
cd GhostFrame

# Build the app
./build.sh

# Install to Applications
cp -r build/GhostFrame.app /Applications/

# Create a release DMG (optional)
./release.sh
```

## How It Works

GhostFrame patches Electron applications by injecting `setContentProtection(true)` into the app's main process. This uses macOS's native content protection API to prevent the window from being captured.

For Dock hiding, it modifies the app's `Info.plist` to set `LSUIElement = true`.

For background disguise, it changes the `process.title` to a system-like name.

## License


License. See [LICENSE](LICENSE) for details.

## Author

Created by [ghostframer](https://github.com/ghostframer)
