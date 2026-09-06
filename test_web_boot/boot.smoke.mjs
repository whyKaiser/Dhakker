// Boot smoke check for the built web app.
//
// The failure it guards against: a permanently blank page. Before this, when
// a resource the engine needs could not be fetched, the page stayed white
// with no message — the app's own Dart error handling never ran, because the
// failure happened in the JS layer before main() was reached.
//
// Three scenarios, all offline against a local static server:
//
//   A. gstatic.com unreachable — CanvasKit must come from OUR origin, and the
//      page must show the failure screen rather than nothing.
//   B. The success contract — window.dhakkerAppReady() removes the boot
//      screen. This is the hook lib/boot_signal.dart calls after the app's
//      first frame, so it is what "the app is up" actually depends on.
//   C. gstatic.com AND the local CanvasKit unreachable — the failure screen
//      must still appear, with a retry button, in both languages, leaking
//      nothing.
//
// ── What this canNOT show ────────────────────────────────────────────────
//
// A successful boot of the real app. The Firebase JS SDK is still fetched
// from gstatic by the firebase_core web plugin, and there is no network
// here, so the app cannot reach its first frame in this environment at all.
// Scenario B therefore tests the watchdog's success path directly rather
// than pretending the app booted. Boot success against live Firebase is a
// separate claim and is NOT established by this file. See docs/WEB_BOOT.md.

import { chromium } from "playwright-core";
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(here, "..", "build", "web");
const PORT = Number(process.env.BOOT_SMOKE_PORT || 8123);

/** Chromium is found, in order, from: an explicit override, whatever
 *  playwright-core resolves (the usual case in CI, where `playwright install`
 *  has just run), then a few well-known locations. */
function findChromium() {
  if (process.env.CHROMIUM_PATH) return process.env.CHROMIUM_PATH;
  try {
    const p = chromium.executablePath();
    if (p && existsSync(p)) return p;
  } catch { /* not installed via playwright; fall through */ }
  return [
    "/opt/pw-browsers/chromium-1194/chrome-linux/chrome",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
    "/usr/bin/google-chrome",
  ].find((p) => existsSync(p));
}
const CHROME = findChromium();

const TYPES = {
  ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript",
  ".json": "application/json", ".wasm": "application/wasm", ".css": "text/css",
  ".png": "image/png", ".jpg": "image/jpeg", ".svg": "image/svg+xml",
  ".ttf": "font/ttf", ".otf": "font/otf", ".woff2": "font/woff2",
  ".bin": "application/octet-stream", ".symbols": "text/plain",
};

let failures = 0;
function fail(msg) {
  console.error(`   FAIL: ${msg}`);
  failures += 1;
  process.exitCode = 1;
}

if (!existsSync(path.join(ROOT, "index.html"))) {
  console.error(
    "build/web/index.html not found.\n" +
    "Build first:  flutter build web --release --no-web-resources-cdn",
  );
  process.exit(2);
}
if (!CHROME) {
  console.error("No Chromium binary found. Set CHROMIUM_PATH to one.");
  process.exit(2);
}

const server = createServer(async (req, res) => {
  try {
    const rel =
      decodeURIComponent(req.url.split("?")[0]).replace(/^\/+/, "") || "index.html";
    const file = path.join(ROOT, rel);
    if (!file.startsWith(ROOT)) { res.writeHead(403).end(); return; }
    const s = await stat(file).catch(() => null);
    if (!s || !s.isFile()) { res.writeHead(404).end(); return; }
    res.writeHead(200, {
      "Content-Type": TYPES[path.extname(file)] || "application/octet-stream",
    });
    res.end(await readFile(file));
  } catch { res.writeHead(500).end(); }
});
await new Promise((r) => server.listen(PORT, "127.0.0.1", r));

const browser = await chromium.launch({
  executablePath: CHROME,
  args: ["--no-sandbox"],
});

/** Opens the page with `block` aborted, recording what was blocked and what
 *  was served from our own origin. Waits until the page settles. */
async function open(block) {
  const page = await browser.newPage();
  const blocked = [];
  const local = [];
  for (const pattern of block) {
    await page.route(pattern, (route) => {
      blocked.push(route.request().url());
      return route.abort();
    });
  }
  page.on("request", (r) => {
    const u = r.url();
    if (u.includes(`127.0.0.1:${PORT}`)) local.push(u.split(`${PORT}/`)[1] ?? "");
  });

  // Observe the app's own signal without displacing the page's handler.
  await page.addInitScript(() => {
    window.__booted = false;
    let real;
    Object.defineProperty(window, "dhakkerAppReady", {
      configurable: true,
      get() {
        return function () { window.__booted = true; if (real) real(); };
      },
      set(fn) { real = fn; },
    });
  });

  await page.goto(`http://127.0.0.1:${PORT}/index.html`, {
    waitUntil: "load", timeout: 60000,
  });
  await Promise.race([
    page.waitForFunction(() => window.__booted === true, { timeout: 40000 }).catch(() => null),
    page.waitForSelector("#boot.failed", { timeout: 40000 }).catch(() => null),
  ]);
  return { page, blocked, local };
}

async function state(page) {
  return {
    booted: await page.evaluate(() => window.__booted === true),
    fallback: (await page.locator("#boot.failed").count()) > 0,
    bootPresent: (await page.locator("#boot").count()) > 0,
    text: await page.locator("#boot").innerText().catch(() => ""),
  };
}

// ── A · gstatic unreachable ──────────────────────────────────────────────
console.log("\n── A · gstatic.com blocked");
{
  const { page, blocked, local } = await open([
    "**://www.gstatic.com/**",
    "**://fonts.gstatic.com/**",
  ]);
  const s = await state(page);

  // The renderer must no longer come from the CDN.
  const cdnCanvasKit = blocked.filter((u) => u.includes("flutter-canvaskit"));
  const localCanvasKit = local.filter((u) => u.includes("canvaskit"));
  console.log(`   CanvasKit from CDN   : ${cdnCanvasKit.length}`);
  console.log(`   CanvasKit from us    : ${localCanvasKit.length}`);
  if (cdnCanvasKit.length) fail("CanvasKit was still requested from gstatic");
  if (!localCanvasKit.length) fail("CanvasKit was not served from our own origin");

  // And the user must be told something, not shown a blank page.
  console.log(`   fallback shown       : ${s.fallback}`);
  if (!s.booted && !s.fallback) fail("blank page: no app and no message");
  await page.close();
}

// ── B · the success contract the app relies on ───────────────────────────
//
// Isolated on purpose. The engine is replaced with an empty script so that
// nothing loads and nothing fails: the watchdog has no reason to settle
// either way, and the ONLY thing that can resolve it is the hook. That makes
// this a test of the contract lib/boot_signal.dart depends on, rather than a
// test of whatever the network happened to do.
//
// Note the watchdog is deliberately one-shot: once it has shown the failure
// screen it stays shown, and a late app-ready signal will NOT silently swap
// a message the user is already reading for a half-loaded app.
console.log("\n── B · window.dhakkerAppReady() removes the boot screen");
{
  const page = await browser.newPage();
  await page.route("**/flutter_bootstrap.js", (route) =>
    route.fulfill({ status: 200, contentType: "text/javascript", body: "" }),
  );
  await page.goto(`http://127.0.0.1:${PORT}/index.html`, { waitUntil: "load" });

  const before = (await page.locator("#boot").count()) > 0;
  if (!before) fail("the boot screen was not shown while loading");

  // Exactly what lib/boot_signal.dart calls after the first frame.
  await page.evaluate(() => window.dhakkerAppReady());
  await page.waitForTimeout(300);

  const stillThere = (await page.locator("#boot").count()) > 0;
  console.log(`   boot screen shown while loading : ${before}`);
  console.log(`   boot screen removed on signal   : ${!stillThere}`);
  if (stillThere) fail("the boot screen survived the app-ready signal");
  await page.close();
}

// ── C · nothing loadable at all: the message must still appear ───────────
console.log("\n── C · gstatic.com AND local CanvasKit blocked");
{
  const { page } = await open([
    "**://www.gstatic.com/**",
    "**://fonts.gstatic.com/**",
    "**/canvaskit/**",
  ]);
  const s = await state(page);
  console.log(`   fallback shown       : ${s.fallback}`);
  if (!s.fallback) fail("the app could not boot, yet no failure message appeared");
  else {
    if (!(await page.locator("#boot-retry").count())) fail("fallback has no retry button");
    for (const phrase of ["تعذّر تشغيل التطبيق", "Couldn’t start the app"]) {
      if (!s.text.includes(phrase)) fail(`fallback is missing: ${phrase}`);
    }
    // A user-facing failure screen must never carry internals.
    for (const leak of ["gstatic", "firebase", "apiKey", "canvaskit", "Error:", "http"]) {
      if (s.text.toLowerCase().includes(leak.toLowerCase())) {
        fail(`fallback text leaks internals: ${leak}`);
      }
    }
    if (!failures) console.log("   bilingual, retry button present, no internals leaked.");
  }
  await page.close();
}

await browser.close();
server.close();

console.log(
  failures ? `\nSMOKE CHECK FAILED (${failures})` : "\nSMOKE CHECK PASSED",
);
