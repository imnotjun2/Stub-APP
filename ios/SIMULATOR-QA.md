# Stub iOS Simulator QA

Run `./scripts/run-simulator-qa.sh` after booting an iPhone Simulator. The script prefers a booted iPhone 16 Pro, builds a deterministic Simulator executable, installs and launches the `Stub` scheme, and saves the settled initial screenshot to `qa/home-launch.png`.

## Verified baseline

The 2026-08-11 baseline passed with Xcode 26.6 on `iPhone 16 Pro - Stub QA` / iOS 26.5. It covered a real Photos-picker import, Movie + IMAX save, Home/Trips/Trip Book/Wall/detail navigation, JSON and media-file readback, full app relaunch, and Chinese/light plus English/dark rendering. The editable canonical-record and trip-placement operations also remain covered by the isolated persistence contract in `scripts/check.sh`.

## Automated-control anchors

The following accessibility identifiers are stable and intended for Xcode UI tests or XcodeBuildMCP interaction:

| Surface | Identifier |
|---|---|
| Home | `homeScreen` |
| Trips | `tripsScreen` |
| Trip Book | `tripBookScreen` |
| Wall | `wallScreen` |
| Profile | `profileScreen` |
| Add button | `addStubButton` |
| Editor | `stubEditorScreen` |
| Primary photo picker | `primaryPhotoPicker` |
| Title field | `stubTitleField` |
| Save button | `saveStubButton` |
| Memory-photo picker | `memoryPhotosPicker` |
| Category chip | `category.<stable-id>` |
| Detail | `stubDetailScreen` |
| Language toggle | `languageToggle` |
| Appearance option | `appearance.system`, `appearance.light`, `appearance.dark` |

## Regression journey

1. Confirm Home renders in Chinese/light mode with the ticket image as the visual focus.
2. Open Trips, switch Map/Books, open the Sapporo Trip Book and return.
3. Open Wall, change category and tag filters, then open a detail card.
4. Open Profile, switch to English and Dark, inspect legibility, then restore the desired state.
5. Tap `addStubButton`, choose a real ticket in `primaryPhotoPicker`, enter a title and select Movie.
6. Select IMAX and Dolby Cinema, attach one memory photo, write a note and save.
7. Open the saved record, edit its note, add it to the Sapporo Trip Book and confirm Home/Wall/Trip Book show one canonical record.
8. Terminate and relaunch the app; confirm the record, formats, attachment, edit and trip placement persist.
9. Inspect the console for crashes, image-decoding failures, persistence errors and missing resources.
10. Capture Home light, Trips light, Trip Book light, Wall light, Editor light, Profile dark English and the persisted Home state. Store durable artifacts under `ios/qa/`.
