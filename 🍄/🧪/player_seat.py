#!/usr/bin/env python3
"""PLAYER SEAT — the rig locked down to player parity.

An agent sits here and experiences ONLY what a player does:
  READS:  the visible screen text, the visible bubble field, the resource
          panel, the biome tab bar.
  INPUTS: key presses (with shift), taps, real-time waiting.

Runs HEADLESS (owner call 2026-07-12: mechanics first) — same scene tree,
same visibility flags, same text; no pixels, so no screenshots.

No resource injection, no time_skip, no predicate scores, no dev
introspection. If a verb isn't on this surface, the seat refuses it.

`look` also carries `witness` — the Witness belief graph (Core/Witness), a
memory grown ONLY from events this seat already saw on screen (parity-safe
by construction: fog-of-war is weak measurement). Use it to navigate; pass
--no-graph for the screen-text-only control arm.

Sessions persist across CLI invocations: `start` boots a detached listener
in a per-seat sandbox lane; every later command reconnects through the
lane's queue/results files. State (turn counter, lane path) lives in the
lane's seat_state.json.

Usage:
  player_seat.py start <seat>            boot a fresh game (headed, welcome ON)
  player_seat.py look <seat>             everything the player can currently read
  player_seat.py press <seat> <key> [--shift]
  player_seat.py tap <seat> <gx> <gy>    tap the bubble/plot at grid pos
  player_seat.py wait <seat> <seconds>   real time passes (no skip)
  player_seat.py screenshot <seat> <name>
  player_seat.py stop <seat>

All output is one JSON object on stdout.
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

RUNNER = Path("/home/primearchitect/ws/SpaceWheat/🍄") / "\U0001F39B️"
sys.path.insert(0, str(RUNNER))
from rig_client import RigClient  # noqa: E402

SEAT_ROOT = Path("/tmp/sw_player_seats")

# Keys a player can physically press. Anything else is refused. Named
# aliases are for shells that eat punctuation (`;` unquoted ends a bash
# command — fleet agents typed "semicolon" and were refused).
ALLOWED_KEYS = set("abcdefghijklmnopqrstuvwxyz0123456789;',.[]-=") | {
    "escape", "space", "enter", "tab", "up", "down", "left", "right",
    "semicolon", "apostrophe", "comma", "period", "minus", "equal", "equals"}


def _lane(seat: str) -> Path:
    return SEAT_ROOT / seat


def _state_path(seat: str) -> Path:
    return _lane(seat) / "seat_state.json"


def _load_state(seat: str) -> dict:
    p = _state_path(seat)
    if not p.exists():
        return {}
    return json.loads(p.read_text())


def _save_state(seat: str, st: dict) -> None:
    _state_path(seat).write_text(json.dumps(st))


def _client(seat: str) -> RigClient:
    os.environ["RIG_BRIDGE_SENTINEL_WSL_PATH"] = ""
    os.environ.pop("RIG_BRIDGE_SENTINEL_WSL_PATH", None)
    os.environ.pop("RIG_HEARTBEAT_WSL_PATH", None)
    return RigClient(xdg=_lane(seat))


def _turn(seat: str, st: dict, c: RigClient, action: str, **kw):
    st["turn"] = int(st.get("turn", 0)) + 1
    _save_state(seat, st)
    return c.run_turn(st["turn"], action, timeout_s=45, **kw)


def _seat_is_live(seat: str) -> bool:
    st = _load_state(seat)
    pid = int(st.get("pid", 0))
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


CHECKPOINT_DIR = Path("/home/primearchitect/ws/SpaceWheat/🍄/🧪/checkpoints")


def cmd_start(seat: str, fresh: bool = False, checkpoint: str = "") -> dict:
    # Relay guard: a live seat is someone's campaign in progress. Refusing here
    # protects relay legs from wiping it with a reflexive `start`.
    if _seat_is_live(seat) and not fresh:
        return {"ok": False, "error": "seat_already_running",
                "note": "this seat is live — continue with look/press/wait, "
                        "or pass --fresh to wipe it and boot a new game."}
    ckpt_path = None
    if checkpoint:
        ckpt_path = CHECKPOINT_DIR / ("%s.tres" % checkpoint)
        if not ckpt_path.exists():
            have = sorted(p.stem for p in CHECKPOINT_DIR.glob("*.tres"))
            return {"ok": False, "error": "unknown_checkpoint",
                    "available": have}
    lane = _lane(seat)
    lane.mkdir(parents=True, exist_ok=True)
    c = _client(seat)
    c.kill_existing_listeners(xdg=lane)
    c.clear_rig_files(preserve_live_sentinel=False)
    env = {"RIG_SKIP_WELCOME": "0"}
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            allow_resource_injection=False,
                            listener_log_path=lane / "listener.log",
                            extra_env=env)
    ready = c.wait_for_ready(proc, timeout_s=240, xdg=lane)
    ok = c.ready_seen(ready) or c._bridge_sentinel_is_ready(xdg=lane)
    st = {"turn": 0, "pid": proc.pid, "started": time.time()}
    _save_state(seat, st)
    if ok and ckpt_path is not None:
        # Owner directive: fleets start from solid save files once an act is
        # fleet-proven complete — same as a player loading their own save.
        r = _turn(seat, st, c, "load_game_path", path=str(ckpt_path))
        if not r.get("loaded", r.get("ok", False)):
            return {"ok": False, "error": "checkpoint_load_failed",
                    "detail": str(r)[:200]}
        return {"ok": True, "seat": seat, "checkpoint": checkpoint,
                "note": "campaign loaded from the '%s' save — `look`, then "
                        "check the X STORY tab for where you stand." % checkpoint}
    return {"ok": bool(ok), "seat": seat, "note": "game booted; the welcome "
            "splash may be on screen — `look`, read it, press any key to begin."}


def _visible_lines(c, seat, st, under="") -> list:
    kw = {"under": under} if under else {}
    r = _turn(seat, st, c, "overlay_text", **kw)
    out = []
    for x in r.get("lines", []):
        tx = str(x.get("text", "")) if isinstance(x, dict) else str(x)
        tx = tx.strip()
        if tx:
            out.append(tx)
    return out


def cmd_look(seat: str, graph: bool = True) -> dict:
    st = _load_state(seat)
    c = _client(seat)
    text = _visible_lines(c, seat, st)
    bs = _turn(seat, st, c, "bubble_state")
    # Headless has no force graph (no bubble field) — the chips and toasts
    # carry the plot state instead, exactly as they do for a player.
    field = [{"pos": b.get("pos"), "axis": b.get("axis"),
              "measured": bool(b.get("measured")), "biome": b.get("biome")}
             for b in bs.get("bubbles", []) if b.get("visible")] \
        if bs.get("ok") else "headless: no bubble field — read the chips/toasts"
    rs = _turn(seat, st, c, "resource_snapshot")
    slots = _turn(seat, st, c, "biome_slots")
    tabs = [{"key": s.get("key"), "biome": s.get("biome")}
            for s in slots.get("slots", []) if s.get("biome")]
    # De-dup consecutive repeats to keep the read short.
    seen, screen = set(), []
    for ln in text:
        if ln not in seen:
            seen.add(ln)
            screen.append(ln)
    out = {"ok": True, "screen_text": screen, "field": field,
           "wallet": rs.get("resources", rs.get("snapshot", {})),
           "biome_tabs": tabs}
    if graph:
        # The Witness: a belief field grown ONLY from what this seat has seen
        # (player-parity is structural — fog-of-war is weak measurement).
        # Read it as a navigation graph: for each biome node, glyphs/bloch z
        # per role — z>0 on `yield` means "the field believes harvests here
        # pay off"; low purity means "it doesn't know yet"; low `coverage`
        # means "scout to buy measurement efficiency". `--no-graph` keeps the
        # A/B control arm honest.
        wg = _turn(seat, st, c, "witness_graph", compact=True)
        if wg.get("ok", False) and isinstance(wg.get("witness"), dict):
            out["witness"] = wg["witness"]
    return out


def cmd_press(seat: str, key: str, shift: bool) -> dict:
    if key.lower() not in ALLOWED_KEYS:
        return {"ok": False, "error": "not_a_player_key", "key": key}
    st = _load_state(seat)
    c = _client(seat)
    kw = {"key": key, "settle_frames": 10}
    if shift:
        kw["shift"] = True
    r = _turn(seat, st, c, "press_key", **kw)
    return {"ok": bool(r.get("ok", False)), "pressed": key, "shift": shift}


def cmd_tap(seat: str, _gx: int, _gy: int) -> dict:
    return {"ok": False, "error": "headless_no_tap",
            "hint": "this run is headless — keyboard only (mouse parity is a headed lane)"}


def cmd_wait(seat: str, seconds: float) -> dict:
    seconds = min(max(seconds, 0.0), 30.0)
    time.sleep(seconds)
    return {"ok": True, "waited_s": seconds}


def cmd_screenshot(seat: str, _name: str) -> dict:
    return {"ok": False, "error": "headless_no_pixels",
            "hint": "this run is headless — `look` is your eyes"}


def cmd_bank(seat: str, name: str) -> dict:
    # Harness-side checkpoint: save the live campaign into the shared
    # checkpoints dir (owner directive: aggressive checkpoints so marathons
    # resume where the last one died instead of replaying the early game).
    if not name or not name.replace("_", "").isalnum():
        return {"ok": False, "error": "bad_checkpoint_name"}
    CHECKPOINT_DIR.mkdir(parents=True, exist_ok=True)
    st = _load_state(seat)
    c = _client(seat)
    path = CHECKPOINT_DIR / ("%s.tres" % name)
    r = _turn(seat, st, c, "save_game_path", path=str(path))
    if not r.get("saved", False):
        return {"ok": False, "error": "save_failed", "detail": str(r)[:200]}
    flags = _turn(seat, st, c, "story_flags").get("flags_fired", {}) or {}
    (CHECKPOINT_DIR / ("%s.json" % name)).write_text(json.dumps(
        {"name": name, "banked_from": seat, "time": time.time(),
         "flags_fired": sorted(flags.keys())}, ensure_ascii=False, indent=1))
    # Bank the Witness gauge beside the save — diff-stable by construction,
    # so `diff a.witness_gauge.json b.witness_gauge.json` shows exactly what
    # the belief field learned between two checkpoints (empty diff = nothing).
    wg = _turn(seat, st, c, "witness_gauge")
    if wg.get("ok", False) and isinstance(wg.get("gauge"), dict):
        (CHECKPOINT_DIR / ("%s.witness_gauge.json" % name)).write_text(
            json.dumps(wg["gauge"], ensure_ascii=False, indent=1, sort_keys=True))
    return {"ok": True, "banked": name, "flags": len(flags)}


def cmd_stop(seat: str) -> dict:
    c = _client(seat)
    c.kill_existing_listeners(xdg=_lane(seat))
    return {"ok": True, "seat": seat, "stopped": True}


def main() -> int:
    args = sys.argv[1:]
    if len(args) < 2:
        print(json.dumps({"ok": False, "error": "usage", "help": __doc__}))
        return 1
    cmd, seat = args[0], args[1]
    try:
        if cmd == "start":
            ckpt = ""
            if "--checkpoint" in args:
                i = args.index("--checkpoint")
                ckpt = args[i + 1] if i + 1 < len(args) else ""
            out = cmd_start(seat, "--fresh" in args, ckpt)
        elif cmd == "look":
            out = cmd_look(seat, graph="--no-graph" not in args)
        elif cmd == "press":
            out = cmd_press(seat, args[2], "--shift" in args)
        elif cmd == "tap":
            out = cmd_tap(seat, int(args[2]), int(args[3]))
        elif cmd == "wait":
            out = cmd_wait(seat, float(args[2]))
        elif cmd == "screenshot":
            out = cmd_screenshot(seat, args[2] if len(args) > 2 else "shot")
        elif cmd == "bank":
            out = cmd_bank(seat, args[2] if len(args) > 2 else "")
        elif cmd == "stop":
            out = cmd_stop(seat)
        else:
            out = {"ok": False, "error": "unknown_command",
                   "allowed": ["start", "look", "press", "tap", "wait",
                               "screenshot", "bank", "stop"]}
    except Exception as exc:  # honest failure beats a hung agent
        out = {"ok": False, "error": "seat_exception", "detail": str(exc)[:300]}
    print(json.dumps(out, ensure_ascii=False))
    return 0 if out.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
