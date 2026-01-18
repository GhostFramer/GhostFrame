# GhostFrame 👻

**GhostFrame** is a premium stealth mode manager for macOS that allows you to make Electron-based applications invisible to screen recording, screen sharing, and screenshots. It also provides advanced features like Dock hiding and background process disguising.

![GhostFrame Header](assets/header.png)

## ✨ Features

- **Stealth Mode (Invisibility)**: Makes app windows completely invisible to screen capture software (OBS, Zoom, QuickTime, screenshots) while remaining visible to you.
- **Dock Hiding**: Completely hide the application icon from the macOS Dock.
- **Background Disguise**: Disguise the process name in Activity Monitor to look like a system process.
- **Premium UI**: A native, liquid-glass aesthetic designed for macOS.
- **Menu Bar Access**: Quick toggle controls right from your menu bar.

## 🚀 Installation

1. Download the latest `GhostFrame.dmg` from the [Releases](https://github.com/your-username/GhostFrame/releases) page.
2. Drag **GhostFrame.app** to your **Applications** folder.
3. Launch GhostFrame.

## 🛠 Usage

1. Open GhostFrame.
2. The "Available Applications" section will list all compatible Electron apps found on your system.
3. Click **Add** next to an app (e.g., VS Code, Discord, Slack).
4. Configure your protection settings:
   - **Invis (Invisibility)**: Check this to block screen capture.
   - **Dock**: Check this to hide the app from the Dock (requires app restart).
   - **Backg (Background)**: Check this to disguise the process name.
5. Toggle the **Status** switch to **ON**.
6. **Restart the target app** for changes to take effect.

## ⚠️ Important Notes

- **Restart Required**: Most changes (especially Dock hiding and Stealth Mode) require the target application to be fully restarted. Use the "Restart App" option in the actions menu (three dots).
- **Electron Only**: Currently, GhostFrame supports applications built with the Electron framework (VS Code, Discord, Slack, Obsidian, etc.).

## 🏗 Building from Source

Requirements: macOS 13.0+, Xcode 14+ (for Swift compiler).

```bash
# Clone the repository
git clone https://github.com/your-username/GhostFrame.git
cd GhostFrame

# Build the app
./build.sh

# Create a release DMG
./release.sh
```

## 📜 License

MIT License. See [LICENSE](LICENSE) for details.
