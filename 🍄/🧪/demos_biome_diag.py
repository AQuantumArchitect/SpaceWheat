#!/usr/bin/env python3
"""Diagnose TheDemos biome QC state via rig instrument."""
import sys, time
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient
from turn_driver import TurnDriver

_driver = TurnDriver(start=0)
t = _driver.t

def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    try:
        c.wait_for_ready(proc, timeout_s=180)
        time.sleep(0.5)

        # Check biome state for TheDemos
        r = c.run_turn(t(), "biome_state", biome="TheDemos", timeout_s=30)
        print("TheDemos biome_state:", r)

        # Check grid snapshot
        r2 = c.run_turn(t(), "grid_snapshot", timeout_s=30)
        print("\ngrid_snapshot:", r2)

        # Navigate to TheDemos (U key) and check berry_state
        c.run_turn(t(), "press_key", key="U", settle_frames=5, timeout_s=15)
        r3 = c.run_turn(t(), "berry_state", biome="TheDemos", timeout_s=30)
        print("\nTheDemos berry_state:", r3)

        # Check known_icons
        r4 = c.run_turn(t(), "known_icons", timeout_s=30)
        print("\nknown_icons:", r4)

    finally:
        c.run_turn(t(), "stop", timeout_s=10)
        c.terminate_listener(proc)

if __name__ == "__main__":
    main()
