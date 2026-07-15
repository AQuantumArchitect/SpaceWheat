import shutil
import sys
import tempfile
from pathlib import Path

import pytest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNNER_ROOT = PROJECT_ROOT / "🍄" / "🎛️"
if str(RUNNER_ROOT) not in sys.path:
    sys.path.insert(0, str(RUNNER_ROOT))

from rig_client import RigClient  # noqa: E402


def test_arc_teaching_offer_reborn_on_load_and_claimed_pair_stays_claimed() -> None:
    # The vocabulary loop's load contract (leg L2i): quest offers are session
    # state, so a load must REGENERATE the arc offer for every fired flag whose
    # teaching (reward pair) is not yet in known_icons — and must NOT re-offer
    # a claimed teaching (its pair is in the signature; re-offering would
    # double-teach and pump standing via save/load cycling) nor carry the
    # previous session's offers across (a stale tutorial row shadowed the one
    # live teaching on every loaded checkpoint).
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")

    xdg_root = Path(tempfile.mkdtemp(prefix="sw_pytest_arc_rebirth_"))
    rig = RigClient(xdg=xdg_root, root_from_file=RUNNER_ROOT / "milk_hunt_runner.py")
    rig.clear_rig_files()

    proc = None
    try:
        proc = rig.start_listener(
            load_slot=None,
            scenario_id="demos_normal",
            allow_resource_injection=True,
            listener_stdout="null",
            rig_log_profile="quiet",
            extra_env={"RIG_QUEUE_POLL_MS": "80"},
        )
        assert RigClient.wait_for_bridge_sentinel(timeout_s=60.0, xdg=rig.xdg_root), "rig listener not ready"

        turn = [1]

        def step(action, **kw):
            turn[0] += 1
            return rig.run_turn(turn[0], action, timeout_s=60.0, **kw)

        def offers():
            row = step("story_offers")
            assert row.get("ok", False), row
            return row.get("story_offers", [])

        def offers_by_flag():
            return {str(o.get("source_flag", "")): o for o in offers()}

        def signature_icons():
            row = step("known_icons")
            assert row.get("ok", False), row
            return {(i.get("north", ""), i.get("south", "")) for i in row.get("icons", [])}

        def claim_arc(flag_id, biome, berries):
            offer = offers_by_flag().get(flag_id)
            assert offer is not None, "no offer for %s" % flag_id
            quest_id = int(offer.get("id", -1))
            acc = step("accept_quest", quest_id=quest_id)
            assert acc.get("accepted", False), acc
            cb = step("consume_berry", biome=biome, count=berries)
            assert cb.get("ok", False), cb
            # Readiness is polled by QuestManager._physics_process; give it frames.
            step("press_key", key="ESCAPE", settle_frames=30)
            claimed = step("complete_or_claim", quest_id=quest_id)
            assert claimed.get("completed_or_claimed", False), claimed

        # Fire two TEACHING flags through the real firing path.
        for flag_id in ("village_stirs", "spring_connects"):
            fired = step("fire_flag", id=flag_id)
            assert fired.get("ok", False) and fired.get("fired", False), fired
        by_flag = offers_by_flag()
        assert "village_stirs" in by_flag and "spring_connects" in by_flag, by_flag

        # Claim village_stirs → 💨/🔨 joins the signature (the claim IS the teaching).
        claim_arc("village_stirs", "Village", 3)
        assert ("💨", "🔨") in signature_icons()

        save_path = xdg_root / "arc_rebirth.tres"
        assert step("save_game_path", path=str(save_path)).get("saved", False)
        assert step("load_game_path", path=str(save_path)).get("loaded", False)

        # Post-load board: exactly the unclaimed teaching reborn. The claimed
        # pair must not re-offer, and no offer leaks in from the old session.
        post = offers_by_flag()
        assert "spring_connects" in post, post
        assert "village_stirs" not in post, post
        assert all(str(o.get("source_flag", "")) != "" for o in offers()), \
            "session offer leaked across the load: %s" % offers()
        assert ("💨", "🔨") in signature_icons()

        # The reborn offer completes the ritual: accept → work → claim → teach.
        claim_arc("spring_connects", "StarterForest", 8)
        assert ("💧", "🌊") in signature_icons()

        # And a further roundtrip re-offers nothing — both teachings are held.
        assert step("save_game_path", path=str(save_path)).get("saved", False)
        assert step("load_game_path", path=str(save_path)).get("loaded", False)
        assert offers_by_flag() == {}, offers_by_flag()
        assert {("💨", "🔨"), ("💧", "🌊")} <= signature_icons()
    finally:
        RigClient.terminate_listener(proc, timeout_s=5.0)
        shutil.rmtree(xdg_root, ignore_errors=True)
