#!/usr/bin/env python3
"""Verify the vocabulary-reward multiplier via reap_probe (bypasses the ❄️ measure
gate). Two FRESH boots of demos_normal — vocab OFF (vocab_r_bonus=0) then ON (=1) —
reap the same starting state and compare Village reap credits. The known emoji 👥
(The Demos signature 🌾👥) should pay ~4× more with vocab ON (closed system, r=1 →
(1+1)²=4). Also confirms the multiplier is live-tunable via the balance board path."""
import sys, time
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402


def reap_credits(bonus: float) -> dict:
    c = RigClient(); c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    t = [0]
    def cmd(a, **kw): t[0] += 1; return c.run_turn(t[0], a, timeout_s=kw.pop("timeout_s", 30), **kw)
    out = {}
    try:
        c.wait_for_ready(proc, timeout_s=150)
        cmd("balance_patch", patch={"tuning": {"vocab_r_bonus": bonus}})
        # confirm the tuning landed
        bal = cmd("balance_snapshot").get("balance", {})
        tun = (bal.get("tuning", {}) if isinstance(bal, dict) else {})
        out["bonus_applied"] = tun.get("vocab_r_bonus", "?")
        rows = cmd("reap_probe").get("reap_probe", [])
        for r in rows:
            out[str(r.get("biome"))] = int(r.get("credits", 0))
    finally:
        try: cmd("stop", timeout_s=8)
        except Exception: pass
        c.terminate_listener(proc)
    return out


def main():
    print("=== VOCAB OFF (vocab_r_bonus=0) ===")
    off = reap_credits(0.0)
    print("  ", off)
    print("=== VOCAB ON (vocab_r_bonus=1 → known 👥/🌾 ×4 at r=1) ===")
    on = reap_credits(1.0)
    print("  ", on)
    print("\n=== VERDICT (reap credits, known-emoji boost shows as higher total) ===")
    for biome in sorted(set(off) | set(on)):
        if biome in ("bonus_applied",):
            continue
        o, n = off.get(biome, 0), on.get(biome, 0)
        ratio = (f"{n/o:.2f}x" if o else "n/a")
        print(f"  {biome}: OFF={o}  ON={n}  ({ratio})")
    village_off, village_on = off.get("Village", 0), on.get("Village", 0)
    print("\n  ✅ vocab multiplier raises known-emoji reap payout (escape mechanic live + tunable)"
          if village_on > village_off else
          "  ⚠ Village payout not higher with vocab — investigate (does Village hold a known 👥 pole?)")


if __name__ == "__main__":
    main()
