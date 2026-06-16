#!/usr/bin/env python3
"""Determined play: farm resources across rounds, then accept + complete a market
contract to prove the full loop closes (measure→produce→deliver→reward→signature).
Reports honestly whether the loop completes or hits a fuel/balance wall."""
import sys, time, json
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402


def main():
    c = RigClient(); c.clear_rig_files(preserve_live_sentinel=False)
    log = c.runner_root / "logs" / "rig_listener.log"
    try: log.write_text("")
    except OSError: pass
    t = [0]
    def cmd(a, **kw): t[0] += 1; return c.run_turn(t[0], a, timeout_s=kw.pop("timeout_s", 30), **kw)
    def resources():
        r = cmd("resource_snapshot").get("resources", {})
        return r.get("resources", r) if isinstance(r, dict) else {}

    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    try:
        c.wait_for_ready(proc, timeout_s=150)
        r0 = resources()
        print("start:", {k: v for k, v in r0.items() if v})

        print("\n--- FARM ROUNDS (victory_lap + time_skip) ---")
        for rnd in range(10):
            vl = cmd("victory_lap", timeout_s=90).get("victory_lap", {})
            cmd("time_skip", phrames=90, timeout_s=60)
            r = resources()
            energy = r.get("❄", 0)
            mf = len(vl.get("measure_failures", []))
            print(f"  round {rnd}: harvested={vl.get('harvest_total')} measure_fail={mf} ❄={energy} "
                  f"| {', '.join(f'{k}×{v}' for k,v in sorted(r.items(), key=lambda x:-x[1])[:6] if v)}")
            if energy <= 0 and mf > 0:
                print("  (out of ❄ energy — measurement stalls)")
                break

        rN = resources()
        print("\nafter farming:", {k: v for k, v in sorted(rN.items(), key=lambda x: -x[1]) if v})

        print("\n--- OFFERS — find an affordable contract ---")
        offers = cmd("offer_quests", full=True).get("offers", [])
        affordable = []
        for i, o in enumerate(offers):
            res, qty = o.get("resource", ""), int(o.get("quantity", 0))
            have = rN.get(res, 0)
            tag = "✓AFFORD" if have >= qty else f"need {qty} have {have}"
            print(f"  [{i}] {o.get('faction')} deliver {qty}×{res} ({tag}) reward={o.get('reward_resources',{})}")
            if have >= qty:
                affordable.append((i, o))

        if not affordable:
            print("\n  No contract affordable yet. Loop is fuel/throughput-gated — reporting honestly.")
            return

        idx, off = affordable[0]
        qid = int(off.get("id", -1))
        print(f"\n--- ACCEPT + COMPLETE contract [{idx}] (deliver {off.get('quantity')}×{off.get('resource')}) ---")
        print("  accept:", cmd("accept_offer", offer_index=idx).get("accepted"))
        before = resources()
        comp = cmd("complete_quest", quest_id=qid)
        print("  complete_quest:", comp.get("completed"), "rewards:", comp.get("rewards"))
        after = resources()
        delta = {k: after.get(k, 0) - before.get(k, 0) for k in set(after) | set(before)
                 if after.get(k, 0) - before.get(k, 0)}
        print("  Δ resources:", delta)
        ki = cmd("known_icons")
        print("  known icons now:", ki.get("known_icons", ki.get("icons", [])))
        print("  story flags:", cmd("story_flags").get("flags_fired", {}))
        print("\n  ✅ FULL LOOP CLOSED" if comp.get("completed") else "\n  ✗ completion failed")
    finally:
        try: cmd("stop", timeout_s=8)
        except Exception: pass
        c.terminate_listener(proc)
    errs = [l for l in log.read_text(errors="replace").splitlines()
            if any(x in l for x in ("SCRIPT ERROR", "ERROR:", "push_error"))]
    print(f"\nLOG ERRORS: {len(errs)}")
    for e in errs[:10]: print("  ⚠", e)


if __name__ == "__main__":
    main()
