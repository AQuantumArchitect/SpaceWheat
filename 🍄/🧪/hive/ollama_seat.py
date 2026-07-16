#!/usr/bin/env python3
"""ollama_seat.py — a roc-Ollama model plays SpaceWheat through the player seat.

Smoke driver for the yurt mesh: boots a player_seat, feeds the model ONLY what a
player reads (screen_text + wallet, witness stripped), and asks for exactly one
next command per turn: PRESS <KEY> [SHIFT] | WAIT <seconds> | LOOK.

Backends (auto-picked):
  * bridge  — roc's yurt-bridge OpenAI-compatible proxy   (needs YURT_TOKEN)
              POST {BRIDGE_URL}/v1/chat/completions, Authorization: Bearer
              models from GET {BRIDGE_URL}/v1/models
  * raw     — a directly reachable Ollama                  (OLLAMA_URL set)
              POST {OLLAMA_URL}/api/chat, models from GET {OLLAMA_URL}/api/tags

Env:
  YURT_TOKEN / YURT_BRIDGE_TOKEN  bearer token for roc's bridge
  BRIDGE_URL   default http://roc.tailff1b6b.ts.net:8787
  OLLAMA_URL   e.g. http://127.0.0.1:11434 (raw backend)
  OLLAMA_MODEL force a model id (else best small instruct from tags)
  SEAT_NAME    default ollama1;  MAX_TURNS default 40;  HISTORY_N default 6

Usage (from SpaceWheat repo root):
  YURT_TOKEN=... python3 🍄/🧪/hive/ollama_seat.py

Never put the token in a tracked file.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# Windows consoles/pipes default to cp1252 — printing model output or seat
# JSON with emoji then crashes. Force UTF-8 on our own stdio too.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

REPO_ROOT = Path(__file__).resolve().parents[3]  # .../SpaceWheat
SEAT_PY = REPO_ROOT / "🍄" / "🧪" / "player_seat.py"

SEAT = os.environ.get("SEAT_NAME", "ollama1")
MAX_TURNS = int(os.environ.get("MAX_TURNS", "40"))
HISTORY_N = int(os.environ.get("HISTORY_N", "6"))
SCREEN_CAP = int(os.environ.get("SCREEN_CAP", "4000"))
NUM_PREDICT = int(os.environ.get("SEAT_NUM_PREDICT", "24"))
SEAT_THINK = os.environ.get("SEAT_THINK", "").strip().lower()  # "off" | "on" | ""

BRIDGE_URL = os.environ.get("BRIDGE_URL", "http://roc.tailff1b6b.ts.net:8787").rstrip("/")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "").rstrip("/")
TOKEN = (os.environ.get("YURT_TOKEN") or os.environ.get("YURT_BRIDGE_TOKEN") or "").strip()

SYSTEM_BRIEF = """You are playing SpaceWheat, a quantum farming game, through a text seat.
Each turn you see the current SCREEN TEXT and your WALLET. The screen shows an
objective banner and on-screen hints - FOLLOW THE HINTS; they tell you which key
to press next. Keys are single characters (letters, digits, arrows as words).

Reply with EXACTLY ONE command on one line, nothing else:
  PRESS <KEY>          press a key (e.g. PRESS E, PRESS 1, PRESS F)
  PRESS <KEY> SHIFT    press with shift held (e.g. PRESS F SHIFT)
  WAIT <seconds>       let real time pass (1-10)
  LOOK                 re-read the screen

No prose, no punctuation, no explanation. One command only."""

CMD_RE = re.compile(
    r"\b(?:PRESS\s+(?P<key>[A-Za-z0-9]+)(?P<shift>\s+SHIFT)?|WAIT\s+(?P<secs>\d+(?:\.\d+)?)|(?P<look>LOOK))\b",
    re.IGNORECASE,
)

# Reasoning models (qwen3 &c.) wrap deliberation in <think>...</think>. Any
# PRESS/WAIT/LOOK inside that block is deliberation, not a command — strip
# closed blocks AND an unclosed trailing block (budget ran out mid-think).
THINK_BLOCK_RE = re.compile(r"<think>.*?</think>", re.IGNORECASE | re.DOTALL)
THINK_TAIL_RE = re.compile(r"<think>.*\Z", re.IGNORECASE | re.DOTALL)


def strip_think(text: str) -> str:
    text = THINK_BLOCK_RE.sub("", text or "")
    return THINK_TAIL_RE.sub("", text)

# preference order for "best small instruct model"
MODEL_PREFS = ["qwen2.5", "llama3.2", "llama3.1", "llama3", "phi3", "gemma2", "mistral"]


def http_json(url: str, payload: dict | None = None, headers: dict | None = None,
              timeout: float = 300.0):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, headers={
        "Content-Type": "application/json", **(headers or {})})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read() or b"null")


class Brain:
    """One next-command oracle over either backend."""

    def __init__(self):
        if OLLAMA_URL:
            self.kind = "raw"
        elif TOKEN:
            self.kind = "bridge"
        else:
            sys.exit("FATAL: no backend. Set OLLAMA_URL (raw) or YURT_TOKEN (roc bridge).\n"
                     "Roc's raw :11434 is closed by design; the bridge token arrives via "
                     "Syncthing work/_roc/bridge-client.toml after pairing.")
        self.model = os.environ.get("OLLAMA_MODEL") or self._pick_model()
        print(f"[brain] backend={self.kind} model={self.model}", flush=True)

    def _auth(self) -> dict:
        return {"Authorization": f"Bearer {TOKEN}"} if self.kind == "bridge" else {}

    def _pick_model(self) -> str:
        if self.kind == "raw":
            tags = http_json(f"{OLLAMA_URL}/api/tags", timeout=20)
            names = [m["name"] for m in tags.get("models", [])]
        else:
            tags = http_json(f"{BRIDGE_URL}/v1/models", headers=self._auth(), timeout=20)
            names = [m["id"] for m in tags.get("data", [])]
        if not names:
            sys.exit("FATAL: backend reachable but no models installed.")
        print(f"[brain] models on backend: {names}", flush=True)
        for pref in MODEL_PREFS:
            for n in names:
                if pref in n:
                    return n
        return names[0]

    def next_command(self, messages: list[dict]) -> str:
        if self.kind == "raw":
            payload = {
                "model": self.model, "messages": messages, "stream": False,
                "options": {"temperature": 0.2, "num_predict": NUM_PREDICT},
            }
            if SEAT_THINK == "off":
                payload["think"] = False  # qwen3 &c.: don't burn budget thinking
            out = http_json(f"{OLLAMA_URL}/api/chat", payload)
            msg = out.get("message", {})
            # thinking-only reply (content empty): no command -> caller LOOKs
            return msg.get("content") or ""
        out = http_json(f"{BRIDGE_URL}/v1/chat/completions", {
            "model": self.model, "messages": messages,
            "temperature": 0.2, "max_tokens": NUM_PREDICT,
        }, headers=self._auth())
        return out["choices"][0]["message"].get("content") or ""


def seat(*args: str) -> dict:
    # encoding pinned: the seat prints UTF-8 (emoji JSON); Windows' default
    # cp1252 reader thread dies on it and the model goes blind.
    p = subprocess.run([sys.executable, str(SEAT_PY), *args],
                       capture_output=True, text=True, encoding="utf-8",
                       errors="replace", cwd=REPO_ROOT, timeout=300)
    line = (p.stdout or "").strip().splitlines()
    try:
        return json.loads(line[-1]) if line else {"ok": False, "error": p.stderr[-400:]}
    except json.JSONDecodeError:
        return {"ok": False, "error": (p.stdout + p.stderr)[-400:]}


def observation() -> str:
    """screen_text + wallet only; witness stripped via --no-graph."""
    lk = seat("look", SEAT, "--no-graph")
    if not lk.get("ok", False):
        return f"(look failed: {lk.get('error', '?')})"
    screen = str(lk.get("screen_text", ""))[:SCREEN_CAP]
    wallet = json.dumps(lk.get("wallet", {}), ensure_ascii=False)
    return f"SCREEN TEXT:\n{screen}\n\nWALLET: {wallet}"


def main() -> None:
    brain = Brain()

    print(f"[seat] booting {SEAT} --fresh", flush=True)
    st = seat("start", SEAT, "--fresh")
    if not st.get("ok", False):
        sys.exit(f"FATAL: seat start failed: {st}")

    history: list[tuple[str, str]] = []  # (obs, cmd)
    try:
        for turn in range(1, MAX_TURNS + 1):
            obs = observation()
            messages = [{"role": "system", "content": SYSTEM_BRIEF}]
            for h_obs, h_cmd in history[-HISTORY_N:]:
                messages.append({"role": "user", "content": h_obs})
                messages.append({"role": "assistant", "content": h_cmd})
            messages.append({"role": "user", "content": obs})

            try:
                raw = brain.next_command(messages)
            except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
                print(f"[turn {turn}] brain error: {e}; stopping.", flush=True)
                break

            m = CMD_RE.search(strip_think(raw))
            if not m:
                print(f"[turn {turn}] unparseable: {raw!r} -> LOOK", flush=True)
                history.append((obs, "LOOK"))
                continue

            if m.group("look"):
                cmd, res = "LOOK", {"ok": True}
            elif m.group("secs"):
                secs = max(1.0, min(10.0, float(m.group("secs"))))
                cmd = f"WAIT {secs:g}"
                res = seat("wait", SEAT, str(secs))
            else:
                key = m.group("key")
                shift = bool(m.group("shift"))
                cmd = f"PRESS {key.upper()}" + (" SHIFT" if shift else "")
                args = ["press", SEAT, key.lower()]
                if shift:
                    args.append("--shift")
                res = seat(*args)

            print(f"[turn {turn}] {cmd}  ok={res.get('ok')}"
                  f"{'' if res.get('ok') else ' err=' + str(res.get('error'))[:120]}",
                  flush=True)
            history.append((obs, cmd))
            time.sleep(0.3)
    finally:
        print("[seat] stopping", flush=True)
        seat("stop", SEAT)

    print(f"[done] {len(history)} commands issued by {brain.model}", flush=True)


if __name__ == "__main__":
    main()
