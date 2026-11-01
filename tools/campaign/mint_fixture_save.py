#!/usr/bin/env python3
"""Write a save file holding the state a player has when a story beat opens.

    python3 tools/campaign/mint_fixture_save.py the_door_stays_open
    python3 tools/campaign/mint_fixture_save.py lantern_door /tmp/lantern.tres

Boots a headless demos_normal lane, runs the `start_at_beat` rig verb
(Core/Campaign/CampaignFixture.gd — built from the spec, no economy bypass
beyond the fixture's own modest wallet floor) and banks the result with
save_game_path. Default output: 🍄/🧪/checkpoints/fixture_<beat>.tres
(gitignored; re-mint whenever the spec changes). The profiling scripts'
"endgame" scenario loads fixture_the_door_stays_open.tres.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "🍄" / "🎛️"
sys.path.insert(0, str(RUNNER))


def main(argv: list) -> int:
    if not argv:
        print(__doc__)
        return 2
    beat = argv[0]
    out = Path(argv[1]) if len(argv) > 1 else ROOT / "🍄" / "🧪" / "checkpoints" / ("fixture_%s.tres" % beat)
    out.parent.mkdir(parents=True, exist_ok=True)
    from rig_client import RigClient  # noqa: E402
    c = RigClient(root_from_file=RUNNER / "milk_hunt_runner.py")
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            allow_resource_injection=False, extra_env={"RIG_UNLOCK_ALL": "0"})
    try:
        c.wait_for_ready(proc, timeout_s=240)
        r = c.run_turn(1, "start_at_beat", id=beat, timeout_s=300)
        if not (r.get("ok") and r.get("fired")):
            print("fixture did not open %s: %s" % (beat, json.dumps(r, ensure_ascii=False)[:600]))
            return 1
        s = c.run_turn(2, "save_game_path", path=str(out.resolve()), timeout_s=120)
        if not s.get("saved"):
            print("save failed: %s" % json.dumps(s, ensure_ascii=False)[:300])
            return 1
        print("minted %s (%d ancestors, biomes %s)" % (
            out, len(r["report"]["ancestors"]), r.get("loaded_biomes")))
        return 0
    finally:
        c.terminate_listener(proc)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
