# Stub iOS

This folder contains the native SwiftUI implementation of the validated HTML Demo. It is not a WebView wrapper.

## Requirements

- Xcode 16 or newer
- iOS 17 or newer
- An iPhone Simulator or a development-signed device

Open `Stub.xcodeproj`, select the `Stub` scheme, choose an iPhone Simulator and run. The validated reference device is iPhone 16 Pro. Photo-library import works in Simulator; camera capture requires a physical iPhone.

After Xcode is installed and a Simulator is booted, `./scripts/run-simulator-qa.sh` performs the command-line build/install/launch smoke test. The full interaction checklist and stable accessibility identifiers are documented in `SIMULATOR-QA.md`.

## Product architecture

- `StubRecord` is the canonical record.
- Home, Wall and Trip Book read the same record.
- `TripPlacement` stores only a trip reference and presentation metadata.
- User records are encoded to `Application Support/Stub/archive-v1.json`.
- Uploaded images are resized and written under `Application Support/Stub/Media`.
- Sample ticket, poster, map, photo and airline assets are bundled resources.

The native app intentionally cannot access the HTML Demo's browser IndexedDB. Importing those browser records requires a later explicit export/import bridge.

## TestFlight release

The project is prepared for an App Store Connect upload with `ExportOptions-TestFlight.plist`. The generated app `Info.plist` declares `ITSAppUsesNonExemptEncryption = false`, because this local-only demo does not implement non-exempt encryption.

Before the first upload, sign in to a paid Apple Developer account in Xcode, select its team for the `Stub` target, register the bundle identifier `com.stub.life`, and create the matching app record in App Store Connect. API-based uploads also require an App Store Connect API key stored outside this repository; never commit the `.p8` key or its environment file.

Every uploaded TestFlight build must use a new `CURRENT_PROJECT_VERSION`. Keep `MARKETING_VERSION` at `0.1` during the demo phase and increment the build number for each upload.

## Verification status

Xcode 26.6 successfully builds the native target against the iOS 26.5 Simulator SDK. The app has been installed and interactively exercised on an iPhone 16 Pro Simulator, including real ticket selection from Photos, save, Home/Trips/Trip Book/Wall/detail navigation, relaunch persistence and Chinese/light plus English/dark rendering. See `IMPLEMENTATION-AUDIT.md`, `SIMULATOR-QA.md` and the screenshots under `qa/` for the current evidence.
