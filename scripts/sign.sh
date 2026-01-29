#!/bin/bash
# sign.sh - Code sign Halo.app with Developer ID certificate and hardened runtime
set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Halo"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
ENTITLEMENTS="$PROJECT_DIR/Halo.entitlements"
SIGNING_IDENTITY="Developer ID Application: Jurgen Klaaben (E89Q3796E9)"

echo "=========================================="
echo "Code Signing $APP_NAME.app"
echo "=========================================="

# Verify app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found. Run build.sh first."
    exit 1
fi

# Verify entitlements file exists
if [ ! -f "$ENTITLEMENTS" ]; then
    echo "Error: Entitlements file not found at $ENTITLEMENTS"
    exit 1
fi

# Check signing identity is available
echo "Checking signing identity..."
if ! security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
    echo "Error: Signing identity not found: $SIGNING_IDENTITY"
    echo ""
    echo "Available identities:"
    security find-identity -v -p codesigning
    exit 1
fi

echo "Using identity: $SIGNING_IDENTITY"
echo ""

# Remove any existing signatures
echo "Removing existing signatures..."
codesign --remove-signature "$APP_BUNDLE" 2>/dev/null || true

# Sign the app bundle with hardened runtime
echo "Signing with hardened runtime..."
# Try with timestamp first, fall back to no timestamp if server unreachable
if codesign --force --deep --strict \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGNING_IDENTITY" \
    --timestamp \
    "$APP_BUNDLE" 2>/dev/null; then
    echo "Signed with secure timestamp."
else
    echo "Timestamp server unavailable, signing without timestamp..."
    echo "(Note: Notarization may fail without timestamp)"
    codesign --force --deep --strict \
        --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "$SIGNING_IDENTITY" \
        "$APP_BUNDLE"
fi

echo ""
echo "Verifying signature..."

# Verify the signature
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo ""
echo "Checking code signing requirements..."
codesign -d --entitlements - "$APP_BUNDLE" 2>/dev/null | head -20

echo ""
echo "Code signing complete!"
echo ""

# Display signature info
echo "Signature details:"
codesign -dv "$APP_BUNDLE" 2>&1 | grep -E "(Authority|Identifier|TeamIdentifier|Timestamp)"
