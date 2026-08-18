import time


def test_title_menu_restart_path_reaches_arc_handover(rig_boot) -> None:
    # The player's real boot is title → F (menu/start) → welcome → any-key dismiss →
    # gameplay. The rig's default lane skips all of that (pending/auto boot), so bugs
    # that live only on the player path — the welcome modal trapping Q/E/R was one —
    # evade every other test. This walks the shipped path end-to-end — every Act-0
    # hat and verb, title screen to the capstone reap — and proves the real
    # keyboard grammar still drives the tutorial pipeline to its capstone flag
    # (arc_handover) on it. (Previously targeted first_breath; the 2026-08-17
    # campaign reorder relocated that whole berry ritual to a mid-game act-3 beat
    # behind a standing ladder, unreachable in a short smoke — arc_handover is now
    # Act 0's own "you did something real" capstone, riding the reap.)
    rig, _proc = rig_boot(
        prefix="sw_pytest_title_path_",
        load_slot=None,
        scenario_id="demos_normal",  # the shipped default — what a real player boots
        allow_resource_injection=True,
        listener_stdout="null",
        rig_log_profile="quiet",
        extra_env={
            "RIG_QUEUE_POLL_MS": "80",
            "RIG_DRIVE_TITLE": "1",   # leave the title up; we drive the player path
            "RIG_SKIP_WELCOME": "0",  # the welcome modal must actually appear
        },
    )

    turn = [1]

    def step(action, **kw):
        turn[0] += 1
        return rig.run_turn(turn[0], action, timeout_s=60.0, **kw)

    def press(key, frames=4):
        step("press_key", key=key, settle_frames=frames)

    # 1. Title → start. keys=["F"] is the player's first F on the title screen;
    #    start_from_title then guarantees the game booted (same entrypoint the menu
    #    uses) and resolves farm + shell — exactly the restart lane.
    started = step("start_from_title", keys=["F"], settle_frames=10)
    info = started.get("start_from_title", {})
    assert info.get("farm") and info.get("shell") and info.get("game_root"), started

    # 2. Welcome-modal regression (the input trap): ANY key must dismiss it, and the
    #    key row must act afterwards. "5" both dismisses and selects the Icon hat.
    press("5", frames=8)
    frame_row = step("confirm_state")
    assert frame_row.get("current_frame") in ("icon", "ace"), frame_row
    if frame_row.get("current_frame") != "icon":
        press("5", frames=8)  # first press was eaten by the welcome — dismiss counts, retry selects
        frame_row = step("confirm_state")
        assert frame_row.get("current_frame") == "icon", frame_row

    # 2b. The Act-0 tutorial chain must be LIVE once the game starts (headless:
    #     connect_to_farm auto-onboards; headed: the welcome dismissal calls
    #     maybe_start_tutorial). A fresh demos_normal boot with no Act-0 step
    #     anywhere is a broken front door. Predicate-driven tutorial steps now
    #     auto-accept (Break #1 fix), so step 0 lives in active_quests rather than
    #     waiting in story_offers for an R-accept the player was never taught —
    #     accept EITHER surface.
    offers_row = step("story_offers")
    offered = offers_row.get("story_offers", []) if offers_row.get("ok", False) else []
    actives_row = step("active_quests", full=True)
    actives = actives_row.get("quests", []) if actives_row.get("ok", False) else []
    tutorial_live = [
        q for q in list(offered) + list(actives)
        if str(q.get("category", "")) == "TUTORIAL" or int(q.get("tutorial_step", -1)) >= 0
    ]
    assert tutorial_live, (
        f"no Act-0 tutorial step live after start (offers={offers_row}, actives={actives_row})"
    )

    # 2c. BOOT-RACE regression: zero progression actions taken, so NO campaign flag
    #     may have fired yet. The farm registers as active before its boot finishes;
    #     QuestManager once snapshotted the signature baseline in that window (empty
    #     known_icons → seed lands → growth=1) and first_breath greeted a fresh game
    #     with "You did something." tutorial_seen is a marker, not a campaign flag.
    pre_action = step("story_flags")
    pre_fired = pre_action.get("flags_fired", {}) if pre_action.get("ok", False) else {}
    campaign_fired = [f for f in pre_fired if f != "tutorial_seen"]
    assert not campaign_fired, (
        f"campaign flags fired on the title path before any player action: {campaign_fired}"
    )

    # 3. The progression loop on the player path: walk the REAL Act-0 chain by
    #    keyboard, start to finish, in the 2026-08-17 capstone order:
    #      0 core_loop → 1 contracts → 2 wayfinding → 3 superposition →
    #      4 entanglement (grants the 🍼) → 5 reap_season (the capstone).
    #    Reap moved LAST on purpose — it is once-affordable early (Fibonacci
    #    🍼 costs, wallet floor 1) and reaps every biome at once, so it lands
    #    after the player has built a field worth reaping; the entanglement
    #    step's claim pays its cost, and Shift+F is funnel-locked until the
    #    capstone step is live. first_harvest fires ON the capstone reap;
    #    arc_handover (loom_opens ∧ first_harvest) is Act 0's handover beat.
    #    Because a refused action no longer records (durable-ledger law), the
    #    first_harvest assertion below doubles as proof the capstone reap was
    #    SOLVENT — an unfunded reap would refuse, record nothing, fire nothing.
    # 0 core_loop — explore/strike/extract on TheDemos (Ace hat).
    press("8", frames=4)
    press("G", frames=4)
    press("F", frames=8)   # explore
    press("R", frames=10)  # strike
    press("Q", frames=8)   # extract
    # 1 contracts — accept on the Arc tab, deliver 2×🌾 in Commitments.
    #   demos_normal boots with 21×🌾, so the granary already covers it
    #   (and the hint now says so honestly — live stores count).
    #   Find the contracts row by its tutorial_teaches tag instead of
    #   assuming row 0 (GHJKL; ordinal matches ControlsOverlay._arc_rows(),
    #   which walks get_story_offers() in the same order the rig returns).
    press("X", frames=6)
    press("I", frames=6)
    row_keys = "GHJKL;"
    deadline = time.time() + 15.0
    contracts_idx = None
    while time.time() < deadline and contracts_idx is None:
        offers = step("story_offers").get("story_offers", []) or []
        for i, o in enumerate(offers):
            if o.get("tutorial_teaches") == "contracts":
                contracts_idx = i
                break
        if contracts_idx is None:
            time.sleep(0.25)
    assert contracts_idx is not None, "contracts step never offered after core_loop"
    press(row_keys[contracts_idx], frames=6)  # the contracts offer's row
    press("R", frames=10)  # accept
    press("ESCAPE", frames=6)
    press("C", frames=6)
    press("U", frames=6)
    press("G", frames=6)   # the delivery is the first commitment row
    press("R", frames=12)  # deliver
    press("ESCAPE", frames=6)
    # 2 wayfinding — stand in StarterForest; arrival is the gate.
    slots_row = step("biome_slots")
    forest_key = next(
        str(s["key"]).lower() for s in slots_row.get("slots", [])
        if s["biome"] == "StarterForest"
    )
    press(forest_key, frames=12)
    # 3 superposition — Druid E until coherence ≥ 0.3 (fires loom_opens).
    for pk in "GHJ":
        press("0", frames=4)
        press(pk, frames=4)
        press("E", frames=8)
    # 4 entanglement — Operator: pair, R, Bell. Completion auto-claims and
    #   grants the capstone's 🍼.
    press("9", frames=4)
    # Step 3's plot-select can coincide with whatever plot was already
    # focused from wayfinding — a re-press on the SAME plot toggles its
    # checkbox (by design). That stray check would eat one of the two slots
    # Shift+G/Shift+H mean to mark here, so clear first — apostrophe clears
    # when non-empty, bulk-checks when empty, so only clear if the rig
    # reports something is already marked.
    pre_state = step("instrument_state")
    if pre_state.get("checked_plots"):
        step("press_key", key="'", settle_frames=6)
    step("press_key", key="G", shift=True, settle_frames=6)
    step("press_key", key="H", shift=True, settle_frames=6)
    press("R", frames=10)
    press("Q", frames=12)
    step("time_skip", phrames=300)

    # 5 reap_season — wait for the capstone step to go live (the bell weave's
    #   completion → chain unlock → auto-accept), then reap. The Shift+F
    #   funnel gate opens exactly here (VERB_UNLOCK_STEP "ace:shift+F": 5) —
    #   an earlier Shift+F would have been redirected, not spent.
    deadline = time.time() + 20.0
    capstone_live = False
    while time.time() < deadline and not capstone_live:
        actives_row2 = step("active_quests", full=True)
        for q in actives_row2.get("quests", []) or []:
            if q.get("tutorial_teaches") == "reap_season":
                capstone_live = True
                break
        if not capstone_live:
            time.sleep(0.25)
    assert capstone_live, "reap_season capstone never went live after the Bell weave"
    # Come home and put the field in play, exactly as the capstone hint says:
    # reap only has material when explored plots are still in the season (the
    # core_loop plot was extracted — its terminal released), so explore fresh
    # ground before turning the wheel.
    demos_key = next(
        str(s["key"]).lower() for s in step("biome_slots").get("slots", [])
        if s["biome"] == "TheDemos"
    )
    press(demos_key, frames=8)
    press("8", frames=4)
    for pk in "GH":
        press(pk, frames=4)
        press("F", frames=8)   # explore — puts the plot in play
    step("press_key", key="F", shift=True, settle_frames=12)

    deadline = time.time() + 20.0
    fired = {}
    while time.time() < deadline:
        row = step("story_flags")
        fired = row.get("flags_fired", {}) if row.get("ok", False) else {}
        if "arc_handover" in fired:
            break
        time.sleep(0.25)
    assert "loom_opens" in fired, f"loom_opens did not fire on the title path: {fired}"
    assert "first_harvest" in fired, (
        f"first_harvest did not fire on the capstone reap (unfunded reaps refuse "
        f"and record nothing — was the 🍼 grant missing?): {fired}"
    )
    assert "arc_handover" in fired, f"arc_handover did not fire on the title path: {fired}"
