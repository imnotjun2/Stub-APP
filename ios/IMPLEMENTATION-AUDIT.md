# Stub iOS implementation audit

Audit date: 2026-08-11

The native target is intentionally implemented with SwiftUI rather than a WebView. It mirrors the validated HTML Demo's product model and visual language while using iOS-native navigation, sheets, photo picking, camera capture, persistence and accessibility semantics.

| Requirement | Native implementation | Current evidence |
|---|---|---|
| Cream-paper design | Semantic light/dark palette, serif editorial headings, paper cards, brick-red primary controls, old-gold memory accents and reused ticket/map/photo assets | `StubTheme.swift`, `Components.swift`, generated App Icon and bundled resources |
| Four primary views | Home timeline, Trips map/books, Wall grid and Profile settings use a native `TabView`, with a centered add action | `AppShell.swift` and the four feature view files |
| Real ticket import | `PhotosPicker` imports the primary ticket; `CameraPicker` captures a photo on a physical iPhone; image data is resized before storage | `StubEditorView.swift`, `ImageSupport.swift` |
| Dynamic metadata | Movie formats, flight/train subtypes, airline/aircraft/cabin/seat, route/times, generic location and stable tags are editable | `Models.swift`, `StubEditorView.swift` |
| Poster and memory photos | Reliable bundled poster suggestion requires a title match and user confirmation; a manual poster and up to six memory photos are supported | `StubEditorView.swift` |
| Canonical record model | Home, Wall and Trip Book read one `StubRecord`; `TripPlacement` keeps only trip-specific reference and presentation metadata | `Models.swift`, `ArchiveStore.swift` |
| Local persistence | Records and trips are atomically encoded to Application Support; uploaded media is stored in a dedicated Media directory | `ArchiveStore.swift` |
| Theme and language | System/light/dark appearance and Chinese/English interface settings are persisted with `AppStorage`; user-authored content is not translated | `AppShell.swift`, `ProfileView.swift` |
| Native project | A shared `Stub` scheme, iPhone-only app target, generated Info.plist keys, photo/camera permission copy, asset catalog and app icon are included | `Stub.xcodeproj`, `Assets.xcassets` |

## Verification

- OpenStep project file: `plutil` passed.
- Shared scheme XML: `xmllint` passed.
- All Swift source: parser passed.
- Cross-platform SwiftUI core: `swiftc -typecheck` and a full link pass succeeded against the installed macOS SDK with iOS-only presentation modifiers conditionally excluded.
- Native iOS build: Xcode 26.6 compiled, linked, processed the asset catalog and produced `Stub.app` against the iOS 26.5 Simulator SDK with deployment target iOS 17; `xcodebuild` finished with `BUILD SUCCEEDED`.
- Persistence contract: save, attachment write, trip reference, reload, canonical edit and delete passed in an isolated temporary archive.
- Static native contract: no `WKWebView`, `SFSafariViewController` or `WebView` wrapper exists.
- Resources and 1024 × 1024 marketing icon: present.
- Simulator runtime: the app was installed and launched on `iPhone 16 Pro - Stub QA` running iOS 26.5.
- Interactive journey: Home rendered; the add sheet opened; the system Photos picker imported a real ticket image; Movie + IMAX was saved; the new canonical record appeared on Home and Wall; Trips, the Sapporo Trip Book and record detail opened successfully.
- Relaunch persistence: the created record reloaded after a full terminate/launch cycle. Its JSON record and stored JPEG were both read back from `Application Support/Stub`.
- Theme and language: the same persisted Home view rendered in Chinese/light and English/dark with legible semantic colors.
- Runtime health: no crash, image-decoding failure, missing-resource error or persistence error was observed during the interaction pass.

## Simulator evidence

The reproducible smoke-test script now prefers a booted iPhone 16 Pro and uses a standard single executable for deterministic `simctl` launch. Captured screenshots live under `ios/qa/`, including the settled cream Home screen, the persisted Home state after relaunch and the English dark theme.

final result: native iOS build and iPhone 16 Pro Simulator verification passed
