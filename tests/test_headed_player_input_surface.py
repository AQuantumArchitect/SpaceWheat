import json

from conftest import ROOT, read_source as _read


def test_rig_listener_exposes_player_input_backend_and_key_commands() -> None:
    src = _read("🍄/🎛️/rig_listener.gd")
    assert 'execution_backend?: "direct"|"player_input"|"auto"' not in src
    assert '"press_key":' in src
    assert '"key_sequence":' in src
    assert "func _press_key(" in src
    assert "func _select_biome_via_input(" in src
    assert "func _select_plot_via_input(" in src
    assert "func _open_quest_board_via_input(" in src
    assert '"quests"|"atlas"|"controls"' in src
    assert '"vocabulary"|"semantic_map"' not in src


def test_player_input_backend_does_not_hide_direct_fallbacks() -> None:
    src = _read("UI/Core/QuantumInstrumentInput.gd")
    assert "class_name QuantumInstrumentInput" in src
    assert "func _unhandled_key_input(" in src
    assert "func inject_instrument(" in src
    assert "func set_checked_plots(" in src
    assert "PlayerInputMacroRunner" not in src


def test_runner_batch_and_launcher_thread_display_backend_flags() -> None:
    runner = _read("🍄/🎛️/milk_hunt_runner.py")
    batch = _read("🍄/🎛️/milk_hunt_batch.py")
    client = _read("🍄/🎛️/rig_client.py")
    launcher = _read("🍄/🎛️/🟢.sh")
    # Shared CLI flags live in make_base_parser's spec table since the fable
    # push (slop knot #25); the runner composes it, so the flag literal lives
    # in milk_hunt_args.py while the runner's use of the value stays local.
    args_mod = _read("🍄/🎛️/milk_hunt_args.py")
    assert "--display-mode" in args_mod
    assert "make_base_parser" in runner
    assert "--policy-execution-backend" in runner
    assert "execution_backend=policy_execution_backend" in runner
    assert '--display-mode", str(display_mode)' in batch
    assert '--policy-execution-backend", str(policy_execution_backend)' in batch
    assert 'env["RIG_DISPLAY_MODE"] = str(display_mode or "headless")' in client
    assert "def clear_rig_files(self, preserve_live_sentinel: bool = True) -> None:" in client
    assert "if not preserve_live_sentinel or not self._bridge_sentinel_is_ready(self.xdg_root):" in client
    assert 'if [ "$RIG_DISPLAY_MODE" = "headed" ]; then' in launcher
    assert 'sw_godot --rendering-driver "$RIG_RENDERING_DRIVER" --path . --script 🍄/🎛️/rig_listener.gd' in launcher
    assert 'sw_godot --headless --path . --script 🍄/🎛️/rig_listener.gd' in launcher


def test_seed_save_accepts_headed_player_input_flags() -> None:
    seed = _read("🍄/🎛️/milk_hunt_seed_save.py")
    # --display-mode is a shared flag composed from make_base_parser (knot
    # #25); seed_save opts into it via only=. --ready-timeout stays local.
    args_mod = _read("🍄/🎛️/milk_hunt_args.py")
    assert "--display-mode" in args_mod
    assert '"display_mode"' in seed  # the only= opt-in
    assert "--ready-timeout" in seed
    assert 'display_mode=str(args.display_mode or "headless")' in seed
    assert "if proc is not None and not args.reuse_listener:" in seed


def test_dev_runner_forks_are_deleted() -> None:
    assert not (ROOT / "🍄" / "🎛️" / "dev" / "milk_hunt_runner_graphics_waits.py").exists()
    assert not (ROOT / "🍄" / "🎛️" / "dev" / "milk_hunt_runner_quantum_waits.py").exists()


def test_rig_listener_tap_injects_a_real_mouse_event() -> None:
    # Mouse-only campaign (2026-08-05) Phase 0: `tap` must inject a genuine
    # InputEventMouseButton press+release via push_input — the same event
    # class/path a real OS click takes — never call a picking handler
    # directly (that shortcut is what caused the "hit whatever plane it
    # might" bug months ago). dev_tap_register (QuantumField3D.gd) is the
    # shortcut pattern to avoid; it's dev/env-var-gated and NOT reachable
    # from this rig verb.
    src = _read("🍄/🎛️/rig_listener.gd")
    assert '"tap":' in src
    assert "InputEventMouseButton.new()" in src
    assert "tap_vp.push_input(tap_ev, true)" in src
    assert "rig_screen_pos_for_grid(tap_key)" in src


def test_control_rect_supports_scoped_lookup() -> None:
    # `control_rect`'s bare name search silently resolves to whichever
    # SelectionButtonRow (Tool/Biome/Menu) the DFS visits first, since all
    # three independently name children "SelectBtn_N" — an ambiguous match
    # is exactly the "click whatever it might" failure mode. `under` scopes
    # the search to a named ancestor's subtree.
    src = _read("🍄/🎛️/rig_listener.gd")
    assert '"control_rect":' in src
    assert 'cr_under := str(cmd.get("under", ""))' in src
    assert '"node_children":' in src


def test_selection_button_row_frees_buttons_before_readding() -> None:
    # _clear_buttons() must detach (remove_child) before queue_free(), not
    # queue_free() alone — otherwise a same-frame rebuild re-adds a child
    # with the same requested name while the old, not-yet-freed sibling
    # still occupies it, and Godot silently discards the new name in favor
    # of an auto-generated "@Control@N". That made every SelectBtn_N lookup
    # (Tool/Biome/Menu hat rows) fail after the row's first rebuild.
    src = _read("UI/Widgets/SelectionButtonRow.gd")
    assert "remove_child(btn_data.container)" in src
    assert "btn_data.container.queue_free()" in src


def test_app_boot_chain_zeroes_offsets_not_just_anchors() -> None:
    # set_anchors_preset(FULL_RECT) alone keeps the CURRENT offsets to preserve
    # the visual rect under the new anchors. For a freshly created (0,0)-sized
    # Control added to an already-realized (nonzero) parent, that bakes in
    # offsets equal to -parent_size, exactly cancelling the anchor scaling and
    # permanently collapsing .size to (0,0) -- with no visual symptom, since
    # nothing ever painted there anyway. AppRoot -> GameRoot -> QuantumField3D
    # is exactly this shape (each .new()'d and add_child()'d into an already-
    # sized live parent), so this silently zeroed out EVERY Control in the
    # game: the field's own _gui_input never fires (has_point() against a
    # (0,0) rect is never true), so no mouse click on ANY unexplored plot
    # bubble ever reaches handle_bubble_tap -- the game's own "or just tap
    # it" hint was false for a mouse-only player from the very first screen.
    # Only set_anchors_and_offsets_preset() actually zeroes the offsets so
    # the rect spans the (real) parent; that's the fix, pinned here so
    # nobody "simplifies" these three calls back to the bare form.
    for path in ("scenes/AppRoot.gd", "scenes/GameRoot.gd", "UI/PlayerShell.gd"):
        src = _read(path)
        assert "set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)" in src, path
        assert "\tset_anchors_preset(Control.PRESET_FULL_RECT)" not in src, path


def test_game_root_sits_below_player_shell_in_sibling_order() -> None:
    # Fixing the (0,0)-size bug above (test_app_boot_chain_zeroes_offsets_not_just_anchors)
    # exposed a SECOND, more severe bug it had been accidentally masking: GameRoot ->
    # QuantumField3D is a full-screen Control with MOUSE_FILTER_STOP, added as a LATER
    # sibling of PlayerShell under AppRoot -- no CanvasLayer actually separates them,
    # despite a comment in GameRoot.gd once claiming one does. Once the field's size
    # stopped being permanently (0,0), its full-screen hit-box started winning every
    # click meant for PlayerShell's HUD chrome underneath it (menu row, hat row, biome
    # row, all four Q/E/R/F action chips) -- a mouse player could tap plot bubbles
    # (routed through QuantumField3D itself) and nothing else. AppRoot.start_game()
    # must sibling-order GameRoot BELOW PlayerShell (move_child(game_root, 0)) so the
    # HUD stays on top for both rendering and input, matching the codebase's own
    # stated intent. Verified live: control_rect on MenuSelectionRow/ActionBtn_F
    # buttons now dispatch (ui_stack opens EscapeMenu; dispatch_ledger records
    # explore success=true) instead of silently hitting QuantumField3D.
    src = _read("scenes/AppRoot.gd")
    assert "add_child(game_root)" in src
    assert "move_child(game_root, 0)" in src
    add_idx = src.index("add_child(game_root)")
    move_idx = src.index("move_child(game_root, 0)")
    assert add_idx < move_idx, "move_child must run after add_child(game_root)"


def test_pointer_bleed_guard_does_not_treat_play_base_as_a_menu() -> None:
    # PlayerShell._any_menu_open() (the keyboard-side twin of this guard) correctly
    # checks overlay_stack.size() > 1 -- PlayBase (the permanent, never-popped stack
    # base, OverlayStackManager.gd) doesn't count as "a menu is open" on its own.
    # UIContextController._apply_pointer_bleed_guard() used to check is_empty()
    # instead and read the top overlay's is_transparent_overlay flag directly --
    # PlayBase never declares that property, so the instant it became the stack's
    # sole remaining top (i.e. normal gameplay, nothing open) after ANY real overlay
    # had been pushed+popped even once, menu_open evaluated true FOREVER, silently
    # disabling hat/biome row pointer input for the rest of the session. Must match
    # the keyboard guard's size() > 1 check exactly.
    src = _read("UI/Managers/UIContextController.gd")
    assert "overlay_stack.size() > 1" in src
    assert "overlay_stack.is_empty()" not in src


def test_player_shell_passes_through_clicks_it_does_not_claim() -> None:
    # PlayerShell extends Control, full-rect, and never set its OWN mouse_filter --
    # Godot's Control default is MOUSE_FILTER_STOP, so a full-screen PlayerShell
    # became the pick target for every point no NAMED child widget claimed (e.g.
    # empty HUD space over a 3D plot bubble). That silently absorbed every tap
    # aimed at QuantumField3D beneath it once AppRoot.start_game()'s sibling-order
    # fix (test_game_root_sits_below_player_shell_in_sibling_order, above) put
    # PlayerShell's HUD on top for picking -- the single most severe mouse-only
    # blocker of the whole campaign, since NO plot tap could ever reach the field.
    # Verified live: hover_probe at a bubble's exact screen_pos resolved to
    # PlayerShell, not QuantumField3D, until this filter was set.
    src = _read("UI/PlayerShell.gd")
    assert "mouse_filter = Control.MOUSE_FILTER_IGNORE" in src


def test_bubble_tap_verb_resolution_uses_terminal_state_methods() -> None:
    # handle_bubble_tap used to gate the explore/measure/pop verb choice on a
    # hand-rolled "terminal.is_bound" check BEFORE looking at is_measured.
    # Terminal.gd's MEASURE handler calls release_register(), which intentionally
    # sets is_bound=false while KEEPING is_measured=true (the register frees for
    # reuse; the terminal keeps its frozen snapshot so it can still be popped --
    # exactly Terminal.can_pop()'s documented case). Gating on is_bound first
    # excluded that state entirely, so every mouse Strike immediately fell through
    # to "explore" again instead of advancing to Extract -- the Explore->Strike->
    # Extract loop could never complete by mouse. Fixed by using the terminal's
    # own can_pop()/can_measure() methods. Verified live: tap 1 (explore) -> tap 2
    # (measure) -> tap 3 (pop), all success=true, mouse-only.
    src = _read("UI/Core/QuantumInstrumentInput.gd")
    assert "terminal.can_pop()" in src
    assert "terminal.can_measure()" in src


def test_controls_overlay_arc_tab_rows_and_pager_are_clickable() -> None:
    # Wave-4 sensor wall (literalist): the Arc tab (X > I) is the mouse path to
    # the game's own advertised "Hearth Keepers" quest offer, but its rows had
    # NO click affordance at all (only the R-accept HUD chip did -- a mouse
    # player could never pick WHICH row to accept), and the "page N/M · A/D"
    # footer was inert text with no mouse equivalent for A/D paging. Both now
    # route through ClickWire onto the SAME authorities the A/D keys and
    # GHJKL; picks already call (_select_arc_row / _on_navigate) -- one
    # selection/paging authority, not a duplicated mouse-only path. Verified
    # live: clicking a row moves the expanded predicate detail to that row;
    # clicking the pager glyph advances the page and its content.
    src = _read("UI/Overlays/ControlsOverlay.gd")
    assert "ClickWire.attach(row, _select_arc_row.bind(idx))" in src
    assert "func _select_arc_row(idx: int) -> void:" in src
    assert "ClickWire.attach(prev_lbl, _on_navigate.bind(Vector2i(-1, 0)))" in src
    assert "ClickWire.attach(next_lbl, _on_navigate.bind(Vector2i(1, 0)))" in src


def test_locked_action_chip_click_speaks_instead_of_going_silent() -> None:
    # A locked (progressive-disclosure) Q/E/R/F chip click used to be a total
    # no-op -- zero toast, zero press flash, indistinguishable from a click
    # that never landed (mouse-only campaign wave 4, lost-lamb). Verified
    # live: with a locked Icon-hat chip clicked, the toast "not yet -- now:
    # <objective>" (UIProgression.redirect_locked(), the same one the
    # keyboard's own locked-verb refusal already shows) now fires, and
    # dispatch_ledger correctly stays empty (no accidental dispatch).
    src = _read("UI/Widgets/ActionPreviewRow.gd")
    assert 'const UIProgression = preload("res://UI/Core/UIProgression.gd")' in src
    assert "UIProgression.redirect_locked()" in src
    assert 'label_node.text.contains("🔒")' in src


def test_action_chip_click_threads_shift_state_for_reap_season() -> None:
    # Wave-5 sensor wall (earnest): ActionPreviewRow's action_pressed signal
    # never carried the click's modifier state -- PlayerShell._route_action_key
    # -> QuantumInstrumentInput.invoke_action -> _dispatch_action_key all
    # hardcoded shift=false, so Shift+F "Reap Season" (the chip's own tooltip
    # names it) had NO mouse path at all, ever, for any input -- a real
    # ceiling, since tutorial step 2 requires exactly one reap gate and no
    # mouse-only player could ever produce one. Fixed by reading the real
    # mouse event's own shift_pressed (mirroring the keyboard path's
    # event.is_shift_pressed()) and threading it through every hop.
    apr_src = _read("UI/Widgets/ActionPreviewRow.gd")
    assert "signal action_pressed(action_key: String, shift: bool)" in apr_src
    assert "action_pressed.emit(action_key, event.shift_pressed)" in apr_src

    shell_src = _read("UI/PlayerShell.gd")
    assert "func _route_action_key(action_key: String, shift: bool = false) -> void:" in shell_src
    assert "instrument_input.invoke_action(action_key, shift)" in shell_src

    qii_src = _read("UI/Core/QuantumInstrumentInput.gd")
    assert "func invoke_action(action_key: String, shift: bool = false) -> void:" in qii_src
    assert "_dispatch_action_key(action_key, shift)" in qii_src


def test_tutorial_step1_hint_survives_the_objective_banners_truncation() -> None:
    # Wave-5 sensor wall (literalist): UIProgression._short_line() truncates
    # tutorial_hint at the first sentence boundary within a ~100-char
    # lookahead (OBJECTIVE_MAX_CHARS=70 + 30) -- the first fix's two-sentence
    # hint ("Cross to StarterForest first... Icon hat (5): F tracks...") put
    # the ACTIONABLE second sentence past that boundary, so it silently never
    # rendered on screen at all; the banner stayed byte-identical before and
    # after crossing biomes, with no instruction for what to do once there.
    # Pin the hint under OBJECTIVE_MAX_CHARS so the whole thing always shows.
    #
    # 2026-08-10: the destination moved OUT of the prose. Cramming "Cross to
    # StarterForest" into the hint made the banner repeat a journey the player
    # had already made — the literalist read a standing order it had obeyed,
    # and the lost-lamb called it LOOPING. UIProgression._travel_line() now
    # derives the crossing from the step's own `biome` field and drops it the
    # moment you arrive, so the hint is free to spend all 70 chars on the
    # ritual. The destination is still asserted — just at its real authority.
    OBJECTIVE_MAX_CHARS = 70
    data = json.loads(_read("Core/Quests/data/tutorial_arc.json"))
    step1 = next(s for s in data["steps"] if s.get("tutorial_step") == 1)
    assert len(step1["tutorial_hint"]) <= OBJECTIVE_MAX_CHARS
    assert step1["biome"] == "StarterForest"
    assert "Icon hat" in step1["tutorial_hint"]


def test_tutorial_objective_spotlight_honors_the_steps_own_biome() -> None:
    # The Icon-hat vocabulary step (tutorial_arc.json step 1) is authored to
    # happen in StarterForest -- TheDemos's only word is already the player's
    # own starting signature, so incorporating it there is refused by
    # construction (a real, silent dead end after a ~100s ripen wait; mouse-
    # only campaign wave 4). objective_target()'s TUTORIAL branch used to
    # hardcode biome:"" regardless of the step's own data, so
    # ObjectiveSpotlight never pulsed the biome tab to redirect the player.
    # Fixed by reading the step's own "biome" field (already present on the
    # quest dict -- QuestPipeline.from_tutorial_def copies it verbatim)
    # instead of discarding it.
    src = _read("UI/Core/UIProgression.gd")
    assert 'var step_biome := str(best.get("biome", ""))' in src
    assert 'return {"key": hat_key, "biome": step_biome}' in src


def test_mouse_biome_tab_click_gets_the_same_confirm_as_keyboard() -> None:
    # Wave-5 sensor wall (lost-lamb): a StarterForest plot bubble's orbit can
    # coincide with BiomeSelectionRow's fixed tab band, so a tap meant for
    # the bubble switches biomes instead -- reproduced 2/2, with NO toast and
    # NO Focus repoint either way, because the mouse path called
    # ActiveBiomeManager.set_active_biome() directly instead of going
    # through QuantumInstrumentInput._select_biome() (the keyboard TYUIOP
    # path), which is the only place that repoints the Focus cursor and
    # shows the "-> Village" confirm toast (added because "4 of 6 testers
    # couldn't tell it worked"). Root cause: two divergent code paths for
    # the same action. Fixed by routing both through a shared tail.
    row_src = _read("UI/Widgets/BiomeSelectionRow.gd")
    assert "signal biome_confirmed(old_biome: String, new_biome: String, key: String)" in row_src
    assert "var old_biome = active_biome_router.get_active_biome()" in row_src
    assert "biome_confirmed.emit(old_biome, biome_name, active_biome_router.get_slot_key(slot_idx))" in row_src

    qii_src = _read("UI/Core/QuantumInstrumentInput.gd")
    assert "func confirm_biome_switch(old_biome: String, new_biome: String, key: String) -> void:" in qii_src
    assert "_apply_biome_switch(old_biome, new_biome, key)" in qii_src

    shell_src = _read("UI/PlayerShell.gd")
    assert "biome_row.biome_confirmed.connect(_route_biome_confirm)" in shell_src
    assert "func _route_biome_confirm(old_biome: String, new_biome: String, key: String) -> void:" in shell_src
    assert "instrument_input.confirm_biome_switch(old_biome, new_biome, key)" in shell_src


def test_shift_tap_toggles_multiselect_check_for_entanglement() -> None:
    # Wave-6 sensor wall (earnest): the entanglement tutorial step reads
    # "Operator hat (9): hold Shift and tap two plot keys (G H J K L ;) to
    # check the pair, then press R and weave a Bell (Q)." The keyboard path
    # (Shift+GHJKL;) calls _toggle_check_at_plot_idx -> toggle_check, but a
    # mouse tap always ran the single-plot Explore/Strike/Extract cycle
    # regardless of shift state -- no hat that builds a multi-select
    # (Operator's Bell weave) had ANY mouse path, the true Act-1 mouse-only
    # ceiling. Fixed by threading the real click's shift_pressed state all
    # the way from QuantumField3D's _gui_input through node_clicked ->
    # FarmView -> handle_bubble_tap, which now toggles the checkbox instead
    # of running the verb cycle when shift is held (mirrors keyboard exactly:
    # no focus move, no Explore/Strike/Extract dispatch).
    field_src = _read("Core/Visualization/QuantumField3D.gd")
    assert "signal node_clicked(grid_pos: Vector2i, button_index: int, shift: bool)" in field_src
    assert "func _try_pick(screen_pos: Vector2, button: int, shift: bool = false) -> void:" in field_src
    assert "_try_pick(ev.position, ev.button_index, ev.shift_pressed)" in field_src
    assert "node_clicked.emit(best.grid_pos, button, shift)" in field_src

    qii_src = _read("UI/Core/QuantumInstrumentInput.gd")
    assert "func handle_bubble_tap(grid_pos: Vector2i, shift: bool = false) -> Dictionary:" in qii_src
    assert 'if shift:\n\t\ttoggle_check(grid_pos)' in qii_src

    shell_src = _read("UI/FarmView.gd")
    assert "func _on_quantum_node_clicked(grid_pos: Vector2i, button_index: int, shift: bool = false) -> void:" in shell_src
    assert "instrument_input.handle_bubble_tap(grid_pos, shift)" in shell_src


def test_field3d_miss_tap_toasts_instead_of_silent_no_op() -> None:
    # Wave-6 "active-biome desync" lead (earnest): re-investigated against
    # earnest's own real rig transcript (not a fresh guess) -- there was NO
    # biome-authority divergence anywhere in the recorded turns (zero
    # focus_biome dispatches, bubble_state's biome tag always matched what
    # was rendered). The real mechanism: QuantumField3D's own idle-drift +
    # live force-dynamics continuously move every orb, so a tap that lands
    # on empty space (the target having drifted since the player last
    # looked) was a SILENT no-op -- then a later action-chip press fired
    # against whatever plot was still focused from the last successful tap,
    # not the one the player was trying to reach. Fixed by toasting on a
    # genuine total miss in _try_pick.
    #
    # Live-verified this ALSO exposed a second, pre-existing bug: _toast()
    # called show_hint() with no importance arg, defaulting to 1 --
    # PlayerShell.show_hint()'s own doc comment says "Importance < 2 is
    # logged only; no toast is shown," so _toast() (incl. the pre-existing
    # depth-cap-refusal message below) had never actually shown anything.
    # A synthetic miss-tap produced zero new overlay lines until importance
    # was raised to 2, confirmed live via the rig.
    field_src = _read("Core/Visualization/QuantumField3D.gd")
    assert 'shell.show_hint("[color=#8899aa]•[/color] %s" % msg, 2)' in field_src
    assert '_toast("Nothing there — the field keeps moving, aim again")' in field_src


def test_fast_forward_ledger_matches_its_own_toast() -> None:
    # Wave-7 mouse-only lead (lost-lamb): Fast-Forward's chip toast always
    # fired ("the odds spin forward") but dispatch_ledger always logged
    # success:false for the same action -- two read sites shared one absent
    # dict key with OPPOSITE defaults. Farm.gd's time_skip_phrames() never
    # set "success" at all; QuantumInstrumentInput's toast check read
    # result.get("success", true) while its ledger-writer read
    # result.get("success", false) -- same missing key, opposite defaults,
    # opposite conclusions. Root-caused via lost-lamb's own precise repro
    # (Core/Farm.gd:1040, UI/Core/QuantumInstrumentInput.gd:2020+2300).
    # Fixed at the source: time_skip_phrames() now sets success:true on
    # every return path, so both readers agree without relying on defaults.
    farm_src = _read("Core/Farm.gd")
    assert '{"ok": true, "success": true, "phrames": 0, "delta": dt}' in farm_src
    assert '"ok": true,\n\t\t"success": true,\n\t\t"phrames": steps,' in farm_src


def test_submenu_actions_write_to_dispatch_ledger() -> None:
    # Wave-7 mouse-only finding (lost-lamb): a real, mouse-only Bell weave
    # (Operator hat, shift-tap two plots, gate submenu, tap Bell) genuinely
    # succeeded -- entanglement fired, the tutorial advanced -- with ZERO
    # new dispatch_ledger entry. _execute_build_gate() and
    # _execute_inject_icon() (the submenu-routed action handlers) only ever
    # emitted the action_performed signal; only _run_action() (the direct
    # Q/E/R/F chip path) wrote to dispatch_ledger. Rig probes that assert
    # exactly-once dispatch via dispatch_ledger were blind to every
    # submenu-routed action, including the campaign's own entanglement
    # mechanic. Fixed by factoring the ledger-append into a shared
    # _append_dispatch_ledger() helper and calling it from both submenu
    # handlers too.
    qii_src = _read("UI/Core/QuantumInstrumentInput.gd")
    assert "func _append_dispatch_ledger(action_name: String, success: bool) -> void:" in qii_src
    assert '_append_dispatch_ledger("build_gate", bool(result.get("success", false)))' in qii_src
    assert '_append_dispatch_ledger("build_gate", false)' in qii_src
    assert '_append_dispatch_ledger("inject_icon", true)' in qii_src
    assert '_append_dispatch_ledger("inject_icon", false)' in qii_src


def test_selection_button_row_defers_to_a_live_3d_pick_target() -> None:
    # Wave-7 documented lead (lost-lamb), fixed 2026-08-06 per owner ruling "defer to
    # 3D for all things, 2D is being deprecated": BiomeSelectionRow's fixed HUD band
    # structurally overlaps the 3D field's live orbit space, so a tap aimed at a
    # drifting StarterForest orb could land on a biome-tab chip instead -- and unlike
    # an ordinary miss, the biome switch shows a legible, CONFIRMING "-> Village"
    # toast, which reads as a deliberate success rather than a misdirected tap. Fixed
    # by teaching the shared SelectionButtonRow base (Tool/Biome/Menu rows all inherit
    # it) to check QuantumField3D.has_pickable_target() before claiming a click, and
    # forward to receive_deferred_tap() instead of doing chip selection when a real 3D
    # target is there. Live-verified via the rig: a tap that landed on an orb sitting
    # inside BiomeSelectionRow's own rect dispatched "explore" (a plot action) with
    # active_biome unchanged, instead of switching biomes.
    row_src = _read("UI/Widgets/SelectionButtonRow.gd")
    assert "func _live_field3d() -> Node:" in row_src
    assert 'get_tree().get_nodes_in_group("quantum_field_3d")' in row_src
    assert "func _defers_to_field3d(screen_pos: Vector2) -> bool:" in row_src
    assert "func _forward_to_field3d(screen_pos: Vector2, button: int, shift: bool) -> void:" in row_src
    assert "if _defers_to_field3d(event.global_position):" in row_src

    field_src = _read("Core/Visualization/QuantumField3D.gd")
    assert 'add_to_group("quantum_field_3d")' in field_src
    assert "func has_pickable_target(screen_pos: Vector2) -> bool:" in field_src
    assert "func receive_deferred_tap(screen_pos: Vector2, button: int, shift: bool = false) -> void:" in field_src


def test_field3d_has_no_passive_idle_rotation() -> None:
    # Owner ask, 2026-08-06: "the passive rotation of the manifold graph should be
    # removed... all motion and adjustment [should] have meaning or [be] the result
    # of the player" -- a playtester read the old idle auto-rotation as meaningful
    # when it wasn't. Removed the _process() pivot spin and its now-dead
    # _orbit_hold_until_ms gate/hold-timer entirely; camera motion is now only the
    # player's own drag, or the honest physics (force dynamics, Bloch-state
    # evolution). Live-verified via the rig: orb screen positions were pixel-identical
    # across 6s of real idle time with no input.
    field_src = _read("Core/Visualization/QuantumField3D.gd")
    assert "_pivot.rotate_object_local(Vector3.UP, dt * 0.08 * _time_scale)" not in field_src
    assert "_orbit_hold_until_ms" not in field_src


def test_install_checkpoint_verb_reuses_canonical_slot_load() -> None:
    # Owner ruling 2026-08-06: "checkpoints are supposed to be using the save/load
    # system, don't invent new systems." Wave 8 worked around the load_game_path /
    # QuantumField3D-remount gap with an ad hoc live-session double-hop (path-load ->
    # save-to-slot -> slot-load). Checkpoints are ordinary GameState .tres resources
    # (mint_checkpoint.py writes them via the same save_game_path -> ResourceSaver.save
    # SaveStore already uses for slot saves), so installing one is a plain file copy
    # onto a slot path -- no new boot pipeline needed. install_checkpoint does exactly
    # that copy; the caller then loads it through the already-canonical, AppRoot/
    # restart_into-aware load_game(slot) verb, unchanged.
    src = _read("🍄/🎛️/rig_listener.gd")
    assert '"install_checkpoint":' in src
    assert "DirAccess.copy_absolute(ckpt_path, dest_abs)" in src
    assert "SaveStore.get_save_path(install_slot)" in src
