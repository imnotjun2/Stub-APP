import assert from "node:assert/strict";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "../node_modules/.pnpm/playwright@1.61.1/node_modules/playwright/index.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(here, "..");
const qaDir = path.join(projectRoot, "qa-web");
const baseURL = "http://127.0.0.1:4173/";
const ticketPath = path.join(projectRoot, "public/reference-crops/movie-ticket-reference.png");

await mkdir(qaDir, { recursive: true });

const result = {
  baseURL,
  screenshots: [],
  viewports: [],
  interactions: [],
  consoleErrors: [],
  pageErrors: [],
  httpErrors: [],
  final: "running",
};

const browser = await chromium.launch({
  headless: true,
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
});

async function waitForStable(page) {
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
  await page.waitForTimeout(250);
}

function attachDiagnostics(page, label) {
  page.on("console", (message) => {
    if (message.type() === "error") result.consoleErrors.push(`${label}: ${message.text()}`);
  });
  page.on("pageerror", (error) => result.pageErrors.push(`${label}: ${error.message}`));
  page.on("response", (response) => {
    if (response.status() >= 400) result.httpErrors.push({ label, status: response.status(), url: response.url() });
  });
}

async function capture(page, name) {
  const toast = page.getByTestId("toast");
  if (await toast.isVisible().catch(() => false)) await toast.getByRole("button").click();
  await waitForStable(page);
  await page.locator(".mobile-scroll").evaluateAll((nodes) => nodes.forEach((node) => { node.scrollTop = 0; }));
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  const file = path.join(qaDir, `${name}.png`);
  await page.screenshot({ path: file, fullPage: false });
  result.screenshots.push(file);
}

async function assertFlatWebShell(page, expectedWidth, expectedHeight) {
  await page.getByTestId("web-stage").waitFor();
  const box = await page.getByTestId("device-screen").boundingBox();
  assert.ok(box, "web screen should have a bounding box");
  assert.ok(Math.abs(box.width - expectedWidth) <= 1, `expected web width ${expectedWidth}, got ${box.width}`);
  assert.ok(Math.abs(box.height - expectedHeight) <= 1, `expected web height ${expectedHeight}, got ${box.height}`);
  for (const selector of [".phone-bezel", ".status-bar", ".home-indicator-svg", ".device-menu-bar", ".keyboard-dock", ".device-camera"]) {
    assert.equal(await page.locator(selector).count(), 0, `${selector} must not exist in web presentation`);
  }
  const overflow = await page.evaluate(() => ({ width: document.documentElement.scrollWidth, viewport: window.innerWidth }));
  assert.ok(overflow.width <= overflow.viewport, `page should not overflow horizontally: ${JSON.stringify(overflow)}`);
}

try {
  const desktop = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    colorScheme: "light",
    reducedMotion: "reduce",
  });
  const page = await desktop.newPage();
  attachDiagnostics(page, "desktop");
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.getByTestId("home-screen").waitFor();
  await assertFlatWebShell(page, 1440, 1000);
  result.viewports.push({ name: "desktop", width: 1440, height: 1000, deviceScaleFactor: 1 });
  await capture(page, "home-desktop");
  result.interactions.push("desktop:home-loaded-without-device-chrome");

  const desktopNav = await page.locator("nav.bottom-nav").evaluate((node) => {
    const style = getComputedStyle(node);
    const box = node.getBoundingClientRect();
    return { left: box.left, width: box.width, columns: style.gridTemplateColumns };
  });
  assert.ok(desktopNav.left < 40 && desktopNav.width <= 150, `desktop nav should be a left rail: ${JSON.stringify(desktopNav)}`);

  await page.getByRole("button", { name: "旅册", exact: true }).click();
  await page.getByTestId("trips-screen").waitFor();
  await capture(page, "trips-desktop");
  await page.locator(".trip-cover-card").click();
  await page.getByTestId("trip-book-screen").waitFor();
  result.interactions.push("desktop:trip-book-opened");
  await page.locator(".subpage-header .icon-button.plain").click();

  await page.getByRole("button", { name: "墙", exact: true }).click();
  await page.getByTestId("wall-screen").waitFor();
  await capture(page, "wall-desktop");
  const columns = await page.locator(".stub-wall").evaluate((node) => getComputedStyle(node).columnCount);
  assert.equal(columns, "3", "desktop wall should use three columns");

  await page.getByRole("button", { name: "回顾", exact: true }).click();
  await page.getByTestId("profile-screen").waitFor();
  await capture(page, "review-desktop");
  await page.getByRole("button", { name: "深色", exact: true }).click();
  assert.equal(await page.locator("html").getAttribute("data-stub-theme"), "dark");
  await capture(page, "review-desktop-dark");
  result.interactions.push("desktop:wall-review-theme");

  await page.getByRole("button", { name: "存根", exact: true }).click();
  await page.getByRole("button", { name: "留下一张", exact: true }).click();
  await page.getByTestId("import-screen").waitFor();
  await page.locator('[data-testid="library-file-input"]').setInputFiles(ticketPath);
  await page.getByTestId("review-screen").waitFor();
  await page.getByTestId("title-input").fill("网页中的真实票据");
  await page.getByTestId("note-input").fill("这张票据从浏览器直接上传。");
  await page.getByTestId("note-input").evaluate((element) => element.blur());
  assert.equal(await page.locator(".keyboard-dock").count(), 0, "native web inputs should not show a simulated keyboard");
  await page.getByTestId("save-button").click();
  await page.getByTestId("home-screen").waitFor();
  await page.getByText("这张票据从浏览器直接上传。", { exact: true }).waitFor();
  result.interactions.push("desktop:ticket-uploaded-and-saved");
  await desktop.close();

  const mobile = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1,
    colorScheme: "light",
    reducedMotion: "reduce",
  });
  const mobilePage = await mobile.newPage();
  attachDiagnostics(mobilePage, "mobile");
  await mobilePage.goto(baseURL, { waitUntil: "networkidle" });
  await mobilePage.getByTestId("home-screen").waitFor();
  await assertFlatWebShell(mobilePage, 390, 844);
  result.viewports.push({ name: "mobile", width: 390, height: 844, deviceScaleFactor: 1 });
  await capture(mobilePage, "home-mobile");
  const mobileNav = await mobilePage.locator("nav.bottom-nav").evaluate((node) => {
    const box = node.getBoundingClientRect();
    return { bottom: window.innerHeight - box.bottom, width: box.width };
  });
  assert.ok(mobileNav.bottom >= 10 && mobileNav.width >= 350, `mobile nav should float near the bottom: ${JSON.stringify(mobileNav)}`);
  await mobilePage.getByRole("button", { name: "旅册", exact: true }).click();
  await mobilePage.getByTestId("trips-screen").waitFor();
  await capture(mobilePage, "trips-mobile");
  result.interactions.push("mobile:responsive-navigation");
  await mobile.close();

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
