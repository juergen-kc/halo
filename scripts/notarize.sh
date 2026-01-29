#!/bin/bash
# notarize.sh - Submit Halo.app to Apple for notarization
set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Halo"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
BUNDLE_ID="com.halo.oura"
NOTARIZATION_PROFILE="halo-notarization"
ZIP_FILE="$PROJECT_DIR/$APP_NAME-notarization.zip"

echo "=========================================="
echo "Notarizing $APP_NAME.app"
echo "=========================================="

# Verify app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found. Run build.sh first."
    exit 1
fi

# Verify app is signed
echo "Verifying app is properly signed..."
if ! codesign --verify --deep --strict "$APP_BUNDLE" 2>/dev/null; then
    echo "Error: App is not properly signed. Run sign.sh first."
    exit 1
fi

# Check for stored credentials
echo "Checking notarization credentials..."
if ! xcrun notarytool history --keychain-profile "$NOTARIZATION_PROFILE" >/dev/null 2>&1; then
    echo ""
    echo "Error: Notarization credentials not found."
    echo ""
    echo "Please set up credentials with:"
    echo "  xcrun notarytool store-credentials \"$NOTARIZATION_PROFILE\" \\"
    echo "    --apple-id \"your-apple-id@example.com\" \\"
    echo "    --team-id \"E89Q3796E9\" \\"
    echo "    --password \"your-app-specific-password\""
    echo ""
    echo "You can create an App-Specific Password at:"
    echo "  https://appleid.apple.com -> Security -> App-Specific Passwords"
    echo ""
    exit 1
fi

# Create ZIP for notarization (Apple requires ZIP or DMG)
echo "Creating ZIP archive for notarization..."
rm -f "$ZIP_FILE"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_FILE"

echo "ZIP created: $ZIP_FILE ($(du -h "$ZIP_FILE" | cut -f1))"
echo ""

# Submit for notarization
echo "Submitting to Apple for notarization..."
echo "This may take a few minutes..."
echo ""

xcrun notarytool submit "$ZIP_FILE" \
    --keychain-profile "$NOTARIZATION_PROFILE" \
    --wait

# Clean up ZIP
rm -f "$ZIP_FILE"

# Staple the notarization ticket
echo ""
echo "Stapling notarization ticket to app..."
xcrun stapler staple "$APP_BUNDLE"

# Verify stapling
echo ""
echo "Verifying notarization..."
xcrun stapler validate "$APP_BUNDLE"

echo ""
echo "Checking Gatekeeper assessment..."
spctl --assess --type execute -v "$APP_BUNDLE"

echo ""
echo "Notarization complete!"
echo "$APP_BUNDLE is ready for distribution."
