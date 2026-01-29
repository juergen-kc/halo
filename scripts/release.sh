#!/bin/bash
# release.sh - Create GitHub release for Halo
set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Halo"
VERSION="1.0.0"
DMG_PATH="$PROJECT_DIR/$APP_NAME.dmg"
TAG="v$VERSION"

echo "=========================================="
echo "Creating GitHub Release $TAG"
echo "=========================================="

cd "$PROJECT_DIR"

# Check gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed."
    echo "Install with: brew install gh"
    exit 1
fi

# Check gh is authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: GitHub CLI not authenticated."
    echo "Run: gh auth login"
    exit 1
fi

# Check if remote is configured
if ! git remote get-url origin &> /dev/null; then
    echo "Error: No git remote 'origin' configured."
    echo ""
    echo "Please add a remote with:"
    echo "  git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
    echo ""
    exit 1
fi

# Check if DMG exists
if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG not found at $DMG_PATH"
    echo "Run create-dmg.sh first."
    exit 1
fi

# Verify DMG is notarized
echo "Verifying DMG is notarized..."
if ! xcrun stapler validate "$DMG_PATH" &> /dev/null; then
    echo "Warning: DMG may not be notarized. Continue anyway? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if tag already exists
if git rev-parse "$TAG" &> /dev/null; then
    echo "Warning: Tag $TAG already exists locally."
    echo "Delete it and recreate? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        git tag -d "$TAG"
    else
        exit 1
    fi
fi

# Create and push tag
echo "Creating tag $TAG..."
git tag -a "$TAG" -m "Release $VERSION"
git push origin "$TAG"

# Create release notes
RELEASE_NOTES=$(cat <<EOF
# $APP_NAME $VERSION

Your personal Oura Ring companion for the macOS menu bar.

## Features

- Real-time sleep, readiness, and activity scores in your menu bar
- Detailed sleep analysis with stages breakdown
- Heart rate monitoring and trends
- Morning sleep summary notifications
- Native macOS app with minimal resource usage
- Secure OAuth authentication with Oura

## Installation

1. Download \`$APP_NAME.dmg\` below
2. Open the DMG and drag $APP_NAME to Applications
3. Launch $APP_NAME and sign in with your Oura account

## Requirements

- macOS 13.0 (Ventura) or later
- Oura Ring with active subscription

## What's New

- Initial release
EOF
)

# Create GitHub release with DMG
echo ""
echo "Creating GitHub release..."
gh release create "$TAG" \
    --title "$APP_NAME $VERSION" \
    --notes "$RELEASE_NOTES" \
    "$DMG_PATH"

echo ""
echo "Release created successfully!"
echo ""
echo "View release:"
gh release view "$TAG" --web || echo "  $(git remote get-url origin | sed 's/\.git$//')/releases/tag/$TAG"
