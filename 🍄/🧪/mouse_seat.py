#!/usr/bin/env python3
"""MOUSE SEAT — the player seat with the keyboard taken away.

Same parity contract as `player_seat.py` (read only what's on screen, no
resource injection, no dev introspection, progressive disclosure ON), with
two deliberate differences:

  1. It runs HEADED, on its own private Xvfb display, so real
     `InputEventMouseButton` press+release events have somewhere to land and
     parallel seats never fight over one screen (or steal the owner's).
  2. `press` is REFUSED. Mouse-only discipline used to be an honour rule in
     the persona prompt; every wave depended on the tester choosing not to
     cheat. Here the seat simply has no keyboard, so a leg that reports
     "reached X by mouse alone" cannot have quietly used a key.

Reading `clickables` is parity-safe: it lists the VISIBLE, click-receiving
buttons a sighted player can see, with the point a tap should aim at. It
exists so a driver never has to guess a node name — a guessed name that
resolves to the wrong row is the "hit whatever it might" failure this
campaign forbids.

Usage:
  mouse_seat.py start <seat> [--fresh] [--checkpoint NAME]
  mouse_seat.py look <seat>              screen text, field, wallet, buttons
  mouse_seat.py tap <seat> <gx> <gy>     click the bubble/plot at grid pos
  mouse_seat.py click <seat> <Name> [--under Parent]
                                         click a named button's centre
  mouse_seat.py click_at <seat> <x> <y>  click a raw screen point
  mouse_seat.py wait <seat> <seconds>
  mouse_seat.py screenshot <seat> <name>
  mouse_seat.py bank <seat> <name>
  mouse_seat.py stop <seat>

All output is one JSON object on stdout.
"""
import json
import os
import subprocess
import sys
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
import time
from pathlib import Path

ROOT = Path("/home/primearchitect/ws/SpaceWheat")
RUNNER = ROOT / "\U0001F344" / "\U0001F39B️"
sys.path.insert(0, str(RUNNER))
from rig_client import RigClient  # noqa: E402

SEAT_ROOT = Path("/tmp/sw_mouse_seats")
CHECKPOINT_DIR = ROOT / "\U0001F344" / "\U0001F9EA" / "checkpoints"
SHOT_DIR = ROOT / "logs" / "mouse_seat_shots"

# Headed seats run on the ambient display (WSLg's :0), same as every other
# headed probe in this repo. A private Xvfb per seat was tried and is NOT
# possible here: WSLg mounts /tmp/.X11-unix read-only, so no second X server
# can create its listening socket. Consequence to know when scheduling legs —
# each seat opens a REAL window on the owner's desktop. Taps are injected with
# viewport.push_input, not OS events, so window focus never affects a result;
# the cost of running several at once is visual noise, not wrong readings.
DEFAULT_DISPLAY = os.environ.get("DISPLAY", ":0")


def _lane(seat: str) -> Path:
    return SEAT_ROOT / seat


def _state_path(seat: str) -> Path:
    return _lane(seat) / "seat_state.json"


def _load_state(seat: str) -> dict:
    p = _state_path(seat)
    return json.loads(p.read_text()) if p.exists() else {}


def _save_state(seat: str, st: dict) -> None:
    _state_path(seat).write_text(json.dumps(st))


def _display_for(seat: str) -> str:
    """The display this seat's listener was launched on, so reconnecting CLI
    invocations always talk to the same window."""
    return str(_load_state(seat).get("display") or DEFAULT_DISPLAY)


def _client(seat: str) -> RigClient:
    os.environ.pop("RIG_BRIDGE_SENTINEL_WSL_PATH", None)
    os.environ.pop("RIG_HEARTBEAT_WSL_PATH", None)
    return RigClient(xdg=_lane(seat))


def _turn(seat: str, st: dict, c: RigClient, action: str, **kw):
    st["turn"] = int(st.get("turn", 0)) + 1
    _save_state(seat, st)
    return c.run_turn(st["turn"], action, timeout_s=60, **kw)


def _seat_is_live(seat: str) -> bool:
    pid = int(_load_state(seat).get("pid", 0))
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def cmd_start(seat: str, fresh: bool = False, checkpoint: str = "") -> dict:
    if _seat_is_live(seat) and not fresh:
        return {"ok": False, "error": "seat_already_running",
                "note": "this seat is live — continue with look/tap/click, "
                        "or pass --fresh to wipe it and boot a new game."}
    ckpt_path = None
    if checkpoint:
        ckpt_path = CHECKPOINT_DIR / ("%s.tres" % checkpoint)
        if not ckpt_path.exists():
            return {"ok": False, "error": "unknown_checkpoint",
                    "available": sorted(p.stem for p in CHECKPOINT_DIR.glob("*.tres"))}
    lane = _lane(seat)
    lane.mkdir(parents=True, exist_ok=True)
    display = DEFAULT_DISPLAY
    c = _client(seat)
    c.kill_existing_listeners(xdg=lane)
    c.clear_rig_files(preserve_live_sentinel=False)
    # Parity, same as player_seat: welcome splash ON, progressive disclosure ON.
    env = {"RIG_SKIP_WELCOME": "0", "RIG_UNLOCK_ALL": "0", "DISPLAY": display}
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            allow_resource_injection=False,
                            listener_log_path=lane / "listener.log",
                            extra_env=env)
    ready = c.wait_for_ready(proc, timeout_s=300, xdg=lane)
    ok = c.ready_seen(ready) or c._bridge_sentinel_is_ready(xdg=lane)
    st = {"turn": 0, "pid": proc.pid, "started": time.time(), "display": display}
    _save_state(seat, st)
    if ok and ckpt_path is not None:
        r = _turn(seat, st, c, "load_game_path", path=str(ckpt_path))
        if not r.get("loaded", r.get("ok", False)):
            return {"ok": False, "error": "checkpoint_load_failed",
                    "detail": str(r)[:200]}
        return {"ok": True, "seat": seat, "checkpoint": checkpoint, "display": display,
                "note": "campaign loaded from '%s' — `look` first; the X STORY "
                        "tab says where you stand." % checkpoint}
    return {"ok": bool(ok), "seat": seat, "display": display,
            "note": "game booted headed; the welcome splash may be up — `look`, "
                    "then click anywhere (click_at) to dismiss it."}


def _visible_lines(c, seat, st) -> list:
    r = _turn(seat, st, c, "overlay_text")
    out, seen = [], set()
    for x in r.get("lines", []):
        tx = (str(x.get("text", "")) if isinstance(x, dict) else str(x)).strip()
        if tx and tx not in seen:
            seen.add(tx)
            out.append(tx)
    return out


def cmd_look(seat: str) -> dict:
    st = _load_state(seat)
    c = _client(seat)
    screen = _visible_lines(c, seat, st)
    bs = _turn(seat, st, c, "bubble_state")
    field = [{"pos": b.get("pos"), "axis": b.get("axis"),
              "measured": bool(b.get("measured")), "biome": b.get("biome")}
             for b in bs.get("bubbles", []) if b.get("visible")] if bs.get("ok") else []
    # `field` lists only REVEALED bubbles, so before the first exploration it is
    # empty — leaving a mouse leg with nothing to aim `tap` at, and no way to
    # click its very first plot. plot_glance carries every assigned tile,
    # revealed or not, with the grid pos `tap` takes.
    glance = _turn(seat, st, c, "plot_glance")
    plots = [{"pos": p.get("pos"), "key": p.get("key"), "biome": p.get("biome"),
              "revealed": p.get("revealed"), "measured": p.get("measured"),
              "focused": p.get("focused")}
             for p in glance.get("plots", [])] if glance.get("ok") else []
    rs = _turn(seat, st, c, "resource_snapshot")
    slots = _turn(seat, st, c, "biome_slots")
    ck = _turn(seat, st, c, "clickables")
    buttons = [{"name": b.get("name"), "label": b.get("label"),
                "parent": b.get("parent"), "disabled": b.get("disabled"),
                "center": b.get("center")}
               for b in ck.get("clickables", [])]
    return {"ok": True, "screen_text": screen, "field": field, "plots": plots,
            "wallet": rs.get("resources", rs.get("snapshot", {})),
            "biome_tabs": [{"key": s.get("key"), "biome": s.get("biome")}
                           for s in slots.get("slots", []) if s.get("biome")],
            "active_biome": slots.get("active", ""),
            "buttons": buttons}


def cmd_press(*_a, **_k) -> dict:
    return {"ok": False, "error": "no_keyboard",
            "hint": "this seat is MOUSE ONLY by construction. Use `tap` (a "
                    "bubble by grid pos), `click` (a named button from look's "
                    "`buttons`), or `click_at` (a raw point). If a thing can "
                    "only be reached by a key, that IS the finding — report it."}


def cmd_tap(seat: str, gx: int, gy: int) -> dict:
    st = _load_state(seat)
    c = _client(seat)
    r = _turn(seat, st, c, "tap", pos=[gx, gy], settle_frames=10)
    if not r.get("ok", False):
        return {"ok": False, "error": r.get("error", "tap_failed"), "pos": [gx, gy]}
    return {"ok": True, "tapped_grid": [gx, gy], "at_screen": r.get("tapped")}


def cmd_click(seat: str, name: str, under: str = "") -> dict:
    st = _load_state(seat)
    c = _client(seat)
    if not under:
        # Every SelectionButtonRow names its chips SelectBtn_0..N independently,
        # so "SelectBtn_0" is live in the menu row, the biome row AND the hat row
        # at once. An unscoped lookup silently resolves to whichever the tree walk
        # reaches first — clicking the wrong row while reporting success. Refuse
        # instead: a guessed target is worse than no target.
        ck = _turn(seat, st, c, "clickables")
        parents = [b.get("parent", "") for b in ck.get("clickables", [])
                   if b.get("name") == name]
        if len(parents) > 1:
            return {"ok": False, "error": "ambiguous_name", "name": name,
                    "parents": parents,
                    "hint": "%d visible controls share this name — re-run with "
                            "--under <parent> to say which one you meant" % len(parents)}
    kw = {"name": name}
    if under:
        kw["under"] = under
    rect = _turn(seat, st, c, "control_rect", **kw)
    if not rect.get("ok", False):
        return {"ok": False, "error": rect.get("error", "control_not_found"),
                "name": name, "under": under}
    if not rect.get("visible", False):
        return {"ok": False, "error": "control_not_visible", "name": name,
                "hint": "a player cannot click what isn't on screen"}
    cx, cy = rect.get("center", [-1, -1])
    r = _turn(seat, st, c, "tap", screen=[cx, cy], settle_frames=10)
    return {"ok": bool(r.get("ok", False)), "clicked": name, "at_screen": [cx, cy]}


def cmd_click_at(seat: str, x: int, y: int) -> dict:
    st = _load_state(seat)
    c = _client(seat)
    r = _turn(seat, st, c, "tap", screen=[x, y], settle_frames=10)
    return {"ok": bool(r.get("ok", False)), "clicked_screen": [x, y]}


def cmd_wait(_seat: str, seconds: float) -> dict:
    seconds = min(max(seconds, 0.0), 30.0)
    time.sleep(seconds)
    return {"ok": True, "waited_s": seconds}


def cmd_screenshot(seat: str, name: str) -> dict:
    st = _load_state(seat)
    c = _client(seat)
    safe = "".join(ch for ch in name if ch.isalnum() or ch in "_-") or "shot"
    r = _turn(seat, st, c, "screenshot", path="user://rig/%s.png" % safe, settle_frames=4)
    abs_path = str(r.get("screenshot", {}).get("abs", ""))
    if abs_path and Path(abs_path).exists():
        SHOT_DIR.mkdir(parents=True, exist_ok=True)
        dest = SHOT_DIR / ("%s_%s.png" % (seat, safe))
        dest.write_bytes(Path(abs_path).read_bytes())
        return {"ok": True, "shot": str(dest)}
    return {"ok": False, "error": "screenshot_failed", "detail": str(r)[:200]}


def cmd_bank(seat: str, name: str) -> dict:
    if not name or not name.replace("_", "").isalnum():
        return {"ok": False, "error": "bad_checkpoint_name",
                "hint": "letters/digits/underscores only"}
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
    return {"ok": True, "banked": name, "flags": len(flags)}


def cmd_stop(seat: str) -> dict:
    c = _client(seat)
    c.kill_existing_listeners(xdg=_lane(seat))
    return {"ok": True, "seat": seat, "stopped": True}


def _arg_after(args: list, flag: str, default: str = "") -> str:
    if flag in args:
        i = args.index(flag)
        if i + 1 < len(args):
            return args[i + 1]
    return default


def main() -> int:
    args = sys.argv[1:]
    if len(args) < 2:
        print(json.dumps({"ok": False, "error": "usage", "help": __doc__}))
        return 1
    cmd, seat = args[0], args[1]
    try:
        if cmd == "start":
            out = cmd_start(seat, "--fresh" in args, _arg_after(args, "--checkpoint"))
        elif cmd == "look":
            out = cmd_look(seat)
        elif cmd == "press":
            out = cmd_press()
        elif cmd == "tap":
            out = cmd_tap(seat, int(args[2]), int(args[3]))
        elif cmd == "click":
            out = cmd_click(seat, args[2], _arg_after(args, "--under"))
        elif cmd == "click_at":
            out = cmd_click_at(seat, int(args[2]), int(args[3]))
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
                   "allowed": ["start", "look", "tap", "click", "click_at",
                               "wait", "screenshot", "bank", "stop"]}
    except Exception as exc:  # honest failure beats a hung agent
        out = {"ok": False, "error": "seat_exception", "detail": str(exc)[:300]}
    print(json.dumps(out, ensure_ascii=False))
    return 0 if out.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
