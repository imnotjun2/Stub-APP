# Stub responsive web Design QA

## Comparison setup

- Home visual source: `../design-concepts/original-home-visual-reference.png` (`853 × 1844`).
- Trips visual source: `../design-concepts/original-trips-visual-reference.png` (`853 × 1844`).
- Browser captures: mobile `390 × 844` and desktop `1440 × 1000`, device scale factor `1`.
- Final mobile comparison sheets: `qa-web/comparison-home-mobile-final.png` and `qa-web/comparison-trips-mobile-final.png` (`804 × 876`).

## Iteration history

The first web pass still presented the product inside an iPhone shell. This was a P1 product mismatch because the requested deliverable is a directly usable HTML website, not a phone mockup. The runtime now has an explicit `web` presentation: the document occupies the browser viewport, native scrolling and native file inputs are enabled, and device chrome, simulated status bar, home indicator, camera, device picker and simulated keyboard are omitted.

The first desktop pass inherited the mobile bottom navigation and left too much unused horizontal space. The final responsive layout uses a persistent branded left rail above `960px`, an explicit “留下一张” action and a wider content canvas; mobile retains the compact floating bottom navigation. The Wall expands to three columns on desktop while content-heavy views stay within a readable maximum width.

Image decoding initially caused a late scroll-anchor shift during screenshot capture. The QA runner now waits for decoded images, resets to scroll position zero and verifies the stable frame before capture.

## Playwright evidence

`qa-web/playwright-result.json` reports `final: passed`. The direct Playwright run used system Chrome against `http://localhost:4173/` in a fresh browser context and checked:

- no iPhone bezel or simulated device chrome at desktop or mobile widths;
- full-viewport responsive layout with no horizontal overflow;
- desktop left navigation and mobile bottom navigation;
- Home, Trips, Trip Book, Wall and Review navigation;
- three-column desktop Wall;
- dark-mode rendering;
- real ticket-file upload and save without a simulated keyboard;
- no console errors, page errors or failed HTTP responses.

Rendered evidence includes `home-desktop.png`, `trips-desktop.png`, `wall-desktop.png`, `review-desktop.png`, `review-desktop-dark.png`, `home-mobile.png` and `trips-mobile.png` under `qa-web/`.

## Final findings

No actionable P0, P1 or P2 findings remain. The cream-paper palette, editorial typography, gold memory accents, ticket-first content and brick-red primary action remain consistent with the selected Stub visual direction. Desktop and mobile now present the same canonical product as responsive browser views rather than duplicated device-specific implementations.

final result: passed
