#!/bin/bash

# GhostFrame Build Script
# Builds the GhostFrame stealth mode manager app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="GhostFrame"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "👻 Building GhostFrame..."

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Compile Swift code
echo "⚡ Compiling Swift code..."
swiftc -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -framework Cocoa \
    -framework SwiftUI \
    -O \
    "$SCRIPT_DIR/GhostFrame.swift"

# Create Info.plist
echo "📝 Creating Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>GhostFrame</string>
    <key>CFBundleIdentifier</key>
    <string>com.ghostframe.stealth</string>
    <key>CFBundleName</key>
    <string>GhostFrame</string>
    <key>CFBundleDisplayName</key>
    <string>GhostFrame</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "✅ Build complete!"
echo "📦 App bundle: $APP_BUNDLE"
echo ""
echo "To install, run:"
echo "  cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
echo "To run directly:"
echo "  open \"$APP_BUNDLE\""
