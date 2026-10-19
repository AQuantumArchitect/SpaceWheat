"""Captain [7] R = Chart — story biomes are reached deliberately, not by luck.

Owner decision: while a story door beat (a compiled flag with a "chart"
field — woodlot_door → Woodlot, lantern_door → Lanternfall, ...) is open and
its biome is not on the spindle, Captain R charts THAT biome at the chart
price (CampaignRuntime.chart_cost(), 🦅×21). With no open door, R stays the
random Add Biome for side biomes. Slots full still refuses toward the cull.

The godot battery (tests/captain_chart_smoke.gd) drives the REAL
Farm.discover_biome on a booted farm; the source pins keep the chip, the
controls reference, the refusal toast and the banner on the one authority
(Farm.chart_target).
"""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
FARM = ROOT / "Core" / "Farm.gd"
PROG = ROOT / "UI" / "Core" / "UIProgression.gd"
QII = ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd"
TOOLS = ROOT / "Core" / "GameState" / "ToolConfig.gd"
CHIPS = ROOT / "Core" / "UI" / "ChipResolverRegistry.gd"
CAPTAIN = ROOT / "Core" / "UI" / "CaptainChipResolvers.gd"
CONTROLS = ROOT / "UI" / "Overlays" / "ControlsOverlay.gd"
FLAGS = ROOT / "Core" / "Quests" / "data" / "story_flags.json"
RUNTIME = ROOT / "Core" / "Quests" / "data" / "campaign_runtime.json"


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def test_chart_battery_drives_the_real_discover():
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    result = subprocess.run(
        ["godot", "--headless", "--script", "tests/captain_chart_smoke.gd"],
        cwd=ROOT, capture_output=True, text=True, timeout=300,
    )
    tail = (result.stdout + result.stderr)[-3000:]
    assert result.returncode == 0, f"chart battery failed:\n{tail}"
    assert "Captain chart smoke:" in result.stdout, tail
    assert " 0 failed" in result.stdout, f"chart battery reported failures:\n{tail}"
    assert "SCRIPT ERROR" not in result.stdout + result.stderr, tail


def test_every_door_beat_charts_a_biome_at_the_chart_price():
    flags = json.loads(src(FLAGS))
    doors = {f["id"]: f["chart"] for f in flags if f.get("chart")}
    runtime = json.loads(src(RUNTIME))
    assert runtime["charts"] == doors
    assert doors["woodlot_door"] == "Woodlot"
    assert doors["lantern_door"] == "Lanternfall"
    assert runtime["chart_cost"]["🦅"] == 21


def test_discover_branches_on_the_chart_target_not_the_draw():
    farm = src(FARM)
    assert "func chart_target() -> Dictionary" in farm
    target = farm.split("func chart_target() -> Dictionary")[1].split("\nfunc ")[0]
    assert "CampaignRuntime.charts()" in target
    assert "story_flags_fired" in target
    assert "flag_door_is_resolved" in target
    assert "get_all_story_flags" in target  # file order
    can = farm.split("func can_discover_biome()")[1].split("\nfunc ")[0]
    # Slots-full guidance wins over the chart (cull first).
    assert can.index("Biome slots full") < can.index("chart_target()")
    assert "CampaignRuntime.chart_cost()" in can
    assert "ActionCostRuntime.preflight_cost(" in can
    assert '"chart_short": true' in can
    disc = farm.split("func discover_biome()")[1].split("\nfunc ")[0]
    assert disc.index('gate.get("chart"') < disc.index("weighted_random_pick")
    assert "ActionCostRuntime.commit_cost(" in disc
    assert '"Charted %s!"' in disc
    short = farm.split("func chart_shortfall_message(")[1].split("\nfunc ")[0]
    assert "you hold" in short


def test_chip_and_controls_say_chart_when_r_will_chart():
    tools = src(TOOLS)
    captain_r = tools.split('"R": {"action": "discover_biome"')[1].split("}")[0]
    assert '"chip_resolver": "captain.r_chart"' in captain_r
    chips = src(CHIPS)
    assert '"captain.r_chart":' in chips
    assert "CaptainChipResolvers.resolve_r(ctx)" in chips
    cap = src(CAPTAIN)
    assert "chart_target_biome" in cap
    assert '"Chart %s"' in cap
    assert '"action"' not in cap.split("static func chart_patch")[1]  # same dispatch
    controls = src(CONTROLS)
    verbs = controls.split("func _guide_verbs_table")[1].split("\nfunc ")[0]
    assert "captain.r_chart" in verbs and "chart_patch(" in verbs


def test_chart_refusal_names_held_vs_needed_and_the_forest_walk():
    qii = src(QII)
    arm = qii.split('"discover_biome":')[1].split('"remove_biome":')[0]
    assert "chart_short" in arm
    assert arm.index("chart_short") < arm.index("slots_full_refusal")
    assert "eagle_short_refusal" in arm


def test_banner_points_at_captain_then_r_chart():
    prog = src(PROG)
    walk = prog.split("static func _discover_walk_line()")[1].split("\nstatic func ")[0]
    assert "_eagle_short" in walk and "_eagle_gather_line" in walk
    assert walk.index("_eagle_short") < walk.index("Chart")
    assert "_chart_target_biome()" in walk
    assert '"▸ [7] Captain, then [R] Chart %s"' in walk
    assert '"▸ [R] Chart %s"' in walk
    target = prog.split("static func objective_target()")[1].split("static func ")[0]
    paid = target.split("if _slots_full():")[1]
    assert "_chart_target_biome()" in paid
    flags = json.loads(src(FLAGS))
    lantern = next(f for f in flags if f.get("id") == "lantern_door")
    hint = str(lantern.get("arc_quest", {}).get("hint", ""))
    assert "[7]" in hint and "[R] Chart Lanternfall" in hint
