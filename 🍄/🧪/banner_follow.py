#!/usr/bin/env python3
"""Follow the banner. No LLM, no game knowledge, no seams.

For a campaign beat B: build B's opening state with the spec fixture
(`start_at_beat`), then do only what the objective banner says — press the
keys it names, in the order it names them, re-read, repeat. Report whether the story moved, how many
presses it took, and how it failed if it did not:

  moved        a story flag fired, or the beat's own Arc quest was claimed
               (contract claims on the way are recorded, not counted)
  no_banner    the banner was empty (nothing tells the player what to do)
  no_key       the banner names no key a keyboard player can press (a line
               that says to wait is waited out, up to WAIT_CAP × WAIT_SECONDS)
  stuck        banner and game state stopped changing for STUCK_AFTER presses
  loop         the banner cycled through the same few lines without progress
  cap          press budget spent while things changed but the story did not

This is the referee the guidance has to pass: if a player who trusts the
banner completely cannot move the story from a beat's opening state, the
banner is wrong there, whatever the beat's hint prose says.

    python3 🍄/🧪/banner_follow.py village_stirs mill_wakes     # some beats
    python3 🍄/🧪/banner_follow.py --campaign demos --jobs 3     # every beat
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import hashlib
import json
import re
import shutil
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "🍄" / "🎛️"
sys.path.insert(0, str(RUNNER))
sys.path.insert(0, str(ROOT / "tools" / "campaign"))
import spec as S  # noqa: E402

KEY_RE = re.compile(r"\[([^\]\s]{1,8})\]")
SHIFT_RE = re.compile(r"shift\s*\+?\s*\[([^\]\s]{1,8})\]", re.I)
STUCK_AFTER = 8
WAIT_SECONDS = 3.0
WAIT_CAP = 60          # three minutes of real time per beat
PRESS_CAP = 150
# The keys a keyboard player has (player_seat.ALLOWED_KEYS, by name).
KEYNAMES = {"esc": "escape", "space": "space", "enter": "enter", "tab": "tab",
            "↑": "up", "↓": "down", "←": "left", "→": "right"}


def parse_keys(line: str) -> list:
    """Every pressable key the line names, in reading order — a literal
    player reads "📖 [X], Arc [I], Accept [R]" as three presses."""
    out, pos = [], 0
    for m in re.finditer(r"((?:(?:ctrl|shift)\s*\+?\s*)*)\[([^\]\s]{1,8})\]", line, re.I):
        t = KEYNAMES.get(m.group(2).strip().lower(), m.group(2).strip().lower())
        mods = m.group(1).lower()
        if len(t) == 1 or t in KEYNAMES.values():
            out.append((("ctrl+" if "ctrl" in mods else "") + t, "shift" in mods))
    if not out and re.search(r"\bESC\b", line):
        out.append(("escape", False))
    return out


def parse_key(line: str):
    """First pressable key the line names, as (key, shift) — or None."""
    m = SHIFT_RE.search(line)
    if m:
        return m.group(1).lower(), True
    for tok in KEY_RE.findall(line):
        t = tok.strip().lower()
        t = KEYNAMES.get(t, t)
        if len(t) == 1 or t in KEYNAMES.values():
            return t, False
    if re.search(r"\bESC\b", line):
        return "escape", False
    return None


class Follower:
    def __init__(self, rig):
        self.rig = rig
        self.n = 0

    def t(self, action, timeout=60, **kw):
        self.n += 1
        return self.rig.run_turn(self.n, action, timeout_s=timeout, **kw)

    def banner(self) -> list[str]:
        r = self.t("overlay_text", under="BannerLines")
        lines = [str(x.get("text", "")).strip() for x in r.get("lines", []) if isinstance(x, dict)]
        return [ln for ln in lines if ln]

    def toasts(self) -> list[str]:
        r = self.t("overlay_text", under="HintToastStack")
        return [str(x.get("text", "")).strip() for x in r.get("lines", [])
                if isinstance(x, dict) and str(x.get("text", "")).strip()][:6]

    def story(self):
        flags = set((self.t("story_flags").get("flags_fired", {}) or {}).keys())
        qs = self.t("active_quests", full=True).get("quests", []) or []
        led = self.t("quest_ledger")
        claimed = [q for q in (led.get("completed", []) or []) if isinstance(q, dict)]
        return flags, qs, claimed

    def signature(self, banner, qs):
        w = self.t("resource_snapshot").get("resources", {})
        prog = [(q.get("id"), round(float(q.get("progress", 0) or 0), 2), q.get("status")) for q in qs]
        blob = json.dumps([banner, prog, sorted((k, int(v)) for k, v in w.items() if isinstance(v, (int, float)))],
                          ensure_ascii=False, sort_keys=True, default=str)
        return hashlib.sha1(blob.encode()).hexdigest()[:12]


# Keys that are honest as the FIRST press of a line on each kind of surface.
# A line that starts with anything else names a key of a menu you don't
# have open — the toast/menu mismatch the surface graph exists to prevent.
MENU_KEYS = set("TYUIO") | set("GHJKL;'") | {"A", "D", "R", "Q", "E", "F", "C", "X", "ESCAPE", "1", "2", "3"}
SUBMENU_KEYS = {"Q", "E", "R", "F", "ESCAPE"}


def check_surface(f, line: str, rep: dict) -> None:
    """Record lines whose first key isn't valid where the player stands, and
    visible toasts that name keys of a surface the player has left."""
    g = f.t("guide_step")
    here = str(g.get("surface", "field"))
    for t in g.get("stale_toasts", []) or []:
        rep.setdefault("stale_toasts", []).append({"surface": here, "toast": t})
    ks = parse_keys(line)
    if not ks:
        return
    first = ks[0][0].upper()
    ok = True
    if here.startswith("X/") or here.startswith("C/"):
        ok = first in MENU_KEYS
    elif here.startswith("menu:"):
        ok = first == "ESCAPE"
    elif here in ("field:icon", "field:gate", "field:confirm"):
        ok = first in SUBMENU_KEYS
    if not ok:
        rep.setdefault("off_surface", []).append({"surface": here, "line": line[:140]})
    # On the field, a line that labels a hat verb ("Explore [F]") must name
    # what that key fires now (the chip resolver), not what it fires elsewhere.
    chips = g.get("chips", {}) or {}
    # Only a verb that acts on the plot and hat already in hand can be judged
    # before the line's own earlier keys (a plot, a hat) are pressed.
    if "plot [" in line or "hat [" in line or "close [" in line:
        chips = {}
    for label, key in re.findall(r"([A-Za-z][A-Za-z ]+?) \[([QERF])\]", line):
        chip = chips.get(key, {})
        want = label.strip().split()[-1].lower()
        have = (str(chip.get("label", "")) + " " + str(chip.get("action", ""))).lower()
        if chip and want in ("explore", "strike", "gather", "track", "incorporate") and want not in have:
            # The first frame after a boot or a surface change can read the
            # chip before its resolver settles; only a mismatch that survives
            # a second look is the player's.
            time.sleep(0.4)
            again = (f.t("guide_step").get("chips", {}) or {}).get(key, {})
            have = (str(again.get("label", "")) + " " + str(again.get("action", ""))).lower()
            if again and want not in have:
                rep.setdefault("verb_mismatch", []).append({"line": line[:140], "key": key, "chip": again})


def follow(rig, beat: str, cap: int = PRESS_CAP) -> dict:
    f = Follower(rig)
    r = f.t("start_at_beat", id=beat, wait_frames=300, timeout=240)
    rep = {"beat": beat, "fixture_ok": bool(r.get("ok")), "fired": r.get("fired"),
           "presses": 0, "outcome": None, "trail": [], "toasts_seen": []}
    if not r.get("ok"):
        rep["outcome"] = "fixture_failed"
        rep["why"] = r.get("error")
        return rep
    f.t("press_key", key="escape", settle_frames=4)  # start from the field, no menu open
    flags0, qs, claimed0 = f.story()
    fired_ids0 = set(flags0)
    claimed_ids0 = {str(q.get("id")) for q in claimed0}
    rep["contract_claims"] = 0
    rep["accepted"] = False
    same, last_sig, seen_lines, waits = 0, None, [], 0
    for i in range(cap):
        banner = f.banner()
        line = banner[0] if banner else ""
        for tx in f.toasts():
            if tx not in rep["toasts_seen"]:
                rep["toasts_seen"].append(tx)
        flags, qs, claimed = f.story()
        new_flags = sorted(set(flags) - fired_ids0)
        new = [q for q in claimed if str(q.get("id")) not in claimed_ids0]
        beat_claim = [q for q in new if q.get("source_flag") == beat]
        rep["contract_claims"] = sum(1 for q in new if not q.get("source_flag"))
        if any(q.get("source_flag") == beat for q in qs):
            rep["accepted"] = True
        if new_flags or beat_claim:
            rep["outcome"] = "moved"
            rep["moved_by"] = {"flags": new_flags, "beat_claimed": bool(beat_claim)}
            break
        if not line:
            rep["outcome"] = "no_banner"
            break
        ks = parse_keys(line)
        k = ks[0] if ks else None
        if k is None and re.search(r"\bwait\b", line, re.I) and waits < WAIT_CAP:
            # The banner says the game needs time, not a press: a trusting
            # player waits. Time is budgeted separately from presses.
            waits += 1
            time.sleep(WAIT_SECONDS)
            continue
        if k is None:
            rep["outcome"] = "no_key"
            rep["why"] = line
            break
        sig = f.signature(banner, qs)
        same = same + 1 if sig == last_sig else 0
        last_sig = sig
        seen_lines.append(line)
        if same >= STUCK_AFTER:
            rep["outcome"] = "stuck"
            rep["why"] = line
            break
        recent = seen_lines[-16:]
        if len(recent) == 16 and len(set(recent)) <= 2 and i > 30 and rep["contract_claims"] == 0:
            rep["outcome"] = "loop"
            rep["why"] = " ⇄ ".join(sorted(set(recent)))
            break
        check_surface(f, line, rep)
        for key, shift in ks:
            f.t("press_key", key=key, shift=shift, settle_frames=12)
            rep["presses"] += 1
        if len(rep["trail"]) < 40:
            rep["trail"].append({"banner": line[:120],
                                 "keys": " ".join(("shift+" if sh else "") + k for k, sh in ks)})
        time.sleep(0.15)
    rep["waits"] = waits
    if rep["outcome"] is None:
        rep["outcome"] = "cap"
    return rep


JOURNEY_WAIT_CAP = 300  # seconds on one unchanging wait line before a journey calls it a wall
LOOP_WINDOW = 40  # a journey whose last 40 lines are one or two lines, with no flag, is looping


def journey(rig, start: str, minutes: float = 30.0, until: str = "") -> dict:
    """Start at one beat's fixture and keep following the banner across beats:
    how far does trusting the banner take you? Stops when the banner and the
    game stop changing (STUCK_AFTER presses) or after `minutes`."""
    f = Follower(rig)
    rep = {"start": start, "fired": [], "presses": 0, "waits": 0, "stopped": None, "why": None,
           "trail": [], "lines": {}}
    if start != "fresh":  # "fresh": a new game, no fixture — Act 0 onward
        r = f.t("start_at_beat", id=start, wait_frames=300, timeout=240)
        if not r.get("ok"):
            rep["stopped"] = "fixture_failed"
            return rep
    f.t("press_key", key="escape", settle_frames=4)
    seen = set((f.t("story_flags").get("flags_fired", {}) or {}).keys())
    t_end = time.time() + minutes * 60
    same, last_sig = 0, None
    idle, last_wait = 0, None
    while time.time() < t_end:
        banner = f.banner()
        line = banner[0] if banner else ""
        flags = set((f.t("story_flags").get("flags_fired", {}) or {}).keys())
        for fid in sorted(flags - seen):
            rep["fired"].append({"flag": fid, "press": rep["presses"], "t": round(time.time() - t_end + minutes * 60)})
        if flags - seen:
            same = 0
        seen |= flags
        if until and until in seen:
            rep["stopped"], rep["why"] = "reached", until
            break
        if not line:
            rep["stopped"], rep["why"] = "no_banner", ""
            break
        ks = parse_keys(line)
        if not ks and re.search(r"\bwait\b", line, re.I):
            rep["waits"] += 1
            idle = idle + 1 if line == last_wait else 1
            last_wait = line
            if idle * WAIT_SECONDS > JOURNEY_WAIT_CAP:
                rep["stopped"], rep["why"] = "waiting", line
                break
            time.sleep(WAIT_SECONDS)
            continue
        idle, last_wait = 0, None
        if not ks:
            rep["stopped"], rep["why"] = "no_key", line
            break
        qs = f.t("active_quests", full=True).get("quests", []) or []
        sig = f.signature(banner, qs)
        same = same + 1 if sig == last_sig else 0
        last_sig = sig
        if same >= STUCK_AFTER:
            rep["stopped"], rep["why"] = "stuck", line
            break
        check_surface(f, line, rep)
        for key, shift in ks:
            f.t("press_key", key=key, shift=shift, settle_frames=12)
            rep["presses"] += 1
        rep["lines"][line] = rep["lines"].get(line, 0) + 1
        rep["trail"] = (rep["trail"] + [line[:120]])[-80:]
        since = rep["presses"] - (rep["fired"][-1]["press"] if rep["fired"] else 0)
        if since > LOOP_WINDOW and len(set(rep["trail"][-LOOP_WINDOW:])) <= 2:
            rep["stopped"], rep["why"] = "loop", " ⇄ ".join(sorted(set(rep["trail"][-LOOP_WINDOW:])))
            # Why: the resolver's own account on both sides of the loop.
            g = f.t("guide_step")
            rep["loop_guide"] = [{"live_beat": g.get("live_beat"), "step": g.get("step"),
                                  "trace": g.get("trace"), "explain": g.get("explain")}]
            break
        time.sleep(0.15)
    if rep["stopped"] is None:
        rep["stopped"] = "time"
    rep["last_banner"] = line
    return rep


def run_one(beat: str, cap: int, chain_minutes: float = 0.0, until: str = "") -> dict:
    from rig_client import RigClient  # noqa: E402
    xdg = Path(tempfile.mkdtemp(prefix="sw_follow_%s_" % beat))
    rig = RigClient(xdg=xdg, root_from_file=RUNNER / "milk_hunt_runner.py")
    rig.clear_rig_files()
    proc = rig.start_listener(scenario_id="demos_normal", display_mode="headless",
                              allow_resource_injection=False, listener_stdout="null",
                              rig_log_profile="quiet",
                              extra_env={"RIG_UNLOCK_ALL": "0", "RIG_QUEUE_POLL_MS": "60"})
    t0 = time.time()
    try:
        if not RigClient.wait_for_bridge_sentinel(timeout_s=240, xdg=rig.xdg_root):
            return {"beat": beat, "outcome": "boot_failed"}
        rep = journey(rig, beat, chain_minutes, until) if chain_minutes > 0 else follow(rig, beat, cap)
    except Exception as exc:  # report, never hide
        rep = {"beat": beat, "outcome": "error", "why": repr(exc)[:300]}
    finally:
        RigClient.terminate_listener(proc, timeout_s=5.0)
        shutil.rmtree(xdg, ignore_errors=True)
    rep["seconds"] = round(time.time() - t0, 1)
    return rep


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("beats", nargs="*")
    ap.add_argument("--campaign", default="")
    ap.add_argument("--jobs", type=int, default=1)
    ap.add_argument("--cap", type=int, default=PRESS_CAP)
    ap.add_argument("--out", default="")
    ap.add_argument("--journey", type=float, default=0.0,
                    help="minutes: from each named beat, keep following across beats")
    ap.add_argument("--until", default="", help="journey: stop once this story flag fires (e.g. island_free)")
    args = ap.parse_args(argv)
    beats = list(args.beats)
    if args.campaign:
        beats += [b["id"] for c, _a, _ch, b in S.iter_beats(S.load()) if c["id"] == args.campaign]
    results = []
    with cf.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as ex:
        for rep in ex.map(lambda b: run_one(b, args.cap, args.journey, args.until), beats):
            results.append(rep)
            if args.journey:
                print(json.dumps({k: rep.get(k) for k in ("start", "stopped", "why", "presses", "waits")},
                                 ensure_ascii=False), flush=True)
                print("  fired:", " → ".join("%s@%ds" % (x["flag"], x["t"]) for x in rep.get("fired", [])), flush=True)
                print("  off-surface lines: %d, stale toasts: %d, verb mismatches: %d" % (len(rep.get("off_surface", [])),
                      len(rep.get("stale_toasts", [])), len(rep.get("verb_mismatch", []))), flush=True)
                continue
            print(json.dumps({k: rep.get(k) for k in ("beat", "outcome", "presses", "waits", "accepted", "contract_claims",
                                                      "why", "moved_by", "seconds")},
                             ensure_ascii=False), flush=True)
    if args.out:
        Path(args.out).write_text(json.dumps(results, ensure_ascii=False, indent=1), encoding="utf-8")
    moved = sum(1 for r in results if r.get("outcome") == "moved")
    print("moved %d of %d" % (moved, len(results)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
