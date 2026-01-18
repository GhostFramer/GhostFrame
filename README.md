# GhostFrame

> 👻 **Stealth Mode Manager for macOS**

A beautiful, modern menu bar app with glass UI that makes your Electron apps invisible to screenshots, screen recordings, and screen sharing.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **🛡️ Content Protection** - Makes app windows appear black in screenshots and screen recordings
- **👻 Dock Hiding** - Hides app icons from the macOS dock
- **🎯 Mission Control Hiding** - Apps won't appear in Mission Control
- **🎨 Beautiful Glass UI** - Native macOS vibrancy/blur effects with cyan-purple gradient
- **⚡ One-Click Toggle** - Enable/disable protection with animated switches
- **🔄 Auto-Restart** - Properly restarts apps after changes using NSWorkspace APIs
- **📱 Multi-App Support** - Works with many Electron-based apps

## Supported Apps

| App | Status |
|-----|--------|
| Antigravity | Supported |
| Visual Studio Code | Supported |
| Cursor | Supported |
| Windsurf | Supported |
| Slack | Supported |
| Discord | Supported |
| Notion | Supported |
| Figma | Supported |
| Obsidian | Supported |
| Postman | Supported |
| Spotify | Supported |
| WhatsApp | Supported |
| Telegram | Supported |
| 1Password | Supported |

## Installation

### Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/GhostFrame.git
cd GhostFrame

# Build the app
chmod +x build.sh
./build.sh

# Install to Applications
cp -r build/GhostFrame.app /Applications/

# Run
open /Applications/GhostFrame.app
```

### Quick Install

```bash
./build.sh && cp -r build/GhostFrame.app /Applications/ && open /Applications/GhostFrame.app
```

## Usage

1. **Launch GhostFrame** - Look for the icon in your menu bar
2. **Toggle Protection** - Click the switch next to any app
3. **Restart App** - Click "Restart Now" when prompted
4. **Enjoy Privacy** - Your app is now invisible to screen capture!

## How It Works

GhostFrame patches Electron apps to enable macOS content protection APIs:

```javascript
// Applied to each Electron app
window.setContentProtection(true);      // Windows appear black in screen capture
window.setHiddenInMissionControl(true); // Hidden from Mission Control
app.dock.hide();                        // Removes dock icon
```

Changes are stored in a backup file (`.ghostframe.backup`) and can be reverted anytime.

## UI Features

- **Glass/Vibrancy Effect** - Uses `NSVisualEffectView` with `.hudWindow` material
- **Animated Toggles** - Spring animations for smooth interactions
- **Hover Effects** - Cards scale and shadow on hover
- **Status Indicators** - Green/orange dots show protection state
- **Running State** - Blue indicator shows if app is running

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (for building)

## License

MIT License - Feel free to use, modify, and distribute.

## Disclaimer

This tool is intended for privacy protection during legitimate use cases like online assessments, presentations, or personal privacy. Use responsibly and ethically.
