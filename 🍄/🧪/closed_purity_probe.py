#!/usr/bin/env python3
"""Decompose the purity shortfall: init (thermal Gibbs) vs Euler drift over evolution."""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402


def order_of(c, turn, phrames):
    rows = c.run_turn(turn, "reservoir_sweep", h_scales=[1.0], l_scales=[1.0],
                      phrames=phrames, timeout_s=180).get("reservoir_sweep", [])
    if not rows:
        return None
    r = rows[0]
    return (float(r.get("order", -1)), float(r.get("richness", -1)))


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless")
    try:
        c.wait_for_ready(proc, timeout_s=120)
        print("\n─── PURITY DECOMPOSITION (order = mean purity) ───")
        for ph in [1, 50, 200, 800]:
            res = order_of(c, ph, ph)
            if res:
                print(f"  phrames={ph:4d}  purity={res[0]:.5f}  richness={res[1]:.4f}")
    finally:
        try:
            c.run_turn(999, "stop", timeout_s=10)
        except Exception:
            pass
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
