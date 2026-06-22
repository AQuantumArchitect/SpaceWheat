#!/usr/bin/env python3
"""#125: does Ace Strike (R/measure) + Extract (Q/pop) yield resources on the
live closed substrate? Headless, live C++. Reads the wallet before/after.
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def wallet(c):
    r = c.run_turn(turn(), "resource_snapshot", timeout_s=20)
    res = r.get("resources", {})
    # snapshot may nest {ordered:[...], resources:{...}}
    if isinstance(res, dict) and "resources" in res:
        res = res["resources"]
    return {k: v for k, v in res.items()} if isinstance(res, dict) else {}


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    try:
        c.wait_for_ready(proc, timeout_s=180)

        def istate():
            return c.run_turn(turn(), "instrument_state", timeout_s=20)

        def press(k, shift=False):
            return c.run_turn(turn(), "press_key", key=k, shift=shift, timeout_s=20)

        # Strike from a clean ground state so Hadamard gives exactly p=0.5 (max
        # surprisal). Skipping evolution first would leave an off-eigenstate where
        # H-then-strike lands at an arbitrary, often near-certain, probability.
        print("init:", istate())
        press("G")  # select plot 0 (also enters plot ring)
        print("after G:", istate())

        # Put the register in genuine superposition (p≈0.5) so the strike carries
        # real surprisal — otherwise a near-ground-state register collapses to a
        # near-certain outcome (recorded_prob≈1 → surprisal≈0 → reward floor 1).
        # empty positions → all biome registers get the Hadamard (superposition)
        hg = c.run_turn(turn(), "gate_inject", gate="hadamard", biome="StarterForest",
                        positions=[], timeout_s=20)
        print("hadamard inject ok:", hg.get("ok"), hg.get("gate_result", {}))

        w0 = wallet(c)
        print("wallet before:", w0)

        r_strike = press("R")  # Strike = measure (collapse)
        print("Strike(R) press resp ok:", r_strike.get("ok"))
        w1 = wallet(c)
        print("wallet after Strike:", w1)

        r_extract = press("Q")  # Extract = pop (cash out)
        print("Extract(Q) press resp ok:", r_extract.get("ok"))
        w2 = wallet(c)
        print("wallet after Extract:", w2)

        # delta
        keys = set(w0) | set(w2)
        delta = {k: w2.get(k, 0) - w0.get(k, 0) for k in keys if w2.get(k, 0) != w0.get(k, 0)}
        print("NET wallet delta (Strike+Extract):", delta if delta else "NONE")
    finally:
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
