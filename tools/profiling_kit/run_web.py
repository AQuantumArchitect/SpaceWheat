#!/usr/bin/env python3
"""Measure the browser build's frame rate on real hardware GL. Windows-native.

    py -3 run_web.py                 # default: 15s settle, 30s sample
    py -3 run_web.py --seconds 60
    py -3 run_web.py --browser "C:\\Path\\To\\chrome.exe"

Standard library only. There is no node, no npm, no playwright here on purpose:
the repo's own web smoke (`scripts/smoke-test-web-export.mjs`) needs
`playwright-core` from a WSL-side node_modules and shells out to `python3`,
which does not exist on Windows. Python 3 does.

WHY THIS EXISTS AT ALL — the number it replaces is wrong in a specific way.
The only web frame rate ever recorded for SpaceWheat is 9.5 fps, and the run
that produced it names its own renderer as SwiftShader: Chromium's software
rasteriser. A headless Chromium falls back to it by default, so the existing
smoke lane cannot measure a GPU no matter which machine it runs on. This script
launches a HEADED browser, and refuses to report a verdict unless the page says
it is talking to real hardware.

HOW IT MEASURES. A tiny script is injected into index.html on the way out of the
local server, so the page counts its own requestAnimationFrame callbacks and
posts the result back. That is the frame rate a player sees — the browser's
presented frames — not an engine counter, and not something inferred from
outside the tab.

THE FOUR TRAPS IT GUARDS AGAINST, each of which produces a confident wrong number:
  1. Software rendering. Reported as `webgl_renderer`, and `trustworthy` is
     false when it looks like SwiftShader/llvmpipe/WARP.
  2. Background throttling. Chromium drops an occluded or unfocused tab to
     ~1 rAF/sec. Launched with the throttling features disabled, and the report
     carries `document_hidden` and `had_focus` so a throttled sample is visible
     rather than mysterious.
  3. A service worker serving a cached, un-injected page. The server stamps a
     nonce into the injected script; if the nonce does not come back, the run is
     rejected instead of reported.
  4. Boot churn counted as steady state. The pck alone is 183 MB — the first
     seconds are loading, not playing. Settle is separate, and its own frame
     rate is reported next to the steady-state one.
"""

from __future__ import annotations

import argparse
import http.server
import json
import os
import platform
import re
import shutil
import socketserver
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_BUNDLE = HERE / "web"
DEFAULT_RESULTS = HERE / "results"

SOFTWARE_MARKERS = (
    "swiftshader", "llvmpipe", "lavapipe", "softpipe", "software",
    "basic render", "(warp)", "microsoft basic",
)

WINDOWS_BROWSERS = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
]

# Linux entries exist so this script can be exercised end-to-end before it is
# handed over. A Linux run here lands on llvmpipe and will correctly report
# itself untrustworthy — which is the behaviour worth rehearsing.
LINUX_BROWSERS = [
    "/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser",
]


# ---------------------------------------------------------------------------
# The page-side probe
# ---------------------------------------------------------------------------

PROBE = r"""
<script>
(function () {
  var CFG = __CFG__;
  function post(body) {
    body.nonce = CFG.nonce;
    return fetch("/__perf", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(body),
    }).catch(function () {});
  }
  // Ask the ENGINE'S OWN canvas which GPU it is talking to. getContext returns
  // the context that already exists rather than making a new one, so this is
  // the renderer actually drawing the game — and it does not spend a second
  // WebGL context, which is how the first version of this function came back
  // "none" on a machine that was rendering fine.
  function gpu(canvas) {
    try {
      var gl = null;
      if (canvas) gl = canvas.getContext("webgl2") || canvas.getContext("webgl");
      var borrowed = !!gl;
      if (!gl) {
        var c = document.createElement("canvas");
        gl = c.getContext("webgl2") || c.getContext("webgl");
      }
      if (!gl) return {renderer: "none", vendor: "none", from_engine_canvas: false};
      var ext = gl.getExtension("WEBGL_debug_renderer_info");
      return {
        renderer: ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : "masked",
        vendor: ext ? gl.getParameter(ext.UNMASKED_VENDOR_WEBGL) : "masked",
        version: gl.getParameter(gl.VERSION),
        from_engine_canvas: borrowed,
      };
    } catch (e) { return {renderer: "error: " + e, vendor: "?", from_engine_canvas: false}; }
  }
  // Count rAF callbacks and, in the same window, watch how late a 50ms timer
  // lands. A high frame rate with a stalled timer means the main thread is
  // being held by something — that pair says more than either number alone.
  function sample(seconds) {
    return new Promise(function (done) {
      var frames = 0, worstPing = 0, t0 = performance.now(), stamps = [];
      (function frame() {
        frames += 1;
        stamps.push(performance.now());
        if (performance.now() - t0 < seconds * 1000) requestAnimationFrame(frame);
      })();
      (function ping() {
        var sent = performance.now();
        setTimeout(function () {
          worstPing = Math.max(worstPing, performance.now() - sent - 50);
          if (performance.now() - t0 < seconds * 1000) ping();
        }, 50);
      })();
      setTimeout(function () {
        var elapsed = (performance.now() - t0) / 1000;
        var gaps = [];
        for (var i = 1; i < stamps.length; i++) gaps.push(stamps[i] - stamps[i - 1]);
        gaps.sort(function (a, b) { return a - b; });
        function pct(q) {
          if (!gaps.length) return 0;
          return gaps[Math.min(gaps.length - 1, Math.round(q * (gaps.length - 1)))];
        }
        done({
          seconds: elapsed,
          frames: frames,
          fps_mean: frames / elapsed,
          frame_ms_p50: pct(0.50),
          frame_ms_p95: pct(0.95),
          frame_ms_p99: pct(0.99),
          frame_ms_max: gaps.length ? gaps[gaps.length - 1] : 0,
          worst_timer_overrun_ms: worstPing,
        });
      }, seconds * 1000 + 120);
    });
  }
  var errors = [];
  window.addEventListener("error", function (e) { errors.push(String(e.message).slice(0, 300)); });
  window.addEventListener("unhandledrejection", function (e) { errors.push("rejection: " + String(e.reason).slice(0, 300)); });

  // Godot routes the game's own print() to console.log, so hooking it here —
  // this script is injected into <head>, before the engine loads — turns the
  // engine's boot banner into a usable signal. The canvas alone is not one:
  // index.html ships a placeholder <canvas id="canvas"> and the engine only
  // resizes it (canvasResizePolicy 2) once it is actually running, which on a
  // software rasteriser can be minutes after the page is "loaded".
  var logLines = [];
  var BOOT_RE = /native acceleration enabled|SpaceWheat v|Godot Engine v/i;
  var sawBootLine = false;
  ["log", "info", "warn", "error"].forEach(function (level) {
    var original = console[level].bind(console);
    console[level] = function () {
      try {
        var text = Array.prototype.map.call(arguments, String).join(" ");
        if (logLines.length < 400) logLines.push(level + ": " + text.slice(0, 300));
        if (BOOT_RE.test(text)) sawBootLine = true;
      } catch (e) { /* never let instrumentation break the page */ }
      return original.apply(null, arguments);
    };
  });

  var hiddenAtAnyPoint = document.hidden;
  document.addEventListener("visibilitychange", function () {
    if (document.hidden) hiddenAtAnyPoint = true;
  });

  (async function () {
    var bootStart = performance.now();
    var deadline = bootStart + CFG.boot_timeout * 1000;
    // "A canvas exists" is NOT "the engine started". index.html ships a
    // placeholder <canvas id="canvas"> at the HTML default of 300x150; the
    // first version of this script accepted it instantly, declared boot
    // complete in 0.0s, and then measured a page that was still downloading a
    // 183 MB pack. Two independent signals now, whichever arrives first:
    // the engine's own boot banner on the console, or the canvas being resized
    // to the viewport (GODOT_CONFIG.canvasResizePolicy = 2).
    var canvas = null, bootSignal = null;
    while (performance.now() < deadline) {
      var c = document.querySelector("canvas");
      var resized = c && (c.width > 300 || c.height > 150);
      if (globalThis.crossOriginIsolated === true && (resized || (sawBootLine && c))) {
        canvas = c;
        bootSignal = resized ? "canvas_resized" : "engine_console_banner";
        break;
      }
      await new Promise(function (r) { setTimeout(r, 250); });
    }
    if (!canvas) {
      var last = document.querySelector("canvas");
      await post({ok: false, failed: "the engine never started within " + CFG.boot_timeout +
        "s (canvas " + (last ? last.width + "x" + last.height : "absent") +
        ", boot banner " + (sawBootLine ? "seen" : "not seen") + ")",
        cross_origin_isolated: globalThis.crossOriginIsolated === true,
        console_errors: errors, console_tail: logLines.slice(-40)});
      return;
    }
    var bootSeconds = (performance.now() - bootStart) / 1000;
    // The settle window is measured too — a build whose first ten seconds are
    // a slideshow is a real problem even if steady state is fine.
    var settle = await sample(CFG.settle);
    var steady = await sample(CFG.seconds);
    await post({
      ok: true,
      cross_origin_isolated: globalThis.crossOriginIsolated === true,
      shared_array_buffer: typeof SharedArrayBuffer !== "undefined",
      hardware_concurrency: navigator.hardwareConcurrency || null,
      device_memory_gb: navigator.deviceMemory || null,
      user_agent: navigator.userAgent,
      canvas: {width: canvas.width, height: canvas.height},
      gpu: gpu(canvas),
      boot_seconds: bootSeconds,
      boot_signal: bootSignal,
      console_tail: logLines.slice(-60),
      settle: settle,
      steady_state: steady,
      document_hidden: document.hidden,
      hidden_at_any_point: hiddenAtAnyPoint,
      had_focus: document.hasFocus(),
      console_errors: errors,
    });
  })();
})();
</script>
"""


# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

class Result:
    def __init__(self) -> None:
        self.payload: dict | None = None
        self.ready = threading.Event()


def make_handler(bundle: Path, cfg: dict, result: Result):
    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **kw):
            super().__init__(*a, directory=str(bundle), **kw)

        def log_message(self, fmt, *args):  # quiet; the run prints its own story
            pass

        def end_headers(self):
            # SharedArrayBuffer — and therefore Godot's threaded WASM — is gated
            # behind cross-origin isolation. itch.io grants these too when the
            # project has "SharedArrayBuffer support" enabled; without them the
            # engine will not start and the failure looks like a perf problem.
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
            self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
            self.send_header("Cache-Control", "no-store")
            super().end_headers()

        def do_POST(self):
            if self.path != "/__perf":
                self.send_error(404)
                return
            length = int(self.headers.get("Content-Length", "0"))
            try:
                body = json.loads(self.rfile.read(length).decode("utf-8"))
            except (ValueError, UnicodeDecodeError) as exc:
                self.send_error(400, str(exc))
                return
            self.send_response(204)
            self.end_headers()
            if body.get("nonce") == cfg["nonce"] and result.payload is None:
                result.payload = body
                result.ready.set()

        def do_GET(self):
            if self.path.split("?")[0] in ("/", "/index.html"):
                self._serve_injected()
                return
            super().do_GET()

        def _serve_injected(self):
            html = (bundle / "index.html").read_text(encoding="utf-8")
            probe = PROBE.replace("__CFG__", json.dumps(cfg))
            # Into <head>, not before </body>: the probe hooks console.log to
            # catch the engine's boot banner, and a hook installed after the
            # engine's own <script> would miss it.
            if "<head>" in html:
                html = html.replace("<head>", "<head>\n" + probe, 1)
            elif "</body>" in html:
                html = html.replace("</body>", probe + "\n</body>", 1)
            else:
                html = probe + html
            raw = html.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

    return Handler


class ThreadedServer(socketserver.ThreadingTCPServer):
    # Threaded on purpose. index.pck is 183 MB and index.side.wasm is another
    # 40 MB; a single-threaded server serialises them behind each other and the
    # resulting slow boot reads exactly like a slow game.
    allow_reuse_address = True
    daemon_threads = True


# ---------------------------------------------------------------------------
# Browser
# ---------------------------------------------------------------------------

def find_browser(explicit: str | None) -> str:
    explicit = explicit or os.environ.get("SW_BROWSER") or None
    if explicit:
        if not Path(explicit).exists():
            sys.exit(f"no browser at {explicit}")
        return explicit
    candidates = WINDOWS_BROWSERS if os.name == "nt" else LINUX_BROWSERS
    for candidate in candidates:
        if Path(candidate).exists():
            return candidate
    found = shutil.which("google-chrome") or shutil.which("chromium")
    if found:
        return found
    sys.exit(
        "found no Chrome or Edge in the usual places. Pass --browser "
        r'"C:\Path\To\chrome.exe".'
    )


def launch(browser: str, url: str, profile_dir: Path) -> subprocess.Popen:
    args = [
        browser,
        f"--user-data-dir={profile_dir}",
        "--no-first-run",
        "--no-default-browser-check",
        "--new-window",
        "--window-size=1280,860",
        "--window-position=0,0",
        "--autoplay-policy=no-user-gesture-required",
        # Without these, Chromium throttles an unfocused or occluded tab to
        # roughly one frame per second, and the run reports ~1 fps for a game
        # that is fine. This is the single easiest way to measure a wrong number.
        "--disable-background-timer-throttling",
        "--disable-backgrounding-occluded-windows",
        "--disable-renderer-backgrounding",
        "--disable-features=CalculateNativeWinOcclusion",
        url,
    ]
    return subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# ---------------------------------------------------------------------------

def verdict(payload: dict) -> tuple[bool, list[str]]:
    caveats: list[str] = []
    gpu = (payload.get("gpu") or {})
    renderer = str(gpu.get("renderer", "")).lower()
    software = any(m in renderer for m in SOFTWARE_MARKERS)
    if software:
        caveats.append(
            f"renderer {gpu.get('renderer')!r} is a software rasteriser — this run "
            "cannot judge an fps floor, which is exactly the flaw in the 9.5 fps "
            "number it was meant to replace"
        )
    if renderer in ("masked", "none", ""):
        caveats.append(
            f"renderer reported as {gpu.get('renderer')!r} — cannot confirm hardware GL"
        )
        software = True
    if payload.get("hidden_at_any_point"):
        caveats.append("the tab was hidden at some point — frames may have been throttled")
    if not payload.get("had_focus"):
        caveats.append("the window did not have focus at the end of the run")
    if not payload.get("cross_origin_isolated"):
        caveats.append("not cross-origin isolated — the threaded engine cannot run properly")
    steady = payload.get("steady_state") or {}
    if steady.get("frames", 0) < 60:
        caveats.append(f"only {steady.get('frames', 0)} frames sampled — too few for a percentile")
    fatal = [e for e in payload.get("console_errors", [])
             if re.search(r"abort|out of memory|failed to (instantiate|fetch)|RuntimeError", e, re.I)]
    if fatal:
        caveats.append(f"{len(fatal)} fatal console errors: {fatal[:2]}")
    return (not software and payload.get("cross_origin_isolated", False)), caveats


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bundle", default=str(DEFAULT_BUNDLE), help="unzipped web export dir")
    ap.add_argument("--results", default=str(DEFAULT_RESULTS))
    ap.add_argument("--label", default="web")
    ap.add_argument("--seconds", type=float, default=30.0, help="steady-state sample window")
    ap.add_argument("--settle", type=float, default=15.0, help="post-boot grace, measured separately")
    ap.add_argument("--boot-timeout", type=float, default=180.0)
    ap.add_argument("--port", type=int, default=8043)
    ap.add_argument("--browser", default=None)
    ap.add_argument("--keep-open", action="store_true", help="leave the browser up after the run")
    args = ap.parse_args()

    bundle = Path(args.bundle).resolve()
    entry = bundle / "index.html"
    if not entry.exists():
        sys.exit(f"no index.html in {bundle} — unzip spacewheat-web-*.zip in there first")
    if str(bundle).startswith("\\\\wsl"):
        sys.exit(
            "the bundle is on a \\\\wsl$ path. 183 MB of pck across the 9p bridge will "
            "look like a performance problem and will not be one. Copy it to a local "
            "NTFS folder first."
        )

    results_dir = Path(args.results).resolve()
    results_dir.mkdir(parents=True, exist_ok=True)

    cfg = {
        "nonce": os.urandom(8).hex(),
        "seconds": args.seconds,
        "settle": args.settle,
        "boot_timeout": args.boot_timeout,
    }
    result = Result()
    server = ThreadedServer(("127.0.0.1", args.port), make_handler(bundle, cfg, result))
    threading.Thread(target=server.serve_forever, daemon=True).start()

    url = f"http://127.0.0.1:{args.port}/index.html"
    browser = find_browser(args.browser)
    profile_dir = Path(tempfile.mkdtemp(prefix="sw-profile-"))

    print(f"bundle   {bundle}")
    print(f"serving  {url}  (COOP/COEP, threaded)")
    print(f"browser  {browser}")
    print(f"window   boot<={args.boot_timeout:.0f}s, settle {args.settle:.0f}s, sample {args.seconds:.0f}s")
    print("\nA browser window will open. LEAVE IT IN FRONT and do not click away —")
    print("a background tab is throttled and the number would be meaningless.\n")

    proc = launch(browser, url, profile_dir)
    budget = args.boot_timeout + args.settle + args.seconds + 60
    started = time.time()
    try:
        while not result.ready.wait(timeout=2.0):
            if time.time() - started > budget:
                print(f"FAIL: no result within {budget:.0f}s — the page never reported back")
                return 2
            if proc.poll() is not None and not result.ready.is_set():
                # Chrome forks and the launcher exits immediately; only treat a
                # dead process as fatal once the whole budget is gone.
                pass
    finally:
        if not args.keep_open:
            proc.terminate()
            if os.name == "nt":
                # Chrome re-parents its own children; terminate() alone leaves
                # the window up and the next run's port already claimed.
                subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                               check=False)
        server.shutdown()
        shutil.rmtree(profile_dir, ignore_errors=True)

    payload = result.payload or {}
    if not payload.get("ok"):
        print(f"FAIL: {payload.get('failed', 'the page reported a failure')}")
        out = results_dir / f"{args.label}-FAILED.json"
        out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(f"wrote {out}")
        return 2

    trustworthy, caveats = verdict(payload)
    report = {
        "schema": "spacewheat.perf.web/1",
        "label": args.label,
        "bundle": str(bundle),
        "host": {
            "machine": platform.machine(),
            "processor": platform.processor(),
            "release": platform.platform(),
        },
        "trustworthy": trustworthy,
        "caveats": caveats,
        **payload,
    }
    out = results_dir / f"{args.label}.json"
    out.write_text(json.dumps(report, indent=2), encoding="utf-8")

    s = report["steady_state"]
    st = report["settle"]
    print("=" * 64)
    print(f"  renderer     {report['gpu'].get('renderer')}")
    print(f"  vendor       {report['gpu'].get('vendor')}")
    print(f"  canvas       {report['canvas']['width']}x{report['canvas']['height']}")
    print(f"  boot         {report['boot_seconds']:.1f}s to first live canvas")
    print(f"  settle fps   {st['fps_mean']:.1f} mean  (first {args.settle:.0f}s after boot)")
    print(f"  STEADY fps   {s['fps_mean']:.1f} mean   p50 frame {s['frame_ms_p50']:.1f}ms"
          f"   p95 {s['frame_ms_p95']:.1f}ms   worst {s['frame_ms_max']:.0f}ms")
    print(f"  timer stall  {s['worst_timer_overrun_ms']:.0f}ms worst")
    print(f"  trustworthy  {trustworthy}")
    for c in caveats:
        print(f"    ! {c}")
    print("=" * 64)
    print(f"wrote {out}")
    return 0 if trustworthy else 1


if __name__ == "__main__":
    sys.exit(main())
