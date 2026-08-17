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
# 2026-08-17 reorder: act 1 is the teachings-first road (tutorial verbs +
# Millwright deliveries), not the berry staircase — that whole chapter
# (first_breath, forest_*) moved to act 3 and belongs to an act3 checkpoint.
ACT1_FLAGS = ["first_harvest", "loom_opens", "arc_handover", "village_stirs"]

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

        def actives():
            return t("active_quests", full=True).get("quests", []) or []

        def offers():
            return t("story_offers").get("story_offers", []) or []

        def wallet():
            r = t("resource_snapshot").get("resources", {})
            return (r.get("resources", r) or {})

        def gather_on(biome_key, resource, quantity, max_rounds=10):
            # Ace strike+extract across the biome's plots until the wallet
            # holds `quantity` of `resource`.
            press(biome_key, settle=8)
            press("8", settle=4)
            for rnd in range(max_rounds):
                if float(wallet().get(resource, 0)) >= quantity:
                    return True
                press("ghjkl;"[rnd % 6], settle=4)
                press("f", settle=6)
                press("r", settle=8)
                press("q", settle=6)
            return float(wallet().get(resource, 0)) >= quantity

        def tutorial_drive():
            # The six Act-0 steps, by keyboard (order: tutorial_arc.json).
            # 0 core_loop — explore/strike/extract on TheDemos.
            press("t", settle=8)
            press("8", settle=4)
            press("g", settle=6)
            press("f", settle=10)
            press("r", settle=12)
            press("q", settle=10)
            # 1 reap_season — Shift+F. (fires first_harvest too)
            t("press_key", key="f", shift=True, settle_frames=12)
            # 2 contracts — accept on the Arc tab, deliver 2×🌾 in Commitments.
            #   demos_normal boots with 21×🌾, so the granary covers it.
            press("x", settle=6)
            press("i", settle=6)
            press("g", settle=6)   # the contracts offer is the first Arc row
            press("r", settle=10)  # accept
            press("escape", settle=6)
            press("c", settle=6)
            press("u", settle=6)
            press("g", settle=6)   # the delivery is the first commitment row
            press("r", settle=12)  # deliver
            press("escape", settle=6)
            # 3 wayfinding — stand in StarterForest; arrival is the gate.
            press("u", settle=12)
            # 4 superposition — Druid E until coherence ≥ 0.3 (fires loom_opens).
            for pk in "ghj":
                press("0", settle=4)
                press(pk, settle=4)
                press("e", settle=8)
            # 5 entanglement — Operator: pair, R, Bell (fires arc_handover).
            press("9", settle=4)
            t("press_key", key="g", shift=True, settle_frames=6)
            t("press_key", key="h", shift=True, settle_frames=6)
            press("r", settle=10)
            press("q", settle=12)
            t("time_skip", phrames=300)

        def millwright_deliveries(max_contracts=6):
            # Keep Millwright market deliveries until village_stirs fires —
            # access climbs +0.02 per kept delivery (the act-1 standing road).
            for _ in range(max_contracts):
                if "village_stirs" in flags():
                    return True
                press("y", settle=10)      # stand in the Village (its board)
                press("c", settle=6)
                press("y", settle=6)       # market tab
                press("g", settle=6)       # first offer row
                press("r", settle=10)      # accept
                press("escape", settle=6)
                q = next((a for a in actives()
                          if str(a.get("type", "")) in ("DELIVERY", "DELIVER")
                          and a.get("resource")), None)
                if q is None:
                    press("'", settle=60)
                    continue
                if not gather_on("y", str(q["resource"]), float(q.get("quantity", 1))):
                    print("  gather stalled on", q.get("resource"))
                idx = next((i for i, a in enumerate(actives())
                            if int(a.get("id", -1)) == int(q.get("id", -2))), -1)
                if idx < 0 or idx >= 6:
                    continue
                press("c", settle=6)
                press("u", settle=6)
                press("ghjkl;"[idx], settle=6)
                press("r", settle=12)      # claim
                press("escape", settle=6)
                press("'", settle=60)      # let the flag evaluator breathe
            return "village_stirs" in flags()

        tutorial_drive()
        millwright_deliveries()
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
            "criterion": "teachings-first act 0-1 road (2026-08-17 reorder): "
                         "tutorial verbs + Millwright deliveries; berry chapter is act 3",
        }
        (CKPT_DIR / ("%s.json" % name)).write_text(
            json.dumps(manifest, ensure_ascii=False, indent=1))
        print("CHECKPOINT MINTED:", ckpt_path)
        return 0
    finally:
        c.terminate_listener(proc)


if __name__ == "__main__":
    sys.exit(main())
