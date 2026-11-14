"""Issue #83: the Starter Forest teaches single explore, then orbit, then Mass Explore."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(p):
    return (ROOT / p).read_text()


def _step():
    steps = json.loads(src("Core/Quests/data/tutorial_arc.json"))["steps"]
    return next(s for s in steps if s["tutorial_teaches"] == "wayfinding")


def test_wayfinding_asks_in_order_and_keeps_its_slot():
    st = _step()
    assert st["tutorial_step"] == 2 and st["biome"] == "StarterForest"
    kinds = [(p["type"], p.get("gate")) for p in st["state_predicates"]]
    assert kinds == [("active_biome_is", None), ("biome_explored", None),
                     ("gate_sequence_contains", "orbit"),
                     ("gate_sequence_contains", "batch_explore")]
    assert "Shift" not in st["tutorial_hint"] and len(st["tutorial_hint"]) <= 70
    assert st["redarken_biome"] == "StarterForest"


def test_walk_runs_single_explore_then_orbit_then_survey():
    w = json.loads(src("Core/Campaign/campaign.json"))["guide"]["walks"]["lesson:wayfinding"]
    assert w.index("explore_each") < w.index("orbit") < w.index("survey")


def test_orbit_and_mass_explore_are_recorded():
    assert '"orbit"' in src("Core/Visualization/QuantumField3D.gd").split("func _note_orbit")[1][:300]
    qii = src("UI/Core/QuantumInstrumentInput.gd").split("func _mass_explore(")[1].split("\nfunc ")[0]
    assert '"batch_explore"' in qii


def test_redarken_and_timeout_live_in_the_quest_manager():
    qm = src("Core/Quests/QuestManager.gd")
    assert "ORBIT_GRACE_SEC" in qm and "unreveal_plot" in qm.split("func _tick_wayfinding_lesson")[1]
    assert "plot_unrevealed" in src("Core/Farm.gd")
