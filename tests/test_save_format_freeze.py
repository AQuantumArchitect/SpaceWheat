"""Save-format freeze ratchet (beta launch, 2026-07-09; floor added 2026-07-10).

External players' saves must survive every update from the soft launch on.
Two rules enforced here:

1. You may not change the GameState schema without bumping save_version AND
   teaching GameStateSerializer how to migrate.
2. The compatibility floor is v4 (the beta format). "v3" was stamped in
   April 2026 and never bumped through several incompatible migrations, so
   pre-v4 saves are refused at load (SaveStore.MIN_COMPATIBLE_SAVE_VERSION)
   rather than half-loaded into garbage. The floor may never rise past a
   version external players actually hold without an explicit owner decision.

If the schema test fails you, do all three:
  1. Bump the `save_version` default in Core/GameState/GameState.gd.
  2. Add a migration branch for the old version in
     GameStateSerializer.apply_state_to_farm (v4+ loads stay accepted).
  3. Update FROZEN_SCHEMAS below with the new version's field list.

Removing or renaming a field is a migration too — old saves still carry it.
"""

import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
GAME_STATE = PROJECT_ROOT / "Core" / "GameState" / "GameState.gd"
SAVE_STORE = PROJECT_ROOT / "Core" / "GameState" / "SaveStore.gd"
SERIALIZER = PROJECT_ROOT / "Core" / "GameState" / "GameStateSerializer.gd"

# The beta floor: the version external players' saves start at.
BETA_FLOOR = 4

# version → exact set of @export fields that shipped under that version.
# Only the CURRENT version needs to be exhaustively right; older entries are
# historical record.
FROZEN_SCHEMAS = {
    4: {
        "scenario_id", "save_timestamp", "game_time", "quantum_time_scale",
        "observation_stride", "save_version", "advanced_mode_enabled",
        "grid_width", "grid_height",
        "all_emoji_credits", "tributes_paid", "tributes_failed",
        "known_icons", "active_icon_slots", "known_emojis",
        "atom_map_snapshot", "atom_map_snapshot_source", "atom_map_snapshot_time",
        "policy_state", "policy_graph_path", "policy_graph_jsonl",
        "balance_profile_id", "balance_workbench_config",
        "farm_variable_graph_path", "farm_variable_graph_jsonl",
        "economy_variables", "reap_count",
        "faction_density", "bridges",
        "story_flags_fired", "story_log",
        "faction_standings", "player_alignment", "player_faction_name",
        "unlocked_biomes", "unexplored_biome_pool", "active_biome_name",
        "selected_plot_positions", "revealed_plots",
        "quest_pages", "quest_board_current_page",
        "plots",
        "biotic_activation", "chaos_activation", "imperium_activation",
        "active_contracts",
        "biome_states", "plot_biome_assignments",
    },
}


def _declared_version() -> int:
    src = GAME_STATE.read_text(encoding="utf-8")
    m = re.search(r"^const CURRENT_SAVE_VERSION\s*:?=\s*(\d+)", src, re.M)
    assert m, "GameState.gd must declare CURRENT_SAVE_VERSION"
    # The @export declaration must stay 0 (unstamped) — ResourceSaver elides
    # declaration-default values, and an elided save_version line would make
    # every fresh save fail its own compatibility floor.
    d = re.search(r"^@export var save_version:\s*int\s*=\s*(\d+)", src, re.M)
    assert d and int(d.group(1)) == 0, (
        "@export var save_version must declare 0 and be stamped in _init "
        "(see the elision note in GameState.gd)"
    )
    assert re.search(r"save_version\s*=\s*CURRENT_SAVE_VERSION", src), (
        "GameState._init must stamp save_version = CURRENT_SAVE_VERSION"
    )
    return int(m.group(1))


def _declared_floor() -> int:
    src = SAVE_STORE.read_text(encoding="utf-8")
    m = re.search(r"^const MIN_COMPATIBLE_SAVE_VERSION\s*=\s*(\d+)", src, re.M)
    assert m, "SaveStore.gd must declare MIN_COMPATIBLE_SAVE_VERSION"
    return int(m.group(1))


def _exported_fields() -> set:
    src = GAME_STATE.read_text(encoding="utf-8")
    return set(re.findall(r"^@export var (\w+)", src, re.M))


def test_current_version_has_a_frozen_schema() -> None:
    version = _declared_version()
    assert version in FROZEN_SCHEMAS, (
        f"save_version={version} has no entry in FROZEN_SCHEMAS. "
        "Add its field list here so the schema stays ratcheted."
    )


def test_schema_unchanged_without_version_bump() -> None:
    version = _declared_version()
    frozen = FROZEN_SCHEMAS[version]
    live = _exported_fields()
    added = sorted(live - frozen)
    removed = sorted(frozen - live)
    assert not added and not removed, (
        f"GameState schema changed under save_version={version} "
        f"(added={added}, removed={removed}). External beta saves would break "
        "silently. Bump save_version, add a migration branch in "
        "GameStateSerializer.apply_state_to_farm, and refreeze the schema "
        "in FROZEN_SCHEMAS (see module docstring)."
    )


def test_floor_is_the_beta_floor() -> None:
    # The floor exists to refuse PRE-beta eras. Raising it past the beta
    # floor would orphan real players' saves — that needs an owner decision
    # and a migration, not a constant edit.
    assert _declared_floor() == BETA_FLOOR, (
        f"MIN_COMPATIBLE_SAVE_VERSION moved off the beta floor ({BETA_FLOOR}). "
        "If this is intentional, players below the new floor lose their "
        "saves: get an explicit owner sign-off and update BETA_FLOOR here."
    )


def test_loads_refuse_below_floor() -> None:
    src = SAVE_STORE.read_text(encoding="utf-8")
    for fn in ("load_state(", "load_state_by_path("):
        body_start = src.find(f"static func {fn}")
        assert body_start >= 0, f"SaveStore.{fn} missing"
        # The compatibility check must appear in the function body before the
        # ResourceLoader call.
        body = src[body_start:body_start + 1600]
        assert "is_save_compatible" in body.split("ResourceLoader")[0], (
            f"SaveStore.{fn} must refuse pre-floor saves BEFORE ResourceLoader "
            "touches them (a pre-beta save half-loads into garbage)."
        )


def test_serializer_accepts_floor_through_current() -> None:
    version = _declared_version()
    floor = _declared_floor()
    src = SERIALIZER.read_text(encoding="utf-8")
    m = re.search(
        r"state\.save_version\s*<\s*SaveStore\.MIN_COMPATIBLE_SAVE_VERSION"
        r"\s+or\s+state\.save_version\s*>\s*GameState\.CURRENT_SAVE_VERSION",
        src,
    )
    assert m, (
        "GameStateSerializer.apply_state_to_farm must keep the explicit "
        "supported-version range guard (MIN_COMPATIBLE_SAVE_VERSION .. "
        "CURRENT_SAVE_VERSION) on state.save_version."
    )
    # Every superseded version from the floor up needs an explicit
    # migration/compat branch.
    for old in range(floor, version):
        assert re.search(rf"state\.save_version\s*==\s*{old}\b", src), (
            f"No explicit handling for legacy save_version=={old} in "
            "GameStateSerializer.apply_state_to_farm."
        )
