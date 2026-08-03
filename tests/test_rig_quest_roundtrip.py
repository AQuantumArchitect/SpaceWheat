PLOT = ["G", "H", "J", "K", "L", "SEMICOLON"]


def test_learned_icon_survives_path_save_load_roundtrip(rig_boot) -> None:
    # The invariant: an icon LEARNED by the player survives a save/load roundtrip. Icons are
    # learned by incorporation (steer a qubit's Berry phase to ripe, then Icon-R) — the
    # canonical path — not by market offers (those grant RESOURCES; QuestPipeline.from_market_contract
    # erases icon rewards). Quest-offer icon rewards are a B6 (quest-unification) concern; this
    # test exercises the save/load invariant via the real learning path, decoupled from that.
    rig, _proc = rig_boot(
        prefix="sw_pytest_quest_roundtrip_",
        load_slot=None,
        scenario_id="new_game_easy",
        allow_resource_injection=True,
        listener_stdout="null",
        rig_log_profile="quiet",
        extra_env={"RIG_QUEUE_POLL_MS": "80"},
    )

    turn = [1]
    def step(action, **kw):
        turn[0] += 1
        return rig.run_turn(turn[0], action, timeout_s=60.0, **kw)
    def press(key, frames=4):
        step("press_key", key=key, settle_frames=frames)

    def known():
        row = step("known_icons")
        return row.get("icons", []) if row.get("ok", False) else []

    sig_before = len(known())
    bn = "StarterForest"
    qs = step("berry_state", biome=bn).get("qubits", []) or []
    plots = PLOT[: len(qs)] if qs else PLOT
    # Incorporate: Druid-excite each plot, Icon-track, evolve to ripe, Icon-R.
    press("0", 2)
    for pk in plots:
        press(pk, 3); press("E", 3)
    press("5", 2)
    trk = [bool(q.get("tracked")) for q in (step("berry_state", biome=bn).get("qubits", []) or [])]
    for i, pk in enumerate(plots):
        if i >= len(trk) or not trk[i]:
            press(pk, 3); press("F", 3)
    step("time_skip", phrames=900)
    for pk in plots:
        press(pk, 3); press("R", 4)

    icons = known()
    assert len(icons) > sig_before, f"incorporation did not grow signature: {icons}"
    learned = icons[-1]
    north = str(learned.get("north", ""))
    south = str(learned.get("south", ""))
    assert north and south, icons

    save_path = rig.xdg_root / "quest_roundtrip.tres"
    save_row = step("save_game_path", path=str(save_path))
    assert save_row.get("ok", False), save_row
    assert bool(save_row.get("saved", False)), save_row

    load_row = step("load_game_path", path=str(save_path))
    assert load_row.get("ok", False), load_row
    assert bool(load_row.get("loaded", False)), load_row

    icons_after_load = step("known_icons")
    assert icons_after_load.get("ok", False), icons_after_load
    assert {"north": north, "south": south} in icons_after_load.get("icons", []), icons_after_load
