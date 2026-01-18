#!/bin/bash

# GhostFrame Release Script
# Creates a DMG for distribution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="GhostFrame"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
RELEASE_DIR="$SCRIPT_DIR/release"

# Ensure build exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "⚠️  App bundle not found. Building first..."
    ./build.sh
fi

echo "📦 Creating DMG..."

mkdir -p "$RELEASE_DIR"
rm -f "$RELEASE_DIR/$DMG_NAME"

# Create a temporary folder for DMG contents
DMG_SOURCE="$BUILD_DIR/dmg_source"
rm -rf "$DMG_SOURCE"
mkdir -p "$DMG_SOURCE"

# Copy App to source
cp -r "$APP_BUNDLE" "$DMG_SOURCE/"

# Create a link to Applications folder
ln -s /Applications "$DMG_SOURCE/Applications"

# Create DMG using hdiutil
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_SOURCE" \
  -ov -format UDZO \
  "$RELEASE_DIR/$DMG_NAME"

echo "✅ Release created: $RELEASE_DIR/$DMG_NAME"
open "$RELEASE_DIR"
