#!/usr/bin/env python3
"""Headed: verify REGISTER-FIRST bubbles + in-place measure/harvest.

Register bubbles exist from boot but start HIDDEN (reveal-on-first-touch
exploration): a fresh field is DARK, and the cursor landing on a plot wakes its
bubble permanently. R (measure) flips the SELECTED bubble to a frozen cyan-ringed
readout WITHOUT spawning a new bubble or disturbing the others. Q (harvest)
returns that bubble to live. This probe captures four shots so we can eyeball
each stage:

  rf_boot.png      — DARK field: no plot focused yet, so no bubbles revealed
  rf_select.png    — plot 0 selected → its bubble blooms in (others still dark)
  rf_measure.png   — after R: selected bubble cyan-ringed
  rf_harvest.png   — after Q: selected bubble back to live

Prints instrument_state at each stage + the absolute shot paths.
"""
import sys
import shutil
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
    log_path = HERE.parent.parent / "logs" / "register_first_listener.log"
    out_dir = HERE.parent.parent / "logs"
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            listener_log_path=log_path, rig_log_profile="debug",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0", "RIG_SKIP_WELCOME": "0"})
    try:
        ready = c.wait_for_ready(proc, timeout_s=200)
        print("ready:", ready)

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=25, **kw)

        def press(k, shift=False, settle=4):
            return t("press_key", key=k, shift=shift, settle_frames=settle)

        def istate():
            return t("instrument_state")

        def shot(name):
            r = t("screenshot", path="user://rig/%s.png" % name, settle_frames=4)
            sc = r.get("screenshot", {})
            abs_path = sc.get("abs", "")
            print("shot %s -> saved=%s abs=%s" % (name, sc.get("saved"), abs_path))
            if abs_path and Path(abs_path).exists():
                shutil.copy(abs_path, out_dir / ("%s.png" % name))
                print("  copied to logs/%s.png" % name)
            return r

        # Dismiss welcome, settle into live view
        press("f"); press("f"); press("f", settle=10)

        # BOOT: bubbles must already be present (register-first) with NO strike.
        print("instrument BOOT:", istate())
        shot("rf_boot")

        # Make the registers visually interesting (spread), then select plot 0.
        hg = t("gate_inject", gate="hadamard", biome="StarterForest", positions=[])
        print("hadamard ok:", hg.get("ok"))
        press("g", settle=6)
        shot("rf_select")

        # MEASURE: R flips the selected bubble in place.
        print("strike R:", press("r", settle=12).get("ok"))
        print("instrument AFTER R:", istate())
        shot("rf_measure")

        # HARVEST: Q returns the bubble to live.
        print("harvest Q:", press("q", settle=12).get("ok"))
        print("instrument AFTER Q:", istate())
        shot("rf_harvest")
    finally:
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
