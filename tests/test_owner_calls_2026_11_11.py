"""Pins for the owner's calls of 2026-11-11 (the night-2 "For Luke" list).

Each test names the call it pins. Source-level, like the 11-09 pins: the live
proof for each is in the hive ledger (strict follower runs from sk32_end).
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _campaign() -> dict:
    return json.loads(_read("Core/Campaign/campaign.json"))


def _beat(cid: str) -> dict:
    def walk(o):
        if isinstance(o, dict):
            if o.get("id") == cid:
                return o
            for v in o.values():
                r = walk(v)
                if r:
                    return r
        elif isinstance(o, list):
            for v in o:
                r = walk(v)
                if r:
                    return r
        return None
    return walk(_campaign()) or {}


def test_fill_the_urn_names_its_lever():
    # Druid Superpose lifts the urn off its 💀 pole past the tipping point;
    # the basin fills itself (urn11: ⚱ 0% → 100%, held hands-off).
    hint = _beat("the_basin")["offer"]["hint"]
    assert "Druid [0]" in hint and "Superpose [E]" in hint
    guide = _read("Core/Campaign/Guide.gd")
    assert "static func _lift_off_pole(" in guide
    steer = guide.split("static func _steer(", 1)[1].split("\nstatic func ", 1)[0]
    assert "_lift_off_pole(biome, col, emoji, q)" in steer
    lift = guide.split("static func _lift_off_pole(", 1)[1].split("\nstatic func ", 1)[0]
    # Banked strikes must not skip the lift (that sent Shrine ⇄ Village).
    assert "_plot_measured" not in lift
    assert '["Superpose", "E"]' in lift


def test_charge_row_shows_where_each_end_condition_stands():
    gloss = _read("Core/Quests/PredicateGloss.gd")
    assert "static func live(pred: Dictionary, qm = null) -> String:" in gloss
    for t in ("biome_frozen_loops_gte", "biome_loops_linked", "bridge_braids_gte",
              "purity_at_most", "mutual_information_at_least", "winding_changed_uncut"):
        assert '"%s"' % t in gloss.split("static func live(", 1)[1].split("\nstatic func ", 1)[0]
    overlay = _read("UI/Overlays/ControlsOverlay.gd")
    assert "PredicateGloss.live(p, qm_live)" in overlay


def test_gate_order_progress_survives_a_save():
    proj = _read("Core/Quests/QuestStateProjectionService.gd")
    arm = proj.split('"gate_order":', 1)[1].split('\n\t\t"', 1)[0]
    assert 'lesson_receipts[rkey] = step' in arm


def test_gate_walks_lock_the_clock_first():
    guide = _read("Core/Campaign/Guide.gd")
    assert "static func _hold_clock(" in guide
    for fn in ("_gate_word(", "_entangle("):
        body = guide.split("static func " + fn, 1)[1].split("\nstatic func ", 1)[0]
        assert "_hold_clock(q)" in body
    assert "− (⏪)" in _find_by_body("Two Chores, One Thread")["offer"]["hint"]


def _find_by_body(prefix: str) -> dict:
    out = []

    def walk(o):
        if isinstance(o, dict):
            if str(o.get("offer", {}).get("body", "")).startswith(prefix):
                out.append(o)
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk(_campaign())
    return out[0]


def test_walkless_rituals_have_walks():
    walks = _campaign()["guide"]["walks"]
    assert walks["wilson_survived_flip"] == ["fence"]
    assert walks["bridge_braids_gte"] == ["braid"]
    assert walks["bridge_fused_gte"] == ["fuse"]
    assert walks["biome_frozen_loops_gte"] == ["travel", "hat:icon", "berry"]
    guide = _read("Core/Campaign/Guide.gd")
    assert 'if gate == "gauge_flip":' in guide
    validate = _read("tools/campaign/validate.py")
    assert '"fence", "braid", "fuse"' in validate


def test_cull_is_the_players_choice():
    farm = _read("Core/Farm.gd")
    assert "func cullable_biomes() -> Array[String]:" in farm
    cull = _read("Core/Campaign/Guide.gd").split("static func _cull(", 1)[1].split("\nstatic func ", 1)[0]
    assert "pick one to let go" in cull
    assert "farm.cullable_biomes()" in cull


def test_ace_f_is_gather_first_on_a_struck_plot():
    ace = _read("Core/UI/AceChipResolvers.gd")
    f = ace.split("static func resolve_f(", 1)[1].split("\nstatic func ", 1)[0]
    assert "_plot_measured(" in f
    assert '"shift_label": "Mass Explore · Ctrl+⇧ Reap Season"' in f


def test_lamp_oil_has_a_resources_entry():
    res = _campaign()["resources"]["🪔"]
    assert res["spent_by"] == "plant 🌉/🪔"
    assert set(res["plots"]) == {"Lanternfall", "ZenoLatch"}
    assert any(t["biome"] == "Village" for t in res["trades"])


def test_literalist_text_fixes():
    assert '"caption": "[%s] %s" % [hat_key, label_name]' in _read("UI/Widgets/ToolSelectionRow.gd")
    assert '" in hand" if in_hand else ""' in _read("UI/Overlays/QuestBoard.gd")
    assert "nothing on Charge right now" in _read("UI/Overlays/ControlsOverlay.gd")
    spec = _read("Core/Campaign/campaign.json")
    assert "Claim the weave and it leaves you a 🍼" in spec
    assert "Accept here, take one of their contracts from the Market" in spec


def test_loom_post_game_soft_locks():
    # The Fusion: one fusion spends the bridge, and the centred soft gate
    # scored "fuse ≥ 1" at 0.5 — it could never fire (dx3).
    qm = _read("Core/Quests/QuestManager.gd")
    count_types = qm.split("const COUNT_GATE_TYPES", 1)[1].split("\n]", 1)[0]
    for t in ("bridge_built_gte", "bridge_braids_gte", "bridge_fused_gte"):
        assert '"%s"' % t in count_types
    assert "QuestMath.count_gate(float(farm.bridge_register.fused_total)" in qm
    # A gate word begun before a save resumes after it (braid_order, lm).
    proj = _read("Core/Quests/QuestStateProjectionService.gd")
    assert "for wkey in _gate_words:" in proj
    # The pair gate never names Gate with fewer than two marks.
    pg = _read("Core/Campaign/Guide.gd").split("static func _pair_gate(", 1)[1].split("\nstatic func ", 1)[0]
    assert "if have.size() + parts.size() < 2:" in pg
    # The leftover-handshake line names Claim only for a ready beat (dx3).
    uip = _read("UI/Core/UIProgression.gd")
    assert 'if str(best.get("status", "")) == "ready":\n\t\t\treturn _claim_walk_line(best)' in uip
    # purity_at_most has a walk, which grays in open country.
    assert _campaign()["guide"]["walks"]["purity_at_most"] == ["gray"]
    gray = _read("Core/Campaign/Guide.gd").split("static func _gray(", 1)[1].split("\nstatic func ", 1)[0]
    assert "_biome_open(" in gray and '_last_action_ms("hadamard")' in gray


def test_a_still_country_gets_a_nudge_not_an_endless_wait():
    # Gilded Rot at the shipped speed: its plots go still, and a loop 0.003 rad
    # short of 2π never ripens on its own (pn3: 25 min at ×32). One Druid
    # Spin ripens it.
    guide = _read("Core/Campaign/Guide.gd")
    berry = guide.split("static func _berry(", 1)[1].split("\nstatic func ", 1)[0]
    assert "_nudge(q)" in berry
    nudge = guide.split("static func _nudge(", 1)[1].split("\nstatic func ", 1)[0]
    assert '["Spin +", "R"]' in nudge and "NUDGE_AFTER_MS" in nudge
    # The Icon-hat steps defer to a due nudge while the Druid is worn.
    assert guide.count("var nd := _nudge(q)") >= 2
