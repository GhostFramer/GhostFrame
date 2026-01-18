#!/bin/bash

# GhostFrame Build Script
# Builds the GhostFrame stealth mode manager app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="GhostFrame"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ICONS_DIR="$HOME/Downloads/Ghostframe icons"

echo "👻 Building GhostFrame..."

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy icons if available
if [ -d "$ICONS_DIR" ]; then
    echo "🎨 Setting up icons..."
    
    # Create iconset
    ICONSET="$BUILD_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET"
    
    # Copy icons to iconset with proper naming
    cp "$ICONS_DIR/GhostFrame_icon_16x16_transparent.png" "$ICONSET/icon_16x16.png" 2>/dev/null || true
    cp "$ICONS_DIR/GhostFrame_icon_32x32_transparent.png" "$ICONSET/icon_16x16@2x.png" 2>/dev/null || true
    cp "$ICONS_DIR/GhostFrame_icon_32x32_transparent.png" "$ICONSET/icon_32x32.png" 2>/dev/null || true
    cp "$ICONS_DIR/GhostFrame_icon_64x64_transparent.png" "$ICONSET/icon_32x32@2x.png" 2>/dev/null || true
    cp "$ICONS_DIR/GhostFrame_icon_128x128_transparent.png" "$ICONSET/icon_128x128.png" 2>/dev/null || true
    cp "$ICONS_DIR/GhostFrame_icon_256x256_transparent.png" "$ICONSET/icon_128x128@2x.png" 2>/dev/null || true
    cp "$ICONS_DIR/GhostFrame_icon_256x256_transparent.png" "$ICONSET/icon_256x256.png" 2>/dev/null || true
    cp "$ICONS_DIR/GhostFrame_icon_512x512_transparent.png" "$ICONSET/icon_256x256@2x.png" 2>/dev/null || true
    cp "$ICONS_DIR/GhostFrame_icon_512x512_transparent.png" "$ICONSET/icon_512x512.png" 2>/dev/null || true
    cp "$ICONS_DIR/GhostFrame_icon_1024x1024_transparent.png" "$ICONSET/icon_512x512@2x.png" 2>/dev/null || true
    
    # Create icns file
    iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || echo "⚠️ Could not create icns (iconutil may require more icon sizes)"
    
    # Copy menu bar icon (16x16 or 32x32 for retina)
    cp "$ICONS_DIR/GhostFrame_icon_32x32_transparent.png" "$APP_BUNDLE/Contents/Resources/menubar_icon.png" 2>/dev/null || true
    
    rm -rf "$ICONSET"
fi

# Compile Swift code
echo "⚡ Compiling Swift code..."
swiftc -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Carbon \
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
    <string>2.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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
