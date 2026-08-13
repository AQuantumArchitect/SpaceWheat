#!/usr/bin/env node
// smoke-test-web-export.mjs — the browser smoke lane for the Web export
// (The Gallery, G4 — docs/ENGINE_FRONTIER.md Part II; docs/release/WEB_DOOR.md).
//
// Boots the exported bundle in real Chromium and verifies what the static QA
// (scripts/qa-web-export.sh) cannot: that the engine actually starts, renders
// frames, and stays responsive. Emits a JSON report — the honest performance
// statement ITCH_STATUS.md asks for — and exits non-zero on failure.
//
// Checks:
//   1. page loads with no fatal console/page errors
//   2. crossOriginIsolated === true (threads need COOP/COEP; qa-web-export
//      checks the headers, this checks the browser actually granted it)
//   3. a canvas appears (the engine attached its rendering surface)
//   4. requestAnimationFrame runs: measured FPS over SAMPLE_SECONDS
//   5. main thread stays responsive: an interleaved setTimeout ping keeps
//      landing within PING_BUDGET_MS
//
// Usage:
//   node scripts/smoke-test-web-export.mjs [export-dir] [--min-fps N]
//     [--boot-timeout SECS] [--report PATH] [--chromium PATH]
//
// Requirements: node >= 18, playwright-core (npm i playwright-core), and a
// Chromium (PLAYWRIGHT_BROWSERS_PATH, --chromium, or playwright's default).
// The static server is scripts/serve-web-local.py (COOP/COEP headers).

import { spawn } from "node:child_process";
import { existsSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright-core");

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = dirname(SCRIPT_DIR);

const args = process.argv.slice(2);
function flag(name, fallback) {
  const i = args.indexOf(name);
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  return fallback;
}
const positional = args.filter((a, i) => !a.startsWith("--") && (i === 0 || !args[i - 1].startsWith("--")));

const EXPORT_DIR = resolve(positional[0] || join(PROJECT_DIR, "releases", "web-local"));
const MIN_FPS = parseFloat(flag("--min-fps", "20"));
const BOOT_TIMEOUT_S = parseFloat(flag("--boot-timeout", "90"));
const SAMPLE_SECONDS = parseFloat(flag("--sample-seconds", "6"));
const SETTLE_SECONDS = parseFloat(flag("--settle-seconds", "10"));
const PING_BUDGET_MS = parseFloat(flag("--ping-budget", "250"));
const REPORT_PATH = flag("--report", join(EXPORT_DIR, "web-smoke-report.json"));
const CHROMIUM_PATH = flag("--chromium", process.env.SW_CHROMIUM || "");
const PORT = parseInt(flag("--port", "8043"), 10);
const ENTRY = flag("--entry", "index.html");

const report = {
  export_dir: EXPORT_DIR,
  started_at: new Date().toISOString(),
  checks: {},
  console_errors: [],
  verdict: "FAIL",
};

function check(name, ok, detail) {
  report.checks[name] = { ok, detail };
  console.log(`${ok ? "✓" : "✗"} ${name}${detail !== undefined ? ` — ${detail}` : ""}`);
  return ok;
}

function fail(msg) {
  console.error(`FAIL: ${msg}`);
  report.verdict = "FAIL";
  report.failed = msg;
  writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2) + "\n");
  process.exit(1);
}

if (!existsSync(join(EXPORT_DIR, ENTRY))) {
  fail(`export entry not found: ${join(EXPORT_DIR, ENTRY)} (build with scripts/build-web-local.sh)`);
}

// --- static server (COOP/COEP) -------------------------------------------
// `python3` does not exist on Windows (the Store alias stub is not it).
const PYTHON = process.env.SW_PYTHON || (process.platform === "win32" ? "python" : "python3");
const server = spawn(PYTHON, [join(SCRIPT_DIR, "serve-web-local.py"), EXPORT_DIR, "--port", String(PORT)], {
  stdio: ["ignore", "pipe", "pipe"],
});
const stopServer = () => { try { server.kill(); } catch { /* gone */ } };
process.on("exit", stopServer);

const BASE = `http://127.0.0.1:${PORT}`;
async function waitForServer() {
  for (let i = 0; i < 80; i++) {
    try {
      const r = await fetch(`${BASE}/${ENTRY}`);
      if (r.ok) return true;
    } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 250));
  }
  return false;
}

// --- the smoke -------------------------------------------------------------
try {
  if (!(await waitForServer())) fail("local server did not come up");
  check("server_up", true, BASE);

  const launchOpts = { headless: true };
  if (CHROMIUM_PATH) launchOpts.executablePath = CHROMIUM_PATH;
  const browser = await chromium.launch(launchOpts);
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

  page.on("console", (msg) => {
    if (msg.type() === "error") report.console_errors.push(msg.text().slice(0, 400));
  });
  page.on("pageerror", (err) => report.console_errors.push(`pageerror: ${String(err).slice(0, 400)}`));

  await page.goto(`${BASE}/${ENTRY}`, { waitUntil: "domcontentloaded", timeout: 30_000 });
  check("page_loaded", true);

  // Godot's loader registers a service worker and may reload once to gain
  // cross-origin isolation — give the boot a real budget.
  let isolated = false;
  let canvasUp = false;
  const deadline = Date.now() + BOOT_TIMEOUT_S * 1000;
  while (Date.now() < deadline && !(isolated && canvasUp)) {
    isolated = await page.evaluate(() => globalThis.crossOriginIsolated === true).catch(() => false);
    canvasUp = await page.evaluate(() => {
      const c = document.querySelector("canvas");
      return !!c && c.width > 0 && c.height > 0;
    }).catch(() => false);
    if (!(isolated && canvasUp)) await page.waitForTimeout(500);
  }
  if (!check("cross_origin_isolated", isolated)) fail("browser did not grant crossOriginIsolated (COOP/COEP)");
  if (!check("canvas_present", canvasUp)) fail(`no live canvas within ${BOOT_TIMEOUT_S}s — engine did not attach`);

  // Record WHAT rendered: an fps number without its renderer is an adjective.
  // Headless/CI Chromium often falls back to SwiftShader (software GL), which
  // caps fps far below what the same bundle does on consumer hardware.
  report.webgl_renderer = await page.evaluate(() => {
    try {
      const c = document.createElement("canvas");
      const gl = c.getContext("webgl2") || c.getContext("webgl");
      const ext = gl && gl.getExtension("WEBGL_debug_renderer_info");
      return ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : (gl ? "unknown" : "none");
    } catch (e) { return `error: ${e}`; }
  }).catch(() => "unavailable");

  // Settle: the canvas attaches while the boot is still churning (pck load,
  // biome discovery, first-scene build). The verdict is about STEADY STATE,
  // so give the boot a fixed grace period before sampling — boot cost is
  // already bounded separately by --boot-timeout.
  if (SETTLE_SECONDS > 0) await page.waitForTimeout(SETTLE_SECONDS * 1000);

  // Frame + responsiveness sample: rAF counter and a setTimeout ping race,
  // measured together on the real main thread.
  const sample = await page.evaluate(async (cfg) => {
    return await new Promise((resolveSample) => {
      let frames = 0;
      let worstPing = 0;
      let pings = 0;
      const t0 = performance.now();
      function onFrame() {
        frames += 1;
        if (performance.now() - t0 < cfg.seconds * 1000) requestAnimationFrame(onFrame);
      }
      requestAnimationFrame(onFrame);
      function ping() {
        const sent = performance.now();
        setTimeout(() => {
          worstPing = Math.max(worstPing, performance.now() - sent - 50);
          pings += 1;
          if (performance.now() - t0 < cfg.seconds * 1000) ping();
        }, 50);
      }
      ping();
      setTimeout(() => {
        const elapsed = (performance.now() - t0) / 1000;
        resolveSample({ fps: frames / elapsed, worst_ping_ms: worstPing, pings });
      }, cfg.seconds * 1000 + 100);
    });
  }, { seconds: SAMPLE_SECONDS });

  report.sample = sample;
  const fpsOk = check("fps_at_least", sample.fps >= MIN_FPS, `${sample.fps.toFixed(1)} fps (floor ${MIN_FPS})`);
  const pingOk = check("main_thread_responsive", sample.worst_ping_ms <= PING_BUDGET_MS,
    `worst timer overrun ${sample.worst_ping_ms.toFixed(0)}ms (budget ${PING_BUDGET_MS}ms)`);

  const fatal = report.console_errors.filter((e) => /abort|out of memory|failed to (instantiate|fetch)|RuntimeError/i.test(e));
  const errsOk = check("no_fatal_errors", fatal.length === 0, `${report.console_errors.length} console errors, ${fatal.length} fatal`);

  await browser.close();
  stopServer();

  if (fpsOk && pingOk && errsOk) {
    report.verdict = "PASS";
    writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2) + "\n");
    console.log(`\nPASS — report: ${REPORT_PATH}`);
    process.exit(0);
  }
  fail("one or more smoke checks failed (see report)");
} catch (err) {
  fail(`smoke crashed: ${err?.message || err}`);
}
