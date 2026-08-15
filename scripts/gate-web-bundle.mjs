// Release gate for the browser build. Loads a finished web export in a real
// browser TWICE and asserts what a player actually sees each time.
//
//   node scripts/gate-web-bundle.mjs <export-dir> [--chromium <path>] [--keep]
//
// Why two loads. `smoke-test-web-export.mjs` serves the bundle WITH COOP/COEP
// headers, so it can only ever observe the happy host. itch.io does not send
// those headers unless "SharedArrayBuffer support" is ticked, and 0.1.0-alpha
// shipped with it unticked: the engine never started and the stock Godot shell
// showed nothing at all — no error, no progress bar, a black tab forever. A
// gate that only tests the good case is blind to the case that shipped.
//
// So:
//   HEADERS PRESENT  -> the game must boot to a live canvas, and pressing the
//                       key the title card advertises must start a farm without
//                       aborting. (This catches an Emscripten/libc++ mismatch,
//                       which loads fine and dies at the first call into a stub.)
//   HEADERS ABSENT   -> the game cannot run, and that is allowed — but the page
//                       must SAY SO. A visible notice is a pass; a silent black
//                       screen is a failure.
//
// Exit code 0 = both cases behaved. Non-zero = do not ship.

import { chromium } from 'playwright-core';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
// Resolve once: the traversal guard below compares against this, and a relative
// ROOT would make every request look like an escape attempt and 404.
const ROOT = args.find((a) => !a.startsWith('--')) && path.resolve(args.find((a) => !a.startsWith('--')));
const CHROMIUM = args.includes('--chromium')
  ? args[args.indexOf('--chromium') + 1]
  : process.env.SW_CHROMIUM;
const KEEP = args.includes('--keep');

if (!ROOT || !fs.existsSync(path.join(ROOT, 'index.html'))) {
  console.error('usage: gate-web-bundle.mjs <export-dir containing index.html>');
  process.exit(2);
}

const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
  '.json': 'application/json', '.png': 'image/png', '.pck': 'application/octet-stream',
};

function serve(port, withHeaders) {
  const server = http.createServer((req, res) => {
    const rel = decodeURIComponent(req.url.split('?')[0]).replace(/^\/+/, '') || 'index.html';
    const file = path.join(ROOT, rel);
    if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      res.writeHead(404).end();
      return;
    }
    const headers = { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' };
    if (withHeaders) {
      headers['Cross-Origin-Opener-Policy'] = 'same-origin';
      headers['Cross-Origin-Embedder-Policy'] = 'require-corp';
      headers['Cross-Origin-Resource-Policy'] = 'cross-origin';
    }
    res.writeHead(200, headers);
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => server.listen(port, '127.0.0.1', () => resolve(server)));
}

const launch = () => chromium.launch({
  headless: true,
  ...(CHROMIUM ? { executablePath: CHROMIUM } : {}),
  args: ['--enable-unsafe-swiftshader', '--use-gl=swiftshader', '--no-sandbox'],
});

const failures = [];
const note = (ok, label, detail) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? ' — ' + detail : ''}`);
  if (!ok) failures.push(label);
};

async function waitForBoot(page, seconds) {
  for (let i = 0; i < seconds; i++) {
    if (await page.evaluate(() => !document.getElementById('status'))) return true;
    await page.waitForTimeout(1000);
  }
  return false;
}

// ---- Case 1: isolation headers present. The game must run, and must survive
// starting an actual farm.
async function caseWithHeaders() {
  const server = await serve(8791, true);
  const browser = await launch();
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 720 } })).newPage();
  let abort = null;
  const watch = (t) => {
    if (/Aborted|undefined symbol|RuntimeError/i.test(t)) abort = abort || t;
  };
  page.on('console', (m) => watch(m.text()));
  page.on('pageerror', (e) => watch(String(e)));

  try {
    await page.goto('http://127.0.0.1:8791/index.html', { waitUntil: 'domcontentloaded', timeout: 60000 });
    const booted = await waitForBoot(page, 180);
    note(booted, 'headers present: engine reaches a live canvas',
      booted ? 'loading overlay removed' : 'still showing the loader after 180s');
    if (!booted) return;

    const size = await page.evaluate(() => {
      const c = document.getElementById('canvas');
      return c ? `${c.width}x${c.height}` : 'none';
    });
    note(size !== 'none' && size !== '300x150', 'headers present: canvas is sized', size);

    // Start a real game. An Emscripten mismatch survives boot and dies here.
    await page.waitForTimeout(4000);
    await (await page.$('#canvas')).click({ position: { x: 640, y: 360 } });
    await page.keyboard.press('F');
    await page.waitForTimeout(12000);
    note(!abort, 'headers present: starting a farm does not abort',
      abort ? abort.slice(0, 200) : 'no abort in 12s after F');
  } finally {
    await browser.close();
    server.close();
  }
}

// ---- Case 2: no isolation headers. Running is impossible; staying silent is
// the bug.
async function caseWithoutHeaders() {
  const server = await serve(8792, false);
  const browser = await launch();
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 720 } })).newPage();
  try {
    await page.goto('http://127.0.0.1:8792/index.html', { waitUntil: 'domcontentloaded', timeout: 60000 });
    // Allow the shell its one service-worker retry plus the reload.
    await page.waitForTimeout(25000);
    const state = await page.evaluate(() => {
      const s = document.getElementById('status');
      const n = document.getElementById('status-notice');
      return {
        isolated: self.crossOriginIsolated,
        gone: !s,
        visible: s ? getComputedStyle(s).visibility : 'removed',
        noticeShown: n ? getComputedStyle(n).display !== 'none' : false,
        text: n ? n.innerText.trim() : '',
      };
    });

    if (state.gone || state.isolated) {
      note(true, 'no headers: engine started anyway', 'nothing to explain');
      return;
    }
    const speaks = state.visible === 'visible' && state.noticeShown && state.text.length > 0;
    note(speaks, 'no headers: the page explains itself instead of going black',
      speaks ? JSON.stringify(state.text.split('\n')[0]) : `overlay ${state.visible}, notice "${state.text}"`);
    if (speaks) {
      const useful = /SharedArrayBuffer|cross-origin/i.test(state.text);
      note(useful, 'no headers: the message names the actual cause');
    }
  } finally {
    await browser.close();
    server.close();
  }
}

await caseWithHeaders();
await caseWithoutHeaders();

console.log('');
if (failures.length) {
  console.error(`web gate FAILED (${failures.length}): ${failures.join('; ')}`);
  process.exit(1);
}
console.log('web gate passed: boots and plays when isolated, speaks when it cannot.');
if (!KEEP) process.exit(0);
