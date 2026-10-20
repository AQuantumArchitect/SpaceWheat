"""The campaign spec is the ONE authoring source for the story, and it must
always be playable through. No Godot needed.

  * the generated runtime files match the spec (edit the spec, then run
    `python3 tools/campaign/build.py` — never hand-edit the outputs)
  * the validator replays every campaign with the supply model: 0 errors
  * the shape the owner decided (2026-10-17) holds: three campaigns, the two
    post-game ones open after the Demos ending, Incorporate taught in Act 1,
    every story biome has a deliberate chart beat, every offered beat asks
    for ONE thing (its objective) and opens on its requires alone.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "campaign"))
import build  # noqa: E402
import spec as S  # noqa: E402
import validate  # noqa: E402


def test_generated_files_are_in_sync_with_the_spec():
    assert build.main(["--check"]) == 0, "run: python3 tools/campaign/build.py"


def test_every_campaign_can_be_played_through():
    report = validate.validate(S.load())
    assert not report.errors, "campaign validator:\n  " + "\n  ".join(report.errors)


def test_three_campaigns_postgame_after_the_demos_ending():
    sp = S.load()
    kinds = {c["id"]: (c.get("kind"), c.get("ending"), c.get("opens_after", "")) for c in sp["campaigns"]}
    assert kinds == {
        "demos": ("main", "island_free", ""),
        "lanternfall": ("postgame", "the_door_stays_open", "island_free"),
        "loom": ("postgame", "close_it_upstairs", "island_free"),
    }


def test_incorporate_is_taught_in_act_one():
    idx = S.beats_by_id(S.load())
    camp, act, _ch, beat = idx["first_breath"]
    assert camp["id"] == "demos" and int(act["act"]) == 1
    assert beat["requires"] == ["village_stirs"]


def test_offered_beats_open_on_requires_alone():
    """One objective per beat: an offered beat's flag predicates are its
    requires (plus a trigger only for player choices), never a second copy
    of the objective."""
    flags = json.loads((ROOT / "Core/Quests/data/story_flags.json").read_text(encoding="utf-8"))
    for f in flags:
        if not f.get("arc_quest"):
            continue
        extra = [p for p in f["predicates"] if p["type"] != "story_flag_set"]
        if extra:
            assert f.get("branch_group"), f"{f['id']}: opens on {extra} — only choice beats carry a trigger"


def test_chain_tested_recharts_lanternfall():
    """Slots fill; Lanternfall is culled for Shrine. the_chain_tested must
    Chart the coast again, not assume the ancestor load still stands."""
    idx = S.beats_by_id(S.load())
    _camp, _act, _ch, beat = idx["the_chain_tested"]
    assert beat.get("chart") == "Lanternfall"
    kinds = [p.get("type") for p in beat.get("objective", [])]
    biomes = [p.get("biome") for p in beat.get("objective", [])]
    assert "biome_evolving" in kinds
    assert "Lanternfall" in biomes


def test_story_biomes_have_a_chart_beat():
    flags = json.loads((ROOT / "Core/Quests/data/story_flags.json").read_text(encoding="utf-8"))
    start = {"TheDemos", "Village", "StarterForest"}
    charted = {f["chart"] for f in flags if f.get("chart")}
    named = set()
    for f in flags:
        for p in (f.get("predicates", []) + ((f.get("arc_quest") or {}).get("state_predicates") or [])):
            if p.get("type") == "biome_evolving":
                named.add(p["biome"])
    assert named - start <= charted, f"story biomes with no chart beat: {sorted(named - start - charted)}"


def test_no_unresolved_params_in_generated_text():
    for name in ("story_flags.json", "tutorial_arc.json", "campaign_runtime.json"):
        txt = (ROOT / "Core/Quests/data" / name).read_text(encoding="utf-8")
        assert "{$" not in txt and '"$' not in txt, f"{name} carries an unresolved $param"


def test_validator_catches_a_broken_campaign():
    """Guard the guard: the replay must fail on the classic walls."""
    import copy
    base = S.load()

    def broken(mutate):
        sp = copy.deepcopy(base)
        idx = {b["id"]: b for _c, _a, _ch, b in S.iter_beats(sp, resolved=False)}
        mutate(sp, idx)
        return validate.validate(sp).errors

    assert broken(lambda sp, i: i["mill_wakes"].__setitem__("requires", []))
    assert broken(lambda sp, i: i["woodlot_door"].pop("chart"))
    assert broken(lambda sp, i: sp["resources"]["🪓"].__setitem__("trades", []))
    assert broken(lambda sp, i: sp["params"]["hub"].__setitem__("signature", 40))
    assert broken(lambda sp, i: sp["params"]["ladder"].__setitem__("timber_teaching", 0.9))


def _src(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def test_old_saves_do_not_reopen_passed_doors_or_leak_postgame():
    """Review fixes (2026-10-17): a door whose child fired is resolved on any
    save version (pre-v6 saves have no completed_quests ledger); post-game
    beats fired under the old single-campaign order stay dormant (no offer,
    no chart) until the main ending."""
    qm = _src("Core/Quests/QuestManager.gd")
    door = qm.split("func _flag_door_is_resolved")[1].split("\nfunc ")[0]
    assert "_child_has_fired(flag_id)" in door
    assert "func flag_is_live" in qm and "opens_after" in qm
    restore = _src("Core/Story/StoryEngine.gd").split("func _restore_arc_quests_after_load")[1].split("\nfunc ")[0]
    assert "flag_door_is_resolved" in restore and "flag_is_live" in restore
    chart = _src("Core/Farm.gd").split("func chart_target()")[1].split("\nfunc ")[0]
    assert "flag_is_live" in chart


def test_waiting_banner_prefers_the_critical_path():
    prog = _src("UI/Core/UIProgression.gd")
    waiting = prog.split("static func waiting_arc_offer")[1].split("\nstatic func ")[0]
    assert "blocking" in waiting, "an offer some unfired beat requires must outrank an optional leaf"
    assert "flag_door_is_resolved" in waiting


def test_chart_price_has_one_source():
    prog = _src("UI/Core/UIProgression.gd")
    assert "_eagle_have() < 21.0" not in prog
    assert "CampaignRuntime.chart_cost()" in prog.split("static func _chart_eagles")[1].split("\nstatic func ")[0]
