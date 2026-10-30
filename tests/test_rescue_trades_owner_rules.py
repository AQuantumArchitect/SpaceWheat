"""Rescue trades — owner rulings 2026-10-29.

- No trade is paid with 🐇. 👥 and 🍞 are bought with 🌾, 🧺 with 👥 only;
  every other resource with 🍞 only (no 🌱, no 💧).
- Staple rescues stand on the Village board only while critical (≤ 2 held);
  🌱 🔥 🔨 🪓 🌊 🦅 only while a live quest asks for them.
- A refusal caused by a short staple toasts a route to the Village Market
  board with that trade selected — it never accepts the trade.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CAMPAIGN = ROOT / "Core" / "Campaign" / "campaign.json"
QB = ROOT / "UI" / "Overlays" / "QuestBoard.gd"
OM = ROOT / "UI" / "Managers" / "OverlayManager.gd"
QII = ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd"
UIP = ROOT / "UI" / "Core" / "UIProgression.gd"
STAPLES = ("👥", "🍞", "🧺")


def _resources() -> dict:
    r = json.loads(CAMPAIGN.read_text(encoding="utf-8"))["resources"]
    return {k: v for k, v in r.items() if not k.startswith("_")}


def _fn(p: Path, name: str) -> str:
    return p.read_text(encoding="utf-8").split("func %s(" % name)[1].split("\nfunc ")[0].split("\nstatic func ")[0]


def test_trade_currencies_follow_the_ruling():
    for emoji, info in _resources().items():
        allowed = {"👥"} if emoji == "🧺" else ({"🌾"} if emoji in STAPLES else {"🍞"})
        for t in info.get("trades", []):
            gives = set(t["give"])
            assert "🐇" not in gives, (emoji, t)
            assert gives <= allowed, "%s trade pays with %s; allowed %s" % (emoji, gives, allowed)


def test_baskets_bought_with_people_only():
    gives = {g for t in _resources()["🧺"]["trades"] for g in t["give"]}
    assert gives == {"👥"}


def test_every_rescue_is_on_the_village_board():
    for emoji, info in _resources().items():
        assert any(t["biome"] == "Village" for t in info["trades"]), emoji


def test_board_visibility_rules():
    body = _fn(QB, "_rescue_open")
    assert "return _vital_stock(emoji) <= STAPLE_CRITICAL" in body
    assert "UIProgression.quest_requests_resource(emoji)" in body
    src = QB.read_text(encoding="utf-8")
    assert 'const QUEST_GATED_RESCUES: Array = ["🌱", "🔥", "🔨", "🪓", "🌊", "🦅"]' in src
    assert "const STAPLE_CRITICAL: int = 2" in src


def test_quest_request_reads_the_live_quests():
    body = UIP.read_text(encoding="utf-8").split("static func quest_requests_resource(")[1].split("\nstatic func ")[0]
    assert "_live_quests()" in body
    assert '_is_discover_ask(q)' in body
    assert '_is_plant_ask(q)' in body
    assert '_quest_asks_gate(q, "hadamard")' in body
    assert "CampaignRuntime.plant_north_for(emoji)" in body


def test_staple_refusal_routes_to_the_market_without_accepting():
    run = _fn(QII, "_run_action")
    assert "_supply_route_for(action_name" in run
    route = _fn(QII, "_supply_route_for")
    assert '"supply:" + staple' in route
    door = _fn(OM, "open_board_on_supply")
    assert "show_supply_focused" in door
    assert "accept" not in door.lower().replace("accepts", "")
    focus = _fn(QB, "show_supply_focused")
    assert "_row_confirm_armed = false" in focus
    assert "_accept_selected" not in focus and "_on_action_r" not in focus
