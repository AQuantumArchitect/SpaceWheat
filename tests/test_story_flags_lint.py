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
# The acts 5-8 audit landed (plan Phase 5): every late gate with an invisible
# numeric climb now carries a minimal mirroring arc (edge_of_the_enclave,
# empire_imposes, island_free, the_fusion, the_door_stays_open) — the last two
# plus island_free are terminal (nothing references them), so rule (d) never
# owed them, but they carry arcs anyway. Remaining debt: acts 0-1 forest beats.
TODO_TEACH_BEFORE_PLANT = set()  # every plant has a teacher upstream — keep it so
TODO_STANDING_WIDTH = set()  # all standing gates carry authored widths — keep it so
TODO_ARC_QUEST = set()  # emptied 2026-07-15 — every referenced numeric gate has a visible quest


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


def test_branch_groups_are_coherent_alternatives():
    """branch_group members must be real alternatives: same act, and a shared
    story_flag_set prereq (the choice point they branch FROM). StoryAtlas
    treats a group as any-one-of for act completion — a group whose members
    span acts or lack a common gate would make that semantics a lie."""
    flags = json.loads(STORY_FLAGS.read_text(encoding="utf-8"))
    groups = {}
    for f in flags:
        g = str(f.get("branch_group", ""))
        if g:
            groups.setdefault(g, []).append(f)
    assert "village_door" in groups, "the five village_path_* doors must share a branch_group"
    for name, members in groups.items():
        assert len(members) >= 2, f"branch_group {name!r} has a single member — not a branch"
        acts = {int(m["act"]) for m in members}
        assert len(acts) == 1, f"branch_group {name!r} spans acts {sorted(acts)}"
        prereq_sets = []
        for m in members:
            prereq_sets.append({str(p.get("flag", ""))
                                for p in m.get("predicates", [])
                                if p.get("type") == "story_flag_set"})
        common = set.intersection(*prereq_sets) if prereq_sets else set()
        assert common, f"branch_group {name!r} members share no story_flag_set prereq"


def test_lane_display_names_parse():
    """Every 'What Survives/Connects/Fades/Turns' display_name must parse as a
    lane — optional I-V numeral, then '— Title' (both authored shapes:
    'What Survives III — …' and 'What Fades — …'). Pins StoryAtlas.lane_of's
    derive-from-display_name contract so a rename fails loudly instead of
    silently dropping a flag off its lane."""
    flags = json.loads(STORY_FLAGS.read_text(encoding="utf-8"))
    lane_re = re.compile(r"^What (Survives|Connects|Fades|Turns)( (I{1,3}|IV|V))? — .+")
    laned = [f for f in flags if str(f["display_name"]).startswith("What ")]
    assert len(laned) >= 20, "expected the ~27 lane-prefixed flags; data reshaped?"
    bad = [f["id"] for f in laned if not lane_re.match(str(f["display_name"]))]
    assert not bad, f"lane display_names that no longer parse: {bad}"


def test_story_flag_any_ids_are_real_flags():
    """Every story_flag_any predicate (flag-level or arc state_predicate) must
    reference only real flag ids — an OR over phantom flags is permanently
    unsatisfiable and the quest it gates would never leave ACTIVE."""
    flags = json.loads(STORY_FLAGS.read_text(encoding="utf-8"))
    known = {str(f["id"]) for f in flags}
    bad = []
    for f in flags:
        pred_sets = [f.get("predicates", [])]
        if isinstance(f.get("arc_quest"), dict):
            pred_sets.append(f["arc_quest"].get("state_predicates", []))
        for preds in pred_sets:
            for p in preds:
                if p.get("type") == "story_flag_any":
                    assert p.get("ids"), f"{f['id']}: story_flag_any with no ids"
                    bad += [(f["id"], i) for i in p["ids"] if str(i) not in known]
    assert not bad, f"story_flag_any references unknown flags: {bad}"
