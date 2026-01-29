# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Halo is a macOS menu bar application that displays Oura Ring health data (sleep, readiness, heart rate). It runs as an LSUIElement (no dock icon) using SwiftUI and Swift 5.9+.

## Build Commands

```bash
# Development build
swift build

# Release build
swift build -c release

# Create app bundle (Halo.app)
./scripts/build.sh

# Full release pipeline (build, sign, notarize, create DMG)
./scripts/release.sh

# Run linter
swiftlint
```

There is no test suite configured.

## Architecture

### State Management
`AppState` (Sources/AppState.swift) is the central @MainActor singleton managing all health data and user preferences. It coordinates API fetching, caching, network monitoring, and notification scheduling. Views observe AppState via @EnvironmentObject.

### Service Layer
- **OuraAPIService** - HTTP requests to Oura API with retry logic and pagination
- **AuthenticationProvider** - Protocol for auth; currently uses Personal Access Token stored in Keychain
- **KeychainService** - Secure token storage (service: `com.commander.oura`)
- **NotificationService** - Morning sleep summary notifications
- **NetworkMonitor** - NWPathMonitor wrapper for connectivity state

### Data Flow
1. AppState initializes, loads token from Keychain, fetches data
2. OuraAPIService makes concurrent async requests for readiness, sleep, heart rate
3. Data populates @Published properties, triggering UI updates
4. Auto-refresh timer periodically re-fetches (respects low-power mode)

### Key Patterns
- All UI state managers use @MainActor
- Services injected into AppState for testability
- Combine publishers for reactive state + async/await for API calls
- Typed error enums with LocalizedError conformance

## Code Style (SwiftLint enforced)

- Line length: 120 warning, 200 error
- Function body length: 50 warning, 100 error
- File length: 500 warning, 1000 error
- Cyclomatic complexity: 15 warning, 25 error
