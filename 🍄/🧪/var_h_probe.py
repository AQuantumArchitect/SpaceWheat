#!/usr/bin/env python3
"""Var(H) smoke test — validate the closed-native chaos↔stability observable.

Confirms three things the whole campaign rework rests on:
  1. Var(H) = ⟨H²⟩−⟨H⟩² is alive and DISCRIMINATES between biomes (not constant).
  2. Var(H) is CONSERVED under unitary evolution (≈ unchanged across a time_skip).
  3. The OPEN-system relaxation quantities are DEGENERATE in the closed system:
     purity ≡ 1.0 and ρ-eigenvalue_gap ≡ 1.0 — i.e. biome_eigenvalue_gap_gte /
     biome_purity_trending always-pass and cannot express chaos vs. stability.
"""
import os, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
_turn = [0]
def t(): _turn[0] += 1; return _turn[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    def go(a, **k):
        k.pop("timeout_s", None); return c.run_turn(t(), a, timeout_s=90, **k)
    PLOT = ["G", "H", "J", "K", "L", "SEMICOLON"]
    def grid():
        g = go("grid_snapshot").get("grid", {}); return g.get("biomes", g)
    def ev(bn):
        return go("energy_variance", biome=bn)
    def press(seq, s=3):
        if isinstance(seq, str): seq = [seq]
        for k in seq: c.run_turn(t(), "press_key", key=k, settle_frames=s, timeout_s=25)
    def qn(bn):
        return len(go("berry_state", biome=bn).get("qubits", []) or [])
    def row(bn, tag=""):
        r = ev(bn)
        print("%-16s %10.4f %8.4f %8.3f %8.3f   %s" % (
            bn, r.get("var_h", -1), r.get("h_gap", -1), r.get("purity", -1),
            r.get("eigenvalue_gap", -1), tag))
        return r

    try:
        c.wait_for_ready(proc, timeout_s=180)
        biomes = grid()
        print("biomes:", biomes)
        hdr = "\n%-16s %10s %8s %8s %8s   %s" % ("biome", "Var(H)", "H-gap", "purity", "ρ-gap", "note")
        print(hdr)
        gaps = {}
        for bn in biomes:
            r = row(bn, "(ground state)")
            gaps[bn] = r.get("h_gap", -1.0)

        # H-gap is the composition-intrinsic stability measure — should DISCRIMINATE
        # across biomes (different Hamiltonians) and NOT move under evolution.
        vals = sorted(set(round(v, 3) for v in gaps.values() if v >= 0))
        print("\nRESULT H-gap discriminating:",
              "OK (%d distinct: %s)" % (len(vals), vals) if len(vals) > 1 else "FLAT (investigate)")

        if biomes:
            b0 = biomes[0]
            print("\n-- disturb %s (Druid-rotate all plots), then re-read --" % b0)
            press(b0[0] if False else "G", 2)  # ensure a plot context exists is handled below
            # Select biome b0, Druid hat (0), rotate each plot to push the state off the eigenstate.
            press("0", 2)
            for pk in PLOT[:qn(b0)]:
                press(pk, 2); press("E", 2)
            go("time_skip", phrames=200)
            r_before = row(b0, "(disturbed)")
            gap_b = r_before.get("h_gap", -1.0)
            go("time_skip", phrames=600)
            r_after = row(b0, "(disturbed +600)")
            print("\nVar(H) after disturbance:", r_before.get("var_h"),
                  "→ rose from 0" if r_before.get("var_h", 0) > 1e-4 else "→ still ~0 (composition gave eigenstate?)")
            print("H-gap stable under evolution: before=%.4f after=%.4f drift=%.5f" % (
                gap_b, r_after.get("h_gap", -1), abs(gap_b - r_after.get("h_gap", gap_b))))

        # Degeneracy of open-system quantities.
        if biomes:
            r0 = ev(biomes[0])
            pur_deg = abs(r0.get("purity", 0.0) - 1.0) < 0.02
            gap_deg = abs(r0.get("eigenvalue_gap", 0.0) - 1.0) < 0.05
            print("RESULT open-system degenerate:",
                  "CONFIRMED (purity≡1, ρ-gap≡1)" if (pur_deg and gap_deg)
                  else f"NOT as expected (purity={r0.get('purity')}, ρ-gap={r0.get('eigenvalue_gap')})")
    finally:
        go("stop"); c.terminate_listener(proc)


if __name__ == "__main__":
    main()
