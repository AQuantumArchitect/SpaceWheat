"""Captain discovery costs 📜 (Carrion Throne paperwork), not 🦅 — issue #103.

- Chart (campaign chart_cost) and the random Add Biome (action_costs.
  discover_biome) charge the same 📜 price, and no 🦅.
- 📜 is not in the starting wallet; the Village board sells it from the
  first day (low-water rescue, not quest-gated), so it is buyable before the
  beat that teaches Captain — no soft lock.
- 🦅 is still the Carrion Throne's emblem.
- The design note for the Ledger Bailiffs sub-tangle exists.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "campaign"))

import spec as S  # noqa: E402
import validate as V  # noqa: E402

CAMPAIGN = ROOT / "Core" / "Campaign" / "campaign.json"
RUNTIME = ROOT / "Core" / "Quests" / "data" / "campaign_runtime.json"
JSONL = ROOT / "Core" / "Config" / "FarmVariableGraph" / "default.jsonl"
FACTIONS = ROOT / "Core" / "Factions" / "data" / "factions.json"
QB = ROOT / "UI" / "Overlays" / "QuestBoard.gd"
SCENARIO = ROOT / "Scenarios" / "demos_normal.tres"
DOC = ROOT / "docs" / "design" / "CAPTAIN_LEDGER_BAILIFFS.md"


def _spec() -> dict:
    return json.loads(CAMPAIGN.read_text(encoding="utf-8"))


def _chart_cost() -> dict:
    return {k: v for k, v in _spec()["chart_cost"].items() if not k.startswith("_")}


def _discover_cost() -> dict:
    out = {}
    for line in JSONL.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        row = json.loads(line)
        path = str(row.get("path", ""))
        if path.startswith("action_costs.discover_biome."):
            out[path.split(".", 2)[2]] = row["value"]
    return out


def test_chart_and_add_biome_cost_ledger_not_eagles():
    assert _chart_cost() == {"📜": 5}
    assert _discover_cost() == _chart_cost(), "Chart and the random Add Biome share one price"
    runtime = json.loads(RUNTIME.read_text(encoding="utf-8"))
    assert {k: v for k, v in runtime["chart_cost"].items() if not k.startswith("_")} == {"📜": 5}


def test_chart_hints_name_the_ledger_price():
    named = 0
    for _, _, _, b in S.iter_beats(_spec()):
        if not b.get("chart"):
            continue
        hint = str((b.get("offer") or {}).get("hint", ""))
        assert "🦅×21" not in hint, b["id"]
        if "Need " in hint:
            assert "Need 📜×5" in hint, (b["id"], hint)
            named += 1
    assert named >= 6, "the door beats that teach the price name 📜"


def test_ledger_is_sold_on_the_village_board_from_day_one():
    res = _spec()["resources"]
    assert "🦅" not in res, "nothing on the story path spends 🦅 any more"
    info = res["📜"]
    price = _chart_cost()["📜"]
    village = [t for t in info["trades"] if t["biome"] == "Village"]
    assert village, "📜 needs a Village rescue trade"
    t = village[0]
    assert t["faction"] == "Carrion Throne"
    assert set(t["give"]) == {"🍞"}, "non-staples are bought with 🍞 only (owner ruling 2026-10-29)"
    assert t["get"] >= price, "one trade pays one commission"
    assert info["low_water"] >= price, "the notice stands until a full commission is held"
    # Not quest-gated: the low-water rule keeps it up before Captain is taught.
    qb = QB.read_text(encoding="utf-8")
    gated = qb.split("const QUEST_GATED_RESCUES: Array = ")[1].split("\n")[0]
    assert "📜" not in gated and "🦅" not in gated
    # Reachable: the Village is a starting biome, the trade's ask grows there,
    # and 📜 is not simply handed over in the starting wallet.
    start = V.scenario_start(SCENARIO)
    assert "Village" in start["biomes"]
    assert start["wallet"].get("📜", 0) == 0
    fs, bs, _ = V.load_world()
    village_atoms = {x for p in V.boot_pairs(bs, fs, "Village") for x in p}
    assert "🍞" in village_atoms


def test_captain_is_taught_by_a_chart_beat_the_validator_accepts():
    spec = S.load()
    teach = [b for _, _, _, b in S.iter_beats(spec)
             if "captain" in b.get("on_open", {}).get("unlock", {}).get("hats", [])]
    assert teach and all(b.get("chart") for b in teach)
    report = V.validate(spec)
    assert report.errors == [], report.errors


def test_eagle_is_still_the_thrones_emblem():
    data = json.loads(FACTIONS.read_text(encoding="utf-8"))
    items = data if isinstance(data, list) else data.get("factions", [])
    throne = next(f for f in items if f.get("name") == "Carrion Throne")
    poles = {(i["pole_0"], i["pole_1"]) for i in throne["icons"]}
    assert ("🦅", "🩸") in poles
    assert ("🏰", "📜") in poles
    assert "🦅" in throne["cloud"]


def test_bailiffs_sub_tangle_design_note():
    doc = DOC.read_text(encoding="utf-8")
    for word in ("Ledger Bailiffs", "BureaucraticAbyss", "Ink Wardens", "BloodLedger",
                 "Archives", "Threshold", "Consequences"):
        assert word in doc, word
