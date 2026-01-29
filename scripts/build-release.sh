#!/bin/bash
# build-release.sh - Master script for complete Halo release pipeline
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "============================================================"
echo "  Halo Release Pipeline"
echo "============================================================"
echo ""
echo "This script will:"
echo "  1. Build the release binary"
echo "  2. Sign with Developer ID certificate"
echo "  3. Notarize with Apple"
echo "  4. Create and notarize DMG"
echo "  5. Create GitHub release"
echo ""
echo "Prerequisites:"
echo "  - Developer ID certificate installed"
echo "  - Notarization credentials stored (xcrun notarytool store-credentials)"
echo "  - Git remote configured"
echo "  - GitHub CLI authenticated (gh auth login)"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Step 1: Build
echo ""
echo "[1/5] Building release binary..."
echo "------------------------------------------------------------"
"$SCRIPT_DIR/build.sh"

# Step 2: Sign
echo ""
echo "[2/5] Signing app bundle..."
echo "------------------------------------------------------------"
"$SCRIPT_DIR/sign.sh"

# Step 3: Notarize app
echo ""
echo "[3/5] Notarizing app bundle..."
echo "------------------------------------------------------------"
"$SCRIPT_DIR/notarize.sh"

# Step 4: Create DMG
echo ""
echo "[4/5] Creating and notarizing DMG..."
echo "------------------------------------------------------------"
"$SCRIPT_DIR/create-dmg.sh"

# Step 5: GitHub release
echo ""
echo "[5/5] Creating GitHub release..."
echo "------------------------------------------------------------"
"$SCRIPT_DIR/release.sh"

echo ""
echo "============================================================"
echo "  Release Pipeline Complete!"
echo "============================================================"
echo ""
echo "Verification commands:"
echo "  codesign --verify --deep --strict Halo.app"
echo "  xcrun stapler validate Halo.app"
echo "  xcrun stapler validate Halo.dmg"
echo "  spctl --assess --type execute Halo.app"
echo ""
echo "Download the DMG on another Mac to verify Gatekeeper accepts it."
