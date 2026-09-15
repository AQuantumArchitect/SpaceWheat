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
    """Keyboard-first mill chip: C opens the board. Arc stays tap."""
    text = src(LADDER)
    assert 'KEY_OPENS := "[%s] opens %s"' in text
    assert "func key_for_home" in text
    assert 'return "C"' in text
    chip = src(CHIP)
    assert 'home_name = "the board"' in chip
    assert 'home_key = "C"' in chip
    banner = src(BANNER)
    assert '_ladder.home_name = "the board"' in banner
    assert '_ladder.home_key = "C"' in banner


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


def test_overlay_manager_has_a_scoot_door():
    text = src(OM)
    assert "func scoot_toward" in text


def test_hud_toasts_skip_detail():
    """Popups are tracker + link. DETAIL is a reprint of the menu; skip it."""
    text = src(TOAST)
    show = text.split("func show_text")[1].split("\nfunc ")[0]
    assert "has_detail = false" in show
    assert '_detail = ""' in show


def test_arc_row_is_inspect_then_shunt_never_accept():
    """Arc is a catalog. Mash through it to the puzzle; R is the only accept."""
    arc = src(ROOT / "UI" / "Overlays" / "ControlsOverlay.gd")
    select = arc.split("func _select_arc_row")[1].split("\nfunc ")[0]
    assert "_tunnel_from_arc" in select
    assert "accept_quest" not in select
    assert "_on_action_r()" not in select
    ladder = src(LADDER)
    assert "Never accept" in ladder


def test_market_is_one_board_with_stalls():
    text = src(BOARD)
    assert "HANDS_MAX" in text
    assert "func _market_rows" in text
    assert '"History"' in text
    assert "held" in text and "offer" in text
    # Fill tab is Commitments (U). Market (Y) is the stall board. History is
    # a Commitments chord, not a top-level tab.
    tab_row = text.split("const TAB_ROW")[1].split("const HANDS_MAX")[0]
    assert '"Commitments"' in tab_row
    assert '"Market"' in tab_row
