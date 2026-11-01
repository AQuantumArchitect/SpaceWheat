"""Playtest note 7: Icon plant must redraw the field and open that faction's board.

Player planted Subsistence (👥/🌾, The Demos) into StarterForest. Extract paid
out, but the graphics never updated and Y had no Subsistence/Demos stall.
Neighborhood offers only mint emojis shared with Wildwood; 👥/🌾 are not in
that spec. The 3D field only rebuilt on biome change / empty bubbles.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIELD = ROOT / "Core" / "Visualization" / "QuantumField3D.gd"
GRAPH = ROOT / "Core" / "Visualization" / "QuantumForceGraph.gd"
INST = ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd"
QII = ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd"
BOARD = ROOT / "UI" / "Overlays" / "QuestBoard.gd"
LATTICE = ROOT / "Core" / "Markets" / "MarketLattice.gd"
BIOMES = ROOT / "Core" / "Biomes" / "data" / "biomes.json"


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def body(path: Path, name: str) -> str:
    parts = src(path).split("func %s(" % name)
    assert len(parts) > 1, "%s() is gone from %s" % (name, path.name)
    return parts[1].split("\nfunc ")[0]


def test_field3d_rebuilds_when_qubit_count_grows() -> None:
    tick = body(FIELD, "_tick_field")
    assert "get_num_qubits()" in tick
    assert "_bubbles.size()" in tick
    assert "nq != _spawned_nq" in tick
    rebuild = tick.split("var biome = _get_active_biome()")[1]
    assert "_rebuild(biome)" in rebuild


def test_force_graph_seeds_when_registers_outrun_bubbles() -> None:
    proc = body(GRAPH, "_process")
    assert "_register_bubbles_behind()" in proc
    assert "_ensure_register_bubbles()" in proc
    behind = body(GRAPH, "_register_bubbles_behind")
    assert "get_num_qubits()" in behind
    assert "quantum_nodes.size()" in behind


def test_inject_reveals_the_new_register_slot() -> None:
    inject = body(INST, "action_inject_icon_pair")
    assert "_reveal_injected_register(biome_name, _qid)" in inject
    reveal = body(INST, "_reveal_injected_register")
    assert "reveal_plot" in reveal
    assert "get_plot_biome_assignments" in reveal
    assert "pos.x" in reveal


def test_planted_word_opens_that_faction_board() -> None:
    lattice = src(LATTICE)
    assert "func propose_planted_word_offers" in lattice
    planted = body(LATTICE, "propose_planted_word_offers")
    assert "best_neighborhood_name" in planted
    assert "get_factions_for_pair" in planted
    assert "propose_faction_offers" in planted
    board = src(BOARD)
    assert "func _ensure_seated_word_offers" in board
    assert "func on_word_seated" in board
    refresh = body(BOARD, "_refresh_pool")
    assert "_decorate_pool(lattice)" in refresh
    decorate = body(BOARD, "_decorate_pool")
    assert "_ensure_seated_word_offers" in decorate
    qii = body(QII, "_execute_inject_icon")
    assert "_open_seated_word_board(icon)" in qii
    open_fn = body(QII, "_open_seated_word_board")
    assert "on_word_seated" in open_fn


def test_starter_forest_does_not_natively_seat_subsistence() -> None:
    """The Demos word is planted, not born in Wildwood/Forest axes."""
    import json
    biomes = json.loads(BIOMES.read_text(encoding="utf-8"))
    forest = next(b for b in biomes if b.get("name") == "StarterForest")
    emojis = set(forest.get("emojis", []))
    assert "👥" not in emojis
    assert "🌾" not in emojis
    natives = set(forest.get("native_factions", []))
    assert "The Demos" not in natives
    wildwood = next(b for b in biomes if b.get("name") == "Wildwood")
    wild_emojis = set(wildwood.get("emojis", []))
    assert "👥" not in wild_emojis
    assert "🌾" not in wild_emojis
