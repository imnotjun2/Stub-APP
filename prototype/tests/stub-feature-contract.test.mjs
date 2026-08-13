import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import { test } from "node:test";

const source = await readFile(new URL("../src/Prototype.tsx", import.meta.url), "utf8");
const styles = await readFile(new URL("../src/prototype.css", import.meta.url), "utf8");

function luminance(hex) {
  const channels = hex.slice(1).match(/../g).map((value) => Number.parseInt(value, 16) / 255).map((value) => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}

function contrast(foreground, background) {
  const values = [luminance(foreground), luminance(background)].sort((a, b) => b - a);
  return (values[0] + 0.05) / (values[1] + 0.05);
}

function cssToken(block, token) {
  return block.match(new RegExp(`--${token}:\\s*(#[0-9a-f]{6})`, "i"))?.[1];
}

test("keeps the v1 user archive untouched while migrating to IndexedDB", () => {
  assert.match(source, /const LEGACY_KEY = "stub-demo-user-entries-v1"/);
  assert.match(source, /window\.indexedDB\.open\(DB_NAME, DB_VERSION\)/);
  for (const store of ["records", "media", "trips", "tripItems", "settings"]) {
    assert.match(source, new RegExp(`createObjectStore\\("${store}"`));
  }
  assert.doesNotMatch(source, /removeItem\(LEGACY_KEY\)/);
  assert.doesNotMatch(source, /setItem\(LEGACY_KEY/);
  assert.match(source, /Legacy migration verification failed/);
});

test("models one canonical stub with referenced trip placements", () => {
  assert.match(source, /type StubRecord = \{/);
  assert.match(source, /type TripItem = \{[\s\S]*tripId: string;[\s\S]*stubId: string;/);
  assert.match(source, /allTripItems[\s\S]*item\.stubId === selectedRecord\.id/);
  assert.match(source, /首页、墙和旅册引用的是同一份资料/);
});

test("includes requested categories, metadata, poster and photo fields", () => {
  for (const format of ["imax", "dolby-cinema", "cinity", "4dx"]) assert.match(source, new RegExp(`"${format}"`));
  for (const field of ["airlineCode", "flightNumber", "aircraft", "cabin", "seat", "departure", "arrival"]) {
    assert.match(source, new RegExp(`${field}: string`));
  }
  assert.match(source, /TravelSubtype = "flight" \| "train" \| "unknown"/);
  assert.match(source, /attachmentIds: string\[\]/);
  assert.match(source, /posterMediaId\?: string/);
  assert.match(source, /data-testid="review-screen"/);
});

test("never assigns the bundled movie poster when the title has no reliable match", () => {
  assert.match(source, /function posterCandidateFor\(title: string\)/);
  assert.match(source, /draft\.useSuggestedPoster && posterCandidate \? posterCandidate\.mediaId/);
  assert.match(source, /未命中绝不套用错误海报/);
  assert.match(source, /暂未找到可靠候选/);
});

test("ships the four requested main views, theme and language controls", () => {
  for (const testId of ["home-screen", "trips-screen", "wall-screen", "profile-screen", "trip-book-screen"]) {
    assert.match(source, new RegExp(`data-testid="${testId}"`));
  }
  assert.match(source, /stub-demo-theme-v2/);
  assert.match(source, /stub-demo-locale-v2/);
  assert.match(source, /document\.documentElement\.dataset\.stubTheme = resolvedTheme/);
  assert.match(styles, /:root\[data-stub-theme="dark"\]/);
  assert.match(styles, /\.stub-wall\s*\{/);
});

test("keeps all informational theme text at WCAG AA contrast", () => {
  const light = styles.match(/:root\s*\{([\s\S]*?)\}/)?.[1] ?? "";
  const dark = styles.match(/:root\[data-stub-theme="dark"\],[\s\S]*?\{([\s\S]*?)\}/)?.[1] ?? "";
  for (const [name, block] of [["light", light], ["dark", dark]]) {
    const canvas = cssToken(block, "stub-canvas");
    const surface = cssToken(block, "stub-surface");
    assert.ok(canvas && surface, `${name} surfaces should exist`);
    for (const token of ["stub-ink", "stub-muted", "stub-subtle", "stub-memory"]) {
      const value = cssToken(block, token);
      assert.ok(value && contrast(value, canvas) >= 4.5, `${name} ${token} should meet 4.5:1 on canvas`);
    }
    const strongBorder = cssToken(block, "stub-border-strong");
    assert.ok(strongBorder && contrast(strongBorder, surface) >= 3, `${name} strong border should meet 3:1 on surface`);
  }
});

test("stores system tags as stable ids while localizing their labels", () => {
  for (const tag of ["tag.premiere", "tag.with-friends", "tag.solo-trip", "tag.rainy-day", "tag.rewatch", "tag.delicious"]) {
    assert.match(source, new RegExp(tag.replace(".", "\\.")));
  }
  assert.match(source, /function tagLabel\(tag: string, locale: Locale\)/);
  assert.match(source, /tag\.startsWith\("custom:"\)/);
  assert.match(source, /txt\("小樽", "Otaru"\)/);
  assert.match(source, /txt\("札幌", "Sapporo"\)/);
});

test("lets migrated user stubs be edited without guessing an unknown travel subtype", () => {
  assert.match(source, /const startEditing = \(record: StubRecord\)/);
  assert.match(source, /编辑标签与信息/);
  assert.match(source, /const cancelDraft = \(\) =>/);
  assert.match(source, /旧版导入不会猜测机票或车票/);
  assert.match(source, /draft\.subtype === "train" \? \(/);
});

test("filters the home timeline and wall with stable personal tag ids", () => {
  assert.match(source, /const \[tagFilter, setTagFilter\]/);
  assert.match(source, /const \[wallTagFilter, setWallTagFilter\]/);
  assert.match(source, /record\.tags\.includes\(tagFilter\)/);
  assert.match(source, /record\.tags\.includes\(wallTagFilter\)/);
  assert.match(source, /类型和标签可以组合筛选/);
});

test("bundles the generated travel, poster and memory-photo assets", async () => {
  const assets = [
    "../public/stub-assets/trip-map-hokkaido.png",
    "../public/stub-assets/movie-poster-pentagram.jpg",
    "../public/stub-assets/hokkaido-ramen.jpg",
  ];
  for (const asset of assets) {
    const info = await stat(new URL(asset, import.meta.url));
    assert.ok(info.size > 10_000, `${asset} should be a real raster asset`);
  }
  for (const asset of ["airline-mu.png", "airline-ca.png", "airline-cz.png"]) {
    const info = await stat(new URL(`../public/stub-assets/${asset}`, import.meta.url));
    assert.ok(info.size > 2_000, `${asset} should contain a non-placeholder airline mark`);
  }
  assert.doesNotMatch(source, /<svg\b/i);
});

test("shows verified bundled airline marks and falls back to an IATA-code badge", () => {
  assert.match(source, /const bundledAirlineLogos: Record<string, string>/);
  for (const code of ["MU", "CA", "CZ"]) assert.match(source, new RegExp(`${code}: \"\\/stub-assets\\/airline-${code.toLowerCase()}\\.png\"`));
  assert.match(source, /airlineLogo \? <img className="airline-logo"/);
  assert.match(source, /: <span className="airline-mark"/);
});
