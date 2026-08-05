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
