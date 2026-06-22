#!/usr/bin/env python3
"""Does Berry phase accumulate now that integrate_step is wired? And do
ground-state qubits precess enough to ripen? Headless, live C++.

Tracks all StarterForest qubits, then time-skips in chunks reading per-qubit
accumulated phase. If phase grows → integrator wired (A fixed). If it stays ~0 →
qubits don't precess from ground state (issue B, design question).
"""
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    print("== boot headless, live C++ ==")
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    try:
        c.wait_for_ready(proc, timeout_s=180)
        time.sleep(1.0)

        def berry(label):
            r = c.run_turn(turn(), "berry_state", biome="StarterForest", timeout_s=20)
            qs = r.get("qubits") or []
            phases = [round(q["phase"], 3) for q in qs]
            ripe = [q["qubit"] for q in qs if q.get("ripe")]
            print(f"[{label}] phases={phases} ripe={ripe} "
                  f"consumed_count={r.get('consumed_count')} consumed_phase={round(r.get('consumed_phase', 0), 3)}")
            return qs

        berry("baseline")

        # Excite qubits OFF the drift axis so they precess under H.
        gate = os.environ.get("BERRY_GATE", "rotate_up")
        positions = [[i, 0] for i in range(5)]
        r = c.run_turn(turn(), "gate_inject", gate=gate, biome="StarterForest",
                       positions=positions, timeout_s=30)
        print(f"gate_inject {gate} ->", (r.get("gate_result") or {}).get("success", r.get("error", r)))

        r = c.run_turn(turn(), "berry_track", biome="StarterForest", timeout_s=20)
        print("berry_track ->", r.get("tracked"))
        berry("after_track")

        for chunk in range(1, 6):
            c.run_turn(turn(), "time_skip", phrames=200, timeout_s=90)
            berry(f"after_skip_{chunk*200}")
    finally:
        c.run_turn(99999, "stop", timeout_s=10)
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
