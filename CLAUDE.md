# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is DirectorSeat?

An iOS app that guides beginners through making short films with their phone. The core differentiator is **Shooting Mode** — the user should feel guided, never lost. The aesthetic is cinematic, dark, and premium.

## Build Commands

```bash
# Build for simulator
xcodebuild -project DirectorSeat.xcodeproj -scheme DirectorSeat -sdk iphonesimulator build

# Build for device
xcodebuild -project DirectorSeat.xcodeproj -scheme DirectorSeat -sdk iphoneos build
```

No SPM dependencies, no CocoaPods, no workspace — open `DirectorSeat.xcodeproj` directly. The project uses **file system synchronized groups**, so new files added under `DirectorSeat/` are automatically picked up by Xcode without modifying `project.pbxproj`.

## Architecture

**MVVM with SwiftUI.** Each screen gets a View + ViewModel pair.

- ViewModels are `ObservableObject` classes
- SwiftUI only — no UIKit unless unavoidable (e.g., camera via `AVCaptureSession`)
- Modern Swift concurrency is enabled: `MainActor` default isolation, approachable concurrency mode

### File Organization

All source files live under `DirectorSeat/`:

```
DirectorSeat/
├── Views/          # SwiftUI screen views
├── ViewModels/     # ObservableObject logic per screen
├── Models/         # Data structures
├── Services/       # API clients, system integrations
├── Theme/          # Centralized colors, fonts, reusable styled components
└── Assets.xcassets
```

## Conventions

- **Theme centralization:** Colors and typography must live in `Theme/`, never hardcoded in views. Every view should pull from the shared theme.
- **Previews required:** Every View file must include a `#Preview` block.
- **No force unwraps** — use `guard let` / `if let`. Exception: only when the value is provably non-nil (e.g., `UIImage(named:)` for bundled assets).
- **Beginner-first UX:** Every screen should have a single, clear primary action. When in doubt, simplify.

## Build Configuration

- **Bundle ID:** `com.tastefyapp.DirectorSeat`
- **Targets:** iPhone and iPad
- **Swift version:** 5.0
- **Concurrency flags:** `SWIFT_APPROACHABLE_CONCURRENCY`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `MEMBER_IMPORT_VISIBILITY`
- **No test target yet** — `ENABLE_TESTABILITY = YES` is set for when one is added

## Current State

Fresh project. Only `ContentView.swift` and `DirectorSeatApp.swift` exist. No screens, models, services, or theme have been built yet.

**Next milestone:** Home screen and Idea Intake screen with mock data. No backend integration yet.
