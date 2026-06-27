#!/usr/bin/env python3
"""Diagnose the market: is it engagement-gated (populates as you engage) or broken?
Reads board_market for StarterForest at boot, after growing signature, and after
discovering a biome — to confirm behavior and inform the tutorial-offer seed."""
import os, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
PLOT = ["G", "H", "J", "K", "L", "SEMICOLON"]
_turn = [0]
def t(): _turn[0] += 1; return _turn[0]

def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    def go(a, **k):
        k.pop("timeout_s", None); return c.run_turn(t(), a, timeout_s=90, **k)
    def press(seq, s=4):
        if isinstance(seq, str): seq = [seq]
        for k in seq: c.run_turn(t(), "press_key", key=k, settle_frames=s, timeout_s=25)
    def known(): return go("known_icons").get("icons", []) or []
    def grid():
        g = go("grid_snapshot").get("grid", {}); return g.get("biomes", g)
    def mkt(bn):
        r = go("board_market", biome=bn)
        return r.get("scope", "?"), r.get("count", -1), (r.get("offers") or [])[:3]
    def qstate(bn): return go("berry_state", biome=bn).get("qubits", [])
    try:
        c.wait_for_ready(proc, timeout_s=180)
        bn = "StarterForest"
        sc, n, off = mkt(bn)
        print(f"BOOT  sig={len(known())} market[{bn}] scope={sc} count={n}")
        # Also check which factions are admitted to StarterForest at boot.
        rd = go("realization_debug", biome=bn)
        print(f"  StarterForest native_factions={rd.get('native_factions')}")
        # Grow signature: incorporate from StarterForest.
        qs = qstate(bn); plots = PLOT[:len(qs)] if qs else PLOT
        press("0", 2)
        for pk in plots: press(pk, 3); press("E", 3)
        press("5", 2)
        trk = [bool(q.get("tracked")) for q in qstate(bn)]
        for i, pk in enumerate(plots):
            if i < len(trk) and not trk[i]: press(pk, 3); press("F", 3)
        go("time_skip", phrames=900)
        for pk in plots: press(pk, 3); press("R", 4)
        sc, n, off = mkt(bn)
        print(f"AFTER-incorp sig={len(known())} market[{bn}] scope={sc} count={n}")
        # Discover a biome → check market for it + StarterForest.
        press("7", 2); press("R", 6)
        g = grid()
        print(f"  grid after discover: {g}")
        for b in g:
            sc, n, off = mkt(b)
            print(f"  market[{b}] scope={sc} count={n}")
    finally:
        go("stop"); c.terminate_listener(proc)

if __name__ == "__main__":
    main()
