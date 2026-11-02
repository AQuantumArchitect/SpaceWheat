// Browser smoke test for the Web-Slim export.
//
// Usage: node smoke.mjs <dir-or-url> [--screenshot out.png] [--timeout-s 120] [--settle-s 10]
//   <dir>  a built export (build/web-slim); served on localhost with no
//          COOP/COEP headers, exactly like GitHub Pages.
//   <url>  an already-live site, e.g. https://aquantumarchitect.github.io/SpaceWheat/
//
// Fails (exit 1) on: page errors, console errors, failed requests for game
// files, a loader that never clears, or a canvas that never gets a size.
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const opt = (name, def) => { const i = args.indexOf(name); return i < 0 ? def : args.splice(i, 2)[1]; };
const shot = opt('--screenshot', null);
const timeoutMs = Number(opt('--timeout-s', 120)) * 1000;
const settleMs = Number(opt('--settle-s', 10)) * 1000;
const target = args[0];
if (!target) { console.error('usage: node smoke.mjs <dir-or-url> [options]'); process.exit(2); }

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json' };

function serve(root) {
  const server = http.createServer((req, res) => {
    let p = decodeURIComponent(req.url.split('?')[0]);
    if (p.endsWith('/')) p += 'index.html';
    const file = path.join(root, path.normalize(p));
    if (!file.startsWith(path.resolve(root)) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      res.writeHead(404); res.end('not found'); return;
    }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise(r => server.listen(0, '127.0.0.1', () => r(server)));
}

let server = null;
let url = target;
if (!/^https?:\/\//.test(target)) {
  server = await serve(path.resolve(target));
  url = `http://127.0.0.1:${server.address().port}/`;
}

const problems = [];
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await (await browser.newContext({ viewport: { width: 1280, height: 720 } })).newPage();
page.on('pageerror', e => problems.push(`pageerror: ${e.message}`));
// Godot's push_warning() reaches the browser as console.error ("WARNING: ..." plus
// an "   at:" line). Those are logged, not failed; real ERROR / SCRIPT ERROR lines fail.
const warnings = [];
page.on('console', m => {
  if (m.type() !== 'error') return;
  const t = m.text();
  if (/^\s*(WARNING:|at:)/.test(t)) warnings.push(t.split('\n')[0]);
  else problems.push(`console.error: ${t}`);
});
page.on('requestfailed', r => problems.push(`request failed: ${r.url()} (${r.failure()?.errorText})`));
page.on('response', r => { if (r.status() >= 400) problems.push(`HTTP ${r.status()}: ${r.url()}`); });

console.log(`loading ${url}`);
const t0 = Date.now();
try {
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForSelector('canvas#canvas', { timeout: 30000 });
  // The shell removes #status when the engine has started; a stuck loader leaves it.
  await page.waitForSelector('#status', { state: 'detached', timeout: timeoutMs });
  console.log(`loader cleared after ${((Date.now() - t0) / 1000).toFixed(1)}s`);
  await page.waitForTimeout(settleMs);
  const size = await page.evaluate(() => { const c = document.getElementById('canvas'); return [c.width, c.height]; });
  console.log(`canvas ${size[0]}x${size[1]}`);
  if (size[0] < 100 || size[1] < 100) problems.push(`canvas never sized (${size.join('x')})`);
  // Title card says "Click — or F — to play": do it, and make sure the game survives.
  await page.mouse.click(640, 360);
  await page.waitForTimeout(settleMs);
  if (shot) { await page.screenshot({ path: shot.replace(/(\.png)?$/, '-title$1') }).catch(() => {}); }
  await page.mouse.click(640, 360);
  await page.waitForTimeout(settleMs);
  const notice = await page.evaluate(() => document.getElementById('status-notice')?.textContent || '');
  if (notice.trim()) problems.push(`loader notice: ${notice.trim()}`);
} catch (e) {
  problems.push(`${e.name}: ${e.message.split('\n')[0]}`);
}
if (shot) { await page.screenshot({ path: shot }).catch(() => {}); console.log(`screenshot -> ${shot}`); }
await browser.close();
server?.close();

if (warnings.length) console.log(`${warnings.length} engine warning(s), not failing:\n  ` + [...new Set(warnings)].filter(w => w.startsWith('WARNING')).join('\n  '));
if (problems.length) {
  console.error(`FAIL (${problems.length}):`);
  for (const p of [...new Set(problems)]) console.error(`  - ${p}`);
  process.exit(1);
}
console.log('PASS');
