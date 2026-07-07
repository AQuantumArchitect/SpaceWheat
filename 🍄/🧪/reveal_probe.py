#!/usr/bin/env python3
"""Headed: verify the exploration reveal + the first_breath boot race + toast layering.

Drives the PLAYER path (title -> F -> welcome -> dismiss) on a fresh demos_normal
game — the exact route the owner playtests — then asserts, in order:

  1. ZERO campaign flags fired before any action (first_breath boot-race regression;
     tutorial_seen is a marker, not a campaign flag).
  2. The bubble field is DARK at boot: bubbles exist but none are visible
     (reveal-on-first-touch).
  3. Selecting plots with G / H / J wakes exactly those bubbles, one per press.
  4. save_game -> load_game round-trips the revealed set.
  5. A toast fired while the QuestBoard overlay is open renders ON TOP (eyeball
     shot rv_toast.png — toast stack z_index above all overlay tiers).

Shots land in logs/: rv_boot.png (dark), rv_select3.png (3 bubbles), rv_toast.png.
Exits nonzero on any assert failure.
"""
import sys
import shutil
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    log_path = HERE.parent.parent / "logs" / "reveal_listener.log"
    out_dir = HERE.parent.parent / "logs"
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            listener_log_path=log_path, rig_log_profile="quiet",
                            extra_env={"RIG_DRIVE_TITLE": "1", "RIG_SKIP_WELCOME": "0"})
    failures = []

    def check(cond, msg):
        tag = "PASS" if cond else "FAIL"
        print(f"[{tag}] {msg}")
        if not cond:
            failures.append(msg)

    try:
        ready = c.wait_for_ready(proc, timeout_s=200)
        print("ready:", ready)

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=30, **kw)

        def press(k, settle=6):
            return t("press_key", key=k, settle_frames=settle)

        def shot(name):
            r = t("screenshot", path="user://rig/%s.png" % name, settle_frames=4)
            abs_path = r.get("screenshot", {}).get("abs", "")
            if abs_path and Path(abs_path).exists():
                shutil.copy(abs_path, out_dir / ("%s.png" % name))
                print("shot %s -> logs/%s.png" % (name, name))
            return r

        # --- The player path: title -> start -> welcome -> dismiss (any key). ---
        started = t("start_from_title", keys=["F"], settle_frames=12)
        info = started.get("start_from_title", {})
        check(bool(info.get("farm")), "title path boots to a live farm")
        press("f", settle=10)  # dismiss welcome splash

        # --- 1. Boot-race regression: no campaign flag may be fired yet. ---
        flags = t("story_flags").get("flags_fired", {})
        campaign = [f for f in flags if f != "tutorial_seen"]
        check(not campaign, f"no campaign flags fired pre-action (got {campaign or 'none'})")

        # --- 2. Dark field: bubbles exist, none visible, nothing revealed. ---
        bs = t("bubble_state")
        check(bs.get("bubble_count", 0) > 0, f"register bubbles exist ({bs.get('bubble_count')})")
        check(bs.get("visible_count", -1) == 0, f"field is dark at boot (visible={bs.get('visible_count')})")
        check(bs.get("revealed_plots") == [], "revealed set empty at boot")
        shot("rv_boot")

        # --- 3. Selection reveals, one bubble per touch. ---
        for i, key in enumerate(("g", "h", "j"), start=1):
            press(key)
            bs = t("bubble_state")
            check(bs.get("visible_count") == i,
                  f"after {key.upper()}: {i} bubble(s) visible (got {bs.get('visible_count')})")
        shot("rv_select3")

        # --- 3b. Biome SWITCH must not reveal (leak regression: the repoint path
        #     carried the slot letter into the new biome and woke its bubble). ---
        press("y")  # switch to the 2nd biome slot
        bs = t("bubble_state")
        check(bs.get("visible_count") == 3,
              f"biome switch reveals nothing (visible={bs.get('visible_count')})")
        press("g")  # deliberate pick in the new biome DOES reveal
        bs = t("bubble_state")
        check(bs.get("visible_count") == 4,
              f"deliberate pick in new biome reveals (visible={bs.get('visible_count')})")
        press("t")  # back to the first biome for the save/load leg
        bs = t("bubble_state")
        check(bs.get("visible_count") == 4,
              f"switching back reveals nothing (visible={bs.get('visible_count')})")

        # --- 4. Persistence: save -> load keeps the revealed set. ---
        saved = t("save_game", slot=0)
        check(bool(saved.get("saved")), "save_game slot 0")
        loaded = t("load_game", slot=0)
        check(bool(loaded.get("loaded")), "load_game slot 0")
        shot("rv_reload")  # settle frames: lazy bubble seed after the restart
        bs = {}
        for _ in range(10):  # restart rebuilds the force graph lazily — poll briefly
            bs = t("bubble_state")
            if bs.get("visible_count") == 4 and len(bs.get("revealed_plots", [])) == 4:
                break
            time.sleep(0.5)
        check(bs.get("visible_count") == 4 and len(bs.get("revealed_plots", [])) == 4,
              f"4 revealed after reload (visible={bs.get('visible_count')}, "
              f"revealed={len(bs.get('revealed_plots', []))})")

        # --- 5. Toast above the QuestBoard overlay (eyeball shot). ---
        press("c", settle=8)  # QuestBoard
        t("toast", text="[b]TOAST LAYER TEST[/b] — must render above this overlay", importance=3)
        shot("rv_toast")
        press("escape", settle=6)
    finally:
        c.terminate_listener(proc)

    print("\n%d failure(s)" % len(failures))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
