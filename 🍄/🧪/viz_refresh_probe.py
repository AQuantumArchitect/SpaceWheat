#!/usr/bin/env python3
"""Does a discrete ρ-mutation (gate inject) refresh the viz projection WITHOUT an
evolution tick? Pre-fix the viz cache lagged (stale until the next tick, which never
comes while paused). Headless, live C++, no time_skip between inject and read.
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "1")  # buffering off → no background tick
_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "1"})
    try:
        c.wait_for_ready(proc, timeout_s=180)

        def bloch():
            r = c.run_turn(turn(), "viz_bloch", biome="StarterForest", timeout_s=20)
            return r.get("qubits", [])

        before = bloch()
        print("before gate:", [(q["qubit"], round(q["cache_z"], 4), round(q["live_z"], 4)) for q in before])

        # Discrete mutation: Hadamard register 0. NO time_skip after.
        hg = c.run_turn(turn(), "gate_inject", gate="hadamard", biome="StarterForest",
                        positions=[], timeout_s=20)
        print("hadamard ok:", hg.get("ok"))

        after = bloch()
        print("after gate :", [(q["qubit"], round(q["cache_z"], 4), round(q["live_z"], 4)) for q in after])

        # Pass criteria: cache_z tracks live_z after the gate (projection refreshed),
        # AND the state actually changed (so we know the gate did something).
        max_drift = max((abs(q["cache_z"] - q["live_z"]) for q in after), default=1.0)
        changed = any(abs(a["cache_z"] - b["cache_z"]) > 1e-6
                      for a, b in zip(after, before))
        print(f"\nmax |cache_z - live_z| after gate = {max_drift:.6f}  (want ~0 → projection fresh)")
        print(f"cache changed by the gate = {changed}  (want True → not frozen)")
        if max_drift < 1e-6 and changed:
            print("RESULT: PASS — viz projection refreshes on discrete mutation (no tick needed)")
        else:
            print("RESULT: FAIL")
            sys.exit(1)
    finally:
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
