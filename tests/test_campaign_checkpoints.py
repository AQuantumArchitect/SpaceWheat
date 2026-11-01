"""Campaign assert gate: the minted checkpoint spine becomes a real pass/fail test.

The fixtures already existed unused: every minted checkpoint in 🍄/🧪/checkpoints/
ships a .flag_progress.json sidecar whose ``flags_fired`` / ``terminal_flags``
record exactly what the campaign had proven at bank time, in the same shape the
``story_flags`` / ``flag_progress`` rig verbs return at runtime. Until this file,
nothing behavioral covered Acts 2-8 — act3_5_drive.py plays the road but asserts
nothing (diagnostic-only, by design).

Two claims per spine checkpoint:
  1. The .tres still loads in the current build (save-migration canary).
  2. Every flag fired at bank time is still fired after the load — the
     "post-load state loss" bug family (quest ledger, berry credit, offer
     regeneration have each independently lost state on load before) gets a
     standing per-act tripwire.

Plus one fire_flag consequence test: forcing a flag through the REAL
_fire_story_flag path must land it in story_flags_fired, append its beat to the
story log, and put its arc_quest on the offer board.
"""

import json
from pathlib import Path

import pytest

CHECKPOINTS = Path(__file__).resolve().parents[1] / "🍄" / "🧪" / "checkpoints"

# The minted campaign spine (mint_checkpoint.py provenance, .flag_progress.json
# pinned). Sweep/persona/leg banks are deliberately excluded — only minted
# checkpoints carry the verified-at-bank-time contract this test replays.
SPINE = ["act1_complete", "act2_complete", "act3_complete", "act4_hub"]


def _sidecar(name: str) -> dict:
    path = CHECKPOINTS / ("%s.flag_progress.json" % name)
    if not path.exists():
        pytest.skip("no sidecar for %s (checkpoint not minted here)" % name)
    return json.loads(path.read_text(encoding="utf-8"))


@pytest.mark.parametrize("name", SPINE)
def test_checkpoint_flags_survive_load(rig_boot, name):
    tres = CHECKPOINTS / ("%s.tres" % name)
    if not tres.exists():
        pytest.skip("no %s.tres" % name)
    expected = sorted(_sidecar(name).get("flags_fired", []))
    assert expected, "sidecar for %s pins no fired flags — refusing vacuous pass" % name

    rig, proc = rig_boot(prefix="sw_campaign_gate_%s_" % name,
                         scenario_id="demos_normal", display_mode="headless")
    loaded = rig.run_turn(1, "load_game_path", path=str(tres), timeout_s=120)
    assert loaded.get("loaded", False), "checkpoint failed to load: %r" % loaded

    flags = rig.run_turn(2, "story_flags", timeout_s=45)
    fired = set(flags.get("flags_fired", {}).keys())
    missing = [f for f in expected if f not in fired]
    assert not missing, (
        "%s: %d flag(s) fired at bank time are gone after load: %s"
        % (name, len(missing), missing))


def test_fire_flag_consequences_react(rig_boot):
    """spring_door forced through the real path: fired + logged + offered."""
    rig, proc = rig_boot(prefix="sw_campaign_gate_fireflag_",
                         scenario_id="demos_normal", display_mode="headless")
    before = rig.run_turn(1, "story_flags", timeout_s=45)
    assert "spring_door" not in before.get("flags_fired", {}), \
        "spring_door already fired at fresh boot — premise broken"
    log_before = len(before.get("story_log", []))

    fired = rig.run_turn(2, "fire_flag", id="spring_door", timeout_s=60)
    assert fired.get("fired", False), "fire_flag did not fire: %r" % fired

    after = rig.run_turn(3, "story_flags", timeout_s=45)
    assert "spring_door" in after.get("flags_fired", {})
    log_after = after.get("story_log", [])
    assert len(log_after) > log_before, "story log did not grow on flag fire"
    assert any(e.get("id") == "spring_door" for e in log_after), \
        "spring_door beat missing from story log"

    offers = rig.run_turn(4, "story_offers", timeout_s=45)
    offer_flags = {str(o.get("source_flag", ""))
                   for o in offers.get("story_offers", []) if isinstance(o, dict)}
    assert "spring_door" in offer_flags, \
        "arc quest for spring_door not on the offer board: %r" % offers
