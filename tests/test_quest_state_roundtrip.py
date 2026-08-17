def test_quest_ledger_survives_save_load_roundtrip(rig_boot) -> None:
    # Launch-blocking QA repro (2026-07-15): accept a contract, complete
    # another, save, reload → Commitments Active came back empty, History said
    # "no past contracts yet", the in-progress contract ceased to exist; only
    # wallet payouts survived. Save v6 persists the quest ledger
    # (QuestManager.to_save_dict → GameState.quest_state), so this test pins:
    #   1. an ACCEPTED-but-unclaimed commitment survives the roundtrip with
    #      its id, status, and accepted_at intact — and does NOT also come
    #      back as a duplicate story offer for the same flag;
    #   2. a COMPLETED contract survives into History;
    #   3. next_quest_id never rewinds (fresh offers can't collide with
    #      restored ids);
    #   4. the restored commitment is LIVE: it can be worked and claimed on
    #      the loaded farm (wired to the new economy/biomes, not the dead
    #      pre-load farm).
    rig, _proc = rig_boot(
        prefix="sw_pytest_quest_ledger_",
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

    def ledger():
        row = step("quest_ledger")
        assert row.get("ok", False), row
        return row

    def offers_by_flag():
        row = step("story_offers")
        assert row.get("ok", False), row
        return {str(o.get("source_flag", "")): o for o in row.get("story_offers", [])}

    def signature_icons():
        row = step("known_icons")
        assert row.get("ok", False), row
        return {(i.get("north", ""), i.get("south", "")) for i in row.get("icons", [])}

    # Two teaching flags through the real firing path → two arc offers.
    for flag_id in ("village_stirs", "spring_connects"):
        fired = step("fire_flag", id=flag_id)
        assert fired.get("ok", False) and fired.get("fired", False), fired
    by_flag = offers_by_flag()
    assert "village_stirs" in by_flag and "spring_connects" in by_flag, by_flag

    # COMPLETE village_stirs: accept → work (Millwright's Union access, the
    # 2026-08-17 reorder's teachings-first road — berry_consumed_count_gte
    # was replaced by standing_gte on the arc_quest's own state_predicates)
    # → claim. grant_standing sets the channel directly rather than grinding
    # the real delivery loop, same role consume_berry played before.
    vs_id = int(by_flag["village_stirs"].get("id", -1))
    assert step("accept_quest", quest_id=vs_id).get("accepted", False)
    assert step("grant_standing", faction="Millwright's Union",
                deltas={"access": 0.2}).get("ok", True)
    step("press_key", key="ESCAPE", settle_frames=30)  # readiness polls per physics frame
    assert step("complete_or_claim", quest_id=vs_id).get("completed_or_claimed", False)

    # ACCEPT spring_connects and leave it in-progress (the QA repro's
    # vanishing commitment).
    sc_id = int(by_flag["spring_connects"].get("id", -1))
    assert step("accept_quest", quest_id=sc_id).get("accepted", False)

    pre = ledger()
    pre_active = {int(q["id"]): q for q in pre["active"]}
    assert sc_id in pre_active and pre_active[sc_id]["status"] == "active", pre
    assert any(int(q.get("id", -1)) == vs_id for q in pre["completed"]), pre
    pre_next_id = int(pre["next_quest_id"])
    pre_accepted_at = int(pre_active[sc_id]["accepted_at"])

    save_path = rig.xdg_root / "quest_ledger.tres"
    assert step("save_game_path", path=str(save_path)).get("saved", False)
    assert step("load_game_path", path=str(save_path)).get("loaded", False)

    # 1+2+3: the ledger came back — commitment intact, history intact,
    # id counter monotonic.
    post = ledger()
    post_active = {int(q["id"]): q for q in post["active"]}
    assert sc_id in post_active, post
    assert post_active[sc_id]["status"] == "active", post
    assert str(post_active[sc_id]["source_flag"]) == "spring_connects", post
    assert int(post_active[sc_id]["accepted_at"]) == pre_accepted_at, post
    assert any(int(q.get("id", -1)) == vs_id and str(q.get("status", "")) == "completed"
               for q in post["completed"]), post
    assert int(post["next_quest_id"]) >= pre_next_id, post

    # 1 (dedup half): the accepted teaching must NOT also be re-offered —
    # the restore ran before StoryEngine's re-offer pass, whose
    # has_quest_for_flag guard sees the restored active. The claimed one
    # stays claimed (pair in signature).
    post_offers = offers_by_flag()
    assert "spring_connects" not in post_offers, post_offers
    assert "village_stirs" not in post_offers, post_offers

    # 4: the restored commitment is live on the loaded farm — work it to
    # ready and claim it; the teaching lands in the signature. spring_connects'
    # state_predicates now gate on Hearth Keepers trust, not berries.
    assert step("grant_standing", faction="Hearth Keepers",
                deltas={"trust": 0.8}).get("ok", True)
    step("press_key", key="ESCAPE", settle_frames=30)
    assert step("complete_or_claim", quest_id=sc_id).get("completed_or_claimed", False)
    assert ("💧", "🌊") in signature_icons()

    # And a second roundtrip carries the grown history: both contracts in
    # History, no phantom actives, no offer resurrection.
    assert step("save_game_path", path=str(save_path)).get("saved", False)
    assert step("load_game_path", path=str(save_path)).get("loaded", False)
    final = ledger()
    final_completed_flags = {str(q.get("source_flag", "")) for q in final["completed"]}
    assert {"village_stirs", "spring_connects"} <= final_completed_flags, final
    assert not any(int(q.get("id", -1)) == sc_id for q in final["active"]), final
    # Neither completed teaching resurrects. new_voices (a pair-less guidance
    # quest cascaded by village_stirs, not itself completed) legitimately
    # DOES reappear here — StoryEngine._restore_arc_quests_after_load's
    # resume-guidance pass (2026-08-13) re-offers at most one such quest on
    # load so a reloading player doesn't lose the next-step nudge. Assert the
    # dedup this test actually pins, not a blanket empty board.
    final_offers = offers_by_flag()
    assert "village_stirs" not in final_offers, final_offers
    assert "spring_connects" not in final_offers, final_offers
