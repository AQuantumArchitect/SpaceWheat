#!/usr/bin/env python3
"""Drive "The Demos" campaign end-to-end in a headed game and catalog gaps.

Boots the rig headed (real window, opengl3 on WSLg) on the live C++ engine
(RIG_DISABLE_LOOKAHEAD=0, as-shipped) and plays the campaign through the same
keyboard→game stack a human hits: Ace-hat harvest (R Strike / Q Extract),
F/time_skip to advance physics, Captain-hat biome discovery, QuestBoard for
quests. After each batch it polls story_flags + resources + active_quests,
screenshots, and writes a JSON state trail. The goal is to reach `ledger_opens`
(Act 5, final) or hit a clearly-documented wall.

Vantage keymap (post L1-L4):
  hats   4 Spark(locked) 5 Icon 6 Merchant(locked) 7 Captain 8 Ace 9 Operator 0 Druid
  submode 1 2 3   biomes T Y U I O P   plots G H J K L ;   crawl W A S D
  Ace verbs  Q Extract  E Pause  R Strike  F Fast-Fwd
  menu ring  Z X C V B N M  (C = quest pipeline)   time-scale - =   ESC unwind

Env:
  RIG_DISABLE_LOOKAHEAD  0 = live C++ (default here), 1 = GDScript stepper
  PT_SCENARIO            scenario id (default: demos_normal)
  CAMPAIGN_MAX_ROUNDS    harvest/advance rounds before giving up (default 40)
"""
import json
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))  # 🍄/🎛️
from rig_client import RigClient  # noqa: E402

SHOTS = HERE / "playthrough_shots"
SHOTS.mkdir(exist_ok=True)
SCEN = os.environ.get("PT_SCENARIO", "demos_normal")
# default to live C++ as-shipped for THIS driver
os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
LOOKAHEAD_ON = os.environ.get("RIG_DISABLE_LOOKAHEAD", "0") == "0"
MAX_ROUNDS = int(os.environ.get("CAMPAIGN_MAX_ROUNDS", "40"))

PLOT_KEYS = ["G", "H", "J", "K", "L", "SEMICOLON"]
BIOME_KEYS = ["T", "Y", "U", "I", "O", "P"]

trail = []        # list of {round, label, story, resources, icons, quests}
errors = []       # (label, detail)
notes = []        # free observations
_turn = [10]


def _t():
    _turn[0] += 1
    return _turn[0]


def press(c, seq, settle=5, label=""):
    """Press a sequence of keys through the real input stack."""
    if isinstance(seq, str):
        seq = [seq]
    for k in seq:
        kspec = k if isinstance(k, dict) else {"key": k}
        kspec.setdefault("settle_frames", settle)
        r = c.run_turn(_t(), "press_key", timeout_s=25, **kspec)
        if not r.get("ok", False) and "press_key" not in r:
            errors.append((label or "press", f"{kspec}: {r.get('error', r)}"))


def shot(c, label):
    safe = "".join(ch if ch.isalnum() else "_" for ch in label)[:48]
    path = f"user://rig/dc_{_turn[0]:03d}_{safe}.png"
    r = c.run_turn(_t(), "screenshot", timeout_s=25, path=path)
    sc = r.get("screenshot") or {}
    if not sc.get("saved"):
        errors.append((label, f"screenshot failed: {r.get('error', r)}"))
        return None
    try:
        dest = SHOTS / Path(sc["abs"]).name
        dest.write_bytes(Path(sc["abs"]).read_bytes())
        return str(dest)
    except Exception as e:
        notes.append(f"{label}: shot at {sc.get('abs')} (copy failed: {e})")
        return sc.get("abs")


def snap(c, action, **kw):
    to = kw.pop("timeout_s", 30)
    return c.run_turn(_t(), action, timeout_s=to, **kw)


def story(c):
    r = snap(c, "story_flags")
    return r.get("flags_fired", {}) or {}, r.get("story_log", []) or []


def resources(c):
    r = snap(c, "resource_snapshot")
    res = r.get("resources")
    # snapshot shape: {"ordered": [...], "resources": {emoji: count}}
    if isinstance(res, dict) and isinstance(res.get("resources"), dict):
        return res["resources"]
    if isinstance(res, dict):
        return res
    rs = r.get("resource_snapshot", {})
    if isinstance(rs, dict) and isinstance(rs.get("resources"), dict):
        return rs["resources"]
    return rs if isinstance(rs, dict) else {}


def quests(c):
    r = snap(c, "active_quests")
    q = r.get("quests")
    return q if isinstance(q, list) else []


def icons(c):
    r = snap(c, "known_icons")
    ic = r.get("icons")
    return ic if isinstance(ic, list) else []


def record(c, round_idx, label):
    flags, log = story(c)
    res = resources(c)
    qs = quests(c)
    ic = icons(c)
    entry = {
        "round": round_idx,
        "label": label,
        "turn": _turn[0],
        "flags_fired": sorted(flags.keys()),
        "n_flags": len(flags),
        "resources": res,
        "n_icons": len(ic),
        "icons": ic,
        "n_quests": len(qs),
        "quests": [
            {"faction": q.get("faction"), "type": q.get("type"),
             "status": q.get("status"), "resource": q.get("resource"),
             "quantity": q.get("quantity")}
            for q in qs
        ],
    }
    trail.append(entry)
    res_str = res
    if isinstance(res, dict):
        res_str = {k: (round(v, 2) if isinstance(v, (int, float)) else v) for k, v in res.items()}
    print(f"[r{round_idx:02d}] {label}: flags={entry['n_flags']}{sorted(flags.keys())} "
          f"icons={entry['n_icons']} quests={entry['n_quests']} res={res_str}")
    return flags


def harvest_round(c, round_idx):
    """One Ace-hat harvest sweep across the active biome's registers + a fast-forward.

    Grammar (verified): R Strike = immediate collapse; Q Extract is DESTRUCTIVE and
    arms a confirm-chord that F commits (any other key cancels). So each register is:
    select → R (strike) → Q (arm extract) → F (confirm extract → reward to inventory).
    """
    press(c, "8", label="ace_hat")          # Ace vantage
    for pk in PLOT_KEYS:
        press(c, pk, settle=3, label=f"select_{pk}")
        press(c, "R", settle=6, label=f"strike_{pk}")   # measure/collapse — immediate
        press(c, "Q", settle=3, label=f"arm_extract_{pk}")  # arm destructive extract
        press(c, "F", settle=5, label=f"confirm_extract_{pk}")  # F confirms → cash out
    # advance time so phase/evolving thresholds accumulate
    press(c, "F", settle=6, label="fast_fwd")           # no pending → fast-forward
    snap(c, "time_skip", phrames=60, timeout_s=60)


def incorporate_round(c, round_idx, ripen_phrames=900):
    """The REAL story-progression loop (Icon hat).

    Story flags read signature_size (=known_icons count) and berries
    (=berry_register consumed_count/phase). Both grow ONLY via icon
    incorporation: Icon frame (5) → select qubit → F (start Berry-phase
    tracking, resumes play) → let time ripen it to ~2π → R (incorporate when
    ripe → +1 signature, +1 berry). The Ace harvest loop does NOT touch these.

    NB: F (not ESCAPE) closes the R injection submenu (QII:227). ESCAPE with
    nothing open pops the system EscapeMenu and derails everything.
    """
    # 0) EXCITE off the ground eigenstate so qubits precess (Druid hat = Hadamard on E).
    #    A ground-state qubit is an H-eigenstate → stationary → never ripens. Hadamard
    #    tips it onto the equator so it traces solid angle under the live Hamiltonian.
    press(c, "0", label="druid_hat")
    for pk in PLOT_KEYS:
        press(c, pk, settle=2, label=f"dsel_{pk}")
        press(c, "E", settle=3, label=f"hadamard_{pk}")  # Druid E = Hadamard
    # 1) start Berry tracking on every register
    press(c, "5", label="icon_hat")
    for pk in PLOT_KEYS:
        press(c, pk, settle=2, label=f"isel_{pk}")
        press(c, "F", settle=3, label=f"track_{pk}")     # toggle Berry track + play
    # 2) ripen — let the Hamiltonian spin the qubits toward 2π
    snap(c, "time_skip", phrames=ripen_phrames, timeout_s=180)
    # 3) incorporate every (hopefully ripe) register
    press(c, "5", settle=1, label="icon_hat2")            # re-enter Icon frame
    for pk in PLOT_KEYS:
        press(c, pk, settle=2, label=f"jsel_{pk}")
        press(c, "R", settle=4, label=f"incorporate_{pk}")  # incorporate if ripe (else opens submenu)
        press(c, "F", settle=3, label=f"close_or_track_{pk}")  # F closes submenu if open (else re-tracks; harmless)


def write_report():
    out = {
        "scenario": SCEN,
        "engine": "live_cpp" if LOOKAHEAD_ON else "gdscript_stepper",
        "rounds": len(trail),
        "final_flags": trail[-1]["flags_fired"] if trail else [],
        "trail": trail,
        "errors": errors,
        "notes": notes,
    }
    p = SHOTS / "campaign_state_trail.json"
    p.write_text(json.dumps(out, indent=2, ensure_ascii=False))
    print(f"\n== wrote state trail → {p} ==")
    print(f"== errors: {len(errors)} ==")
    for e in errors[:30]:
        print("  ERR", e)


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    log_path = c.runner_root / "logs" / "rig_listener.log"
    try:
        log_path.write_text("")
    except OSError:
        pass

    print(f"== boot headed (scenario={SCEN}, engine={'live C++' if LOOKAHEAD_ON else 'stepper'}) ==")
    proc = c.start_listener(
        scenario_id=SCEN,
        display_mode="headed",
        extra_env={
            "RIG_DISABLE_LOOKAHEAD": os.environ.get("RIG_DISABLE_LOOKAHEAD", "0"),
            "RIG_RENDERING_DRIVER": os.environ.get("RIG_RENDERING_DRIVER", "opengl3"),
        },
    )
    try:
        lines = c.wait_for_ready(proc, timeout_s=180)
        print(f"READY ({len(lines)} boot lines)")
        time.sleep(1.5)

        # ---- baseline ----
        shot(c, "00_baseline")
        record(c, 0, "boot_baseline")

        # peek the quest board (C = quest pipeline) so Act-0 tutorial is visible
        press(c, "C", label="questboard_open")
        shot(c, "01_questboard")
        press(c, "ESCAPE", settle=3, label="questboard_close")

        # ---- campaign loop ----
        prev_flags = set(trail[-1]["flags_fired"]) if trail else set()
        for rnd in range(1, MAX_ROUNDS + 1):
            incorporate_round(c, rnd)        # the real story-progression loop
            flags = record(c, rnd, f"incorp_{rnd}")
            if rnd <= 2 or rnd % 4 == 0:
                shot(c, f"round_{rnd:02d}")
            cur = set(flags.keys())
            new = cur - prev_flags
            if new:
                for f in sorted(new):
                    shot(c, f"flag_{f}")
                    notes.append(f"round {rnd}: flag fired → {f}")
                prev_flags = cur
            if "ledger_opens" in cur:
                notes.append(f"REACHED ledger_opens at round {rnd}")
                shot(c, "ZZ_ledger_opens")
                break

        shot(c, "ZZ_final")
        record(c, 999, "final")
    finally:
        write_report()
        c.run_turn(99999, "stop", timeout_s=10)
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
