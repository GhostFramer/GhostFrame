# Phantom

> 🔮 **Stealth Mode Manager for macOS**

A beautiful, modern menu bar app that makes your Electron apps invisible to screenshots, screen recordings, and screen sharing.

![Phantom](https://img.shields.io/badge/macOS-13.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **🛡️ Content Protection** - Makes app windows appear black in screenshots and screen recordings
- **👻 Dock Hiding** - Hides app icons from the macOS dock
- **🎯 Mission Control Hiding** - Apps won't appear in Mission Control
- **🎨 Beautiful Glass UI** - Native macOS vibrancy effects
- **⚡ One-Click Toggle** - Enable/disable protection instantly
- **🔄 Auto-Restart** - Optionally restart apps after changes
- **📱 Multi-App Support** - Works with many Electron apps

## Supported Apps

- Antigravity
- Visual Studio Code
- Cursor
- Slack
- Discord
- Notion
- Figma
- Obsidian
- Postman
- Spotify
- WhatsApp
- Telegram
- 1Password
- Windsurf
- *...and more!*

## Installation

### Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/Phantom.git
cd Phantom

# Build the app
chmod +x build.sh
./build.sh

# Install to Applications
cp -r build/Phantom.app /Applications/

# Run
open /Applications/Phantom.app
```

### Quick Install

```bash
./build.sh && cp -r build/Phantom.app /Applications/ && open /Applications/Phantom.app
```

## Usage

1. **Launch Phantom** - Click the 👁️ icon in your menu bar
2. **Toggle Protection** - Click the switch next to any app
3. **Restart App** - Click "Restart Now" when prompted (required for changes)
4. **Enjoy Privacy** - Your app is now invisible to screen capture!

## How It Works

Phantom patches Electron apps to enable macOS content protection APIs:

- `setContentProtection(true)` - Windows appear black in screen capture
- `setHiddenInMissionControl(true)` - Hidden from Mission Control
- `app.dock.hide()` - Removes dock icon

Changes are stored in a backup file and can be reverted anytime.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (for building)

## License

MIT License - Feel free to use, modify, and distribute.

## Disclaimer

This tool is intended for privacy protection during legitimate use cases like online assessments, presentations, or personal privacy. Use responsibly and ethically.
