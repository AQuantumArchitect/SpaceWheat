"""Snapshot regression for the Surface refactor.

Ensures each refactored overlay still extends Surface and declares the
surface_id, so the snapshot contract cannot silently regress into an
OverlayBase-only implementation.
"""
from conftest import ROOT, read_source as _read

SURFACE_OVERLAYS = {
    "UI/Overlays/InspectorOverlay.gd": "N",
    "UI/Overlays/BiomeInspectorOverlay.gd": "B",
    "UI/Overlays/MapMetaOverlay.gd": "M",
    "UI/Overlays/QubitAtlasOverlay.gd": "V",
    "UI/Overlays/QuestBoard.gd": "C",
    "UI/Overlays/ControlsOverlay.gd": "X",
    "UI/Overlays/EscapeMenu.gd": "Z",
    "UI/Core/FarmSurface.gd": "farm",
}


def test_each_surface_overlay_extends_surface_and_sets_surface_id() -> None:
    for rel_path, expected_id in SURFACE_OVERLAYS.items():
        src = _read(rel_path)
        if rel_path.endswith("FarmSurface.gd"):
            # FarmSurface is a headless snapshot participant (not an overlay).
            assert 'const SURFACE_ID := "farm"' in src, rel_path
            continue
        assert 'extends "res://UI/Core/Surface.gd"' in src, (
            f"{rel_path} must extend Surface.gd"
        )
        assert f'surface_id = "{expected_id}"' in src, (
            f"{rel_path} must set surface_id = \"{expected_id}\""
        )


def test_semantic_map_overlay_removed() -> None:
    # Phase 6 cleanup: M replaces the old SemanticMapOverlay.
    assert not (ROOT / "UI/Overlays/SemanticMapOverlay.gd").exists()


def test_surface_registry_exposes_beneath_helpers() -> None:
    # Z depends on these to read the surface it is currently legending for.
    src = _read("UI/Core/SurfaceRegistry.gd")
    assert "func get_topmost_excluding(" in src
    assert "func get_snapshot_beneath(" in src


def test_surface_base_exposes_shared_chrome_helpers() -> None:
    src = _read("UI/Core/Surface.gd")
    for token in [
        "func get_page_index() -> int:",
        "func get_page_count() -> int:",
        "func build_surface_visible_data(",
        '"page_index": get_page_index()',
        '"page_count": get_page_count()',
        '"selected_label": selected_label',
        '"surface_hint": surface_hint',
    ]:
        assert token in src, token


def test_top_level_menu_registry_includes_m_and_preserves_ring_order() -> None:
    src = _read("UI/Core/MenuRegistry.gd")
    for token in [
        'KEY_Z',
        'KEY_X',
        'KEY_C',
        'KEY_V',
        'KEY_B',
        'KEY_N',
        'KEY_M',
        '"overlay_name": "map_meta"',
        '"description": "Biome x neighborhood relationships"',
    ]:
        assert token in src, f"MenuRegistry missing {token}"
    order = [src.index(token) for token in [
        'KEY_X',
        'KEY_Z',
        'KEY_C',
        'KEY_V',
        'KEY_B',
        'KEY_N',
        'KEY_M',
    ]]
    assert order == sorted(order), "MenuRegistry top-level ring must stay Z→M"


def test_cn_docs_describe_the_current_handoff_loop() -> None:
    manifest = _read("UI/Core/SURFACE_MANIFEST.md")
    grammar = _read("UI/Core/KEYBOARD_GRAMMAR.md")

    for token in [
        "C is the contract board. It consumes the N→C handoff when present and",
        "falls back to current-biome scope when no handoff exists.",
        "N is the biome network / dissipation surface. Its first page is the",
        "network view; the selector page is a browseable biome atlas.",
        "N now also carries",
        "M is the biome × faction map, centered on the selected biome.",
        "Q / R adjust the orbit and zoom on",
        "scope_mode",
        "scope_source",
        "scope_counterparty",
    ]:
        assert token in manifest, token

    for token in [
        "N → C",
        "deliberate two-step loop",
        "consumes the pending scope on open",
        "scope source",
    ]:
        assert token in grammar, token


def test_x_guide_defines_neighborhood_as_icon_signature_plus_biome() -> None:
    src = _read("UI/Overlays/ControlsOverlay.gd")
    for token in [
        "Biomes, Neighborhoods & Economy",
        "canonical terms",
        "full glossary",
        "A neighborhood is an icon signature plus a biome.",
        "icon signature",
        "biome",
        "neighborhood",
        "signature",
        "faction",
        "icon",
    ]:
        assert token in src, token
    assert src.index("canonical terms") < src.index("full glossary")
    assert "Hamiltonian" not in src


def test_player_facing_signature_language_uses_installed_signature() -> None:
    controls = _read("UI/Overlays/ControlsOverlay.gd")
    inspector = _read("UI/Overlays/InspectorOverlay.gd")
    quest = _read("UI/Overlays/QuestBoard.gd")
    assert "installed signature" in controls
    assert "realized signature" not in controls
    assert "neighborhood's installed signature spans more live biomes" in inspector
    assert "realized signature spans more live biomes" not in inspector
    for token in [
        "neighborhood lattice required",
        "no neighborhood partner",
        "no neighborhood offers",
        "live ↔ neighborhood",
        "no neighborhood bound",
        "no current neighborhood",
    ]:
        assert token in quest


def test_retired_cobweb_phrases_do_not_survive_on_player_surfaces() -> None:
    surfaces = {
        "UI/Overlays/ControlsOverlay.gd": _read("UI/Overlays/ControlsOverlay.gd"),
        "UI/Overlays/InspectorOverlay.gd": _read("UI/Overlays/InspectorOverlay.gd"),
        "UI/Overlays/QuestBoard.gd": _read("UI/Overlays/QuestBoard.gd"),
        "UI/Core/MenuRegistry.gd": _read("UI/Core/MenuRegistry.gd"),
    }
    realized_tag = "realized" + "_biome"
    retired = [
        "realized signature",
        "icon neighborhood",
        "faction-biome",
        "per-faction-biome",
    ]
    for path, src in surfaces.items():
        for token in retired:
            assert token not in src, f"{path} still contains {token}"
        assert realized_tag not in src, f"{path} still contains {realized_tag}"


def test_macro_actions_routed_through_facade() -> None:
    # Structural actions must go through MacroActions, not direct instrument calls.
    src = _read("UI/Core/QuantumInstrumentInput.gd")
    for kind in [
        "KIND_DISCOVER_BIOME",
        "KIND_REMOVE_BIOME",
        "KIND_INJECT_ICON",
        "KIND_REMOVE_ICON",
    ]:
        assert kind in src, f"QuantumInstrumentInput must reference MacroActions.{kind}"


def test_frame_selection_callers_are_strict() -> None:
    ctx = _read("UI/Managers/UIContextController.gd")
    instrument = _read("Core/Instrumentation/QuantumInstrument.gd")

    assert "action_bar_manager.select_frame(current_frame)" in ctx
    assert "refresh()" in ctx
    assert 'return {"frame": old_frame, "changed": false, "error": "invalid_frame"}' in instrument
    assert "if not ToolConfig.select_frame(frame_name)" in instrument


def test_boot_manager_exposes_canonical_request_entrypoints() -> None:
    src = _read("Core/Boot/BootManager.gd")
    for token in [
        "func boot_session(request: Dictionary = {}, farm_parent: Node = null) -> Node:",
        "func boot_runtime(farm: Node, shell: Node, quantum_viz: Node = null) -> void:",
        "boot_session start",
        "boot_runtime start",
    ]:
        assert token in src, token


def test_boot_callers_use_canonical_request_path() -> None:
    # GameRoot is the ONE runtime caller of boot_session + boot_runtime; the export tools
    # are the only other (headless, AppRoot-free) callers.
    callers = {
        "scenes/GameRoot.gd": [
            "boot_session(boot_request, self)",
            "boot_runtime(farm, player_shell, quantum_viz)",
        ],
        "tools/export_live_icon_map_live.gd": [
            "boot_session({",
        ],
        "tools/export_live_icon_map.gd": [
            "boot_session({",
        ],
    }
    for rel_path, tokens in callers.items():
        src = _read(rel_path)
        for token in tokens:
            assert token in src, f"{rel_path} missing {token}"


def test_save_load_routes_through_single_boot_authority() -> None:
    # SaveLoadCoordinator.load_and_apply must NOT re-implement boot by calling
    # BootManager.boot_session() directly (a partial pipeline with no GameRoot / boot_runtime
    # / AppRoot guard — the long-standing save/load dual-boot). When an AppRoot exists it
    # routes through restart_into() → AppRoot.start_game → GameRoot, the canonical path.
    src = _read("Core/GameState/SaveLoadCoordinator.gd")
    sla = src[src.index("func load_and_apply("):src.index("func load_and_apply_path(")]
    assert "boot_session(" not in sla, "load_and_apply must not call boot_session directly"
    assert "restart_into(slot)" in sla, "load_and_apply must route through restart_into"


def test_restart_into_awaits_the_approot_remount() -> None:
    # restart_from_pending_boot() is itself a coroutine (frees the old GameRoot, awaits two
    # process frames, then awaits start_game()). restart_into() previously called it bare
    # (no `await`) and returned right after kicking it off, so the whole await chain above it
    # -- load_and_apply(), the load_game rig verb's "loaded: true" ack -- resolved before the
    # remount actually finished. A caller reading farm state immediately after "loaded: true"
    # could see an empty story_flags_fired for over a second (found live via the mouse-only
    # campaign's wave 10: QuestBoard's menu button was missing because UIProgression read
    # tutorial_step against not-yet-applied state).
    src = _read("Core/GameState/SessionLifecycle.gd")
    start = src.index("func restart_into(")
    ri = src[start:start + 1500]
    assert "await app_root.restart_from_pending_boot()" in ri, \
        "restart_into must await restart_from_pending_boot(), not fire-and-forget it"


def test_quest_board_row_tap_requires_a_prior_select_before_confirming() -> None:
    # _selected_index defaults to 0, so row 0 in the Market/Commitments list reads as
    # "already selected" the instant the board opens -- before the player has looked at
    # anything. _on_row_gui_input's "second tap on the selected row fires the verb" shortcut
    # used to key off `idx == _selected_index` alone, which is trivially true for row 0 on
    # its very FIRST tap: a mouse-only player tapping the top offer just to see it instead
    # instantly accepted the contract, sight unseen. Found live via wave 11 of the mouse-only
    # campaign against the act2_complete checkpoint: a single tap on BoardRow_0 alone (no
    # verb-chip tap at all) produced a real accepted quest in active_quests. Worse, a script
    # that then tapped BoardVerb_R (the documented, correct confirm gesture) landed a SECOND,
    # different accept once the market pool refreshed a new offer into row 0 -- a silent
    # double-commit from what read as one deliberate action. _row_confirm_armed must gate the
    # same-index shortcut so a row only "already selected" by default (never actually tapped
    # or keyboard-navigated to) doesn't auto-confirm on its first tap.
    src = _read("UI/Overlays/QuestBoard.gd")
    select_fn = src[src.index("func _select(idx: int)"):src.index("func _on_quest_pool_changed(")]
    assert "_row_confirm_armed = true" in select_fn, \
        "_select() must arm confirm — only a real select (tap or keyboard nav) should allow the next tap to fire the verb"

    row_input_fn = src[src.index("func _on_row_gui_input("):src.index("func _toast_feedback(")]
    assert "idx == _selected_index and _row_confirm_armed" in row_input_fn, \
        "_on_row_gui_input must require _row_confirm_armed, not just an index match, before firing the verb"


def test_rig_boots_through_approot_not_a_parallel_shell() -> None:
    # The rig and a human player share ONE boot path and ONE PlayerShell: the rig brings up
    # the real AppRoot and lets it boot AppRoot → GameRoot → the app-owned shell, then drives
    # keys into that same shell. It must NOT hand-mount a parallel PlayerShell or call the
    # engine boot directly (that was the divergence that hid the welcome-trap bug).
    src = _read("🍄/🎛️/rig_listener.gd")
    assert 'AppRootClass = load("res://scenes/AppRoot.gd")' in src
    assert "app_root.get_player_shell()" in src
    assert "func _await_real_boot(" in src
    # No parallel boot: the rig delegates to AppRoot, never the engine boot calls itself.
    assert "boot_session(" not in src
    assert "boot_runtime(" not in src
    assert 'PlayerShellScene' not in src  # no hand-mounted shell
    # GameRoot stages the shell + instrument on ONE path (no headless early-return that
    # skips boot_runtime — that skip is what forced the rig to hand-mount).
    gr = _read("scenes/GameRoot.gd")
    assert "if bool(boot_request.headless):\n\t\tfarm_view.finalize_runtime_mount(true)" not in gr


def test_authority_adapter_exposes_access_tree_api() -> None:
    src = _read("Core/Factions/AuthorityAdapter.gd")
    for token in [
        "func compose_access_tree(factions: Array, biomes: Array) -> Dictionary:",
        "_compare_access_entries",
        "access-tree entry",
    ]:
        assert token in src, token
    overlay = _read("UI/Overlays/QubitAtlasOverlay.gd")
    assert "compose_access_tree([faction], [biome])" in overlay


def test_quest_board_market_path_is_strict_neighborhood_only() -> None:
    src = _read("UI/Overlays/QuestBoard.gd")
    for token in [
        "propose_neighborhood_offers_scoped(",
        "market unavailable: neighborhood lattice required",
        "market unavailable: no neighborhood partner",
        "market empty: no neighborhood offers",
    ]:
        assert token in src, token
    for token in [
        "_fallback_market_lattice_pool",
        "get_market_lattice()",
        "market.propose_offers(",
    ]:
        assert token not in src, token


def test_quest_manager_is_market_only_for_delivery_completion() -> None:
    src = _read("Core/Quests/QuestManager.gd")
    for token in [
        "offer_quest(",
        "offer_emoji_quest(",
        "offer_quest_emergent(",
        "_maybe_offer_attractor_quest(",
        "_annotate_quest_context(",
        "_track_biome_offer(",
        "_get_simulated_vocab_emojis(",
        "_stamp_offered_quest(",
        "QuestGenerator",
        "QuestTheming",
        "reward_fallback",
    ]:
        assert token not in src, token
    for token in [
        "market lattice required for quest completion",
        "lat.synthesize_and_exercise(",
        "economy.remove_resource(",
    ]:
        assert token in src, token


def test_app_root_boot_is_single_instance() -> None:
    # Two GameRoots = two FarmUIs / two action bars stacked (a dead instance over a live
    # one: stuck on Ace, captions frozen, input swallowed). The boot pipeline must be
    # single-instance: a re-entrancy guard that both start_game and restart_from_pending_boot
    # take, held across restart's null-game_root await window.
    src = _read("scenes/AppRoot.gd")
    assert "var _booting" in src, "AppRoot must declare a _booting re-entrancy guard"
    # start_game refuses to start while a boot is in progress.
    sg = src[src.index("func start_game("):src.index("func restart_from_pending_boot(")]
    assert "if _booting:" in sg and "_booting = true" in sg, "start_game must take the guard"
    # restart holds the guard across the teardown (so the null-game_root frames can't be raced).
    rs = src[src.index("func restart_from_pending_boot("):src.index("func return_to_title(")]
    assert "if _booting:" in rs and "_booting = true" in rs, "restart must take the guard first"


def test_app_root_warms_shell_before_title_card() -> None:
    src = _read("scenes/AppRoot.gd")
    for token in [
        "_create_player_shell()",
        "await get_tree().process_frame",
        "player_shell.warm_shell_surfaces(true)",
        "_build_title()",
    ]:
        assert token in src, token
    assert src.index("_create_player_shell()") < src.index("_build_title()")
    assert src.index("await get_tree().process_frame") < src.index("_build_title()")
    assert src.index("player_shell.warm_shell_surfaces(true)") < src.index("_build_title()")
