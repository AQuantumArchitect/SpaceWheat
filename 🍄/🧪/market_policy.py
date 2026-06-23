#!/usr/bin/env python3
"""Smart market-driving heuristic (the "policy" for accept/lock/reroll decisions).

Instead of blindly accepting all visible offers — which jams the 5-slot commitment cap
with unaffordable contracts and stalls the grind — this:
  1. opens the market + refreshes the pool,
  2. reads the SORTED visible offers (board_visible: faction/reward/affordable/index),
  3. picks the first AFFORDABLE, selectable offer that rewards the target emoji,
  4. accepts ONLY that one and completes it, then rerolls,
  repeating until the target amount is reached.

Importable: `from market_policy import smart_grind`. Also runnable standalone to verify.
"""
import os
import sys
from pathlib import Path

PLOT_KEYS = ["G", "H", "J", "K", "L", "SEMICOLON"]


def smart_grind(go, press, target_emoji, target_amount, get_res, max_cycles=40, reroll_per_cycle=4, log=print):
    """Drive the keyboard market to accumulate target_emoji >= target_amount. Returns (cycles, res)."""
    cycles = 0
    for cycle in range(1, max_cycles + 1):
        cycles = cycle
        press("C"); press("Y", 3)          # open board → Market frame
        pick = None
        for _reroll in range(reroll_per_cycle):
            press("E", 3)                   # reroll the offer pool
            vis = go("board_visible").get("visible", []) or []
            for o in vis:
                if (o.get("index", 99) < len(PLOT_KEYS)
                        and o.get("affordable")
                        and target_emoji in (o.get("reward_resources") or {})):
                    pick = o
                    break
            if pick is not None:
                break
        if pick is None:
            press("ESCAPE", 3)
            log(f"  [c{cycle}] no affordable {target_emoji} offer after {reroll_per_cycle} rerolls")
            continue
        press(PLOT_KEYS[pick["index"]], 2); press("R", 3)   # accept ONLY the chosen offer
        press("ESCAPE", 3)
        go("time_skip", phrames=40)
        press("C"); press("U", 3)                            # Commitments → complete it
        for pk in PLOT_KEYS:
            press(pk, 2); press("R", 4)
        press("ESCAPE", 3)
        r = get_res()
        log(f"  [c{cycle}] took [{pick['faction']}] {pick['resource']}x{pick['quantity']} → "
            f"{target_emoji}={r.get(target_emoji, 0)}")
        if r.get(target_emoji, 0) >= target_amount:
            return cycle, r
    return cycles, get_res()


def _main():
    HERE = Path(__file__).resolve().parent
    sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
    from rig_client import RigClient
    os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
    _turn = [10]

    def tk():
        _turn[0] += 1
        return _turn[0]

    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})

    def go(a, **k):
        k.pop("timeout_s", None)
        return c.run_turn(tk(), a, timeout_s=60, **k)

    def press(k, s=4):
        c.run_turn(tk(), "press_key", key=k, settle_frames=s, timeout_s=25)

    def get_res():
        r = go("resource_snapshot").get("resources") or {}
        if isinstance(r, dict) and isinstance(r.get("resources"), dict):
            r = r["resources"]
        return r

    try:
        c.wait_for_ready(proc, timeout_s=180)
        press("Y")
        print("start 🔨=%d 🍞=%d" % (get_res().get("🔨", 0), get_res().get("🍞", 0)))
        cycles, res = smart_grind(go, press, "🔨", 13, get_res, max_cycles=30)
        print(f"\n== reached 🔨={res.get('🔨', 0)} in {cycles} cycles (no clog) ==")
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    _main()
