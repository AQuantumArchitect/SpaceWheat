"""The guidance resolver is parameterized by the spec (docs/design/
GUIDANCE_FROM_THE_SPEC.md). No Godot needed.

  * the guide block compiles into campaign_runtime.json unchanged
  * every walk step is a kind Core/Campaign/Guide.gd implements, and every
    kind Guide.gd implements is one the validator knows
  * every hat key in the keymap is the key ToolConfig binds to that hat
  * every Act 0 lesson and every main-campaign objective type has a walk
    (the legacy banner is only the fallback when a walk yields no step)
  * the voices read the resolver: the banner and spotlight ask Guide first,
    the Arc's NOW row is Guide's live beat, and story offers are announced by
    the live-beat transition instead of one generic card each
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "campaign"))
import spec as S  # noqa: E402
import validate  # noqa: E402

GUIDE = (ROOT / "Core" / "Campaign" / "Guide.gd").read_text(encoding="utf-8")


def _src(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def test_the_guide_block_compiles_into_the_runtime():
    spec = S.load()
    runtime = json.loads(_src("Core/Quests/data/campaign_runtime.json"))
    want = {k: v for k, v in spec["guide"].items() if not k.startswith("_")}
    assert runtime["guide"] == want


def test_walk_steps_and_resolver_kinds_agree():
    dispatch = GUIDE.split("static func _step(")[1].split("\nstatic func ")[0]
    implemented = set(re.findall(r'^\t\t"([a-z_]+)":', dispatch, re.M))
    assert implemented == validate.GUIDE_STEPS, (
        "Guide._step and validate.GUIDE_STEPS disagree: %s" % sorted(implemented ^ validate.GUIDE_STEPS))
    for wtype, steps in S.load()["guide"]["walks"].items():
        for st in steps:
            assert st.split(":")[0] in implemented, (wtype, st)


def test_hat_keys_match_the_live_bindings():
    hats = S.load()["guide"]["keymap"]["hats"]
    tc = _src("Core/GameState/ToolConfig.gd")
    consts = dict(re.findall(r'const (FRAME_[A-Z]+) := "([a-z]*)"', tc))
    bound = {consts[c]: k for k, c in re.findall(r'"(\d)": (FRAME_[A-Z]+)', tc)}
    assert bound, "ToolConfig's number-row table not found"
    for hat, key in hats.items():
        assert bound.get(hat) == key, "keymap says %s=[%s], ToolConfig binds %r" % (hat, key, bound.get(hat))


def test_main_campaign_and_act0_are_fully_walked():
    report = validate.validate(S.load())
    assert not report.errors, report.errors
    unwalked = [w for w in report.warnings if "no guide walk" in w]
    # Every objective type now has a walk; the legacy banner is only a fallback.
    assert not unwalked, unwalked


def test_every_voice_reads_the_resolver():
    prog = _src("UI/Core/UIProgression.gd")
    obj = prog.split("static func objective_text()")[1].split("\nstatic func ")[0]
    assert "_guide().next_step()" in obj.split("_banner_quest")[0], "banner must ask Guide before legacy lines"
    tgt = prog.split("static func objective_target()")[1].split("\nstatic func ")[0]
    assert "_guide().next_step()" in tgt
    iv = _src("Core/Story/IntroVoice.gd").split("static func live_quest(")[1].split("\nstatic func ")[0]
    assert "Guide.gd\").live_beat(" in iv
    bridge = _src("Core/Story/PlayerEventBridge.gd")
    assert "func _announce_live_beat" in bridge
    offered = bridge.split("func _on_quest_offered")[1].split("\nfunc ")[0]
    assert "on the Arc" in offered and ", 1," in offered, "story offers log quietly; the transition toast speaks"


def test_ranking_follows_the_story_not_the_ask_kind():
    rank = GUIDE.split("static func live_beat(")[1].split("\nstatic func ")[0]
    assert "_critical_path(" in rank
    assert "_is_plant_ask" not in GUIDE and "lantern_teaching" not in GUIDE, \
        "no ask-kind ladders or beat ids in the resolver"
