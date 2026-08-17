def test_arc_teaching_offer_reborn_on_load_and_claimed_pair_stays_claimed(rig_boot) -> None:
    # The vocabulary loop's load contract (leg L2i): quest offers are session
    # state, so a load must REGENERATE the arc offer for every fired flag whose
    # teaching (reward pair) is not yet in known_icons — and must NOT re-offer
    # a claimed teaching (its pair is in the signature; re-offering would
    # double-teach and pump standing via save/load cycling) nor carry the
    # previous session's offers across (a stale tutorial row shadowed the one
    # live teaching on every loaded checkpoint).
    rig, _proc = rig_boot(
        prefix="sw_pytest_arc_rebirth_",
        load_slot=None,
        scenario_id="demos_normal",
        allow_resource_injection=True,
        listener_stdout="null",
        rig_log_profile="quiet",
        extra_env={"RIG_QUEUE_POLL_MS": "80"},
    )

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

    def claim_arc(flag_id, faction, channel, value):
        # 2026-08-17 reorder: village_stirs/spring_connects' arc_quest.state_predicates
        # now gate on faction standing (access/trust), not berry consumption — the
        # teachings-first road earns vocabulary via kept market contracts. Driving a
        # real delivery grind here would test the market, not the load-contract this
        # test pins, so grant_standing sets the channel directly (same role
        # consume_berry played for the old berry-gated beats).
        offer = offers_by_flag().get(flag_id)
        assert offer is not None, "no offer for %s" % flag_id
        quest_id = int(offer.get("id", -1))
        acc = step("accept_quest", quest_id=quest_id)
        assert acc.get("accepted", False), acc
        gs = step("grant_standing", faction=faction, deltas={channel: value})
        assert gs.get("ok", True), gs
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
    claim_arc("village_stirs", "Millwright's Union", "access", 0.2)
    assert ("💨", "🔨") in signature_icons()

    save_path = rig.xdg_root / "arc_rebirth.tres"
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
    claim_arc("spring_connects", "Hearth Keepers", "trust", 0.8)
    assert ("💧", "🌊") in signature_icons()

    # And a further roundtrip re-offers nothing — both teachings are held.
    assert step("save_game_path", path=str(save_path)).get("saved", False)
    assert step("load_game_path", path=str(save_path)).get("loaded", False)
    assert offers_by_flag() == {}, offers_by_flag()
    assert {("💨", "🔨"), ("💧", "🌊")} <= signature_icons()
