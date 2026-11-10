"""Owner calls 2026-11-09 (after the overnight hive run).

  * no quest gate reads the retired `dynamics` channel (always -1: unwinnable)
  * Market Refresh is F (E inspects, F moves forward)
  * no two Arc quests share a title
  * restored ARC quests re-key their ask from the flag's current arc_quest
  * the banner fades on a no-progress timer after the tutorial (GuideFade)
  * the Druid tips a plot toward the resource before the first strike
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def _flags():
    return json.loads(src("Core/Quests/data/story_flags.json"))


def test_no_gate_reads_the_retired_dynamics_channel():
    matcher = src("Core/QuantumSubstrate/FactionStateMatcher.gd")
    assert "obs.dynamics = -1.0" in matcher, "channel revived? then this test can go"
    spec = src("Core/Campaign/campaign.json")
    assert '"type": "dynamics_at_most"' not in spec
    assert '"type": "dynamics_at_least"' not in spec
    for f in _flags():
        aq = f.get("arc_quest") or {}
        for p in list(f.get("predicates", [])) + list(aq.get("state_predicates", [])):
            assert not str(p.get("type", "")).startswith("dynamics_"), f["id"]


def test_still_the_pond_is_guided_by_the_druid():
    pond = next(f for f in _flags() if f["id"] == "pond_depths")["arc_quest"]
    types = [p["type"] for p in pond["state_predicates"]]
    assert "coherence_fell" in types
    assert "Druid" in pond["hint"] and "compass" not in pond["hint"]
    walks = json.loads(src("Core/Campaign/campaign.json"))["guide"]["walks"]
    assert walks["coherence_fell"] == ["still"]
    assert "static func _still(" in src("Core/Campaign/Guide.gd")


def test_market_refresh_is_f():
    board = src("UI/Overlays/QuestBoard.gd")
    f = board.split("func _on_action_f()")[1].split("\nfunc ")[0]
    e = board.split("func _on_action_e()")[1].split("\nfunc ")[0]
    assert "_refresh_pool()" in f and "_refresh_pool()" not in e
    assert '"F": "Refresh"' in board and '"E": "Refresh"' not in board
    keymap = json.loads(src("Core/Campaign/campaign.json"))["guide"]["keymap"]
    assert keymap["verbs"]["refresh"] == "F"


def test_arc_quest_titles_are_unique():
    titles = []
    for f in _flags():
        body = str((f.get("arc_quest") or {}).get("body", ""))
        if " — " in body:
            titles.append(body.split(" — ")[0])
    dupes = {t for t in titles if titles.count(t) > 1}
    assert not dupes, dupes


def test_restored_arc_quests_rekey_their_ask():
    qm = src("Core/Quests/QuestManager.gd")
    body = qm.split("func restore_from_save_dict(")[1].split("\nfunc ")[0]
    assert '"ARC"' in body and '== "ready"' in body
    assert 'for field in ["state_predicates", "hint", "body", "math_note"]' in body


def test_banner_fades_on_a_no_progress_timer():
    fade = src("Core/Campaign/GuideFade.gd")
    assert "static func speaks(" in fade and "SW_GUIDE_MODE" in fade
    assert "RuntimeEnv.is_headless()" in fade  # seats default to always-on
    assert "current_tutorial_step()" in fade   # the tutorial always speaks
    table = json.loads(src("Core/Campaign/campaign.json"))["guide"]["fade_after_s"]
    assert table == sorted(table) and table[-1] >= 180
    assert "_GUIDE_FADE.speaks(" in src("UI/Widgets/ActFilament.gd")


def test_druid_tips_toward_the_resource_before_the_first_strike():
    g = src("Core/Campaign/Guide.gd")
    gather = g.split("static func _gather(")[1].split("\nstatic func ")[0]
    assert gather.index("_tip_toward(res, q)") < gather.index('_hat("ace", q)')
    tip = g.split("static func _tip_toward(")[1].split("\nstatic func ")[0]
    assert "NO_TUTORIAL_SENTINEL" in tip and "strikes.size() > 0" in tip
    assert re.search(r"0\.5 if in_druid else 0\.4", tip) and "TIP_MS" in tip


def test_biome_change_reaches_quests_after_a_load():
    """A .bind(farm) callable died with the farm on load: after any load,
    travel never reached QuestManager (Past the Hedge froze at 50%)."""
    shell = src("UI/PlayerShell.gd")
    assert 'Callable(self, "_handle_active_biome_change").bind(' not in shell
    assert "func _handle_active_biome_change(biome_name: String, _old_biome: String) -> void:" in shell


def test_satisfied_but_unready_quest_waits_instead_of_naming_claim():
    beat = src("Core/Campaign/Guide.gd").split("static func _beat_step(")[1].split("\nstatic func ")[0]
    assert "is settling" in beat


def test_lane_files_unlink_with_retry_on_windows():
    rc = src("🍄/🎛️/rig_client.py")
    clear = rc.split("def clear_rig_files(")[1].split("\n    def ")[0]
    assert "_unlink_retry(self.queue_file)" in clear and "except PermissionError" in rc


def test_learn_word_explores_before_the_icon_hat():
    lw = src("Core/Campaign/Guide.gd").split("static func _learn_word(")[1].split("\nstatic func ")[0]
    assert lw.index("_berry_needs_reveal(cols)") < lw.index('_hat("icon", q)')


def test_focus_biome_follows_the_active_biome_after_a_load():
    qii = src("UI/Core/QuantumInstrumentInput.gd")
    keys = qii.split("func _unhandled_key_input(")[1].split("\nfunc ")[0]
    assert "_sync_focus_biome()" in keys
    mass = qii.split("func _mass_explore(")[1].split("\nfunc ")[0]
    assert "not farm.is_plot_revealed(pos)" in mass


def test_explore_heals_a_held_but_fogged_plot():
    ex = src("Core/Instrumentation/QuantumInstrument.gd").split("func action_explore(")[1].split("\nfunc ")[0]
    assert '"already_bound"' in ex and '"healed": true' in ex and "farm.reveal_plot(grid_pos)" in ex


def test_gather_buys_the_resource_when_no_basket_is_held():
    g = src("Core/Campaign/Guide.gd").split("static func _gather(")[1].split("\nstatic func ")[0]
    assert 'UIP._wallet("🧺") < 1.0 and res != "🧺"' in g and "_supply_via(tr, res, q, depth)" in g


def test_weaves_refuse_an_empty_mark_before_the_hadamard():
    # Wave 19 (distractible): marking a fogged ; then weaving gave a bare
    # "Failed to apply Hadamard"; with the empty mark second, the first plot
    # was H-rotated before the CNOT failed (a half-applied gate).
    gh = src("Core/Instrumentation/Handlers/GateActionHandler.gd")
    for fn, what in (("create_bell_pair", "A Bell pair"), ("create_ghz_state", "A GHZ weave")):
        body = gh.split("static func %s(" % fn)[1].split("\nstatic func ")[0]
        assert body.index('_refuse_no_qubit(farm, positions, "%s")' % what) < body.index('_apply_single_qubit_gate(')
    helper = gh.split("static func _refuse_no_qubit(")[1].split("\nstatic func ")[0]
    assert "explore it first" in helper and "[" not in helper.split('"message":')[1].split("\n")[0].replace("% [what, key]", "")


def test_tracked_unbound_plot_names_the_way_out():
    # Wave 19 keeper: a gathered plot whose loop was still tracked kept Ace F
    # on Fast-Fwd, so it could never be explored and Strike/Gather refused
    # with "R incorporates there" only. The refusal now names untracking.
    qii = src("UI/Core/QuantumInstrumentInput.gd")
    hint = qii.split("func _tracked_elsewhere_hint(")[1].split("\nfunc ")[0]
    assert "plot.terminal == null" in hint and "F stops tracking; then Ace F explores it again" in hint
    block = qii.split("func _block_reason_for_player(")[1].split("\nfunc ")[0]
    pop = block.split('"pop", "reap":')[1]
    assert pop.index("_tracked_elsewhere_hint()") < pop.index("nothing measured to gather here")


def test_staple_rescue_stands_while_the_gather_fee_is_short():
    # Wave 19 strict follower: 0 🧺, 3 👥 — 👥 rescue shut (3 > critical),
    # 🧺 costs more 👥 than held, Q costs 🧺. The rescue now stands during
    # the fee deadlock, and the Guide only routes to a rescue the board shows.
    qb = src("UI/Overlays/QuestBoard.gd").split("func _rescue_open(")[1].split("\nfunc ")[0]
    assert qb.index('emoji != "🧺" and _vital_stock("🧺") < UIProgression.gather_price()') < qb.index("return _vital_stock(emoji) <= STAPLE_CRITICAL")
    g = src("Core/Campaign/Guide.gd").split("static func _gather(")[1].split("\nstatic func ")[0]
    assert "fee_board._rescue_open(res)" in g


def test_anchored_incorporate_reads_as_counted_not_failed():
    # Waves 19-20: the Monolith counts Ledger loops (berry_consumed_count_gte),
    # but an anchored incorporate toasted "✗ …", and sensors left the plot.
    qii = src("UI/Core/QuantumInstrumentInput.gd").split("func _execute_incorporate_icon(")[1].split("\nfunc ")[0]
    assert "✗ %s already anchors" not in qii and "🧬 loop counted" in qii
    camp = src("Core/Campaign/campaign.json")
    assert "two Ledger loops (any Ledger plot counts)" in camp


def test_route_toast_does_not_steal_another_hats_f_verb():
    # Wave 20 distractible: Icon chip "[F] Track", but a route toast took F
    # and opened the Story memoir (twice). Only Ace relabels for a toast.
    owns = src("UI/Widgets/HintToast.gd").split("func owns_f(")[1].split("\nfunc ")[0]
    assert "frame != ToolConfig.FRAME_ACE" in owns
    assert owns.index("frame != ToolConfig.FRAME_ACE") < owns.index("ace_f_would_explore")


def test_every_tool_config_user_preloads_it():
    # ToolConfig has no class_name: a script that calls ToolConfig.* without
    # the preload fails to parse. 7c0a4808 broke every toast this way and
    # neither banner_follow nor the suite noticed.
    import re
    bad = []
    for p in list((ROOT / "UI").rglob("*.gd")) + list((ROOT / "Core").rglob("*.gd")):
        t = p.read_text(encoding="utf-8", errors="ignore")
        code = "\n".join(line.split("#")[0] for line in t.splitlines())  # comments don't count
        if p.name == "ToolConfig.gd" or not re.search(r"\bToolConfig\.", code):
            continue
        if not re.search(r"ToolConfig\s*(:?=)\s*(pre)?load\(", t):
            bad.append(str(p.relative_to(ROOT)))
    assert not bad, bad


def test_gate_order_doors_have_a_walk():
    # Wave 20 keeper: "Two Chores, One Thread" (gate_order hadamard→cnot,
    # mutual_information_at_least) had no Guide walk; the banner never named it.
    import json
    camp = json.loads(src("Core/Campaign/campaign.json"))
    walks = camp["guide"]["walks"]
    assert walks["gate_order"] == ["gate_word"]
    assert walks["mutual_information_at_least"] == ["entangle"]
    g = src("Core/Campaign/Guide.gd").split("static func _gate_word(")[1].split("\nstatic func ")[0]
    assert '_hat("druid", q)' in g and '_hat("operator", q)' in g
    assert 'str(a.get("gate_type", "")) == nxt' in g  # key read from the live picker
    assert '"gate_word"' in src("tools/campaign/validate.py")


def test_first_plot_press_after_a_load_picks_not_marks():
    # Wave 20 strict follower (47 flags): after a load current_plot_idx and
    # current_biome matched G while nothing was picked, so G toggled a mark
    # and the Guide's "plot [G]" repeated for ever.
    sel = src("UI/Core/QuantumInstrumentInput.gd").split("func _select_plot(")[1].split("\nfunc ")[0]
    hl = sel.split("var was_highlighted = (")[1].split(")")[0]
    assert "_instrument.last_selected_position == target_grid_pos" in hl


def test_gate_plant_uses_the_predicates_biome():
    # Night 2: lantern_wakes wants a plant IN Lanternfall (biome-stamped gate
    # key) but the Guide always planted in the Village — the Trim ⇄ Plant
    # churn that held every strict follower at 43-48 flags.
    g = src("Core/Campaign/Guide.gd").split("static func _gate(")[1].split("\nstatic func ")[0]
    assert '_plant(str(pred.get("biome", _km().get("plant_home", "Village")))' in g


def test_loop_came_home_has_a_walk():
    import json
    walks = json.loads(src("Core/Campaign/campaign.json"))["guide"]["walks"]
    assert walks["spinor_read"] == ["spinor"]
    sp = src("Core/Campaign/Guide.gd").split("static func _spinor(")[1].split("\nstatic func ")[0]
    assert '["Stay Home", "R"]' in sp and '["Compare", "E"]' in sp
    # only the hat, not its first mode: the walk lives in the mirror (mode 2)
    assert "get_current_frame()) != ToolConfig.FRAME_ICON" in sp


def test_two_chores_walk_has_no_strike_prep():
    # kp6: strikes don't collapse under the strike-bank model, so the pole
    # prep (c962069a) only spent 👥. Reverted; the MI half is a Bell weave.
    import json
    g = src("Core/Campaign/Guide.gd")
    assert "_to_pole(" not in g
    walks = json.loads(src("Core/Campaign/campaign.json"))["guide"]["walks"]
    assert walks["mutual_information_at_least"] == ["entangle"]


def test_free_terminal_pays_before_the_trip():
    ft = src("Core/Campaign/Guide.gd").split("static func _free_terminal(")[1].split("\nstatic func ")[0]
    assert ft.index("_supply(spend, q, 1)") < ft.index("_travel(biome, q)")



def test_steer_tips_before_the_ace_hat_and_pays_before_the_trip():
    g = src("Core/Campaign/Guide.gd")
    st = g.split("static func _steer(")[1].split("\nstatic func ")[0]
    assert st.index("_supply(spend, q, 1)") < st.index("_travel(biome, q)")
    assert st.index("_tip_toward(emoji, q)") < st.index('_hat("ace", q)')
    assert '_cost_or(["strike", "👥"]' in st
    tip = g.split("static func _tip_toward(")[1].split("\nstatic func ")[0]
    assert "TIP_STALL_MS" in tip  # a pinned pole gives up early


def test_arc_accept_clears_the_selection():
    # Masher w22 + keeper 7: after an accept the next door slid under the
    # cursor and a second R accepted it. Nothing is selected after an accept.
    co = src("UI/Overlays/ControlsOverlay.gd")
    acc = co.split("func _accept_selected_arc(")[1].split("\nfunc ")[0]
    assert "_arc_selected_idx = -1" in acc and "pick a door first" in acc


def test_armed_abandon_names_only_the_confirm():
    # Strict from zero (20 flags): Q toggles the abandon arm, so naming
    # "Abandon [Q] → confirm [F]" again disarmed it, forever.
    mh = src("Core/Campaign/Guide.gd").split("static func _market_held_chord(")[1].split("\nstatic func ")[0]
    assert "_abandon_arm_qid" in mh and "return _chord([tail], q, why)" in mh


def test_board_empty_slot_does_not_select_the_last_row():
    # Wave 26 distractible: L on an empty "—" slot clamped to the LAST row
    # (another page) and the next R accepted Hearth Keepers ×231.
    qb = src("UI/Overlays/QuestBoard.gd")
    sel = qb.split("func _select(")[1].split("\nfunc ")[0]
    assert sel.index("if idx >= total:") < sel.index("_selected_index = clampi(")
    # the market cursor follows its offer through live re-sorts
    assert "_reanchor_market_selection(rows)" in qb.split("func _selected_market_row(")[1].split("\nfunc ")[0]


def test_gather_buys_lap_staples_before_the_trip():
    # Strict from zero, 31 flags: 🍞 0, gather 🦅 — "to Village" ⇄ "to Starter
    # Forest" for 1000+ presses (the 🍞 check came after the trip).
    g = src("Core/Campaign/Guide.gd").split("static func _gather(")[1].split("\nstatic func ")[0]
    assert g.index('for staple in ["🍞", "👥"]') < g.index("var t := _travel(where, q)")
    sf = src("🍄/🧪/strict_follow.py")
    assert "STUCK (ping-pong)" in sf


def test_learn_word_buys_bread_before_the_trip():
    lw = src("Core/Campaign/Guide.gd").split("static func _learn_word(")[1].split("\nstatic func ")[0]
    assert lw.index('_supply("🍞", q, 1)') < lw.index("var t := _travel(str(b), q)")


def test_cull_confirm_says_what_it_costs():
    qii = src("UI/Core/QuantumInstrumentInput.gd")
    assert 'action_name in ["remove_biome"]' in qii and "it can be charted again later" in qii


def test_icon_f_chip_names_stopping_a_live_track():
    # Keepers 10-12 + a distractible killed live loops: F read "Track" while tracking.
    assert '"chip_resolver": "icon.f_track"' in src("Core/GameState/ToolConfig.gd")
    assert '"icon.f_track":' in src("Core/UI/ChipResolverRegistry.gd")
    rf = src("Core/UI/IconChipResolvers.gd").split("static func resolve_f(")[1]
    assert "register.is_tracked(ctx.qubit_index)" in rf and "Stop track" in rf


def test_confirm_prompt_toast_leaves_with_the_confirm():
    # Three sensors saw "Cull Biome — press F to confirm" linger after the cull.
    assert "func dismiss_toasts_with_home(" in src("UI/PlayerShell.gd")
    qii = src("UI/Core/QuantumInstrumentInput.gd")
    assert qii.count('dismiss_toasts_with_home("cancel_confirm")') >= 2


def test_open_country_drops_the_dlc_padlock():
    # Keeper 14: the Spark jolt fired in Gilded Rot (open country) but its chip
    # wore the closed-mode 🔒, so it was never pressed.
    ucc = src("UI/Managers/UIContextController.gd")
    assert "not BalanceConfig.dissipative_enabled() and not _active_biome_open()" in ucc
    assert "is_open_here()" in ucc.split("func _active_biome_open(")[1].split("\nfunc ")[0]


def test_guide_never_names_a_blind_arc_accept():
    da = src("Core/Campaign/Guide.gd").split("static func _door_accept(")[1].split("\nstatic func ")[0]
    assert da.index("if idx < 0:") < da.index('["Accept", _verb("accept")]')


def test_strike_again_shows_a_lap_counter():
    g = src("Core/Campaign/Guide.gd").split("static func _gather(")[1].split("\nstatic func ")[0]
    assert '"strike %d of %d, then Gather"' in g


def test_pump_and_drain_refusals_name_the_stake():
    lh = src("Core/Instrumentation/Handlers/LindbladHandler.gd")
    assert "Insufficient resources for drain" not in lh and "Insufficient resources for pump" not in lh
    assert lh.count("short of %s") == 2


def test_banner_verbs_match_the_chip_labels():
    # Literalist w32: banner "Hadamard [E]" vs chip "[E] Superpose";
    # "Build gate [R]" vs "[R] Gate".
    g = src("Core/Campaign/Guide.gd")
    assert '["Build gate", "R"]' not in g and '["Hadamard", "E"]' not in g
    import json
    assert json.loads(src("Core/Campaign/campaign.json"))["guide"]["keymap"]["verb_labels"]["E"] == "Superpose"
