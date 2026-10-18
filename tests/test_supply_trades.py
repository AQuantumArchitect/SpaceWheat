"""Standing supply trades — the market is how south poles are earned, and an
empty wallet is never a dead end.

The campaign spec's `resources` table (Core/Campaign/campaign.json) lists every
resource a story step spends, its low-water mark, the plots that carry it and
the standing trades that ALWAYS sit on a loaded biome's board. A headless probe
of a fresh demos_normal boot found the old 🧺 path dead: no register mints 🧺,
gather costs 1🧺, and the refusal steered to a Village 🧺 plot that does not
exist — 21 gathers and the game was over.

These pins hold the replacement:
  * every resource has a Village trade, and a broke player can pay it;
  * the board injects the trades through the canonical QuestPipeline path and
    QuestManager settles them at their table price (no lattice pricing);
  * a real boot drains 🧺 to 0 and climbs out at the Village market.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "Core" / "Campaign" / "campaign.json"
RUNTIME = ROOT / "Core" / "Quests" / "data" / "campaign_runtime.json"
SCENARIO = ROOT / "Scenarios" / "demos_normal.tres"
PROBE = ROOT / "tests" / "supply_rescue_smoke.gd"

sys.path.insert(0, str(ROOT / "tools" / "campaign"))
import validate as V  # noqa: E402


def _resources() -> dict:
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    return {k: v for k, v in spec["resources"].items() if not k.startswith("_")}


def _start_wallet() -> dict:
    text = SCENARIO.read_text(encoding="utf-8")
    body = text.split("all_emoji_credits = {", 1)[1].split("}", 1)[0]
    return {m.group(1).replace("️", ""): int(m.group(2))
            for m in re.finditer(r'"([^"]+)":\s*(\d+)', body)}


def _village_gatherable() -> set:
    """Poles a player can gather in the Village neighborhood (Village + TheDemos)."""
    fs, bs, _ = V.load_world()
    out: set = set()
    for name in ("Village", "TheDemos"):
        for pair in V.boot_pairs(bs, fs, name):
            out |= set(pair)
    return out


def test_every_resource_has_a_village_trade_a_broke_player_can_pay():
    resources = _resources()
    wallet = _start_wallet()
    gatherable = _village_gatherable()
    village_paid = {e for e, info in resources.items()
                    if any(t.get("biome") == "Village" for t in info.get("trades", []))}
    assert resources, "campaign resources table is empty"
    for emoji, info in resources.items():
        rescue = [t for t in info.get("trades", []) if t.get("biome") == "Village"]
        assert rescue, f"{emoji}: no Village rescue trade"
        for t in rescue:
            assert t.get("faction"), f"{emoji}: Village trade names no faction"
            assert int(t.get("get", 0)) > 0, f"{emoji}: Village trade pays nothing"
            give = t.get("give", {})
            assert give, f"{emoji}: Village trade asks nothing"
            for g, qty in give.items():
                g = g.replace("️", "")
                # A broke player holds 0 of the thing they need — and 0🧺
                # means no gathering at all. The ask must be neither.
                assert g != emoji, f"{emoji}: the rescue asks for {emoji} itself"
                assert g != "🧺", f"{emoji}: the rescue asks for 🧺, which a broke player cannot gather"
                # Reachable: gatherable in the Village neighborhood or itself
                # paid by another Village trade…
                assert g in gatherable or g in village_paid, (
                    f"{emoji}: Village trade asks {g}, which nothing in the Village yields")
                # …and the opening wallet already covers it several times.
                assert wallet.get(g, 0) >= 2 * int(qty), (
                    f"{emoji}: the opening wallet holds {wallet.get(g, 0)}{g}, "
                    f"under two rounds of the {int(qty)}{g} rescue")


def test_basket_rescue_restocks_above_low_water():
    info = _resources()["🧺"]
    assert info["plots"] == [], "a 🧺 plot appeared — revisit the supply walk"
    rescue = next(t for t in info["trades"] if t["biome"] == "Village")
    # One trade from 0 must lift the wallet over the reserve, or the banner
    # would send the player straight back to the board.
    assert int(rescue["get"]) > int(info["low_water"])


def test_runtime_table_is_compiled_from_the_spec():
    runtime = json.loads(RUNTIME.read_text(encoding="utf-8"))
    assert runtime.get("resources") == _resources(), (
        "campaign_runtime.json is stale — run python3 tools/campaign/build.py")


def test_supply_trades_flow_through_the_canonical_quest_path():
    pipeline = (ROOT / "Core/Quests/QuestPipeline.gd").read_text(encoding="utf-8")
    offer = pipeline.split("static func supply_offer(")[1].split("\nstatic func ")[0]
    for needle in ('"supply_trade": true', '"reward_resources": {emoji: get_n}',
                   "supply_offer_id(emoji, biome_name)", "QuestVoice.apply(q)",
                   '"time_limit": -1.0'):
        assert needle in offer, needle
    board = (ROOT / "UI/Overlays/QuestBoard.gd").read_text(encoding="utf-8")
    refresh = board.split("func _refresh_pool()")[1].split("\nfunc ")[0]
    assert "_refresh_market_pool()" in refresh and "_inject_supply_offers()" in refresh
    supply = board.split("func _supply_offers()")[1].split("\nfunc ")[0]
    assert "CampaignRuntime.trades_for_biome" in supply
    assert "QuestPipeline.supply_offer" in supply
    assert "active_quests.has" in supply  # an accepted trade is not re-offered
    qm = (ROOT / "Core/Quests/QuestManager.gd").read_text(encoding="utf-8")
    complete = qm.split("func complete_quest(")[1].split("\nfunc ")[0]
    assert complete.index("_complete_supply_trade") < complete.index("synthesize_and_exercise")
    settle = qm.split("func _complete_supply_trade(")[1].split("\nfunc ")[0]
    assert "_standing_deltas_for_quest(quest, true)" in settle
    assert "_finalize_quest_completion" in settle
    assert "synthesize_and_exercise" not in settle


@pytest.fixture(scope="module")
def rescue() -> dict:
    if shutil.which("godot") is None:
        pytest.skip("godot not on PATH — cannot boot the real game")
    proc = subprocess.run(["godot", "--headless", "--path", ".", "--script", str(PROBE)],
                          cwd=ROOT, capture_output=True, text=True, timeout=420)
    line = next((l for l in proc.stdout.splitlines()
                 if l.strip().startswith("{") and '"supply-rescue"' in l), None)
    assert line, f"probe emitted no JSON.\nstdout:\n{proc.stdout[-3000:]}\nstderr:\n{proc.stderr[-3000:]}"
    return json.loads(line)


def test_broke_player_climbs_out_at_the_village_market(rescue):
    assert rescue["fails"] == [], rescue
    assert rescue["baskets_drained"] == 0
    assert rescue["baskets_end"] > 0
    assert rescue["baskets_end"] == int(rescue["trade"]["get"])


def test_the_walk_names_one_next_key_at_each_step(rescue):
    assert "Village" in rescue["refusal"] and "🧺 trade" in rescue["refusal"]
    assert "[C] opens the board" in rescue["walk_village"]
    assert rescue["walk_board"].startswith("▸ Market [Y]")
    assert "Accept" in rescue["walk_market"]
    assert rescue["cue_held"].startswith("▸ [R] Deliver")


def test_refused_plant_names_its_south_pole_trade():
    """Story planting costs 5🌱 + 13 of the pair's SOUTH pole; 🪓 and 🌊 have
    no plot anywhere, so a refused 🪵/🪓 or 💧/🌊 plant must point at the
    standing trade that pays the pole — on the toast and on the banner."""
    qii = (ROOT / "UI/Core/QuantumInstrumentInput.gd").read_text(encoding="utf-8")
    inject = qii.split("func _execute_inject_icon(")[1].split("\nfunc ")[0]
    assert "UIProgression.note_plant_south(south)" in inject
    assert 'UIProgression.note_plant_south("")' in inject
    assert "supply_refusal(south, EconomyConstants.ICON_INJECTION_SOUTH_COST, true)" in inject
    prog = (ROOT / "UI/Core/UIProgression.gd").read_text(encoding="utf-8")
    plant = prog.split("static func _plant_walk_line()")[1].split("\nstatic func ")[0]
    assert plant.index("_sprout_short()") < plant.index("_plant_south_short()")
    assert "_supply_walk_line(_plant_south_want)" in plant
    target = prog.split("static func objective_target()")[1].split("\nstatic func ")[0]
    assert "_supply_target(_plant_south_want)" in target


def test_rescue_probe_covers_every_village_trade_and_the_axe(rescue):
    assert rescue["village_trades"] == rescue["village_trades_on_ring"] >= 1
    assert "🪓 trade" in rescue["axe_refusal"]
