# AGENTS.md

## Cursor Cloud specific instructions

This repository is the **OneSignal iOS SDK** (native Swift / Objective-C). It is a
**macOS + Xcode–only** project and **cannot be built, linted, tested, or run inside the
Linux-based Cursor Cloud Agent VM**. This is a hard platform limitation, not a missing
dependency: Xcode, the iOS SDKs, the iOS Simulator, `xcodebuild`, `xcrun`, and
`swiftc --sdk macosx` exist only on macOS and cannot be installed on Linux.

What this means for a Cloud Agent running here:

- There is **no application to run** and **no test/lint/build command that will succeed**
  on this VM. Do not attempt to `apt install` a Swift toolchain to work around this — the
  package only declares `.iOS` / `.macCatalyst` platforms (`Package.swift`) and every
  target depends on iOS `.xcframework` binaries, so a Linux Swift toolchain will not build it.
- All CI runs on `macos-latest` and uses `xcodebuild` / `xcrun` / `swiftc --sdk macosx`
  (see `.github/workflows/ci.yml`). Reproduce those steps only on a real macOS + Xcode host.
- The real developer setup (macOS only) is documented in `GettingStarted.md`,
  `CONTRIBUTING.md`, and `examples/demo/README.md`. In short: `git submodule update --init
  --recursive`, then `iOS_SDK/OneSignalSDK/build_kmp_xcframework.sh`, then open
  `iOS_SDK/OneSignalSDK.xcworkspace` in Xcode and run the `OneSignalDevApp` or `App` scheme
  on an iOS Simulator / device.

Layout / mental model:

- `iOS_SDK/OneSignalSDK/` — SDK source + `OneSignal.xcodeproj` + `OneSignalSDK.xcworkspace`.
  Unit tests use the `UnitTestApp` scheme with test plan `UnitTestApp_TestPlan_Reduced`.
- `iOS_SDK/OneSignalDevApp/` — internal dev/test app that builds against local SDK source.
- `examples/demo/` — SwiftUI reference app (project generated from `project.yml` via XcodeGen).
- `OneSignal-KMP-SDK/` — git submodule (Kotlin Multiplatform, Gradle + JDK 17). It compiles
  into `OneSignalKMP.xcframework`, which `OneSignalCore` links. The submodule **can be
  cloned on Linux**, but its XCFramework assembly tasks
  (`:kmp:assembleOneSignalKMPReleaseXCFramework` / `:kmp:verifyOneSignalKMPXCFramework`)
  require the Apple toolchain, so they also cannot complete on this VM.

Non-obvious gotchas (from the docs):

- Always open the **workspace** (`OneSignalSDK.xcworkspace`), not an individual `.xcodeproj`,
  or builds fail with missing frameworks.
- Real push delivery needs a **physical device** with valid APNs config; the Simulator only
  supports permission prompts / token generation.
- End-to-end features need a valid OneSignal **App ID** (and, for some demo actions, a REST
  API key in a gitignored `Secrets.plist`).
