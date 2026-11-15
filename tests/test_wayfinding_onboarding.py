"""Issue #83/#84: the Starter Forest teaches single explore, then orbit, then Mass Strike and Mass Gather."""
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
                     ("gate_sequence_contains", "batch_strike"),
                     ("gate_sequence_contains", "batch_gather")]
    assert "Shift" not in st["tutorial_hint"] and len(st["tutorial_hint"]) <= 70
    assert st["redarken_biome"] == "StarterForest"
    assert "Shift+R" in st["body"] and "Shift+Q" in st["body"] and "Shift+F" not in st["body"]


def test_walk_runs_single_explore_then_orbit_then_mass_strike_then_gather():
    w = json.loads(src("Core/Campaign/campaign.json"))["guide"]["walks"]["lesson:wayfinding"]
    assert w.index("explore_each") < w.index("orbit") < w.index("mass_strike") < w.index("mass_gather")
    assert "survey" not in w


def test_orbit_and_mass_verbs_are_recorded():
    assert '"orbit"' in src("Core/Visualization/QuantumField3D.gd").split("func _note_orbit")[1][:300]
    qii = src("UI/Core/QuantumInstrumentInput.gd")
    batch = qii.split("func _run_shift_batch(")[1].split("\nfunc ")[0]
    assert "batch_strike" in batch and "batch_gather" in batch
    assert "batch_explore" not in qii


def test_mass_strike_darkens_and_music_is_not_wired_to_it():
    qm = src("Core/Quests/QuestManager.gd")
    tick = qm.split("func _tick_wayfinding_lesson")[1].split("\nfunc ")[0]
    assert "ORBIT_GRACE_SEC" in qm and "unreveal_plot" in tick and "batch_strike" in tick
    assert "plot_unrevealed" in src("Core/Farm.gd")
    assert "batch_strike" not in "".join(p.read_text() for p in (ROOT / "Core").rglob("*Music*.gd"))
