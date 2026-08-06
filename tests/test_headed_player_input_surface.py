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
    OBJECTIVE_MAX_CHARS = 70
    data = json.loads(_read("Core/Quests/data/tutorial_arc.json"))
    step1 = next(s for s in data["steps"] if s.get("tutorial_step") == 1)
    assert len(step1["tutorial_hint"]) <= OBJECTIVE_MAX_CHARS
    assert "StarterForest" in step1["tutorial_hint"]
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
