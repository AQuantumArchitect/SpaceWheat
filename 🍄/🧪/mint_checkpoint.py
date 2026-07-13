#!/usr/bin/env python3
"""Mint a campaign checkpoint save (owner directive 2026-07-12: fleets start
from solid save files once an act is fleet-proven complete).

Plays the fleet-proven loop through the target act by KEYBOARD (the save is a
legitimately-played state, not an injected one), verifies the act's flags all
fired, then banks the save into 🍄/🧪/checkpoints/<name>.tres + manifest.

Usage: python3 mint_checkpoint.py act1_complete
"""
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path("/home/primearchitect/ws/SpaceWheat/🍄") / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

ROOT = Path("/home/primearchitect/ws/SpaceWheat")
CKPT_DIR = ROOT / "🍄" / "🧪" / "checkpoints"

# Act-1 chain: what "solidly complete" means for this checkpoint.
ACT1_FLAGS = ["first_breath", "forest_evolving", "forest_listener",
              "forest_communion", "loop_remembers", "village_stirs"]

_t = [0]


def main() -> int:
    name = sys.argv[1] if len(sys.argv) > 1 else "act1_complete"
    CKPT_DIR.mkdir(parents=True, exist_ok=True)
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            allow_resource_injection=False)
    try:
        print("ready:", c.wait_for_ready(proc, timeout_s=240))

        def t(action, **kw):
            _t[0] += 1
            return c.run_turn(_t[0], action, timeout_s=90, **kw)

        def press(k, settle=8):
            return t("press_key", key=k, settle_frames=settle)

        def flags():
            return t("story_flags").get("flags_fired", {}) or {}

        def berries(biome):
            bs = t("berry_state", biome=biome)
            return int(bs.get("consumed_count", 0)), bs.get("qubits", [])

        def farm_loop(biome_key, biome_name, target_consumed, max_rounds=14,
                      pre_hadamard=False):
            press(biome_key, settle=10)
            if pre_hadamard:
                # Bistable biomes (Village) park qubits at poles — no
                # precession, no swept angle, loops never close. The player's
                # move is the Druid H-gate: superpose, then the walk begins.
                press("0", settle=6)           # Druid hat
                for pk in "ghjkl;":
                    press(pk, settle=4)
                    press("e", settle=6)       # H-Gate
            press("5", settle=6)               # Icon hat
            for _ in range(5):
                press("=", settle=4)           # clock to max
            rounds = 0
            while rounds < max_rounds:
                consumed, qubits = berries(biome_name)
                if consumed >= target_consumed:
                    return consumed
                # (re)track every untracked plot, harvest every ripe one
                plot_keys = "ghjkl;"
                for i, q in enumerate(qubits):
                    if i >= len(plot_keys):
                        break
                    if q.get("ripe"):
                        press(plot_keys[i], settle=4)
                        press("r", settle=8)   # incorporate
                    elif not q.get("tracked"):
                        press(plot_keys[i], settle=4)
                        press("f", settle=4)   # track
                press("'", settle=200)         # let the fast clock ripen loops
                rounds += 1
            return berries(biome_name)[0]

        sf = farm_loop("u", "StarterForest", 7)
        print("StarterForest berries consumed:", sf)
        vg = farm_loop("y", "Village", 2, pre_hadamard=True)
        print("Village berries consumed:", vg)
        # settle: give the flag evaluator time to fire the chain
        press("'", settle=120)

        fired = flags()
        missing = [f for f in ACT1_FLAGS if f not in fired]
        print("fired:", sorted(fired.keys()))
        if missing:
            print("NOT SOLID — missing flags:", missing)
            return 1

        ckpt_path = CKPT_DIR / ("%s.tres" % name)
        r = t("save_game_path", path=str(ckpt_path))
        if not r.get("saved"):
            print("save failed:", json.dumps(r)[:200])
            return 1
        manifest = {
            "name": name,
            "minted": time.strftime("%Y-%m-%d %H:%M"),
            "flags_fired": sorted(fired.keys()),
            "berries": {"StarterForest": sf, "Village": vg},
            "criterion": "fleet-proven solid (fleets #8-#9: act 0-1 cleared, zero stalls/bugs)",
        }
        (CKPT_DIR / ("%s.json" % name)).write_text(
            json.dumps(manifest, ensure_ascii=False, indent=1))
        print("CHECKPOINT MINTED:", ckpt_path)
        return 0
    finally:
        c.terminate_listener(proc)


if __name__ == "__main__":
    sys.exit(main())
