#!/bin/bash
# build.sh - Build release binary and create app bundle for Halo
set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Halo"
BUNDLE_ID="com.halo.oura"
VERSION="1.0.0"

echo "=========================================="
echo "Building $APP_NAME v$VERSION"
echo "=========================================="

cd "$PROJECT_DIR"

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf "$PROJECT_DIR/$APP_NAME.app"
rm -rf "$PROJECT_DIR/.build/release"

# Build release binary with Swift Package Manager
echo "Building release binary..."
swift build -c release

# Create app bundle structure
echo "Creating app bundle..."
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy executable (named Commander from Package.swift)
echo "Copying executable..."
cp "$PROJECT_DIR/.build/release/Commander" "$MACOS/Commander"

# Copy Info.plist
echo "Copying Info.plist..."
cp "$PROJECT_DIR/Info.plist" "$CONTENTS/Info.plist"

# Copy app icon
echo "Copying app icon..."
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$RESOURCES/AppIcon.icns"
else
    echo "Warning: AppIcon.icns not found"
fi

# Set executable permissions
chmod +x "$MACOS/Commander"

echo ""
echo "Build complete: $APP_BUNDLE"
echo ""

# Verify the build
echo "Verifying build..."
ls -la "$APP_BUNDLE/Contents/MacOS/"
echo ""
echo "App bundle structure:"
find "$APP_BUNDLE" -type f | head -20
