#!/usr/bin/env python3
"""Verify first_breath fires on the FIRST incorporation (sig 1→2), not at boot.
Boot (sig 1) → first_breath not fired, low score. Incorporate one icon (sig→2) → fires."""
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
    def fp(): return go("flag_progress", id="first_breath")
    def qstate(bn): return go("berry_state", biome=bn).get("qubits", [])
    try:
        c.wait_for_ready(proc, timeout_s=180)
        bn = "StarterForest"
        sig0 = len(known()); fp0 = fp()
        print(f"BOOT sig={sig0} first_breath fired={fp0.get('fired')} comb={fp0.get('comb')}")
        # One incorporation cycle (Druid excite → Icon track → evolve → Icon R).
        qs = qstate(bn); plots = PLOT[:len(qs)] if qs else PLOT
        press("0", 2)
        for pk in plots: press(pk, 3); press("E", 3)
        press("5", 2)
        trk = [bool(q.get("tracked")) for q in qstate(bn)]
        for i, pk in enumerate(plots):
            if i < len(trk) and not trk[i]: press(pk, 3); press("F", 3)
        go("time_skip", phrames=900)
        for pk in plots: press(pk, 3); press("R", 4)
        sig1 = len(known()); fp1 = fp()
        print(f"AFTER incorporate sig={sig1} first_breath fired={fp1.get('fired')} comb={fp1.get('comb')}")
        ok = (not fp0.get("fired")) and sig1 > sig0 and fp1.get("fired")
        print("RESULT first_breath fires on first incorporation:", "OK" if ok else "CHECK")
    finally:
        go("stop"); c.terminate_listener(proc)

if __name__ == "__main__":
    main()
