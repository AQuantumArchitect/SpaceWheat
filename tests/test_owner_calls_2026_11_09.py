"""Owner calls 2026-11-09 (after the overnight hive run).

  * no quest gate reads the retired `dynamics` channel (always -1: unwinnable)
  * Market Refresh is F (E inspects, F moves forward)
  * no two Arc quests share a title
  * restored ARC quests re-key their ask from the flag's current arc_quest
  * the banner fades on a no-progress timer after the tutorial (GuideFade)
  * the Druid tips a plot toward the resource before the first strike
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def _flags():
    return json.loads(src("Core/Quests/data/story_flags.json"))


def test_no_gate_reads_the_retired_dynamics_channel():
    matcher = src("Core/QuantumSubstrate/FactionStateMatcher.gd")
    assert "obs.dynamics = -1.0" in matcher, "channel revived? then this test can go"
    spec = src("Core/Campaign/campaign.json")
    assert '"type": "dynamics_at_most"' not in spec
    assert '"type": "dynamics_at_least"' not in spec
    for f in _flags():
        aq = f.get("arc_quest") or {}
        for p in list(f.get("predicates", [])) + list(aq.get("state_predicates", [])):
            assert not str(p.get("type", "")).startswith("dynamics_"), f["id"]


def test_still_the_pond_is_guided_by_the_druid():
    pond = next(f for f in _flags() if f["id"] == "pond_depths")["arc_quest"]
    types = [p["type"] for p in pond["state_predicates"]]
    assert "coherence_fell" in types
    assert "Druid" in pond["hint"] and "compass" not in pond["hint"]
    walks = json.loads(src("Core/Campaign/campaign.json"))["guide"]["walks"]
    assert walks["coherence_fell"] == ["still"]
    assert "static func _still(" in src("Core/Campaign/Guide.gd")


def test_market_refresh_is_f():
    board = src("UI/Overlays/QuestBoard.gd")
    f = board.split("func _on_action_f()")[1].split("\nfunc ")[0]
    e = board.split("func _on_action_e()")[1].split("\nfunc ")[0]
    assert "_refresh_pool()" in f and "_refresh_pool()" not in e
    assert '"F": "Refresh"' in board and '"E": "Refresh"' not in board
    keymap = json.loads(src("Core/Campaign/campaign.json"))["guide"]["keymap"]
    assert keymap["verbs"]["refresh"] == "F"


def test_arc_quest_titles_are_unique():
    titles = []
    for f in _flags():
        body = str((f.get("arc_quest") or {}).get("body", ""))
        if " — " in body:
            titles.append(body.split(" — ")[0])
    dupes = {t for t in titles if titles.count(t) > 1}
    assert not dupes, dupes


def test_restored_arc_quests_rekey_their_ask():
    qm = src("Core/Quests/QuestManager.gd")
    body = qm.split("func restore_from_save_dict(")[1].split("\nfunc ")[0]
    assert '"ARC"' in body and '== "ready"' in body
    assert 'for field in ["state_predicates", "hint", "body", "math_note"]' in body


def test_banner_fades_on_a_no_progress_timer():
    fade = src("Core/Campaign/GuideFade.gd")
    assert "static func speaks(" in fade and "SW_GUIDE_MODE" in fade
    assert "RuntimeEnv.is_headless()" in fade  # seats default to always-on
    assert "current_tutorial_step()" in fade   # the tutorial always speaks
    table = json.loads(src("Core/Campaign/campaign.json"))["guide"]["fade_after_s"]
    assert table == sorted(table) and table[-1] >= 180
    assert "_GUIDE_FADE.speaks(" in src("UI/Widgets/ActFilament.gd")


def test_druid_tips_toward_the_resource_before_the_first_strike():
    g = src("Core/Campaign/Guide.gd")
    gather = g.split("static func _gather(")[1].split("\nstatic func ")[0]
    assert gather.index("_tip_toward(res, q)") < gather.index('_hat("ace", q)')
    tip = g.split("static func _tip_toward(")[1].split("\nstatic func ")[0]
    assert "NO_TUTORIAL_SENTINEL" in tip and "strikes.size() > 0" in tip
    assert re.search(r"0\.6 if in_druid else 0\.4", tip)


def test_biome_change_reaches_quests_after_a_load():
    """A .bind(farm) callable died with the farm on load: after any load,
    travel never reached QuestManager (Past the Hedge froze at 50%)."""
    shell = src("UI/PlayerShell.gd")
    assert 'Callable(self, "_handle_active_biome_change").bind(' not in shell
    assert "func _handle_active_biome_change(biome_name: String, _old_biome: String) -> void:" in shell


def test_satisfied_but_unready_quest_waits_instead_of_naming_claim():
    beat = src("Core/Campaign/Guide.gd").split("static func _beat_step(")[1].split("\nstatic func ")[0]
    assert "is settling" in beat


def test_lane_files_unlink_with_retry_on_windows():
    rc = src("🍄/🎛️/rig_client.py")
    clear = rc.split("def clear_rig_files(")[1].split("\n    def ")[0]
    assert "_unlink_retry(self.queue_file)" in clear and "except PermissionError" in rc


def test_learn_word_explores_before_the_icon_hat():
    lw = src("Core/Campaign/Guide.gd").split("static func _learn_word(")[1].split("\nstatic func ")[0]
    assert lw.index("_berry_needs_reveal(cols)") < lw.index('_hat("icon", q)')


def test_focus_biome_follows_the_active_biome_after_a_load():
    qii = src("UI/Core/QuantumInstrumentInput.gd")
    keys = qii.split("func _unhandled_key_input(")[1].split("\nfunc ")[0]
    assert "_sync_focus_biome()" in keys
    mass = qii.split("func _mass_explore(")[1].split("\nfunc ")[0]
    assert "not farm.is_plot_revealed(pos)" in mass


def test_explore_heals_a_held_but_fogged_plot():
    ex = src("Core/Instrumentation/QuantumInstrument.gd").split("func action_explore(")[1].split("\nfunc ")[0]
    assert '"already_bound"' in ex and '"healed": true' in ex and "farm.reveal_plot(grid_pos)" in ex
