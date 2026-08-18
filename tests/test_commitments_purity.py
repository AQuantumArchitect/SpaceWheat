"""Contract-purity + quest-text honesty lints (2026-08-17 capstone pass).

The law (owner, 2026-08-17 playtest): the C board is CONTRACTS — delivery of
goods or manipulation of quantum state, never "press this key". Verb lessons
live in the tutorial line (banner + X Arc tab). The leak was never the market
(from_market_contract forces DELIVERY); it was the Commitments tab listing
ALL of active_quests, auto-accepted verb steps included.

Runtime behavior is pinned in tests/gate_ledger_smoke.gd against the real
QuestManager; these lints pin the SOURCE and DATA contracts so a refactor
can't silently reopen the leak.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STORY_FLAGS = ROOT / "Core" / "Quests" / "data" / "story_flags.json"
TUTORIAL_ARC = ROOT / "Core" / "Quests" / "data" / "tutorial_arc.json"
QUEST_MANAGER = ROOT / "Core" / "Quests" / "QuestManager.gd"
QUEST_BOARD = ROOT / "UI" / "Overlays" / "QuestBoard.gd"
CONTRACT_CHIP = ROOT / "UI" / "Widgets" / "ContractChip.gd"


def test_no_hint_claims_accept_time_snapshot_counting():
    """complete_quest checks LIVE stores (QuestManager) — any hint claiming
    the board 'counts only what you gather AFTER you accept' is a lie that
    sends players to re-harvest goods they already hold. Three flags carried
    it; zero may."""
    for path in (STORY_FLAGS, TUTORIAL_ARC):
        text = path.read_text(encoding="utf-8")
        assert "counts only what you gather AFTER" not in text, (
            f"{path.name} claims accept-time snapshot counting — false; "
            "live stores count (QuestManager.complete_quest)"
        )


def test_board_and_chip_consume_the_filtered_commitments_list():
    """QuestBoard's Commitments tab and the HUD ContractChip must both read
    QuestManager.commitment_quests() (the purity filter + shared ordering),
    not raw active_quests — one list, one order, shared row letters."""
    for path in (QUEST_BOARD, CONTRACT_CHIP):
        src = path.read_text(encoding="utf-8")
        assert "commitment_quests" in src, (
            f"{path.name} no longer consumes commitment_quests() — the "
            "CONTRACTS surfaces must share the filtered list"
        )
    chip_src = CONTRACT_CHIP.read_text(encoding="utf-8")
    assert ".reverse()" not in chip_src, (
        "ContractChip re-grew its reverse() — chip order must MATCH the "
        "board (the reverse made 'quest two' in the HUD a different row "
        "than row H on the board)"
    )


def test_commitment_filter_excludes_auto_advancing_tutorials_at_source():
    src = QUEST_MANAGER.read_text(encoding="utf-8")
    m = re.search(r"func commitment_quests\(\).*?return out", src, re.S)
    assert m, "QuestManager.commitment_quests() missing"
    assert "_tutorial_auto_advances" in m.group(0), (
        "commitment_quests() must exclude via the ONE auto-advance rule "
        "(_tutorial_auto_advances), not a drift-prone re-implementation"
    )


def test_first_harvest_dedupe_and_handover_repredication():
    """The reap double-teach is dead: first_harvest spawns no arc_quest (the
    capstone tutorial step IS the quest for that gate), and arc_handover rides
    Act 0's real completion (loom_opens ∧ first_harvest)."""
    flags = {f["id"]: f for f in json.loads(STORY_FLAGS.read_text(encoding="utf-8"))}
    assert flags["first_harvest"].get("arc_quest") is None, (
        "first_harvest.arc_quest must stay null — its old arc quest asked "
        "for the reap the player had just done"
    )
    prereqs = {p.get("id") for p in flags["arc_handover"]["predicates"]
               if p.get("type") == "story_flag_set"}
    assert {"loom_opens", "first_harvest"} <= prereqs, (
        f"arc_handover must gate on Act 0's real completion, got {prereqs}"
    )


def test_story_flags_file_order_is_act_order():
    """File order is the documented tiebreak for the Arc tab and the HUD
    'Next:' line — the act-3 berry chapter used to sit between act-1 rows,
    which is exactly the disorientation the re-sort killed. Keep it sorted."""
    flags = json.loads(STORY_FLAGS.read_text(encoding="utf-8"))
    acts = [int(f.get("act", 0)) for f in flags]
    assert acts == sorted(acts), (
        "story_flags.json rows out of act order — file order is the Arc "
        "tab's documented tiebreak; insert new flags in act position"
    )
