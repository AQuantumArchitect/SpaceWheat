#!/usr/bin/env python3
"""Headed: the STRANGER test — a zero-context player with only a mouse.

Simulates someone who just downloaded the game and never reads a manual:
every interaction is a left-click (rig `tap`). No keyboard, ever. The probe
walks the real first-session path:

  title → (click) → system menu → (click F chip: play) → welcome splash →
  (click) → dismissed → (click a bubble) → measured → (click it again) →
  paid → (click ⏸ chip) → paused → (click ▶) → resumed

Any stall here is a launch-blocking P0: this is the first ten minutes for
the mouse/touch-primary audience.

Shots: stranger_title.png, stranger_menu.png, stranger_welcome.png,
       stranger_loop.png
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
    log_path = HERE.parent.parent / "logs" / "stranger_mouse_listener.log"
    out_dir = HERE.parent.parent / "logs"
    proc = c.start_listener(
        scenario_id="demos_normal", display_mode="headed",
        listener_log_path=log_path, rig_log_profile="debug",
        extra_env={
            "RIG_SKIP_WELCOME": "0",   # the stranger sees the real splash
            "RIG_DRIVE_TITLE": "1",    # and the real title screen
        })
    failures = []
    try:
        ready = c.wait_for_ready(proc, timeout_s=200)
        print("ready:", ready)

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=30, **kw)

        def check(cond, label):
            print(("PASS " if cond else "FAIL ") + label)
            if not cond:
                failures.append(label)

        def shot(name):
            r = t("screenshot", path="user://rig/%s.png" % name, settle_frames=4)
            sc = r.get("screenshot", {})
            abs_path = sc.get("abs", "")
            if abs_path and Path(abs_path).exists():
                shutil.copy(abs_path, out_dir / ("%s.png" % name))
            return r

        def chip_center(name):
            r = t("control_rect", name=name)
            if r.get("ok", True) and r.get("center") and r.get("visible"):
                return r["center"]
            return None

        def click(screen_xy, settle=12, label=""):
            r = t("tap", screen=list(screen_xy), settle_frames=settle)
            if label:
                print("click %s -> %s" % (label, r.get("tapped")))
            return r

        def bubbles():
            bs = t("bubble_state")
            return bs.get("bubbles", []) if isinstance(bs, dict) else []

        def wallet():
            rs = t("resource_snapshot")
            res = rs.get("resources", {})
            if isinstance(res, dict) and "resources" in res:
                res = res["resources"]
            return dict(res) if isinstance(res, dict) else {}

        # ---- 1. Title: a click must lead somewhere ----------------------
        shot("stranger_title")
        click((640, 360), settle=16, label="title")
        menu_r = t("control_rect", name="EscapeMenu")
        check(bool(menu_r.get("visible")), "title click opens the menu")
        shot("stranger_menu")

        # ---- 2. Menu: click the [F] play chip to start ------------------
        play_chip = chip_center("MenuVerb_F")
        check(play_chip is not None, "menu has a clickable [F] play chip")
        if play_chip is not None:
            click(play_chip, settle=30, label="[F] play chip")
        # Honest signal that the CLICK booted the game: the title layer hides.
        time.sleep(4.0)
        title_after = t("control_rect", name="TitleLayer")
        check(not title_after.get("visible", True), "clicking [F] play actually starts the game")
        # Bind the rig's farm/shell refs WITHOUT pressing any key (keys=[]
        # only resolves; the game is already running from the click).
        sft = t("start_from_title", keys=[], settle_frames=10)
        started = sft.get("start_from_title", {})
        check(bool(started.get("farm")), "farm resolves after the mouse-only boot")

        # ---- 3. Welcome splash: any click dismisses ----------------------
        shot("stranger_welcome")
        wc = chip_center("WelcomeOverlay")
        if wc is not None:
            click((640, 360), settle=12, label="welcome dismiss")
            wc_after = t("control_rect", name="WelcomeOverlay")
            check(not wc_after.get("visible", False), "welcome splash dismissed by click")
        else:
            print("note: welcome overlay not visible (dismissed earlier or headless-onboarded)")

        # ---- 4. The loop, one finger: click bubble → measure → pop ------
        # Three-beat rhythm: on an untouched farm the first tap WAKES the
        # plot (reveal), the second measures, the third harvests. Take any
        # bubble anchor — visible or asleep — like a curious stranger would.
        all_b = bubbles()
        vis = [b for b in all_b if b.get("visible")] or all_b
        check(bool(vis), "a bubble anchor exists to click with zero keyboard input")
        if vis:
            pos = vis[0]["pos"]
            click_r = t("tap", pos=pos, settle_frames=16)
            print("bubble tap1:", click_r.get("tapped"))
            after1 = [b for b in bubbles() if b.get("pos") == pos]
            b1 = after1[0] if after1 else None
            if b1 is not None and not b1.get("measured"):
                # three-beat rhythm: first tap may only WAKE an unrevealed plot
                t("tap", pos=pos, settle_frames=16)
                after1 = [b for b in bubbles() if b.get("pos") == pos]
                b1 = after1[0] if after1 else None
            check(bool(b1 and b1.get("measured")), "clicking a bubble measures it")

            w_before = wallet()
            t("tap", pos=pos, settle_frames=16)
            after2 = [b for b in bubbles() if b.get("pos") == pos]
            b2 = after2[0] if after2 else None
            w_after = wallet()
            gained = {k: int(w_after.get(k, 0)) - int(w_before.get(k, 0))
                      for k in set(w_before) | set(w_after)
                      if int(w_after.get(k, 0)) > int(w_before.get(k, 0))}
            check(bool(b2 is not None and not b2.get("measured")), "second click harvests (back to live)")
            check(bool(gained), "harvest paid out (gained: %s)" % (gained,))
            shot("stranger_loop")

        # ---- 5. Pause chip: mouse players must be able to pause ---------
        pc = chip_center("FpsDisplay")
        check(pc is not None, "time-flow chip (pause) is on screen")
        if pc is not None:
            click(pc, settle=8, label="pause chip")
            click(pc, settle=8, label="resume chip")

    finally:
        c.terminate_listener(proc)

    print("\n%s — %d failure(s)" % ("GREEN" if not failures else "RED", len(failures)))
    for f in failures:
        print("  FAIL:", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
