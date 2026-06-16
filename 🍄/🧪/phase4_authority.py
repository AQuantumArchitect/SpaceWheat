#!/usr/bin/env python3
"""Phase 4 verification: is the canonical evolver now the C++ backend (mode=native),
and does closed-mode purity still hold at 1.0 (C++ exact-unitary running)?

The rig launches with RIG_DISABLE_LOOKAHEAD=1 (set by 🟢.sh). After the Phase-4 decoupling
the BACKEND is set up regardless of that flag (it gates only live buffering), so time-skip
should run through the native C++ engine even here."""
import json
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

P = F = 0


def check(label, cond, detail=""):
    global P, F
    print(f"  {'✅' if cond else '❌'} {label}{(' — ' + detail) if detail else ''}")
    P += 1 if cond else 0
    F += 0 if cond else 1


def find_mode(obj):
    # The evolve_mode may be nested in the time_skip result dict.
    if isinstance(obj, dict):
        if "evolve_mode" in obj:
            return obj["evolve_mode"]
        for v in obj.values():
            m = find_mode(v)
            if m:
                return m
    return None


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless")
    try:
        c.wait_for_ready(proc, timeout_s=120)
        print("\n─── PHASE 4: CANONICAL AUTHORITY = C++ BACKEND ───")

        ts = c.run_turn(1, "time_skip", phrames=30, timeout_s=60)
        mode = find_mode(ts)
        print("    time_skip result (trimmed):", json.dumps(ts)[:300])
        check("time-skip evolved through the C++ backend (mode=native)", mode == "native",
              f"evolve_mode={mode}")

        sweep = c.run_turn(2, "reservoir_sweep", h_scales=[1.0], l_scales=[1.0],
                           phrames=300, timeout_s=180).get("reservoir_sweep", [])
        if sweep:
            order = float(sweep[0].get("order", -1))
            rich = float(sweep[0].get("richness", -1))
            check("closed-mode purity = 1.0 through C++ (r=1 in canonical path)", order > 0.999,
                  f"order={order:.5f}")
            print(f"     richness(S)={rich:.4f}")

        print(f"\n📊 Results: {P} passed, {F} failed")
        print("✅ AUTHORITY = C++ BACKEND, r=1 HOLDS" if F == 0 else "❌ PHASE 4 CHECK FAILED")
    finally:
        try:
            c.run_turn(999, "stop", timeout_s=10)
        except Exception:
            pass
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
