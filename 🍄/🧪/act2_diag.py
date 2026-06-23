#!/usr/bin/env python3
"""Act-2 readiness: are Woodlot/FreshwaterSpring discoverable, and what blocks
lumber_flows / spring_connects? Read-only-ish (discovers biomes to map the order)."""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
_turn = [10]


def t():
    _turn[0] += 1
    return _turn[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})

    def go(a, **k):
        k.pop("timeout_s", None)
        return c.run_turn(t(), a, timeout_s=60, **k)

    def grid():
        g = go("grid_snapshot").get("grid", {})
        return g.get("biomes", g)

    def fprog(fid):
        fp = go("flag_progress", id=fid)
        if fp.get("error"):
            return f"{fid}: {fp['error']}"
        out = [f"{fid} combined={fp.get('combined', 0):.2f}"]
        for ps in fp.get("predicates", []):
            p = ps["pred"]
            d = p.get("type", "")
            for k in ("biome", "faction", "channel", "id", "value"):
                if k in p:
                    d += f" {k}={p[k]}"
            out.append(f"    {ps['score']:.2f}  {d}")
        return "\n".join(out)

    try:
        c.wait_for_ready(proc, timeout_s=180)
        print("grid:", grid())
        fc = go("discovery_forecast").get("forecast", {})
        print("discovery_forecast:", str(fc)[:400])
        # discover several biomes to map the order
        for i in range(8):
            r = go("discover_biome")
            db = r.get("discover_biome", {})
            print(f"  discover #{i+1}: success={db.get('success')} biome={db.get('biome_name', db.get('biome'))} msg={db.get('message','')[:60]}")
            if not db.get("success", False):
                break
        print("\ngrid after discovery:", grid())
        print("\n" + fprog("lumber_flows"))
        print(fprog("spring_connects"))
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
