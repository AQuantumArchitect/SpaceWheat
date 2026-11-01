"""The opening, played honestly — a fresh boot at PLAYER PARITY.

RIG_UNLOCK_ALL=0 (locked hats/menus redirect), resource injection OFF, and the
drive (🍄/🧪/honest_opening.py) may only send key presses plus the read verbs
a sighted player's eyes stand in for — no fire_flag, grant_standing,
time_skip, accept_quest or claim seams (it refuses them itself).

What it proved on 2026-10-17 (headless, this sandbox, ~2–3 min per run):
every Act-0 lesson; Act 1 — arc_handover offered and accepted on the Arc tab,
village_stirs offered and accepted, two kept Millwright deliveries off the
Village board filling its access-0.06 bar, claimed on Commitments; first_breath,
spiral_breaks and new_voices through the Icon hat (berry ritual, a planted
🌾/👥); both Act-2 doors charted with the Captain's Add Biome (🦅×21 draws —
the discovery lean found FreshwaterSpring and Woodlot); woodlot_contact and
lumber_flows claimed; spring_contact and spring_connects claimed on kept
Hearth Keepers deliveries (with the 👥→🧺 basket rescue when gathering ran the
baskets dry); forest_evolving claimed; forest_listener offered — Act 3. The
drive ends there by design. Not attempted: woodlot_wakes (🪵 into the Village
needs 🪓×13, only sold for 🌱 on the Woodlot board) and everything after
forest_listener. The drive reports the first stage that does not happen and
why; this test pins a floor (REQUIRED, through new_voices — the Add Biome
draws after it are random) and prints the rest, so a regression anywhere in
the opening fails loudly while further progress shows up in the log.

One UI finding the drive works around and records in report["notes"]: on the
Arc tab, R can sign a different offer than the row drawn as open (the live
"NOW" row is computed separately from the row list; seen with spiral_breaks
already satisfied and new_voices open).

Long (≈2–5 min headless): skip with SW_SKIP_LONG=1; skipped without godot.
"""
import json
import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "🍄" / "🧪"))

LONG = pytest.mark.skipif(os.environ.get("SW_SKIP_LONG") == "1",
                          reason="SW_SKIP_LONG=1 — honest opening drive skipped")

REQUIRED = [
    "act0:core_loop", "act0:contracts", "act0:wayfinding",
    "act0:superposition", "act0:entanglement", "act0:reap_season",
    "first_harvest", "arc_handover:offered", "arc_handover:accepted",
    "village_stirs:offered", "village_stirs:accepted",
    "village_stirs:ready", "village_stirs:claimed",
    "first_breath:offered", "first_breath:claimed",
    "spiral_breaks:claimed", "new_voices:claimed",
]


def test_the_honest_drive_never_reaches_for_a_seam():
    import honest_opening as H
    assert H.INPUT_VERBS == {"press_key"}
    banned = {"fire_flag", "grant_standing", "add_resource", "set_resource", "time_skip",
              "accept_quest", "accept_offer", "complete_quest", "complete_or_claim",
              "claim_quest", "consume_berry", "start_at_beat", "discover_biome", "inject_icon"}
    assert not (H.READ_VERBS & banned)


@LONG
@pytest.mark.timeout(2700)  # the suite runs --timeout=300; this drive plays minutes of real time
def test_fresh_boot_plays_the_opening_at_player_parity(rig_boot):
    import honest_opening as H
    rig, _proc = rig_boot(prefix="sw_honest_opening_", scenario_id="demos_normal",
                          display_mode="headless", allow_resource_injection=False,
                          listener_stdout="null", rig_log_profile="quiet",
                          extra_env={"RIG_UNLOCK_ALL": "0"}, sentinel_timeout_s=240.0)
    rep = H.drive(rig, log=print)
    print("HONEST OPENING:", json.dumps(rep, ensure_ascii=False))
    missing = [s for s in REQUIRED if s not in rep["reached"]]
    assert not missing, "honest drive stopped at %s: %s (reached %s)" % (
        rep.get("stopped_at"), rep.get("why"), rep["reached"])
