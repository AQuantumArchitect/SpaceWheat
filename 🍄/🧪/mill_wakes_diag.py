#!/usr/bin/env python3
"""Diagnostic: where does 'The Demos' stand vs the village arc, and what blocks mill_wakes?

Read-only. Boots the rig, reports fired flags, known icons, resources, grid state,
Village berry/physics, and the per-predicate flag_progress for village_stirs / mill_wakes.
"""
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))  # 🍄/🎛️
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
    proc = c.start_listener(
        scenario_id=SCEN,
        display_mode="headless",
        extra_env={"RIG_DISABLE_LOOKAHEAD": os.environ.get("RIG_DISABLE_LOOKAHEAD", "0")},
    )
    try:
        c.wait_for_ready(proc, timeout_s=180)

        def go(action, **kw):
            return c.run_turn(t(), action, timeout_s=40, **kw)

        sf = go("story_flags")
        print("== FIRED FLAGS ==", sorted((sf.get("flags_fired") or {}).keys()))

        ki = go("known_icons")
        print("== KNOWN ICONS ==", ki.get("icons"))

        rs = go("resource_snapshot")
        res = rs.get("resources") or {}
        if isinstance(res, dict) and isinstance(res.get("resources"), dict):
            res = res["resources"]
        print("== RESOURCES ==", res)

        grid = go("grid_snapshot")
        print("== GRID ==", json.dumps(grid.get("grid", grid), ensure_ascii=False)[:600])

        for fid in ("forest_listener", "village_stirs", "mill_wakes"):
            fp = go("flag_progress", id=fid)
            if not fp.get("ok", True) or fp.get("error"):
                print(f"\n## {fid}: {fp.get('error', fp)}")
                continue
            print(f"\n## {fid}  fired={fp.get('fired')}  combined={fp.get('combined'):.3f} / {fp.get('threshold')}")
            for ps in fp.get("predicates", []):
                p = ps["pred"]
                desc = p.get("type", "")
                for k in ("biome", "atom", "emoji", "id", "faction", "channel", "value"):
                    if k in p:
                        desc += f" {k}={p[k]}"
                print(f"    {ps['score']:.3f}  {desc}")

        bs = go("berry_state", biome="Village")
        if bs.get("ok", True) and not bs.get("error"):
            print(f"\n== VILLAGE BERRY ==  consumed_count={bs.get('consumed_count')} consumed_phase={bs.get('consumed_phase')}")
            for q in bs.get("qubits", []):
                print(f"    q{q['qubit']} tracked={q['tracked']} phase={q['phase']:.3f} ripe={q['ripe']} thr={q['threshold']:.3f}")
        else:
            print("\n== VILLAGE BERRY == error:", bs.get("error"))
    finally:
        c.run_turn(99999, "stop", timeout_s=10)
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
