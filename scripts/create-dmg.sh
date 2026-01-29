#!/bin/bash
# create-dmg.sh - Create distributable DMG for Halo
set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Halo"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
DMG_PATH="$PROJECT_DIR/$DMG_NAME"
VOLUME_NAME="$APP_NAME"
TMP_DMG="$PROJECT_DIR/tmp-$DMG_NAME"
STAGING_DIR="$PROJECT_DIR/dmg-staging"
SIGNING_IDENTITY="Developer ID Application: Jurgen Klaaben (E89Q3796E9)"
NOTARIZATION_PROFILE="halo-notarization"

echo "=========================================="
echo "Creating DMG for $APP_NAME"
echo "=========================================="

# Verify app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found. Run build.sh first."
    exit 1
fi

# Clean up any existing DMG and staging
echo "Cleaning up previous DMG files..."
rm -f "$DMG_PATH"
rm -f "$TMP_DMG"
rm -rf "$STAGING_DIR"

# Create staging directory
echo "Creating staging directory..."
mkdir -p "$STAGING_DIR"

# Copy app to staging
echo "Copying app bundle..."
cp -R "$APP_BUNDLE" "$STAGING_DIR/"

# Create Applications symlink
echo "Creating Applications symlink..."
ln -s /Applications "$STAGING_DIR/Applications"

# Calculate size (add 20MB buffer)
echo "Calculating DMG size..."
SIZE_KB=$(du -sk "$STAGING_DIR" | cut -f1)
SIZE_MB=$(( (SIZE_KB / 1024) + 20 ))
echo "Staging size: ${SIZE_KB}KB, DMG size: ${SIZE_MB}MB"

# Create temporary DMG
echo "Creating temporary DMG..."
hdiutil create -srcfolder "$STAGING_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${SIZE_MB}m" \
    "$TMP_DMG"

# Convert to compressed, read-only DMG
echo "Converting to compressed DMG..."
hdiutil convert "$TMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

# Clean up
echo "Cleaning up..."
rm -f "$TMP_DMG"
rm -rf "$STAGING_DIR"

echo ""
echo "DMG created: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"

# Sign the DMG
echo ""
echo "Signing DMG..."
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"

echo ""
echo "Verifying DMG signature..."
codesign --verify --verbose=2 "$DMG_PATH"

# Notarize the DMG
echo ""
echo "Notarizing DMG..."
echo "Submitting to Apple..."

xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARIZATION_PROFILE" \
    --wait

# Staple the DMG
echo ""
echo "Stapling notarization ticket to DMG..."
xcrun stapler staple "$DMG_PATH"

echo ""
echo "Verifying DMG notarization..."
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature -v "$DMG_PATH"

echo ""
echo "DMG ready for distribution: $DMG_PATH"
