"""Story-flags predicate lint (Country Chapters, plan Phase 7.1).

Pure-data checks over Core/Quests/data/story_flags.json — no Godot needed:

  (a) the flag graph (story_flag_set edges) is a DAG with no orphan references;
  (b) teach-before-plant closure: every atom_in_biome(B, X) — flag predicate or
      arc state_predicate — has X either native to B (biomes.json emojis), boot-
      known (demos_normal starting signature), or taught by a reward_north/south
      somewhere in the flag's prereq closure. A word you must plant is a word
      the story must have taught you first (the act-2 access-wall deadlock);
  (c) every standing_gte carries an explicit "width" — standing accrues in fixed
      contract-sized steps (+0.02 access/delivery), so the default 0.05 soft-gate
      width silently prices a gate ~2 deliveries late (fccb76d9);
  (d) every flag another flag depends on (via story_flag_set) that gates on
      numeric (non-flag) predicates offers an arc quest — an invisible numeric
      climb with no quest is a wall the player cannot see.

RATCHET: the TODO_* allowlists below name the flags each un-rewoven chapter still
owes. The assertions are EQUALITY, not subset — when a later chapter fixes a flag,
its entry MUST be removed here, and any new violation fails immediately.
"""
import json
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
STORY_FLAGS = PROJECT_ROOT / "Core" / "Quests" / "data" / "story_flags.json"
BIOMES = PROJECT_ROOT / "Core" / "Biomes" / "data" / "biomes.json"
ICONS = PROJECT_ROOT / "Core" / "Factions" / "data" / "icons.json"
DEFAULT_SCENARIO = PROJECT_ROOT / "Scenarios" / "demos_normal.tres"

# -- TODO allowlists (the ratchet) --------------------------------------------
# Chapter 2 (Hearth Keepers / Spring) re-predicates spring_connects as the
# teaching: today its DELIVER asks you to plant 💧 BEFORE it teaches 💧 (the
# self-teach deadlock), and its trust gate carries no width.
TODO_TEACH_BEFORE_PLANT = {
    ("spring_connects", "Village", "💧"),        # chapter 2
    ("village_path_industrial", "Village", "🏭"),  # act-4 chapter: five_doors teachers
    ("village_path_watched", "Village", "🦅"),     # act-4 chapter: eagle_overhead
    ("village_path_cemetery", "Village", "💀"),    # act-4 chapter: serfs_ledger
}
TODO_STANDING_WIDTH = {
    "spring_connects",  # chapter 2 re-predication (trust 0.35→0.42, width 0.02)
}
TODO_ARC_QUEST = {
    "forest_evolving",      # acts 0-1 touch-up pass (plan Phase 4)
    "forest_listener",      # acts 0-1 touch-up pass
    "forest_communion",     # acts 0-1 touch-up pass
    "island_lives",         # act-4 hub chapter
    "village_identity",     # act-4 hub chapter ("A Character" arc, re-priced bars)
    "edge_of_the_enclave",  # acts 5-8 audit (plan Phase 5: signature bar)
    "empire_imposes",       # acts 5-8 audit (gap read)
}


def _load_flags():
    return json.loads(STORY_FLAGS.read_text())


def _all_preds(flag):
    """Flag predicates + arc-quest state predicates, one stream."""
    preds = list(flag.get("predicates", []) or [])
    arc = flag.get("arc_quest") or {}
    preds += list(arc.get("state_predicates", []) or [])
    return preds


def _prereq_ids(flag):
    return [str(p.get("id", "")) for p in (flag.get("predicates", []) or [])
            if p.get("type") == "story_flag_set"]


def test_flag_graph_is_dag_with_no_orphans():
    flags = _load_flags()
    by_id = {f["id"]: f for f in flags}
    assert len(by_id) == len(flags), "duplicate flag ids"

    # No orphan references.
    for f in flags:
        for pid in _prereq_ids(f):
            assert pid in by_id, f"{f['id']} references unknown flag {pid!r}"

    # Acyclic (iterative DFS, three-color).
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {fid: WHITE for fid in by_id}
    for root in by_id:
        if color[root] != WHITE:
            continue
        stack = [(root, iter(_prereq_ids(by_id[root])))]
        color[root] = GRAY
        while stack:
            fid, it = stack[-1]
            nxt = next(it, None)
            if nxt is None:
                color[fid] = BLACK
                stack.pop()
                continue
            assert color[nxt] != GRAY, f"cycle through {nxt} (via {fid})"
            if color[nxt] == WHITE:
                color[nxt] = GRAY
                stack.append((nxt, iter(_prereq_ids(by_id[nxt]))))


def _biome_natives():
    data = json.loads(BIOMES.read_text())
    items = data.get("biomes", data) if isinstance(data, dict) else data
    if isinstance(items, dict):
        return {k: set(v.get("emojis", [])) for k, v in items.items()}
    return {v.get("name"): set(v.get("emojis", [])) for v in items}


def _boot_known_icons():
    """The shipped default scenario's starting signature (demos_normal)."""
    text = DEFAULT_SCENARIO.read_text()
    m = re.search(r"known_icons\s*=\s*\[(.*?)\]", text, re.S)
    assert m, "demos_normal.tres: known_icons block not found"
    poles = set(re.findall(r'"(?:north|south)":\s*"([^"]+)"', m.group(1)))
    assert poles, "demos_normal.tres: known_icons parsed empty"
    return poles


def test_teach_before_plant_closure():
    flags = _load_flags()
    by_id = {f["id"]: f for f in flags}
    natives = _biome_natives()
    boot = _boot_known_icons()

    def closure(fid):
        seen, stack = set(), list(_prereq_ids(by_id[fid]))
        while stack:
            x = stack.pop()
            if x in seen or x not in by_id:
                continue
            seen.add(x)
            stack.extend(_prereq_ids(by_id[x]))
        return seen

    def taught_by(ids):
        words = set()
        for i in ids:
            arc = by_id[i].get("arc_quest") or {}
            for k in ("reward_north", "reward_south"):
                if arc.get(k):
                    words.add(str(arc[k]))
        return words

    violations = set()
    for f in flags:
        plants = [(str(p.get("biome", "")), str(p.get("atom", "")))
                  for p in _all_preds(f) if p.get("type") == "atom_in_biome"]
        if not plants:
            continue
        # A flag's OWN rewards never count: DELIVER pays after the state_pred,
        # and a claim pays after readiness — self-teaching is the deadlock.
        words = taught_by(closure(f["id"])) | boot
        for biome, atom in plants:
            if atom in natives.get(biome, set()) or atom in words:
                continue
            violations.add((f["id"], biome, atom))

    assert violations == TODO_TEACH_BEFORE_PLANT, (
        "teach-before-plant drift.\n"
        f"  new violations: {sorted(violations - TODO_TEACH_BEFORE_PLANT)}\n"
        f"  fixed (remove from allowlist): {sorted(TODO_TEACH_BEFORE_PLANT - violations)}"
    )


def test_every_standing_gate_declares_width():
    flags = _load_flags()
    violations = set()
    for f in flags:
        for p in _all_preds(f):
            if p.get("type") == "standing_gte" and "width" not in p:
                violations.add(f["id"])
    assert violations == TODO_STANDING_WIDTH, (
        "standing_gte width drift (widths are the pacing dial — fccb76d9).\n"
        f"  new violations: {sorted(violations - TODO_STANDING_WIDTH)}\n"
        f"  fixed (remove from allowlist): {sorted(TODO_STANDING_WIDTH - violations)}"
    )


def test_referenced_numeric_gates_offer_arc_quests():
    flags = _load_flags()
    referenced = set()
    for f in flags:
        referenced.update(_prereq_ids(f))

    violations = set()
    for f in flags:
        if f["id"] not in referenced:
            continue
        numeric = [p for p in (f.get("predicates", []) or [])
                   if p.get("type") != "story_flag_set"]
        if numeric and not f.get("arc_quest"):
            violations.add(f["id"])

    assert violations == TODO_ARC_QUEST, (
        "gate-flag arc-quest drift (a numeric climb needs a visible quest).\n"
        f"  new violations: {sorted(violations - TODO_ARC_QUEST)}\n"
        f"  fixed (remove from allowlist): {sorted(TODO_ARC_QUEST - violations)}"
    )


def test_reward_pairs_are_real_icon_axes():
    """Every taught pair must exist as an axis in icons.json (plan Phase 8 risk:
    a reward naming a nonexistent axis teaches a word the engine cannot plant)."""
    flags = _load_flags()
    icons = json.loads(ICONS.read_text())
    axes = {frozenset((i["pole_0"], i["pole_1"])) for i in icons}
    for f in flags:
        arc = f.get("arc_quest") or {}
        north, south = arc.get("reward_north"), arc.get("reward_south")
        if not (north and south):
            continue
        assert frozenset((north, south)) in axes, (
            f"{f['id']}: reward pair {north}/{south} is not an icons.json axis"
        )
