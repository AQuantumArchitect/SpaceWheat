#!/usr/bin/env python3
"""meerkat_cognifold_bridge — Meerkat's live house state, reshaped as cognifold_trace_v1.

SpaceWheat's cognifold instrument (Core/Visualization/CognifoldTraceView.gd, scripts/cognifold.sh)
renders any cognifold_trace_v1 payload polled over HTTP — it was built generic ("game or not").
Meerkat (../Meerkat-dev), Luke's real deployed home-automation quantum reservoir, already produces
exactly the two channels that renderer draws — Berry phase and surprise — but shaped as an
event/ticker stream (GET /api/surprise, /api/surprise/recent, /api/berry), not as cognifold's
per-register scalars. This bridge is the translator, and ONLY that: it issues read-only GETs
against Meerkat's existing API and republishes the reshaped JSON locally. It never writes to
Meerkat, never touches actuators, and Meerkat's own codebase has zero changes because of this file.

One register per surprise source (Meerkat's natural per-sensor/per-zone granularity), carrying that
source's most recent (berry_phase, surprise) reading — plus one synthetic register for the
whole-house Berry ticker. berry_phase/surprise are left absent (never fabricated as 0.0) for a
source with no stamps yet, matching the renderer's own "honestly absent" policy.

edges[] ARE populated (v2): field.bridges (from GET /api/reservoir) is keyed "{a}↔{b}" where a/b
are the same short names surprise-source roles carry after their "calibration_dynamics:" prefix
(e.g. "kitchen", "kasa_mirror_light") — a genuine, exact-string join, not a guess. manifold is
still NOT populated: there's no cluster grouping in Meerkat's API above individual bridges to
justify one.

Usage:
    python3 meerkat_cognifold_bridge.py
    curl 127.0.0.1:8099/cognifold

Env:
    MEERKAT_URL          default http://127.0.0.1:8080
    MEERKAT_BRIDGE_PORT  default 8099
    MEERKAT_BRIDGE_POLL_S  default 3.0
"""
from __future__ import annotations

import json
import os
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MEERKAT_URL = os.environ.get("MEERKAT_URL", "http://127.0.0.1:8080").rstrip("/")
BRIDGE_PORT = int(os.environ.get("MEERKAT_BRIDGE_PORT", "8099"))
POLL_S = float(os.environ.get("MEERKAT_BRIDGE_POLL_S", "3.0"))

_lock = threading.Lock()
_trace: dict | None = None   # last successfully built cognifold_trace_v1, or None if never/dark
_last_error: str | None = None


def _get(path: str, timeout: float = 6.0):
    with urllib.request.urlopen(f"{MEERKAT_URL}{path}", timeout=timeout) as resp:
        return json.loads(resp.read())


# North pole = WHERE (zone the source lives in, or a system-wide 🌀 when the source name carries
# no room). South pole = WHAT (device type / metric). Both are substring keyword scans over the
# raw source name, first match wins — deliberately generic (any new Meerkat sensor gets a sane
# pair automatically) rather than a hand-maintained per-source table that silently goes stale.
_ZONE_KEYWORDS = [
    ("courtyard", "\U0001f333"),  # 🌳
    ("kitchen", "\U0001f373"),    # 🍳
    ("dining", "\U0001f37d️"),  # 🍽️
    ("bathroom", "\U0001f6bf"),   # 🚿
    ("bedroom", "\U0001f6cf️"),  # 🛏️
    ("living", "\U0001f6cb️"),   # 🛋️
    ("studio", "\U0001f3a8"),     # 🎨
    ("lab", "\U0001f52c"),        # 🔬
    ("hallway", "\U0001f6aa"),    # 🚪
    ("exterior", "\U0001f324️"),  # 🌤️
    ("rdk", "\U0001f916"),        # 🤖
]
_ZONE_DEFAULT = "\U0001f300"  # 🌀 — no room named in the source string; honestly abstract/system

_DEVICE_KEYWORDS = [
    ("fractal_scale", "\U0001f4c8"),  # 📈
    ("cpu_load", "\U0001f9ee"),       # 🧮
    ("memory", "\U0001f4be"),         # 💾
    ("training", "\U0001f4da"),       # 📚
    ("dimmer", "\U0001f4a1"),         # 💡
    ("light", "\U0001f4a1"),          # 💡
    ("thermostat", "\U0001f321️"),  # 🌡️
    ("sentinel", "\U0001f441️"),  # 👁️
    ("fridge", "\U0001f9ca"),         # 🧊
    ("tv", "\U0001f4fa"),             # 📺
    ("mirror", "\U0001fa9e"),         # 🪞
    ("shower", "\U0001f6bf"),         # 🚿
    ("blind", "\U0001fa9f"),          # 🪟
    ("clock", "\U0001f550"),          # 🕐
    ("workstation", "\U0001f5a5️"),  # 🖥️
    ("fan", "\U0001f300"),            # 🌀
    ("plug", "\U0001f50c"),           # 🔌
    ("switch", "\U0001f39a️"),   # 🎚️
    ("entry", "\U0001f6aa"),          # 🚪
]
_DEVICE_DEFAULT = "\U0001f441️"  # 👁️ — a bare zone/root source: whole-room presence tracking


def _emoji_for_role(role: str) -> tuple[str, str]:
    low = role.lower()
    north = next((e for kw, e in _ZONE_KEYWORDS if kw in low), _ZONE_DEFAULT)
    south = next((e for kw, e in _DEVICE_KEYWORDS if kw in low), _DEVICE_DEFAULT)
    return north, south


_DYNAMICS_PREFIX = "calibration_dynamics:"


def _bridge_node_name(role: str) -> str | None:
    """The short name field.bridges' "{a}↔{b}" keys use, when this role has one."""
    if role.startswith(_DYNAMICS_PREFIX):
        return role[len(_DYNAMICS_PREFIX):]
    return None


def _build_trace() -> dict:
    """One GET per Meerkat endpoint, reshaped into cognifold_trace_v1. Raises on any failure —
    the caller decides what "dark" means; this function never guesses or fills in fake data."""
    surprise = _get("/api/surprise")
    recent = _get("/api/surprise/recent?limit=200&history=1")
    berry = _get("/api/berry")
    reservoir = _get("/api/reservoir")

    # Most recent stamp per source, from the flat stamps list (already newest-ish via reservoir
    # sampling on the /api/surprise endpoint's own semantics; recent/history covers the rest).
    latest_by_source: dict[str, dict] = {}
    for stamp in recent.get("stamps", []):
        src = stamp.get("source")
        if src is None:
            continue
        prev = latest_by_source.get(src)
        if prev is None or stamp.get("wall_clock", 0) >= prev.get("wall_clock", 0):
            latest_by_source[src] = stamp

    registers = []
    index_by_node_name: dict[str, int] = {}
    for entry in surprise.get("sources", []):
        src = entry.get("source")
        if not src:
            continue
        north, south = _emoji_for_role(src)
        reg = {
            "north_emoji": north,
            "south_emoji": south,
            "node": "meerkat",
            "role": src,
        }
        stamp = latest_by_source.get(src)
        if stamp is not None:
            reg["berry_phase"] = stamp.get("berry_phase")
            reg["surprise"] = stamp.get("surprise")
        node_name = _bridge_node_name(src)
        if node_name is not None:
            index_by_node_name[node_name] = len(registers)
        registers.append(reg)

    ticker = berry.get("ticker", {})
    registers.append({
        "north_emoji": "\U0001f3e0",  # 🏠
        "south_emoji": "\U0001f319",  # 🌙
        "node": "meerkat",
        "role": "house_ticker",
        "berry_phase": ticker.get("phase"),
    })

    # Real correlation edges: field.bridges pairs the exact short names index_by_node_name was
    # keyed on above. No "kind" (not the live-MI channel) — these are the reservoir's standing
    # structural links, drawn as the static coupling lines, same as game H-couplings.
    bridges = reservoir.get("field", {}).get("bridges", {})
    edges = []
    for pair, weight in bridges.items():
        a, sep, b = pair.partition("↔")  # ↔
        if not sep:
            continue
        i, j = index_by_node_name.get(a), index_by_node_name.get(b)
        if i is None or j is None or i == j:
            continue
        edges.append({"i": i, "j": j, "weight": float(weight)})

    return {
        "world": "meerkat-house",
        "registers": registers,
        "edges": edges,
    }


def _poll_loop() -> None:
    global _trace, _last_error
    while True:
        try:
            trace = _build_trace()
            with _lock:
                _trace = trace
                _last_error = None
        except (urllib.error.URLError, OSError, json.JSONDecodeError, TimeoutError) as exc:
            with _lock:
                _last_error = f"{type(exc).__name__}: {exc}"
            print(f"[meerkat_cognifold_bridge] DARK: {_last_error}", flush=True)
        time.sleep(POLL_S)


class _Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # quiet the default stderr access log
        pass

    def do_GET(self):
        if self.path.split("?", 1)[0] != "/cognifold":
            self.send_response(404)
            self.end_headers()
            return
        with _lock:
            trace, err = _trace, _last_error
        if trace is None:
            self.send_response(503)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": err or "no data yet"}).encode("utf-8"))
            return
        body = json.dumps(trace).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> int:
    threading.Thread(target=_poll_loop, daemon=True).start()
    server = ThreadingHTTPServer(("127.0.0.1", BRIDGE_PORT), _Handler)
    print(f"[meerkat_cognifold_bridge] serving http://127.0.0.1:{BRIDGE_PORT}/cognifold "
          f"<- {MEERKAT_URL} (poll {POLL_S}s)", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
