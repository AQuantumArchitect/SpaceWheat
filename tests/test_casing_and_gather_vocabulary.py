"""One casing recipe, and one name for the Q verb (2026-08-25).

Two owner asks, both about the same failure mode — a thing that should have
had one spelling having four.

CASING. "The trims and boundaries are a little messy … I'd like most
everything in bounding boxes, just to give some structure that might later be
replaced with a custom UI casing." That last clause is the requirement: the
box has to be swappable in ONE place. Before this there were four spellings of
the same bevelled box (ResourcePanel outset a brass ghost by +3 at radius+2,
ActionPreviewRow inset one by -3 at radius-2, ChromeFrame lerped N rings at a
CONSTANT radius so its inner corners never nested, SelectionButtonRow and
FpsDisplay drew one bare stroke) and one region — the TimeBar — with no box at
all. `UIStyleFactory.draw_casing` is now the only one.

VOCABULARY. The Q verb had FOUR names: `pop` (the id), "Extract" (the chip),
"Harvest" (the reward toast and Shift+Q), and "gather" (the prose an earlier
pass introduced). The id stays `pop` — it is not player-facing and renaming it
would reach into saves and catalogs. Everything a player reads says Gather.
"""

from conftest import ROOT, read_source

# Regions that must wear the shared casing. Each is a band or corner card the
# player sees as one box; adding a HUD region means adding it here.
CASED_REGIONS = (
    "UI/Widgets/ResourcePanel.gd",
    "UI/Widgets/TimeBar.gd",
    "UI/Widgets/ActionPreviewRow.gd",
    "UI/Widgets/SelectionButtonRow.gd",
    "UI/Widgets/ChromeFrame.gd",
    "UI/HUD/FpsDisplay.gd",
)


def test_the_casing_has_exactly_one_recipe() -> None:
    factory = read_source("UI/Core/UIStyleFactory.gd")
    assert "static func draw_casing(" in factory
    # The radius must track the inset, or inner rings' corners are not
    # concentric with outer ones — the bug ChromeFrame's own copy carried.
    body = factory.split("static func draw_casing(", 1)[1].split("\nstatic func ", 1)[0]
    assert "CASING_RADIUS - step" in body, (
        "a casing whose rings all share one corner radius is a stack of "
        "mismatched rounded rects, not a bevel"
    )


def test_every_hud_region_wears_it() -> None:
    for rel in CASED_REGIONS:
        assert "UIStyleFactory.draw_casing(" in read_source(rel), rel


def test_no_widget_spells_its_own_bevel() -> None:
    # A widget passing a brass tone straight to draw_trim is hand-rolling the
    # casing again — that is how four spellings happened the first time.
    offenders = []
    for path in (ROOT / "UI").rglob("*.gd"):
        rel = path.relative_to(ROOT).as_posix()
        if rel == "UI/Core/UIStyleFactory.gd":
            continue
        src = path.read_text(encoding="utf-8")
        if "draw_trim(" in src and "COLOR_BRASS" in src:
            offenders.append(rel)
    assert offenders == [], (
        "hand-rolled bevel — call UIStyleFactory.draw_casing instead: %s" % offenders
    )


def test_a_box_never_nests_inside_a_box() -> None:
    # The transport chips ride INSIDE the TimeBar's casing, so their row
    # declines its own tray. A tray in a band-box reads as clutter, which is
    # the "messy" this pass was sent to remove — not as structure.
    row = read_source("UI/Widgets/SelectionButtonRow.gd")
    assert "func _draws_own_casing() -> bool:" in row
    assert "_draws_own_casing()" in row.split("func _draw() -> void:", 1)[1]
    clock = read_source("UI/Widgets/ClockSpeedRow.gd")
    declined = clock.split("func _draws_own_casing() -> bool:", 1)[1].split("\n\n", 1)[0]
    assert "return false" in declined
    # Same rule for the debug readout: it left the TimeBar band rather than sit
    # boxed inside a boxed region, and it clears every OTHER band by deriving
    # its top from them — a card floats on the field, never inside a panel.
    shell = read_source("UI/PlayerShell.gd")
    fps_block = shell.split("if fps_display:", 2)[2].split("\n\n", 1)[0]
    assert "get_resource_bar_height()" in fps_block
    assert "get_time_bar_height()" in fps_block


def test_the_counters_fit_inside_the_strips_own_box() -> None:
    # Sizing a glyph from its FONT is blind to how tall the band is, so
    # full-bleed SVGs (🌾, 🪵) drew through the casing while padded ones
    # (👥, 🍞) looked fine. The band is the authority.
    panel = read_source("UI/Widgets/ResourcePanel.gd")
    assert "get_resource_bar_height()" in panel
    assert "icon_font_size * 1.5" not in panel and "icon_font_size * 1.8" not in panel


# ------------------------------------------------------------------ docking

# Panels SEAT into the chassis: their screen-facing edges meet the bezel and
# carry no line of their own. Cards FLOAT on the field: all four edges drawn,
# all four corners rounded, inset clear of the frame. Each entry is
# (file, the CasingEdge names that must be FREE).
DOCKED_PANELS = (
    ("UI/Widgets/ResourcePanel.gd", ("BOTTOM",)),
    ("UI/Widgets/TimeBar.gd", ("TOP", "BOTTOM")),
    ("UI/Widgets/ActionPreviewRow.gd", ("TOP",)),
)
FLOATING_CARDS = (
    "UI/Widgets/SelectionButtonRow.gd",
    "UI/HUD/FpsDisplay.gd",
)


def test_the_chassis_geometry_has_one_home() -> None:
    # The docking system's whole claim is that a panel edge and the bezel's
    # inner ring land on the SAME line. Two constants that have to agree will
    # not stay agreeing, so ChromeFrame reads its geometry off the factory.
    factory = read_source("UI/Core/UIStyleFactory.gd")
    for const in ("BEZEL_OUTER_INSET", "BEZEL_RING_COUNT", "BEZEL_INNER_INSET"):
        assert "const %s" % const in factory, const
    frame = read_source("UI/Widgets/ChromeFrame.gd")
    assert "UIStyleFactory.BEZEL_OUTER_INSET" in frame
    assert "UIStyleFactory.BEZEL_RING_COUNT" in frame


def test_panels_seat_into_the_bezel_on_every_screen_facing_edge() -> None:
    for rel, free in DOCKED_PANELS:
        src = read_source(rel)
        call = src.split("UIStyleFactory.draw_casing(", 1)[1].split("\n\n", 1)[0]
        for edge in ("TOP", "RIGHT", "BOTTOM", "LEFT"):
            named = "CasingEdge.%s" % edge in call
            assert named == (edge in free), (
                "%s: edge %s should be %s" % (rel, edge, "FREE" if edge in free else "DOCKED")
            )
        assert "CasingEdge.ALL" not in call, rel


def test_cards_still_float_free() -> None:
    # The contrast is the point: if everything docked, nothing would read as
    # sitting ON the field, and the chassis would stop meaning anything.
    for rel in FLOATING_CARDS:
        call = read_source(rel).split("UIStyleFactory.draw_casing(", 1)[1].split("\n\n", 1)[0]
        assert "CasingEdge." not in call, (
            "%s is a floating card — it takes the default all-edges casing" % rel
        )


def test_docked_panels_actually_reach_the_bezel() -> None:
    # A docked EDGE with an undocked RECT is the worst of both: no line drawn
    # and a visible gap where the line used to be.
    assert "UIStyleFactory.BEZEL_INNER_INSET" in read_source("UI/Widgets/ResourcePanel.gd")
    shell = read_source("UI/PlayerShell.gd")
    tb = shell.split("if time_bar and layout_manager", 1)[1].split("\n\n", 1)[0]
    assert "BEZEL_INNER_INSET" in tb and "offset_left = 20" not in tb
    abm = read_source("UI/Managers/ActionBarManager.gd")
    dock = abm.split("func _position_action_row", 1)[1].split("\nfunc ", 1)[0]
    assert "BEZEL_INNER_INSET" in dock
    assert "offset_bottom = -bezel" in dock, (
        "the dock used to run off the viewport edge, crossing the whole molding "
        "band and burying the corner rivets under its own rounded corners"
    )


def test_a_docked_band_spans_rail_to_rail() -> None:
    # ResourcePanel is an HBoxContainer; left to itself it sizes to its own
    # content, so the seated panel's one drawn edge stopped in mid-air wherever
    # the wallet happened to end.
    assert "size_flags_horizontal = Control.SIZE_EXPAND_FILL" in read_source(
        "UI/Widgets/ResourcePanel.gd")


# --------------------------------------------------------------- vocabulary

def test_the_q_chip_says_gather() -> None:
    tool = read_source("Core/GameState/ToolConfig.gd")
    ace_q = tool.split('"action": "pop"', 1)[1].split("}", 1)[0]
    assert '"label": "Gather"' in ace_q
    assert '"Extract"' not in tool


def test_the_shift_variant_and_the_toast_agree_with_it() -> None:
    assert '"shift_label": "Mass Gather"' in read_source("Core/GameState/ToolConfig.gd")
    assert '"label": "Mass Gather"' in read_source("UI/Core/InputBindingRegistry.gd")
    # The reward toast used the fourth name, "harvest", for the same verb.
    assert '"plot_harvest": "gather"' in read_source("Core/Story/PlayerEventBridge.gd")


def test_no_player_facing_surface_still_says_extract() -> None:
    # Scoped to the surfaces that describe the Ace loop. Deliberately NOT a
    # repo-wide ban: "Extraction" is a faction icon (icons.json), and the
    # Merchant hat's "maximum extraction" is the Export verb, not Q.
    offenders = []
    for rel in ("Core/GameState/ToolConfig.gd", "UI/Overlays/ControlsOverlay.gd",
                "UI/Overlays/WelcomeOverlay.gd", "UI/Core/QuantumInstrumentInput.gd",
                "UI/Managers/UIContextController.gd", "Core/Quests/data/tutorial_arc.json"):
        for line in read_source(rel).splitlines():
            stripped = line.strip()
            if stripped.startswith("#") or "extract" not in stripped.lower():
                continue
            if "maximum extraction" in stripped.lower():
                continue  # Merchant's Export verb — a different action
            offenders.append("%s: %s" % (rel, stripped[:110]))
    assert offenders == [], (
        "the Q verb has one player-facing name and it is Gather:\n" + "\n".join(offenders)
    )


def test_the_dead_gather_stub_is_gone() -> None:
    # An unreferenced `GATHER_ACTIONS` const sat in Farm.gd naming a mechanic
    # that never shipped. Harmless while "gather" meant nothing; actively
    # confusing the moment it became the name of the Q verb.
    assert "GATHER_ACTIONS" not in read_source("Core/Farm.gd")
