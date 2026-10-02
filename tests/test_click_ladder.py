"""Source-shape pins for the HUD click contract.

Playtest 2026-09-09: clicks meant three different things depending on the
card. ClickLadder is the one grammar — detail, then the menu that already
holds this, then scoot toward the task.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LADDER = ROOT / "UI" / "Core" / "ClickLadder.gd"
TOAST = ROOT / "UI" / "Widgets" / "HintToast.gd"
BANNER = ROOT / "UI" / "Widgets" / "ActFilament.gd"
CHIP = ROOT / "UI" / "Widgets" / "ContractChip.gd"
BOARD = ROOT / "UI" / "Overlays" / "QuestBoard.gd"
OM = ROOT / "UI" / "Managers" / "OverlayManager.gd"


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def test_ladder_names_the_three_rungs():
    text = src(LADDER)
    assert "TAP_FOR_MORE" in text
    assert "TAP_AGAIN_HOME" in text
    assert "TAP_AGAIN_SCOOT" in text
    assert "next_action" in text
    assert '"expand"' in text and '"home"' in text and '"scoot"' in text


def test_board_home_names_the_c_key():
    """Keyboard-first mill chip: C opens the board. Arc names X (wave 8:
    'tap to open the Arc' / [XI] was not a pressable key)."""
    text = src(LADDER)
    assert 'KEY_OPENS := "[%s] opens %s"' in text
    assert "func key_for_home" in text
    assert 'return "C"' in text
    assert 'return "X"' in text
    chip = src(CHIP)
    assert 'home_name = "the board"' in chip
    assert 'home_key = "C"' in chip
    banner = src(BANNER)
    assert '_ladder.home_key = "C"' in banner
    assert '"Market"' in banner
    assert '"Commitments"' in banner
    assert "open_board_on_market" in banner


def test_information_chips_climb_the_ladder():
    for path in (TOAST, BANNER, CHIP):
        text = src(path)
        assert "ClickLadder" in text, f"{path.name} is not on the ladder"
        assert "next_action" in text, f"{path.name} does not climb rungs"


def test_session_reset_tears_down_hud_chrome():
    shell = src(ROOT / "UI" / "PlayerShell.gd")
    assert "func _reset_session_chrome" in shell
    assert "ContractChip" in shell.split("func _reset_session_chrome")[1].split("func ")[0]
    store = src(ROOT / "Core" / "GameState" / "SaveStore.gd")
    assert "func wipe_play_state" in store
    life = src(ROOT / "Core" / "GameState" / "SessionLifecycle.gd")
    assert "SaveStore.wipe_play_state" in life
    deploy = src(ROOT / "scripts" / "lib" / "windows_desktop_deploy.sh")
    assert "reset.bat" in deploy
    assert "app_userdata" in deploy


def test_verb_room_toasts_do_not_scoot_past_accept():
    """Market/Arc/Commitments toasts open the room. A second tap must not
    scoot_toward and skip Accept/Claim (mill chip cheat, sibling)."""
    shell = src(ROOT / "UI" / "PlayerShell.gd")
    fn = shell.split("func show_hint")[1].split("func _sync_toast_stack_mouse")[0]
    assert "_is_verb_room_home" in fn
    helper = shell.split("static func _is_verb_room_home")[1].split("static func ")[0]
    assert "commitments" in helper
    assert "market" in helper
    assert '"ARC"' in helper
    intro = src(ROOT / "Core" / "Story" / "IntroVoice.gd")
    offer = intro.split("func toast_for_offer")[1].split("func flag_postcard")[0]
    assert '"path": "Q"' not in offer
    arc = src(ROOT / "UI" / "Overlays" / "ControlsOverlay.gd")
    tunnel = arc.split("func _tunnel_from_arc")[1].split("func _arc_shunt_kind")[0]
    assert "open_board_on_market" in tunnel


def test_overlay_manager_has_a_scoot_door():
    text = src(OM)
    assert "func scoot_toward" in text
    sig = text.split("func scoot_toward")[1].split("\n")[0]
    assert "plot_idx" in sig
    assert "glyph" in sig
    assert "func _focus_field_plot" in text
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    assert "func focus_plot(" in qii


def test_market_e_inspects_f_lands_on_the_plot():
    """Contracts > Market: E reads the stall, F stands on its plot — not
    the whole board. Shift+E refreshes. Lock lives on Commitments [U].
    Chip names come from VERB_* so toasts stay in sync. Do not accept
    or fill for them."""
    board = src(BOARD)
    assert "func _on_action_shift_e" in board
    assert "func _on_action_shift_f" in board
    assert "func _scoot_selected_to_plot" in board
    infos = board.split("func _current_verb_infos")[1].split("\nfunc ")[0]
    assert "VERB_INSPECT" in infos
    assert "VERB_PLOT" in infos
    assert "VERB_REFRESH" in infos
    assert "VERB_ACCEPT" in infos
    assert '"shift_label": lock_label' in board.split("func _held_verb_infos")[1].split("\nfunc ")[0]
    e_fn = board.split("func _on_action_e")[1].split("\nfunc ")[0]
    assert "_refresh_pool" not in e_fn or "FRAME_MANIFOLD" in e_fn
    shift_e = board.split("func _on_action_shift_e")[1].split("\nfunc ")[0]
    assert "_refresh_pool" in shift_e
    f_fn = board.split("func _on_action_f")[1].split("\nfunc ")[0]
    assert "_scoot_selected_to_plot" in f_fn
    assert "_toggle_lock_selected" not in f_fn
    shift_f = board.split("func _on_action_shift_f")[1].split("\nfunc ")[0]
    assert "_toggle_lock_selected" in shift_f
    assert "FRAME_MARKET" in shift_f
    assert "VERB_LOCK" in shift_f
    ob = src(ROOT / "UI" / "Core" / "OverlayBase.gd")
    assert "func handle_action(action_key: String, shift: bool = false)" in ob
    assert "func _on_action_shift_e" in ob
    assert "func action_cue(" in ob
    shell = src(ROOT / "UI" / "PlayerShell.gd")
    assert "handle_action(action_key, shift)" in shell


def test_hud_toasts_skip_detail():
    """Popups are tracker + link. DETAIL is a reprint of the menu; skip it."""
    text = src(TOAST)
    show = text.split("func show_text")[1].split("\nfunc ")[0]
    assert "has_detail = false" in show
    assert '_detail = ""' in show


def test_f_follows_a_live_toast_into_its_menu():
    """Literalist: F on a live toast opens the named home and the card stays.
    Shift+F is still Reap. Confirm/submenu still own E/F. Opening the home
    must not flatten the instruction."""
    toast = src(TOAST)
    assert "func follow(" in toast
    assert "func owns_f(" in toast
    assert "func f_chip_label(" in toast
    assert "_overlay_is_open" in toast
    ob = src(ROOT / "UI" / "Core" / "OverlayBase.gd")
    fgate = ob.split("get_action_keycode(\"F\")")[1].split("func ")[0]
    assert "return false" in fgate
    follow = toast.split("func follow(")[1].split("\nfunc ")[0]
    assert "owns_f()" in follow
    assert '_ladder.commit("home")' in follow
    assert "_on_tap.call()" in follow
    assert "flatten()" in follow
    assert "[F] opens" in toast
    assert "func _confirm_pending(" in toast
    ace = src(ROOT / "Core" / "UI" / "AceChipResolvers.gd")
    assert "ace_f_would_explore" in ace
    assert "banner_explore" in ace
    qii = src(ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd")
    assert "flatten_all_toasts" in qii
    shell = src(ROOT / "UI" / "PlayerShell.gd")
    inp = shell.split("func _input(")[1].split("func _mark_input_handled")[0]
    assert "top_toast.follow()" in inp
    assert "owns_f" in inp
    assert "toast_f_chip_label" in shell
    assert "qii_owns_ef" in inp
    f_peek = inp.split("event.keycode == KEY_F:")[1].split("if event.keycode == KEY_F")[0]
    assert "not qii_owns_ef" in f_peek
    assert "hat_f_is_verb" in f_peek
    assert "paused" in f_peek
    ace = src(ROOT / "Core" / "UI" / "AceChipResolvers.gd")
    assert "_sim_paused" in ace
    assert "▶ Play" in ace
    chip = shell.split("func toast_f_chip_label")[1].split("\nfunc ")[0]
    assert "has_pending_confirm" in chip
    ace = src(ROOT / "Core" / "UI" / "AceChipResolvers.gd")
    assert "_toast_f_chip_label" in ace
    assert "is_shift_pressed" in inp
    assert "owns_ef_keys" in inp
    om = src(OM)
    home = om.split("func open_event_home")[1].split("func ")[0]
    assert "_flatten_toasts_for_home" not in home
    assert "_raise_toast_column" in home
    assert "func _raise_toast_column" in om


def test_arc_row_is_inspect_then_shunt_never_accept():
    """Arc is a catalog. Mash through it to the puzzle; R is the only accept."""
    arc = src(ROOT / "UI" / "Overlays" / "ControlsOverlay.gd")
    select = arc.split("func _select_arc_row")[1].split("\nfunc ")[0]
    assert "_tunnel_from_arc" in select
    assert "accept_quest" not in select
    assert "_on_action_r()" not in select
    ladder = src(LADDER)
    assert "Never accept" in ladder


def test_market_picks_up_commitments_delivers():
    text = src(BOARD)
    assert "HANDS_MAX" in text
    assert "func _market_rows" in text
    assert '"History"' in text
    assert "VERB_ACCEPT" in text
    assert "VERB_DELIVER" in text
    # Market (Y) is pickup. Commitments (U) is delivery. History is a
    # Commitments chord, not a top-level tab.
    tab_row = text.split("const TAB_ROW")[1].split("const HANDS_MAX")[0]
    assert '"Commitments"' in tab_row
    assert '"Market"' in tab_row
    market = text.split("func _market_rows")[1].split("\nfunc ")[0]
    assert "_is_fill_stall" not in market
    assert 'kind": "offer"' in market
    assert "func held_fill_for" in text
    assert "Market [Y] picks up" in text
    assert "Commitments [U] to deliver" in text
    overlay = src(ROOT / "UI" / "Core" / "OverlayBase.gd")
    assert "func action_cue(" in overlay
