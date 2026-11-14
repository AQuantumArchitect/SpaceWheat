#!/usr/bin/env python3
"""Perturbed walk: banner_follow's trusting player, who also does things the
tutorial never asked for.

banner_follow presses exactly what the banner names, in the order the spec
expects, so it never meets a state the guide did not plan for. A human does
what the banner says AND pokes around: explores a plot they were not told to,
swaps hats, tracks a loop early, opens menus, accepts a contract, pauses time.
This walk injects those deviations (keys only, nothing a keyboard player could
not press) between banner steps, from a seeded RNG, and records where the
banner stops being able to lead the player on.

  python3 perturbed_walk.py --seed 3 --minutes 20 --rate 0.2 --until island_free

A stall is the same vocabulary banner_follow uses (stuck, loop, no_key,
no_banner, waiting). Every stall gets a diagnosis: the guide's own account, the
live quests, the wallet, the last deviations, and whether ESC-ing out clears it
(a recoverable stall) or not (a soft lock).
"""
from __future__ import annotations

import argparse
import json
import random
import re
import shutil
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import banner_follow as bf  # noqa: E402
from banner_follow import Follower, RUNNER, parse_keys, check_surface  # noqa: E402

sys.path.insert(0, str(RUNNER))
from rig_client import RigClient  # noqa: E402

PLOTS = list("ghjkl;")
HATS = list("45678890")  # spark icon merchant captain ace operator druid (digits as the keymap has them)

# Each deviation is a name and a list of (key, shift) presses.
def deviations(rng: random.Random) -> list[tuple[str, list[tuple[str, bool]]]]:
    p = lambda: rng.choice(PLOTS)
    h = lambda: rng.choice(list("456789") + ["0"])
    return [
        ("explore_a_plot", [("8", False), (p(), False), ("f", False)]),
        ("strike_a_plot", [("8", False), (p(), False), ("r", False)]),
        ("gather_a_plot", [("8", False), (p(), False), ("q", False)]),
        ("mass_explore", [("8", False), ("f", True)]),
        ("pause_time", [("8", False), ("e", False)]),
        ("faster_clock", [("=", False)]),
        ("slower_clock", [("-", False)]),
        ("track_early", [("5", False), (p(), False), ("f", False)]),
        ("incorporate_try", [("5", False), (p(), False), ("r", False)]),
        ("druid_poke", [("0", False), (p(), False), (rng.choice(["e", "q", "r"]), False)]),
        ("wear_a_hat", [(h(), False)]),
        ("select_a_plot", [(p(), False)]),
        ("mark_two_plots", [(p(), True), (p(), True)]),
        ("clear_marks", [("'", False)]),
        ("open_x_menu", [("x", False), (rng.choice(list("tyuio")), False)]),
        ("open_board", [("c", False), (rng.choice(list("tyu")), False)]),
        ("board_accept_first", [("c", False), ("y", False), ("g", False), ("r", False)]),
        ("board_abandon_first", [("c", False), ("u", False), ("g", False), ("q", False), ("f", False)]),
        ("arc_accept_first", [("x", False), ("y", False), ("g", False), ("r", False)]),
        ("reap_season", [("8", False), ("ctrl+f", True)]),
        ("travel_a_biome", [(rng.choice(list("tyu")), False)]),
        ("random_keys", [(rng.choice(list("qerf") + PLOTS + list("456789")), False) for _ in range(3)]),
        ("escape", [("escape", False)]),
        # Anything a hat can do, sometimes with the confirm chord: Cull Biome,
        # Trim Icon, Break, Add Biome, Import/Export, gauge verbs.
        ("hat_verb_roulette", [(h(), False), (p(), False), (rng.choice(list("qerf")), False)]
                              + ([("f", False)] if rng.random() < 0.5 else [])),
        ("hat_verb_roulette", [(h(), False), (p(), False), (rng.choice(list("qerf")), False),
                               (rng.choice(list("qer")), False)]),
        ("mode_switch", [(h(), False), (rng.choice(list("123")), False)]),
        ("arc_dismiss_first", [("x", False), ("y", False), ("g", False), ("q", False)]),
        ("arc_dismiss_row", [("x", False), ("y", False), (p(), False), ("q", False), ("f", False)]),
        ("charge_claim_row", [("x", False), ("u", False), (p(), False), ("r", False)]),
    ]


def snapshot(f: Follower) -> dict:
    g = f.t("guide_step")
    qs = f.t("active_quests", full=True).get("quests", []) or []
    return {
        "guide": {k: g.get(k) for k in ("live_beat", "live_status", "step", "surface", "hat", "trace", "explain")},
        "quests": [{"id": q.get("id"), "name": q.get("display_name"), "src": q.get("source_flag"),
                    "status": q.get("status"), "progress": round(float(q.get("progress", 0) or 0), 2)} for q in qs],
        "wallet": {k: v for k, v in (f.t("resource_snapshot").get("resources", {}) or {}).items()
                   if isinstance(v, (int, float)) and v},
        "banner": f.banner()[:3],
    }


VERB_RE = re.compile(r"([A-Za-z]+) \[([QERF])\]\s*$")


def reads_wrong_check(f: Follower, line: str, ks: list, rep: dict) -> int:
    """Menus must show the verb the banner is about to ask for. On an X or C
    surface, a line ending `<Verb> [R]` (Accept, Claim, Deliver) is checked
    against the menu's own text BEFORE the verb key is pressed: if the chip
    does not read that verb, the banner and the menu disagree — the player
    presses R and gets "nothing on R here". The row keys are pressed first so
    the chip reflects the selected row."""
    m = VERB_RE.search(line.strip())
    if not m or len(ks) < 2:
        return 0
    here = str(f.t("guide_step").get("surface", ""))
    if not (here.startswith("X/") or here.startswith("C/")):
        return 0
    verb, vkey = m.group(1), m.group(2)
    if ks[-1][0] != vkey.lower():
        return 0
    for key, shift in ks[:-1]:
        f.t("press_key", key=key, shift=shift, settle_frames=12)
        rep["presses"] += 1
    time.sleep(0.5)
    under = "ControlsOverlay" if here.startswith("X/") else "QuestBoard"
    texts = [str(x.get("text", "")) for x in f.t("overlay_text", under=under).get("lines", [])]
    ok = any(verb.lower() in t.lower() and vkey in t for t in texts)
    rep["verb_checks"] = rep.get("verb_checks", 0) + 1
    if not ok:
        rep.setdefault("reads_wrong", []).append({"t": rep.get("presses"), "line": line[:100], "surface": here,
                                                   "menu_text": texts[:24]})
    return len(ks) - 1   # the row keys are pressed; the caller presses the verb


def walk(rig, seed: int, minutes: float, rate: float, until: str, start: str, save_dir: str = "") -> dict:
    rng = random.Random(seed)
    f = Follower(rig)
    rep = {"seed": seed, "rate": rate, "fired": [], "presses": 0, "deviations": [], "stopped": None,
           "why": None, "n_dev": 0}
    if start != "fresh":
        r = f.t("start_at_beat", id=start, wait_frames=300, timeout=240)
        if not r.get("ok"):
            rep["stopped"] = "fixture_failed"
            return rep
    f.t("press_key", key="escape", settle_frames=4)
    seen = set((f.t("story_flags").get("flags_fired", {}) or {}).keys())
    t0 = time.time()
    t_end = t0 + minutes * 60
    same, last_sig = 0, None
    idle, last_wait = 0, None
    steps_since_flag = 0
    trail: list[str] = []
    while time.time() < t_end:
        banner = f.banner()
        line = banner[0] if banner else ""
        flags = set((f.t("story_flags").get("flags_fired", {}) or {}).keys())
        for fid in sorted(flags - seen):
            rep["fired"].append({"flag": fid, "press": rep["presses"], "t": round(time.time() - t0)})
        if flags - seen:
            same, steps_since_flag = 0, 0
        seen |= flags
        if until and until in seen:
            rep["stopped"], rep["why"] = "reached", until
            break
        stall = None
        ks = parse_keys(line) if line else []
        if not line:
            stall = ("no_banner", "")
        elif not ks and re.search(r"\bwait\b", line, re.I):
            rep["presses"] += 0
            idle = idle + 1 if line == last_wait else 1
            last_wait = line
            if idle * bf.WAIT_SECONDS > bf.JOURNEY_WAIT_CAP:
                stall = ("waiting", line)
            else:
                time.sleep(bf.WAIT_SECONDS)
                continue
        elif not ks:
            stall = ("no_key", line)
        else:
            idle, last_wait = 0, None
            qs = f.t("active_quests", full=True).get("quests", []) or []
            sig = f.signature(banner, qs)
            same = same + 1 if sig == last_sig else 0
            last_sig = sig
            if same >= bf.STUCK_AFTER:
                stall = ("stuck", line)
            trail = (trail + [line[:100]])[-bf.LOOP_WINDOW:]
            if steps_since_flag > bf.LOOP_WINDOW and len(set(trail)) <= 2:
                stall = ("loop", " ⇄ ".join(sorted(set(trail))))
        if stall:
            kind, why = stall
            diag = snapshot(f)
            if save_dir:
                sp = str(Path(save_dir) / ("stall_seed%d_%s_t%d.tres" % (seed, kind, int(time.time() - t0))))
                rep["stall_save"] = f.t("save_game_path", path=sp).get("path", sp)
            # Is it a soft lock, or does getting out of the way clear it?
            for _ in range(2):
                f.t("press_key", key="escape", settle_frames=8)
            time.sleep(0.5)
            after = f.banner()
            line2 = after[0] if after else ""
            recovered = bool(parse_keys(line2)) and line2 != line
            rep.update({"stopped": kind, "why": why, "diagnosis": diag,
                        "after_escape": line2[:140], "recoverable_by_escape": recovered,
                        "last_deviations": rep["deviations"][-12:]})
            if recovered:
                # keep walking: the stall was a menu the deviation left open
                rep.setdefault("recovered_stalls", []).append({"kind": kind, "why": why[:140],
                                                               "t": round(time.time() - t0)})
                rep["stopped"], rep["why"] = None, None
                for k in ("diagnosis", "after_escape", "recoverable_by_escape", "last_deviations"):
                    rep.pop(k, None)
                same, last_sig, idle = 0, None, 0
                continue
            break
        # a deviation, sometimes, before obeying the banner
        if rng.random() < rate:
            name, keys = rng.choice(deviations(rng))
            rep["deviations"].append({"press": rep["presses"], "t": round(time.time() - t0),
                                      "name": name, "keys": " ".join(("shift+" if s else "") + k for k, s in keys),
                                      "banner": line[:90]})
            rep["n_dev"] += 1
            for key, shift in keys:
                f.t("press_key", key=key, shift=shift, settle_frames=10)
                rep["presses"] += 1
            time.sleep(0.1)
            banner = f.banner()
            line = banner[0] if banner else ""
            ks = parse_keys(line) if line else []
            if not ks:
                steps_since_flag += 1
                continue
        check_surface(f, line, rep)
        done = reads_wrong_check(f, line, ks, rep)
        gs = f.t("guide_step")
        pre = {"line": line[:90], "surface": gs.get("surface"), "hat": gs.get("hat")}
        for key, shift in ks[done:]:
            f.t("press_key", key=key, shift=shift, settle_frames=12)
            rep["presses"] += 1
        gs2 = f.t("guide_step")
        pre["after_surface"] = gs2.get("surface")
        us = f.t("ui_stack")
        if "Claim" in line:
            r = f.t("overlay_text", under="ControlsOverlay")
            pre["ctl"] = [str(x.get("text"))[:60] for x in r.get("lines", [])][:22]
        pre["stack"] = [("%s%s" % (e.get("name"), "" if e.get("visible") else "(hidden)")) for e in us.get("stack", [])]
        pre["toasts"] = [t[:80] for t in f.toasts()[:2]]
        rep.setdefault("steps", []).append(pre)
        rep["steps"] = rep["steps"][-30:]
        steps_since_flag += 1
        time.sleep(0.12)
    if rep["stopped"] is None:
        rep["stopped"] = "time"
    rep["seconds"] = round(time.time() - t0)
    rep["last_banner"] = line
    return rep


def run(seed: int, minutes: float, rate: float, until: str, start: str, save_dir: str = "") -> dict:
    xdg = Path(tempfile.mkdtemp(prefix="sw_perturb_%d_" % seed))
    rig = RigClient(xdg=xdg, root_from_file=RUNNER / "milk_hunt_runner.py")
    rig.clear_rig_files()
    proc = rig.start_listener(scenario_id="demos_normal", display_mode="headless",
                              allow_resource_injection=False, listener_stdout="null",
                              rig_log_profile="quiet",
                              extra_env={"RIG_UNLOCK_ALL": "0", "RIG_QUEUE_POLL_MS": "60"})
    try:
        if not RigClient.wait_for_bridge_sentinel(timeout_s=240, xdg=rig.xdg_root):
            return {"seed": seed, "stopped": "boot_failed"}
        return walk(rig, seed, minutes, rate, until, start, save_dir)
    except Exception as exc:  # report, never hide
        return {"seed": seed, "stopped": "error", "why": repr(exc)[:300]}
    finally:
        RigClient.terminate_listener(proc, timeout_s=5.0)
        shutil.rmtree(xdg, ignore_errors=True)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--minutes", type=float, default=20.0)
    ap.add_argument("--rate", type=float, default=0.2, help="chance of a deviation before each banner step")
    ap.add_argument("--until", default="island_free")
    ap.add_argument("--start", default="fresh")
    ap.add_argument("--out", default="")
    ap.add_argument("--save-dir", default="", help="save the game here when a walk stalls")
    a = ap.parse_args(argv)
    rep = run(a.seed, a.minutes, a.rate, a.until, a.start, a.save_dir)
    text = json.dumps(rep, ensure_ascii=False, indent=1, default=str)
    if a.out:
        Path(a.out).write_text(text, encoding="utf-8")
    fired = " → ".join("%s@%ss" % (x["flag"], x["t"]) for x in rep.get("fired", []))
    print(json.dumps({k: rep.get(k) for k in ("seed", "stopped", "why", "presses", "n_dev", "seconds",
                                               "recoverable_by_escape")}, ensure_ascii=False))
    print("fired:", fired[-400:])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
