"""Page-contract regression for the surface overlays.

Keeps the live frame labels and visible-data keys aligned with the current
surface contract.
"""
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def _read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def _assert_in_order(src: str, tokens: list[str], label: str) -> None:
    pos = -1
    for token in tokens:
        next_pos = src.find(token, pos + 1)
        assert next_pos >= 0, f"{label} missing token {token}"
        pos = next_pos


def test_b_surface_is_single_frame_supports_view() -> None:
    src = _read("UI/Overlays/BiomeInspectorOverlay.gd")
    assert "FRAME_SUPPORTS" in src
    assert "frame_ids = [FRAME_SUPPORTS]" in src
    for token in [
        "Biome Microscope",
        "Pure overlay",
        "scope_mode",
        "build_surface_visible_data(",
        "get_visible_data() -> Dictionary:",
    ]:
        assert token in src, f"B surface missing token {token}"


def test_n_surface_reads_as_network_first() -> None:
    src = _read("UI/Overlays/InspectorOverlay.gd")
    _assert_in_order(
        src,
        ["FRAME_NETWORK", "FRAME_BRIDGES", "FRAME_MAP", "FRAME_LIVE", "FRAME_WHOLE", "FRAME_MATRIX"],
        "N frame_ids",
    )
    for token in [
        "Network",
        "Bridges",
        "Selector",
        "Live",
        "Whole",
        "Matrix",
        "network_hint",
        "handoff_target",
        "selected_edge_summary",
        "bridge_count",
    ]:
        assert token in src, f"N surface missing token {token}"


def test_m_surface_has_vectors_and_atlas_pages() -> None:
    src = _read("UI/Overlays/MapMetaOverlay.gd")
    _assert_in_order(src, ["FRAME_VECTORS", "FRAME_EIGEN", "FRAME_DRIFT", "FRAME_BITS", "FRAME_ATLAS"], "M frame_ids")
    for token in [
        "Vectors",
        "Eigenstate",
        "Drift",
        "Bits",
        "Atlas",
        "selected_axis",
        "cluster_snapshot",
        "atlas_state",
    ]:
        assert token in src, f"M surface missing token {token}"


def test_v_surface_keeps_canonical_icon_pages() -> None:
    src = _read("UI/Overlays/QubitAtlasOverlay.gd")
    _assert_in_order(
        src,
        [
            "FRAME_LEXICON",
            "FRAME_AFFINITY",
            "FRAME_ALIGNMENT",
            "FRAME_COVERAGE",
            "FRAME_HINTS",
            "FRAME_SUBSPACE",
        ],
        "V frame_ids",
    )
    for token in [
        "Qubit Atlas",
        "Lexicon",
        "Affinity",
        "Alignment",
        "Coverage",
        "Hints",
        "Subspace",
        "known_icon_count",
        "get_visible_data() -> Dictionary:",
        "get_snapshot() -> Dictionary:",
        "_on_action_f()",
        "Q/R/F  = empty — V is read-only reference",
    ]:
        assert token in src, f"V surface missing token {token}"


def test_c_surface_stays_on_contract_board_pages() -> None:
    src = _read("UI/Overlays/QuestBoard.gd")
    _assert_in_order(
        src,
        ["FRAME_MANIFOLD", "FRAME_MARKET", "FRAME_COMMITMENTS", "FRAME_ARC"],
        "C frame_ids",
    )
    for token in [
        "Manifold",
        "Market",
        "Commitments",
        "Arc",
        "scope_mode",
        "scope_source",
        "scope_counterparty",
        "get_page_index()",
        "get_page_count()",
        "_selected_label_for_tab()",
        "_current_tab_label()",
    ]:
        assert token in src, f"C surface missing token {token}"


def test_z_surface_reads_as_personal_mirror() -> None:
    src = _read("UI/Overlays/ControlsOverlay.gd")
    _assert_in_order(src, ["FRAME_SELF", "FRAME_STORY", "FRAME_BALANCE", "FRAME_GUIDE"], "Z frame_ids")
    for token in [
        "Self",
        "Story",
        "Balance",
        "Guide",
        "Biomes, Neighborhoods & Economy",
        "Verbs (per hat)",
        "Glossary",
        "biome",
        "signature",
        "neighborhood",
        "faction",
        "icon",
    ]:
        assert token in src, f"Z surface missing token {token}"


def test_x_surface_is_system_menu() -> None:
    src = _read("UI/Overlays/EscapeMenu.gd")
    _assert_in_order(src, ["FRAME_RUN", "FRAME_SAVE_LOAD", "FRAME_NEW_GAME", "FRAME_DEV"], "X frame_ids")
    for token in [
        "Now",
        "Save",
        "New",
        "Dev",
        "demos_normal",
        "new_game_easy",
        "_render_all(",
        "_refresh_body(",
    ]:
        assert token in src, f"X surface missing token {token}"
