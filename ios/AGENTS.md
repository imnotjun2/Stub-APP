# Stub iOS implementation notes

- Minimum target is iOS 17.
- Keep this a native SwiftUI app; do not replace screens with a WebView.
- Preserve the cream-paper visual language and semantic color tokens from `../design/Stub-Color-System-v0.1.md`.
- Keep one canonical `StubRecord`. Home, Wall and Trip Book may reference it, while `TripPlacement` owns only trip-specific order and presentation metadata.
- User images remain local by default under Application Support. Do not add accounts, cloud upload, OCR or live flight claims without an explicit product phase.
- Use stable IDs for categories, movie formats and suggested tags. Only system copy is localized; never auto-translate user titles or notes.
- Prefer `NavigationStack`, item-driven sheets, `PhotosPicker`, native controls and small composable SwiftUI views.
