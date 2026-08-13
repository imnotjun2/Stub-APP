# Stub v0.2 Design QA

## Comparison setup

- Primary travel reference: `/Users/bytedance/.codex/generated_images/019fec6c-b682-77b3-8f98-1c888cac97d4/exec-5b81091e-f354-4fde-b5b1-dc4f9d5fd778.png`.
- Supporting home reference: `/Users/bytedance/.codex/generated_images/019fec6c-b682-77b3-8f98-1c888cac97d4/exec-885e54d0-de79-46f5-91e1-2f05e92577cd.png`.
- Both source images are `853 × 1844`; they were normalized to the implementation's `393 × 852` CSS-pixel screen at device scale factor `1`.
- The comparison state is light theme, Chinese locale, iPhone template runtime, with the Home or Trips top-level screen at scroll position zero.
- Final combined evidence: `qa/comparison-home-final.png` and `qa/comparison-trips-final.png`.

## Rendered QA and iteration history

The first valid side-by-side travel comparison is stored at `qa/comparison-trips-pass1.png`. It showed that the implementation had the correct cream-paper palette, editorial serif hierarchy, red route line and book metaphor, but the `438px` map pushed almost the entire trip-book cover below the first viewport. This was an actionable P2 hierarchy mismatch because the reference deliberately shows both the map and a complete book cover together.

The Trips layout was tightened without changing the selected visual language: the intro and segmented control became more compact, the map was reduced to `300px`, and the chapter card became a smaller left-aligned paper annotation. The final comparison at `qa/comparison-trips-final.png` now exposes the complete trip cover above the bottom navigation while preserving readable pins and the selected route. The Home comparison at `qa/comparison-home-final.png` confirms the warm cream background, restrained gold memory accents, realistic ticket crop, editorial brand/type treatment and brick-red primary action language. The remaining difference is the protected iPhone status bar and device frame, which are template-owned chrome rather than app-owned layout.

## Playwright interaction evidence

The final direct Playwright run used the user's permitted system Chrome against `http://localhost:4173/` in a fresh isolated browser context. The full machine-readable result is `qa/playwright-result.json`, whose `final` value is `passed`. It captured eight `393 × 852` implementation screenshots:

- `qa/implementation-home-light-final.png`
- `qa/implementation-trips-light-final.png`
- `qa/implementation-trip-book-light-final.png`
- `qa/implementation-wall-light-final.png`
- `qa/implementation-profile-dark-en-final.png`
- `qa/implementation-trips-dark-en-final.png`
- `qa/implementation-movie-review-light-final.png`
- `qa/implementation-home-after-reload-final.png`

The automated journey verified Home load; idempotent migration of two synthetic legacy records while preserving the legacy key; Trips navigation; trip-book opening; supported airline-mark rendering; Wall tag filtering; dark theme and English switching; a real file upload; movie formats, tags, poster confirmation and memory-photo attachment; saving; canonical-record editing; adding the same record to a trip by reference; reloading; and persistence after reload. The final archive contained two untouched legacy records, three IndexedDB records, four IndexedDB media objects and one trip placement. The trip placement referenced the saved record ID and did not create a duplicate record. This isolated QA context intentionally did not read or mutate the user's actual browser profile.

Browser console errors, uncaught page errors and failed HTTP responses were all empty. The earlier empty-image `src` warnings were fixed by withholding the `src` attribute until an object URL exists, and the favicon 404 was fixed by declaring an existing bundled PNG favicon. The review screenshot waits for image decoding and explicitly dismisses the simulated keyboard before capture.

## Final findings

No actionable P0, P1 or P2 findings remain in the compared Home and Trips states or in the primary upload/edit/persist journey.

- Typography and hierarchy: passed. Serif display moments, UI sans text, bilingual labels and wrapping remain legible in light and dark themes.
- Spacing and clipping: passed. The Home ticket, Trips map/chapter/book hierarchy, fixed navigation, trip-book pages and review form do not overlap or clip at `393 × 852`.
- Color and contrast: passed. The live-token contract requires at least `4.5:1` for informational text and `3:1` for strong borders; the rendered dark Profile and Trips screenshots remain readable.
- Assets and crops: passed. Ticket images, map, poster, ramen photo and supported airline marks render at useful crops without placeholders.
- States and interactions: passed. Primary navigation, filters, theme/locale controls, upload, edit, trip reference and reload persistence all completed.
- Accessibility baseline: passed for this demo. Inputs are labelled, primary controls are semantic buttons, images have appropriate alternative text, reduced motion is respected and the tested contrast thresholds pass.

## Verification commands

- TypeScript: passed with `tsc --noEmit`.
- Protected runtime: passed for 28 protected files.
- Contract and hosting tests: 15 passed, 0 failed.
- Production build and Sites packaging: passed. Vite reports only the non-blocking bundle-size advisory for the `548.89 kB` main chunk.

final result: passed
