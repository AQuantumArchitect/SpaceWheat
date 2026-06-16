#!/usr/bin/env python3
"""Closed-system rig edge-case test: live r=1, blocked drives, harvest, regeneration.

Boots the full game headlessly via the rig and exercises the closed-system invariants
that an isolated --script can't (native Eigen matrix only syncs ρ under a full boot)."""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))  # 🍄/🎛️
from rig_client import RigClient  # noqa: E402

P = 0
F = 0


def check(label, cond, detail=""):
    global P, F
    mark = "✅" if cond else "❌"
    if cond:
        P += 1
    else:
        F += 1
    print(f"  {mark} {label}{(' — ' + detail) if detail else ''}")


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless")
    try:
        c.wait_for_ready(proc, timeout_s=120)
        print("\n─── CLOSED-SYSTEM RIG EDGE CASES ───")

        # (1) LIVE r=1 + L-axis collapse via reservoir_sweep ------------------
        sweep = c.run_turn(1, "reservoir_sweep", h_scales=[1.0], l_scales=[0.5, 1.0, 2.0],
                           phrames=200, timeout_s=180).get("reservoir_sweep", [])
        check("reservoir_sweep returns rows", len(sweep) > 0, f"{len(sweep)} rows")
        # Closed mode forces l_scales=[1.0] → only 1 row despite 3 L values requested.
        check("L axis collapsed to 1 point in closed mode", len(sweep) == 1, f"{len(sweep)} rows")
        if sweep:
            row = sweep[0]
            order = float(row.get("order", -1))
            rich = float(row.get("richness", -1))
            check("order (purity) ≈ 1.0 — every bubble pure (r=1)", order > 0.999,
                  f"order={order:.5f}")
            print(f"     richness(S)={rich:.4f}  integration(MI)={float(row.get('integration', 0)):.4f}")
            # ≥0.997: essentially pure. Any residual below 1.0 is bounded Euler-integrator
            # drift over the evolution window (NOT a Lindblad leak — there are no dissipators).
            for b in row.get("biomes", []):
                check(f"  {b.get('biome')} pure (r=1)", float(b.get("purity", 0)) >= 0.997,
                      f"purity={float(b.get('purity', 0)):.5f}")

        # (2) Dissipative drives are blocked (rig/API bypass guard) -----------
        pump = c.run_turn(2, "lindblad_pump", biome="StarterForest", positions=[[0, 0]], timeout_s=30)
        pr = pump.get("pump_result", pump)
        check("lindblad_pump blocked in closed mode",
              pr.get("error") == "closed_system" or pr.get("blocked") is True, json.dumps(pr)[:120])
        drain = c.run_turn(3, "lindblad_drain", biome="StarterForest", positions=[[0, 0]], timeout_s=30)
        dr = drain.get("drain_result", drain)
        check("lindblad_drain blocked in closed mode",
              dr.get("error") == "closed_system" or dr.get("blocked") is True, json.dumps(dr)[:120])

        # (3) Harvest loop: victory_lap measures+pops everything (no drain) ----
        before = c.run_turn(4, "resource_snapshot", timeout_s=30).get("resources", {}).get("resources", {})
        vl = c.run_turn(5, "victory_lap", timeout_s=120)
        after = c.run_turn(6, "resource_snapshot", timeout_s=30).get("resources", {}).get("resources", {})
        gained = {k: after.get(k, 0) - before.get(k, 0) for k in set(after) | set(before)
                  if after.get(k, 0) - before.get(k, 0) != 0}
        check("victory_lap succeeds", vl.get("victory_lap", {}).get("success", False) or vl.get("ok", False),
              json.dumps(vl.get("victory_lap", vl))[:140])
        check("harvest yields resources (measurement IS the economy)", len(gained) > 0, f"Δ={gained}")

        # (4) Regeneration: collapse → time_skip (H re-spreads) → purity still 1
        c.run_turn(7, "time_skip", phrames=300, timeout_s=60)
        sweep2 = c.run_turn(8, "reservoir_sweep", h_scales=[1.0], l_scales=[1.0],
                            phrames=120, timeout_s=120).get("reservoir_sweep", [])
        if sweep2:
            order2 = float(sweep2[0].get("order", -1))
            rich2 = float(sweep2[0].get("richness", -1))
            check("post-harvest purity still ≈1 (unitary holds r=1)", order2 > 0.999, f"order={order2:.5f}")
            check("entropy regenerates under H (richness>0 after re-spread)", rich2 > 0.0,
                  f"richness={rich2:.4f}")

        print(f"\n📊 Results: {P} passed, {F} failed")
        print("✅ ALL CLOSED-SYSTEM RIG CHECKS PASSED" if F == 0 else "❌ SOME RIG CHECKS FAILED")
    finally:
        try:
            c.run_turn(999, "stop", timeout_s=10)
        except Exception:
            pass
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
