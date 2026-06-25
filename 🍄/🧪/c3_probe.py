#!/usr/bin/env python3
"""C3 verification: discorporate (V/Q) + bookmark (V/R) on the Qubit Atlas.

Incorporate one icon in StarterForest (signature 1->2), open V, select it on the
Lexicon frame, press Q to Discorporate, and confirm the signature shrank back.
Then confirm the last-voice guard refuses to discorporate the final pair.
"""
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
    def qstate(bn): return go("berry_state", biome=bn).get("qubits", [])
    def ensure_hat(h):
        other = "7" if h != "7" else "8"; press(other, 2); press(h, 2)
    try:
        c.wait_for_ready(proc, timeout_s=180)
        print("sig@start:", known())
        # Incorporate one icon in StarterForest to reach signature >= 2.
        bn = "StarterForest"
        qs = qstate(bn); plots = PLOT[:len(qs)] if qs else PLOT
        ensure_hat("0")
        for pk in plots: press(pk, 3); press("E", 3)
        ensure_hat("5")
        trk = [bool(q.get("tracked")) for q in qstate(bn)]
        for i, pk in enumerate(plots):
            if i < len(trk) and not trk[i]: press(pk, 3); press("F", 3)
        go("time_skip", phrames=900)
        for pk in plots: press(pk, 3); press("R", 4)
        sig_before = known()
        print(f"sig after incorporate ({len(sig_before)}):", sig_before)
        # Open V (Qubit Atlas) via the V key (engages the shell overlay_stack so QERF
        # route to the overlay), Lexicon frame (T).
        press("V", 4)
        print("atlas snapshot:", go("overlay_snapshot", overlay="atlas").get("snapshot"))
        press("T", 3)
        # Walk the first few item slots; pick one that is a KNOWN pair, then Q.
        n_before = len(known())
        for pk in ["G", "H", "J", "K", "L"]:
            press(pk, 3); press("Q", 4)
            if len(known()) < n_before:
                break
        sig_after = known()
        ok_disc = len(sig_after) < n_before
        print(f"sig after Discorporate ({len(sig_after)}):", sig_after)
        print("RESULT discorporate:", "OK (signature shrank)" if ok_disc else "FAIL (no change)")
        # Last-voice guard: try to discorporate down to empty — should stop at 1.
        guard_n = len(known())
        for pk in PLOT:
            press(pk, 3); press("Q", 3)
        final = known()
        print(f"after greedy discorporate ({len(final)}):", final)
        print("RESULT last-voice guard:", "OK (kept >=1)" if len(final) >= 1 else "FAIL (emptied)")
        # Bookmark toggle (R) doesn't change signature; just confirm no crash + sig stable.
        bn2 = len(known())
        press("R", 4)
        print("RESULT bookmark (no sig change):", "OK" if len(known()) == bn2 else "FAIL")
    finally:
        go("stop"); c.terminate_listener(proc)

if __name__ == "__main__":
    main()
