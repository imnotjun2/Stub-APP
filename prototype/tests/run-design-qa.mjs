import assert from "node:assert/strict";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "../node_modules/.pnpm/playwright@1.61.1/node_modules/playwright/index.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(here, "..");
const qaDir = path.join(projectRoot, "qa");
const baseURL = "http://localhost:4173/";
const ticketPath = path.join(projectRoot, "public/reference-crops/movie-ticket-reference.png");
const memoryPhotoPath = path.join(projectRoot, "public/stub-assets/hokkaido-ramen.jpg");
const ticketDataUrl = `data:image/png;base64,${(await readFile(ticketPath)).toString("base64")}`;

await mkdir(qaDir, { recursive: true });

const result = {
  baseURL,
  viewport: { width: 1400, height: 1200, deviceScaleFactor: 1 },
  screen: null,
  screenshots: [],
  captureDiagnostics: [],
  interactions: [],
  consoleErrors: [],
  pageErrors: [],
  httpErrors: [],
  migration: null,
  final: "running",
};

const browser = await chromium.launch({
  headless: true,
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
});
const context = await browser.newContext({
  viewport: { width: 1400, height: 1200 },
  deviceScaleFactor: 1,
  colorScheme: "light",
  reducedMotion: "reduce",
});

await context.addInitScript(({ image }) => {
  const marker = "stub-playwright-qa-seeded-v1";
  if (window.localStorage.getItem(marker)) return;
  const legacy = [
    { id: "qa-legacy-1", title: "我的旧电影票", date: "2026-08-09", type: "电影", note: "迁移测试一", image },
    { id: "qa-legacy-2", title: "我的旧旅行票", date: "2026-08-08", type: "旅行", note: "迁移测试二", image },
  ];
  window.localStorage.setItem("stub-demo-user-entries-v1", JSON.stringify(legacy));
  window.localStorage.setItem(marker, "1");
}, { image: ticketDataUrl });

const page = await context.newPage();
page.on("console", (message) => {
  if (message.type() === "error") result.consoleErrors.push(message.text());
});
page.on("pageerror", (error) => result.pageErrors.push(error.message));
page.on("response", (response) => {
  if (response.status() >= 400) result.httpErrors.push({ status: response.status(), url: response.url() });
});

async function waitForStable() {
  await page.evaluate(async () => {
    await document.fonts?.ready;
    await Promise.all(Array.from(document.images).map(async (image) => {
      if (!image.complete) {
        await new Promise((resolve) => {
          image.addEventListener("load", resolve, { once: true });
          image.addEventListener("error", resolve, { once: true });
        });
      }
      await image.decode?.().catch(() => undefined);
    }));
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  });
  await page.waitForTimeout(350);
}

async function capture(name, { resetScroll = true } = {}) {
  const toast = page.getByTestId("toast");
  if (await toast.isVisible().catch(() => false)) {
    await toast.getByRole("button").click();
  }
  await waitForStable();
  if (resetScroll) {
    await page.locator(".mobile-scroll").evaluateAll((nodes) => {
      for (const node of nodes) node.scrollTop = 0;
    });
    await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  }
  const screen = page.getByTestId("device-screen");
  await screen.waitFor({ state: "visible" });
  const box = await screen.boundingBox();
  assert.ok(box, "device screen should have a bounding box");
  assert.ok(Math.abs(box.width - 393) <= 1, `expected screen width 393, got ${box.width}`);
  assert.ok(Math.abs(box.height - 852) <= 1, `expected screen height 852, got ${box.height}`);
  result.screen = { cssWidth: box.width, cssHeight: box.height };
  const file = path.join(qaDir, `${name}.png`);
  result.captureDiagnostics.push(await page.evaluate((captureName) => {
    const scroll = document.querySelector(".mobile-scroll");
    const brand = document.querySelector(".brand-header");
    const keyboard = document.querySelector('[data-testid="keyboard-dock"]');
    const keyboardStyle = keyboard ? getComputedStyle(keyboard) : null;
    const brandBox = brand?.getBoundingClientRect();
    return {
      name: captureName,
      scrollTop: scroll instanceof HTMLElement ? scroll.scrollTop : null,
      brandTop: brandBox?.top ?? null,
      brandBottom: brandBox?.bottom ?? null,
      keyboardVisible: keyboard?.getAttribute("data-visible") ?? null,
      keyboardTransform: keyboardStyle?.transform ?? null,
    };
  }, name));
  await screen.screenshot({ path: file });
  result.screenshots.push(file);
  return file;
}

async function clickNav(name) {
  await page.locator("nav.bottom-nav").getByRole("button", { name, exact: true }).click();
  result.interactions.push(`navigate:${name}`);
}

async function readArchive() {
  return page.evaluate(async () => {
    const legacyRaw = window.localStorage.getItem("stub-demo-user-entries-v1");
    const open = window.indexedDB.open("stub-demo", 1);
    const db = await new Promise((resolve, reject) => {
      open.onsuccess = () => resolve(open.result);
      open.onerror = () => reject(open.error);
    });
    const readStore = (name) => new Promise((resolve, reject) => {
      const request = db.transaction(name, "readonly").objectStore(name).getAll();
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
    const [records, media, trips, tripItems] = await Promise.all(["records", "media", "trips", "tripItems"].map(readStore));
    db.close();
    return { legacy: JSON.parse(legacyRaw || "[]"), records, media, trips, tripItems };
  });
}

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.getByTestId("home-screen").waitFor();
  await capture("implementation-home-light-final");
  result.interactions.push("home:loaded");

  const initialArchive = await readArchive();
  assert.equal(initialArchive.legacy.length, 2, "legacy localStorage archive must remain intact");
  assert.ok(initialArchive.records.some((record) => record.id === "qa-legacy-1"), "first legacy record should migrate");
  assert.ok(initialArchive.records.some((record) => record.id === "qa-legacy-2"), "second legacy record should migrate");
  assert.ok(initialArchive.media.some((asset) => asset.id === "media-qa-legacy-1-ticket" && asset.blob), "first legacy image blob should migrate");
  result.interactions.push("migration:verified");

  await clickNav("旅册");
  await page.getByTestId("trips-screen").waitFor();
  await capture("implementation-trips-light-final");
  await page.locator(".trip-cover-card").click();
  await page.getByTestId("trip-book-screen").waitFor();
  assert.equal(await page.getByTestId("keyboard-dock").getAttribute("data-visible"), "false", "trip book should open with the keyboard dismissed");
  assert.ok(await page.locator(".airline-logo").count(), "trip book should render a supported airline mark");
  await capture("implementation-trip-book-light-final");
  result.interactions.push("trip-book:opened");
  await page.locator(".subpage-header .icon-button.plain").click();

  await clickNav("墙");
  await page.getByTestId("wall-screen").waitFor();
  await capture("implementation-wall-light-final");
  const wallCount = await page.locator(".wall-tile").count();
  await page.getByRole("button", { name: "独自出发", exact: true }).click();
  const filteredWallCount = await page.locator(".wall-tile").count();
  assert.ok(filteredWallCount > 0 && filteredWallCount < wallCount, "tag filter should narrow the Wall");
  result.interactions.push("wall:tag-filtered");

  await clickNav("我的");
  await page.getByTestId("profile-screen").waitFor();
  await page.getByRole("button", { name: "深色", exact: true }).click();
  assert.equal(await page.locator("html").getAttribute("data-stub-theme"), "dark", "dark theme should apply to the document");
  await page.locator("button.mini-language").click();
  assert.equal(await page.locator("html").getAttribute("lang"), "en", "English locale should update document language");
  await capture("implementation-profile-dark-en-final");
  result.interactions.push("profile:dark-en");

  await clickNav("Trips");
  await page.getByTestId("trips-screen").waitFor();
  await capture("implementation-trips-dark-en-final");
  await page.locator("button.mini-language").click();
  await clickNav("我的");
  await page.getByTestId("profile-screen").waitFor();
  await page.getByRole("button", { name: "浅色", exact: true }).click();
  await clickNav("存根");
  await page.locator("button.nav-add").click();
  await page.getByTestId("import-screen").waitFor();
  await page.locator('[data-testid="library-file-input"]').setInputFiles(ticketPath);
  await page.getByTestId("review-screen").waitFor();
  await page.getByTestId("title-input").fill("名侦探柯南：百万美元的五棱星");
  await page.getByRole("button", { name: "电影", exact: true }).click();
  await page.locator(".poster-match").waitFor();
  await page.getByRole("button", { name: "IMAX", exact: true }).click();
  await page.getByRole("button", { name: "Dolby Cinema", exact: true }).click();
  await page.getByRole("button", { name: "首映", exact: true }).click();
  await page.locator('.attachment-editor input[type="file"]').setInputFiles(memoryPhotoPath);
  await page.getByTestId("note-input").fill("Playwright 记录的一场雨夜电影。");
  await page.getByTestId("note-input").evaluate((element) => element.blur());
  await waitForStable();
  await page.getByTestId("keyboard-dock").waitFor({ state: "attached" });
  assert.equal(await page.getByTestId("keyboard-dock").getAttribute("data-visible"), "false", "review evidence should not be obscured by the keyboard");
  await capture("implementation-movie-review-light-final", { resetScroll: false });
  await page.getByTestId("save-button").click();
  await page.getByTestId("home-screen").waitFor();
  await page.getByText("已为这一天留存根", { exact: false }).waitFor();
  result.interactions.push("upload:movie-saved");

  await page.locator(".stub-entry.featured-entry .ticket-button").click();
  await page.getByTestId("detail-screen").waitFor();
  assert.ok(await page.getByText("IMAX", { exact: true }).count(), "movie detail should show IMAX");
  assert.ok(await page.getByText("Dolby Cinema", { exact: true }).count(), "movie detail should show Dolby Cinema");
  assert.ok(await page.locator(".detail-attachments img").count(), "movie detail should show the memory photo");
  await page.getByRole("button", { name: "编辑标签与信息", exact: true }).click();
  await page.getByTestId("review-screen").waitFor();
  await page.getByTestId("note-input").fill("编辑后的雨夜电影记忆。");
  await page.getByTestId("save-button").click();
  await page.getByTestId("detail-screen").waitFor();
  await page.getByText("编辑后的雨夜电影记忆。", { exact: true }).waitFor();
  result.interactions.push("edit:canonical-stub-updated");

  await page.getByRole("button", { name: "收进旅册", exact: true }).click();
  await page.locator(".trip-picker > button").first().click();
  await page.getByText("已收进旅册", { exact: false }).waitFor();
  result.interactions.push("trip-reference:added");

  await page.reload({ waitUntil: "networkidle" });
  await page.getByTestId("home-screen").waitFor();
  const finalArchive = await readArchive();
  const saved = finalArchive.records.find((record) => record.title === "名侦探柯南：百万美元的五棱星");
  assert.ok(saved, "new movie should persist after reload");
  assert.equal(saved.note, "编辑后的雨夜电影记忆。", "edited note should persist");
  assert.deepEqual(saved.details.formatIds.sort(), ["dolby-cinema", "imax"], "movie formats should persist");
  assert.ok(saved.attachmentIds.length === 1, "memory photo attachment should persist");
  assert.ok(finalArchive.tripItems.some((item) => item.stubId === saved.id), "trip should reference the canonical stub id");
  assert.equal(finalArchive.records.filter((record) => record.id === saved.id).length, 1, "trip association must not duplicate the StubRecord");
  assert.equal(finalArchive.legacy.length, 2, "legacy localStorage archive must still be untouched after all writes");
  result.migration = {
    legacyRecords: finalArchive.legacy.length,
    indexedDbRecords: finalArchive.records.length,
    indexedDbMedia: finalArchive.media.length,
    indexedDbTripItems: finalArchive.tripItems.length,
  };
  await capture("implementation-home-after-reload-final");
  result.interactions.push("reload:persistence-verified");

  assert.deepEqual(result.consoleErrors, [], "browser console should have no errors");
  assert.deepEqual(result.pageErrors, [], "page should have no uncaught errors");
  assert.deepEqual(result.httpErrors, [], "page should have no failed HTTP responses");
  result.final = "passed";
} catch (error) {
  result.final = "failed";
  result.error = error instanceof Error ? `${error.name}: ${error.message}\n${error.stack || ""}` : String(error);
  throw error;
} finally {
  await writeFile(path.join(qaDir, "playwright-result.json"), `${JSON.stringify(result, null, 2)}\n`);
  await browser.close();
}
