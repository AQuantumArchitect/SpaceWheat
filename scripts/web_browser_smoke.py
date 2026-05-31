#!/usr/bin/env python3
"""Browser smoke test for a SpaceWheat web export.

Starts the local header-aware server, checks first-load headers, then tries to
launch a Chromium-family browser headlessly to capture DOM and a screenshot.
"""

from __future__ import annotations

import argparse
import json
import html
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request


WINDOWS_BROWSER_CANDIDATES = {
    "edge": [
        pathlib.Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
        pathlib.Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"),
    ],
    "chrome": [
        pathlib.Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
        pathlib.Path(r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"),
    ],
}

SMOKE_REPORT_START = "SPACEWHEAT_SMOKE_REPORT_BEGIN"
SMOKE_REPORT_END = "SPACEWHEAT_SMOKE_REPORT_END"


def json_default(value: object) -> object:
    if isinstance(value, bytes):
        try:
            return value.decode("utf-8")
        except UnicodeDecodeError:
            return value.hex()
    if isinstance(value, pathlib.Path):
        return str(value)
    raise TypeError(f"Object of type {type(value).__name__} is not JSON serializable")


def build_instrumented_html(html_text: str, emscripten_pool_size: int | None = None) -> str:
    hook_script = r"""
<script>
(function () {
  const state = {
    console_error: [],
    console_warn: [],
    console_log: [],
    worker_messages: [],
    window_errors: [],
    unhandled_rejections: [],
    status_updates: [],
    run_dependencies: [],
    aborts: [],
    timestamps_ms: { start: Date.now() }
  };
  function trim(value) {
    const text = String(value);
    return text.length > 700 ? text.slice(0, 700) + "...<truncated>" : text;
  }
  function serialize(args) {
    return Array.from(args).map((item) => {
      if (item instanceof Error) {
        return trim(item.stack || item.message || item.toString());
      }
      if (typeof item === "object" && item !== null) {
        try {
          return trim(JSON.stringify(item));
        } catch (_err) {
          return trim(String(item));
        }
      }
      return trim(String(item));
    });
  }
  function push(bucket, payload) {
    if (!state[bucket]) return;
    state[bucket].push(payload);
    if (state[bucket].length > 50) {
      state[bucket] = state[bucket].slice(-50);
    }
    publish();
  }
  function publish() {
    let node = document.getElementById("sw-smoke-report");
    if (!node) {
      node = document.createElement("pre");
      node.id = "sw-smoke-report";
      node.style.display = "none";
      document.body.appendChild(node);
    }
    node.textContent = "%s\n" + JSON.stringify(state) + "\n%s";
  }
  window.__spacewheatSmoke = state;
  window.__swSmoke_applyConfig = function (cfg) {
    const prevPrint = cfg.onPrint;
    const prevPrintErr = cfg.onPrintError;
    const prevStatus = cfg.onProgress;
    cfg.onPrint = function () {
      push("console_log", serialize(arguments));
      if (typeof prevPrint === "function") prevPrint.apply(this, arguments);
    };
    cfg.onPrintError = function () {
      const parts = serialize(arguments);
      push("console_error", parts);
      for (let i = 0; i < parts.length; i++) {
        const part = parts[i];
        if (part.includes("dependency:")) {
          push("run_dependencies", part);
        }
      }
      if (typeof prevPrintErr === "function") prevPrintErr.apply(this, arguments);
    };
    cfg.monitorRunDependencies = function (count) {
      push("run_dependencies", "count=" + count);
    };
    cfg.onAbort = function (reason) {
      push("aborts", trim(reason));
    };
  };
  const origError = console.error.bind(console);
  const origWarn = console.warn.bind(console);
  const origLog = console.log.bind(console);
  console.error = function () {
    push("console_error", serialize(arguments));
    origError.apply(console, arguments);
  };
  console.warn = function () {
    push("console_warn", serialize(arguments));
    origWarn.apply(console, arguments);
  };
  console.log = function () {
    push("console_log", serialize(arguments));
    origLog.apply(console, arguments);
  };
  window.addEventListener("error", function (event) {
    push("window_errors", {
      message: trim(event.message || ""),
      source: trim(event.filename || ""),
      lineno: event.lineno || 0,
      colno: event.colno || 0
    });
  });
  window.addEventListener("unhandledrejection", function (event) {
    const reason = event.reason;
    if (reason instanceof Error) {
      push("unhandled_rejections", trim(reason.stack || reason.message || reason.toString()));
    } else {
      push("unhandled_rejections", trim(reason));
    }
  });
  const OrigWorker = window.Worker;
  if (typeof OrigWorker === "function") {
  window.Worker = function (spec, options) {
      push("console_warn", ["[sw-smoke] Worker ctor", trim(spec), trim(options ? JSON.stringify(options) : "")]);
      const worker = new OrigWorker(spec, options);
      worker.addEventListener("message", function (event) {
        const data = event && event.data;
        let payload = "";
        try {
          payload = typeof data === "string" ? data : JSON.stringify(data);
        } catch (_err) {
          payload = String(data);
        }
        push("worker_messages", trim(payload));
      });
      worker.addEventListener("error", function (event) {
        push("window_errors", {
          message: trim(event.message || ""),
          source: trim(event.filename || spec || ""),
          lineno: event.lineno || 0,
          colno: event.colno || 0
        });
      });
      worker.addEventListener("messageerror", function (event) {
        push("console_error", ["[sw-smoke] worker messageerror", trim(spec), trim(event && event.message ? event.message : "")]);
      });
      return worker;
    };
    window.Worker.prototype = OrigWorker.prototype;
  }
  push("console_log", [
    "[sw-smoke] env",
    "crossOriginIsolated=" + String(window.crossOriginIsolated),
    "sharedArrayBuffer=" + String(typeof SharedArrayBuffer === "function"),
    "hardwareConcurrency=" + String(navigator.hardwareConcurrency || "")
  ]);
  window.setInterval(function () {
    const status = document.getElementById("status-notice");
    if (status && status.textContent && status.textContent.trim()) {
      push("status_updates", trim(status.textContent.trim()));
    }
  }, 250);
  publish();
})();
</script>
""" % (SMOKE_REPORT_START, SMOKE_REPORT_END)

    instrumented = html_text.replace(
        '<script src="index.js"></script>',
        '<script src="index.smoke.js"></script>\n' + hook_script,
        1,
    )
    engine_stmt = "const engine = new Engine(GODOT_CONFIG);"
    engine_init = "window.__swSmoke_applyConfig?.(GODOT_CONFIG);\n"
    if emscripten_pool_size is not None:
        engine_init += f"GODOT_CONFIG.emscriptenPoolSize = {emscripten_pool_size};\n"
    engine_init += engine_stmt
    instrumented = instrumented.replace(engine_stmt, engine_init, 1)
    return instrumented


def create_smoke_html(export_dir: pathlib.Path, emscripten_pool_size: int | None = None) -> pathlib.Path:
    source = export_dir / "index.html"
    target = export_dir / "index.smoke.html"
    target.write_text(build_instrumented_html(source.read_text(), emscripten_pool_size), encoding="utf-8")
    return target


def build_instrumented_js(js_text: str) -> str:
    worker_hook = r"""
(function () {
  const isWorker = typeof WorkerGlobalScope !== "undefined" && self instanceof WorkerGlobalScope;
  if (!isWorker) return;
  const workerTag = self.name || "em-worker";
  const origWarn = console.warn.bind(console);
  const origError = console.error.bind(console);
  const origLog = console.log.bind(console);
  function forward(kind, args) {
    try {
      postMessage({
        __swSmokeWorker: true,
        kind: kind,
        workerTag: workerTag,
        args: Array.from(args).map((item) => {
          try {
            return typeof item === "object" && item !== null ? JSON.stringify(item) : String(item);
          } catch (_err) {
            return String(item);
          }
        })
      });
    } catch (_err) {}
  }
  forward("boot", ["crossOriginIsolated=" + String(self.crossOriginIsolated), "sharedArrayBuffer=" + String(typeof SharedArrayBuffer === "function")]);
  console.warn = function () {
    forward("warn", arguments);
    return origWarn.apply(console, arguments);
  };
  console.error = function () {
    forward("error", arguments);
    return origError.apply(console, arguments);
  };
  console.log = function () {
    forward("log", arguments);
    return origLog.apply(console, arguments);
  };
  self.addEventListener("error", function (event) {
    forward("uncaught", [
      event && event.message ? event.message : "",
      event && event.filename ? event.filename : "",
      event && event.lineno ? String(event.lineno) : "",
      event && event.colno ? String(event.colno) : ""
    ]);
  });
})();
"""
    replacements = [
        (
            "function loadDynamicLibrary(libName,flags={global:true,nodelete:true},localScope,handle){",
            "function loadDynamicLibrary(libName,flags={global:true,nodelete:true},localScope,handle){console.warn('[sw-smoke] loadDynamicLibrary start',libName,JSON.stringify(flags));",
        ),
        (
            "if(flags.loadAsync){return loadLibData().then(libData=>loadWebAssemblyModule(libData,flags,libName,localScope,handle))}",
            "if(flags.loadAsync){return loadLibData().then(libData=>{console.warn('[sw-smoke] loadLibData resolved',libName,'bytes='+libData.length);return loadWebAssemblyModule(libData,flags,libName,localScope,handle)},error=>{console.error('[sw-smoke] loadLibData rejected',libName,error&&error.stack?error.stack:error);throw error})}",
        ),
        (
            "if(flags.loadAsync){return getExports().then(exports=>{moduleLoaded(exports);return true})}",
            "if(flags.loadAsync){return getExports().then(exports=>{console.warn('[sw-smoke] getExports resolved',libName);moduleLoaded(exports);console.warn('[sw-smoke] moduleLoaded',libName);return true},error=>{console.error('[sw-smoke] getExports rejected',libName,error&&error.stack?error.stack:error);throw error})}",
        ),
        (
            'var loadDylibs=()=>{if(!dynamicLibraries.length){reportUndefinedSymbols();return}addRunDependency("loadDylibs");dynamicLibraries.reduce((chain,lib)=>chain.then(()=>loadDynamicLibrary(lib,{loadAsync:true,global:true,nodelete:true,allowUndefined:true})),Promise.resolve()).then(()=>{reportUndefinedSymbols();removeRunDependency("loadDylibs")})};',
            'var loadDylibs=()=>{console.warn("[sw-smoke] dynamicLibraries",JSON.stringify(dynamicLibraries));if(!dynamicLibraries.length){reportUndefinedSymbols();return}addRunDependency("loadDylibs");dynamicLibraries.reduce((chain,lib)=>chain.then(()=>{console.warn("[sw-smoke] loading dylib",lib);return loadDynamicLibrary(lib,{loadAsync:true,global:true,nodelete:true,allowUndefined:true})}),Promise.resolve()).then(()=>{console.warn("[sw-smoke] loadDylibs resolved");reportUndefinedSymbols();removeRunDependency("loadDylibs")}).catch(error=>{console.error("[sw-smoke] loadDylibs rejected",error&&error.stack?error.stack:error);removeRunDependency("loadDylibs");throw error})};',
        ),
        (
            "function postInstantiation(module,instance){",
            "function postInstantiation(module,instance){console.warn('[sw-smoke] postInstantiation start',libName);",
        ),
        (
            "moduleExports=relocateExports(instance.exports,memoryBase);",
            "moduleExports=relocateExports(instance.exports,memoryBase);console.warn('[sw-smoke] relocateExports done',libName,Object.keys(moduleExports).length);",
        ),
        (
            "if(!flags.allowUndefined){reportUndefinedSymbols()}",
            "if(!flags.allowUndefined){console.warn('[sw-smoke] reportUndefinedSymbols start',libName);reportUndefinedSymbols();console.warn('[sw-smoke] reportUndefinedSymbols done',libName)}",
        ),
        (
            'if(flags.loadAsync){return(async()=>{var instance;if(binary instanceof WebAssembly.Module){instance=new WebAssembly.Instance(binary,info)}else{({module:binary,instance}=await WebAssembly.instantiate(binary,info))}return postInstantiation(binary,instance)})()}',
            'if(flags.loadAsync){return(async()=>{console.warn("[sw-smoke] async instantiate start",libName);var instance;if(binary instanceof WebAssembly.Module){instance=new WebAssembly.Instance(binary,info);console.warn("[sw-smoke] instantiate from module done",libName)}else{({module:binary,instance}=await WebAssembly.instantiate(binary,info));console.warn("[sw-smoke] instantiate raw binary done",libName)}return postInstantiation(binary,instance)})()}',
        ),
        (
            "return moduleExports}",
            "console.warn('[sw-smoke] postInstantiation done',libName);return moduleExports}",
        ),
    ]
    instrumented = worker_hook + js_text
    for old, new in replacements:
        instrumented = instrumented.replace(old, new, 1)
    return instrumented


def create_smoke_js(export_dir: pathlib.Path) -> pathlib.Path:
    source = export_dir / "index.js"
    target = export_dir / "index.smoke.js"
    target.write_text(build_instrumented_js(source.read_text()), encoding="utf-8")
    return target


def extract_smoke_payload(dom: str) -> dict[str, object]:
    pattern = re.compile(
        rf"{re.escape(SMOKE_REPORT_START)}\n(.*?)\n{re.escape(SMOKE_REPORT_END)}",
        re.DOTALL,
    )
    match = pattern.search(dom)
    if not match:
        return {}
    try:
        return json.loads(html.unescape(match.group(1)))
    except json.JSONDecodeError:
        return {"decode_error": True, "raw_excerpt": match.group(1)[:2000]}


def resolve_browser(browser_name: str | None, browser_path: str | None) -> pathlib.Path | None:
    if browser_path:
        path = pathlib.Path(browser_path)
        return path if path.exists() else None

    if browser_name in WINDOWS_BROWSER_CANDIDATES:
        for candidate in WINDOWS_BROWSER_CANDIDATES[browser_name]:
            if candidate.exists():
                return candidate

    for name in ("edge", "chrome"):
        for candidate in WINDOWS_BROWSER_CANDIDATES[name]:
            if candidate.exists():
                return candidate

    for name in ("msedge", "chrome", "chromium", "chromium-browser"):
        resolved = shutil.which(name)
        if resolved:
            return pathlib.Path(resolved)

    return None


def fetch_headers(url: str) -> dict[str, str]:
    req = urllib.request.Request(url, method="HEAD")
    with urllib.request.urlopen(req, timeout=10) as resp:
        return {k.lower(): v for k, v in resp.headers.items()}


def wait_for_server(url: str, timeout_s: float = 10.0) -> None:
    deadline = time.time() + timeout_s
    last_error: Exception | None = None
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2):
                return
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            time.sleep(0.25)
    raise RuntimeError(f"server did not come up for {url}: {last_error}")


def run_browser(
    browser_path: pathlib.Path,
    url: str,
    screenshot_path: pathlib.Path,
    virtual_time_budget_ms: int,
) -> dict[str, object]:
    browser_timeout_s = max(60, int(virtual_time_budget_ms / 1000) + 30)
    dump_cmd = [
        str(browser_path),
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-crash-reporter",
        "--enable-logging=stderr",
        "--v=1",
        "--headless=new",
        "--use-angle=swiftshader",
        "--enable-unsafe-swiftshader",
        "--enable-webgl",
        "--run-all-compositor-stages-before-draw",
        f"--virtual-time-budget={virtual_time_budget_ms}",
        "--dump-dom",
        url,
    ]
    dump_error = ""
    shot_error = ""
    dump_dom = ""
    dump_stderr = ""
    dump_exit: int | None = None
    try:
        dump = subprocess.run(dump_cmd, capture_output=True, text=True, timeout=browser_timeout_s)
        dump_dom = dump.stdout
        dump_stderr = dump.stderr[-4000:]
        dump_exit = dump.returncode
    except subprocess.TimeoutExpired as exc:
        dump_dom = exc.stdout or ""
        dump_stderr = (exc.stderr or "")[-4000:]
        dump_error = f"dump timeout after {browser_timeout_s}s"

    screenshot_cmd = [
        str(browser_path),
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-crash-reporter",
        "--enable-logging=stderr",
        "--v=1",
        "--headless=new",
        "--use-angle=swiftshader",
        "--enable-unsafe-swiftshader",
        "--enable-webgl",
        "--run-all-compositor-stages-before-draw",
        f"--virtual-time-budget={virtual_time_budget_ms}",
        f"--screenshot={screenshot_path}",
        "--window-size=1600,900",
        url,
    ]
    shot_stderr = ""
    shot_exit: int | None = None
    try:
        shot = subprocess.run(screenshot_cmd, capture_output=True, text=True, timeout=browser_timeout_s)
        shot_stderr = shot.stderr[-4000:]
        shot_exit = shot.returncode
    except subprocess.TimeoutExpired as exc:
        shot_stderr = (exc.stderr or "")[-4000:]
        shot_error = f"screenshot timeout after {browser_timeout_s}s"

    dom = dump_dom
    smoke_payload = extract_smoke_payload(dom)
    status_notice_match = re.search(
        r'<div id="status-notice"[^>]*>(.*?)</div>',
        dom,
        re.DOTALL,
    )
    status_notice_text = ""
    if status_notice_match:
        status_notice_text = re.sub(r"<br\s*/?>", "\n", status_notice_match.group(1))
        status_notice_text = re.sub(r"<[^>]+>", "", status_notice_text).strip()
    return {
        "browser_path": str(browser_path),
        "dump_dom_exit": dump_exit,
        "dump_dom_stderr": dump_stderr,
        "dump_dom_error": dump_error,
        "screenshot_exit": shot_exit,
        "screenshot_stderr": shot_stderr,
        "screenshot_error": shot_error,
        "screenshot_path": str(screenshot_path),
        "screenshot_exists": screenshot_path.exists(),
        "screenshot_bytes": screenshot_path.stat().st_size if screenshot_path.exists() else 0,
        "dom_has_status_notice": "status-notice" in dom,
        "dom_has_feature_error": "The following features required to run Godot projects on the Web are missing" in dom,
        "dom_has_unknown_error": "An unknown error occurred." in dom,
        "status_notice_text": status_notice_text,
        "smoke_payload": smoke_payload,
        "dom_excerpt": dom[:4000],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Smoke-test a SpaceWheat web export in a browser.")
    parser.add_argument("export_dir", nargs="?", default="releases/web-local")
    parser.add_argument("--port", type=int, default=8051)
    parser.add_argument("--browser", choices=("edge", "chrome"))
    parser.add_argument("--browser-path")
    parser.add_argument("--virtual-time-budget-ms", type=int, default=30000)
    parser.add_argument("--emscripten-pool-size", type=int, default=None)
    parser.add_argument("--report", default="")
    parser.add_argument("--screenshot", default="")
    args = parser.parse_args()

    export_dir = pathlib.Path(args.export_dir).resolve()
    if not export_dir.is_dir():
        raise SystemExit(f"export dir not found: {export_dir}")

    report_path = pathlib.Path(args.report).resolve() if args.report else export_dir / "web_browser_smoke_report.json"
    screenshot_path = pathlib.Path(args.screenshot).resolve() if args.screenshot else export_dir / "web_browser_smoke.png"
    serve_script = pathlib.Path(__file__).resolve().parent / "serve-web-local.py"
    create_smoke_js(export_dir)
    smoke_html_path = create_smoke_html(export_dir, args.emscripten_pool_size)
    url = f"http://127.0.0.1:{args.port}/{smoke_html_path.name}"

    server = subprocess.Popen(
        [sys.executable, str(serve_script), str(export_dir), "--port", str(args.port)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    report: dict[str, object] = {
        "export_dir": str(export_dir),
        "url": url,
        "port": args.port,
        "browser_requested": args.browser or "",
        "browser_path_requested": args.browser_path or "",
    }

    try:
        wait_for_server(url)
        report["server_ready"] = True
        report["headers"] = {
            "index.html": fetch_headers(f"http://127.0.0.1:{args.port}/index.html"),
            "index.smoke.html": fetch_headers(url),
            "index.smoke.js": fetch_headers(f"http://127.0.0.1:{args.port}/index.smoke.js"),
            "index.wasm": fetch_headers(f"http://127.0.0.1:{args.port}/index.wasm"),
            "index.side.wasm": fetch_headers(f"http://127.0.0.1:{args.port}/index.side.wasm"),
        }

        browser_path = resolve_browser(args.browser, args.browser_path)
        report["browser_found"] = bool(browser_path)
        report["browser_path"] = str(browser_path) if browser_path else ""

        if browser_path:
            report["browser_result"] = run_browser(
                browser_path,
                url,
                screenshot_path,
                args.virtual_time_budget_ms,
            )
        else:
            report["browser_result"] = {"skipped": True, "reason": "no supported browser found"}
    except Exception as exc:  # noqa: BLE001
        report["error"] = str(exc)
    finally:
        server.terminate()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=5)

        if server.stdout:
            report["server_stdout"] = server.stdout.read()[-4000:]
        if server.stderr:
            report["server_stderr"] = server.stderr.read()[-4000:]

    report_path.write_text(json.dumps(report, indent=2, sort_keys=True, default=json_default))
    print(report_path)
    print(json.dumps(report, indent=2, sort_keys=True, default=json_default))
    return 0 if "error" not in report else 1


if __name__ == "__main__":
    raise SystemExit(main())
