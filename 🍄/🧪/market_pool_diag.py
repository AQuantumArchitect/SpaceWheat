#!/usr/bin/env python3
"""Fast read-only: dump the Village market offer pool across several refreshes.
Shows faction / deliverable / reward_resources so we can see if 🔨 is ever offered
(Millwright's Union should be a speaker that rewards 🔨)."""
import os
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

SCEN = os.environ.get("PT_SCENARIO", "demos_normal")
os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
_turn = [10]


def t():
    _turn[0] += 1
    return _turn[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id=SCEN, display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})

    def go(action, **kw):
        kw.pop("timeout_s", None)
        return c.run_turn(t(), action, timeout_s=40, **kw)

    try:
        c.wait_for_ready(proc, timeout_s=180)
        # ensure active biome is Village
        go("press_key", key="Y", settle_frames=4)
        hammer_offers = []
        faction_speak = Counter()
        for refresh in range(1, 13):
            r = go("offer_quests", full=True)
            offers = r.get("offers", [])
            for o in offers:
                fac = o.get("faction", "?")
                faction_speak[fac] += 1
                rr = o.get("reward_resources", o.get("reward_resource_plan", {}))
                if isinstance(rr, dict) and "🔨" in rr:
                    hammer_offers.append({
                        "faction": fac,
                        "deliver": o.get("resource", o.get("deliver", "?")),
                        "qty": o.get("quantity", "?"),
                        "reward": rr,
                    })
        print("== faction speak frequency (Village) ==")
        for k, v in faction_speak.most_common():
            print(f"   {k}: {v}")
        print(f"\n== 🔨-rewarding offers across 12 refreshes: {len(hammer_offers)} ==")
        total_hammer = 0
        for h in hammer_offers:
            total_hammer += h["reward"].get("🔨", 0)
            print(f"   [{h['faction']}] deliver {h['deliver']}x{h['qty']}  →  {h['reward']}")
        print(f"\n== total 🔨 available across 12 refreshes if all completed: {total_hammer} (need 13) ==")
    finally:
        go("stop", timeout_s=10)
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
