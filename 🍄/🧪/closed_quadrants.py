#!/usr/bin/env python3
"""Verify physics isolation across the four (coherent × dissipative) quadrants.

⚠️ KNOWN GAP (Phase 4b, task #78): since Phase 4 routed the rig through the C++ backend,
this test exposes that a RUNTIME dissipation-ON switch (the sweep flipping modes) doesn't
yet propagate L to the native engine — full-open shows purity 1.0 instead of mixing. This
is a research-tool / open-DLC-runtime-switch scenario, NOT shipping (shipping closed mode,
set once at boot, is fully correct through C++ — see closed_rig_test.py 11/11). Passed
through the GDScript reference path pre-Phase-4. Fix = replace-engine-slot on re-register.


The discriminator is purity (order): coherent-only must be EXACTLY pure (r=1); any mode
with dissipation on must MIX (purity < 1). Proves the two generators are independently
switchable and the game behaves correctly in the absence of either."""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

P = F = 0


def check(label, cond, detail=""):
    global P, F
    print(f"  {'✅' if cond else '❌'} {label}{(' — ' + detail) if detail else ''}")
    if cond:
        P += 1
    else:
        F += 1


def sweep(c, turn, coherent, dissipative):
    rows = c.run_turn(turn, "reservoir_sweep", h_scales=[1.0], l_scales=[1.0], phrames=300,
                      coherent=coherent, dissipative=dissipative, timeout_s=180).get("reservoir_sweep", [])
    if not rows:
        return None
    r = rows[0]
    return float(r.get("order", -1)), float(r.get("richness", -1))


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless")
    try:
        c.wait_for_ready(proc, timeout_s=120)
        print("\n─── FOUR-QUADRANT PHYSICS ISOLATION ───")

        pc = sweep(c, 1, True, False)   # pure coherent (the default game)
        fo = sweep(c, 2, True, True)    # full open  (H + L)
        pd = sweep(c, 3, False, True)   # pure dissipative (H off, L on)
        fr = sweep(c, 4, False, False)  # frozen (neither)

        for name, r in [("pure-coherent", pc), ("full-open", fo), ("pure-dissipative", pd), ("frozen", fr)]:
            print(f"  {name:18s}  purity={r[0]:.5f}  richness={r[1]:.4f}" if r else f"  {name}: no data")

        if pc:
            check("coherent-only is exactly pure (r=1)", pc[0] > 0.9995, f"purity={pc[0]:.5f}")
        if fo:
            check("full-open mixes (dissipation breaks purity)", fo[0] < 0.999, f"purity={fo[0]:.5f}")
        if pd:
            check("pure-dissipative mixes (L acts with H off)", pd[0] < 0.999, f"purity={pd[0]:.5f}")
        if pc and pd:
            check("coherent vs pure-dissipative are distinct regimes",
                  abs(pc[1] - pd[1]) > 1e-4 or abs(pc[0] - pd[0]) > 1e-3,
                  f"coh richness={pc[1]:.3f} vs diss {pd[1]:.3f}")

        print(f"\n📊 Results: {P} passed, {F} failed")
        print("✅ ISOLATION VERIFIED" if F == 0 else "❌ ISOLATION CHECK FAILED")
    finally:
        try:
            c.run_turn(999, "stop", timeout_s=10)
        except Exception:
            pass
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
