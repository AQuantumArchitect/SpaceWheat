#!/usr/bin/env python3
"""Deterministic diagnostic: do the Act-1 story flags fire when their underlying
quantities are forced via rig actions? Separates "UI can't drive it" from
"flags/logic are broken". Headless (no window needed) on live C++.

Forces: consume_berry (drives berry_register consumed_count/phase — the `berries`
predicate source) and inject_icon (does it grow known_icons / signature?), then
time_skips so StoryEngine re-evaluates, and reads story_flags + known_icons.
"""
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    print("== boot headless, live C++ ==")
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    try:
        c.wait_for_ready(proc, timeout_s=180)
        time.sleep(1.0)

        def dump(label):
            sf = c.run_turn(turn(), "story_flags", timeout_s=20)
            ki = c.run_turn(turn(), "known_icons", timeout_s=20)
            flags = sorted((sf.get("flags_fired") or {}).keys())
            icons = ki.get("icons") or []
            print(f"[{label}] flags={flags} known_icons={len(icons)} {icons}")
            return flags, icons

        dump("baseline")

        # 1) Force berries via the berry_register (the `berries` predicate source)
        r = c.run_turn(turn(), "consume_berry", biome="StarterForest", count=6,
                       phase_each=3.14159, timeout_s=30)
        print("consume_berry ->", {k: r.get(k) for k in ("consumed_count", "consumed_phase", "ok", "error")})
        c.run_turn(turn(), "time_skip", phrames=120, timeout_s=60)
        dump("after_consume_berry+skip")

        # 2) Try to grow signature via inject_icon rig action
        r = c.run_turn(turn(), "inject_icon", biome="StarterForest", timeout_s=30)
        print("inject_icon ->", r.get("inject_result", r.get("error", r)))
        c.run_turn(turn(), "time_skip", phrames=120, timeout_s=60)
        dump("after_inject_icon+skip")

        # 3) More berries + longer evolve, see if forest_evolving/listener fire
        c.run_turn(turn(), "consume_berry", biome="StarterForest", count=6, phase_each=3.14159, timeout_s=30)
        c.run_turn(turn(), "time_skip", phrames=400, timeout_s=120)
        flags, icons = dump("after_more_berries+long_skip")

        # 4) story_log detail
        sf = c.run_turn(turn(), "story_flags", timeout_s=20)
        log = sf.get("story_log") or []
        print("story_log entries:", len(log))
        for e in log[:12]:
            print("   ", {k: e.get(k) for k in ("id", "act", "display_name", "arc_beat")})
    finally:
        c.run_turn(99999, "stop", timeout_s=10)
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
