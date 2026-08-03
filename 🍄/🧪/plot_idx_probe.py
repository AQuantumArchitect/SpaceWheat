#!/usr/bin/env python3
"""Does pressing each plot key (G..SEMICOLON) land the cursor on the matching plot index,
including index 5 (the empty injection slot for a 5-qubit biome)? Reads instrument_state
(current_plot_idx + cursor_layer + in_submenu) after each press."""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402
from turn_driver import TurnDriver  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
PLOT = ["G", "H", "J", "K", "L", "SEMICOLON"]
# Historical per-script driver timeouts — deliberately NOT unified (SLOP_PATROL knot #8).
GO_TIMEOUT_S = 90
PRESS_TIMEOUT_S = 25
PRESS_SETTLE_FRAMES = 4

_driver = TurnDriver(start=10)


t = _driver.t


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})

    go = _driver.make_go(c, timeout_s=GO_TIMEOUT_S)

    press = _driver.make_press(c, settle_frames=PRESS_SETTLE_FRAMES, timeout_s=PRESS_TIMEOUT_S)

    def qstate(bn):
        return go("berry_state", biome=bn).get("qubits", [])

    def biome_key(name):
        for s in go("biome_slots").get("slots", []):
            if s.get("biome") == name:
                return s.get("key")
        return None

    def ist():
        s = go("instrument_state")
        return f"plot_idx={s.get('current_plot_idx')} cursor_layer={s.get('cursor_layer')} biome={s.get('current_biome')} in_submenu={s.get('in_submenu')}"

    def ensure_hat(h):
        other = "7" if h != "7" else "8"
        press(other, 2); press(h, 2)

    try:
        c.wait_for_ready(proc, timeout_s=180)
        vk = biome_key("Village") or "Y"
        press(vk, 4)
        print(f"Village qubits: {len(qstate('Village'))}")
        ensure_hat("5")  # Icon hat
        print("Icon hat. Pressing each plot key, reading cursor:")
        for pk in PLOT:
            press(pk, 4)
            print(f"  press {pk:10s} → {ist()}")
        print("\nNow press SEMICOLON then R (inject on empty plot index 5):")
        press("SEMICOLON", 4)
        print(f"  after SEMICOLON: {ist()}")
        press("R", 5)
        print(f"  after R:         {ist()}")
        sm = go("submenu_state")
        print(f"  submenu_state: in_submenu={sm.get('in_submenu')} slots={list((sm.get('slots') or {}).keys())}")
        # also try selecting via the rig's direct plot-select helper for comparison
        print("\nTry rig select_plot(5) if available:")
        r = go("select_plot", plot_idx=5)
        print(f"  select_plot(5): {r.get('select_plot', r)}")
        print(f"  state: {ist()}")
        press("R", 5)
        sm2 = go("submenu_state")
        print(f"  after R: in_submenu={sm2.get('in_submenu')} slots={list((sm2.get('slots') or {}).keys())}")
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
