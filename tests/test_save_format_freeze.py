"""Save-format freeze ratchet (beta launch, 2026-07-09).

External players' saves must survive every update from the soft launch on.
The rule this test enforces: you may not change the GameState schema without
bumping save_version AND teaching GameStateSerializer how to migrate.

If this test fails you, do all three:
  1. Bump the `save_version` default in Core/GameState/GameState.gd.
  2. Add a migration branch for the old version in
     GameStateSerializer.apply_state_to_farm (loads must stay accepted).
  3. Update FROZEN_SCHEMAS below with the new version's field list.

Removing or renaming a field is a migration too — old saves still carry it.
"""

import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
GAME_STATE = PROJECT_ROOT / "Core" / "GameState" / "GameState.gd"
SERIALIZER = PROJECT_ROOT / "Core" / "GameState" / "GameStateSerializer.gd"

# version → exact set of @export fields that shipped under that version.
# Only the CURRENT version needs to be exhaustively right; older entries are
# historical record.
FROZEN_SCHEMAS = {
    3: {
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
    m = re.search(r"^@export var save_version:\s*int\s*=\s*(\d+)", src, re.M)
    assert m, "GameState.gd must declare `@export var save_version: int = N`"
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


def test_serializer_accepts_current_and_all_prior_versions() -> None:
    version = _declared_version()
    src = SERIALIZER.read_text(encoding="utf-8")
    m = re.search(
        r"state\.save_version\s*<\s*(\d+)\s+or\s+state\.save_version\s*>\s*(\d+)",
        src,
    )
    assert m, (
        "GameStateSerializer.apply_state_to_farm must keep the explicit "
        "supported-version range guard on state.save_version."
    )
    lo, hi = int(m.group(1)), int(m.group(2))
    assert lo == 1, "v1 saves must stay loadable (beta promise)"
    assert hi == version, (
        f"Serializer supports versions {lo}..{hi} but GameState writes "
        f"version {version}. Extend the guard and add a migration branch."
    )
    # Every superseded version needs an explicit migration/compat branch.
    for old in range(1, version):
        assert re.search(rf"state\.save_version\s*==\s*{old}\b", src), (
            f"No explicit handling for legacy save_version=={old} in "
            "GameStateSerializer.apply_state_to_farm."
        )
