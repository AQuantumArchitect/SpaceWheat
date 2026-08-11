"""The two owner rulings from #229's day-1 decision list, pinned in source.

Both were open design questions the codebase had answered by accident, in
different places, differently. These are source-shape assertions rather than
live-run ones: the point is that the RULE has exactly one home and no second
copy drifts back in, which is the failure mode both of these already had once.

Ruling (a) — HARD RULE: the identity biome cannot be culled.
Ruling (b) — a skipped Act-0 tutorial step retires at act >= 2.
"""
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent

FARM = ROOT / "Core/Farm.gd"
FRAME = ROOT / "Core/GameState/ObservationFrame.gd"
QUEST = ROOT / "Core/Quests/Quest.gd"
QM = ROOT / "Core/Quests/QuestManager.gd"
PIPELINE = ROOT / "Core/Quests/QuestPipeline.gd"
QII = ROOT / "UI/Core/QuantumInstrumentInput.gd"


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


# ── Ruling (a): you cannot cull your own home ───────────────────────────────

def test_identity_biome_has_one_accessor() -> None:
    farm = src(FARM)
    assert "func identity_biome_name() -> String:" in farm, (
        "Farm.identity_biome_name() is the single authority for 'where did this run begin'. "
        "Without it every guard re-derives home differently, which is how the old "
        "faction-proxy guard ended up a no-op in new_game_easy."
    )
    # Derived from the scenario, so no GameState field and no save_version bump.
    assert "SaveStore.load_scenario(" in farm, (
        "identity must be derived from the scenario the run started from"
    )


def test_cull_gate_refuses_the_identity_biome() -> None:
    farm = src(FARM)
    gate = farm.split("func can_remove_biome()")[1].split("\nfunc ")[0]
    assert "identity_biome_name()" in gate, (
        "can_remove_biome must consult the identity rule. It is the ONE gate both the "
        "keyboard and mouse paths reach (ActionValidator pre-press) and that remove_biome "
        "re-checks, so the rule belongs here and only here."
    )
    assert "cannot cull your own home" in gate, "the refusal must say why, in player words"


def test_seed_biomes_are_declared_once() -> None:
    frame = src(FRAME)
    assert "const SEED_BIOMES" in frame, "the seed pair needs one declaration"
    assert "func is_seed_biome(" in frame, (
        "Farm.can_remove_biome asks ObservationFrame rather than keeping its own copy"
    )
    # The pair was spelled out four times and was free to drift; three of those were
    # replaced by SEED_BIOMES and the fourth (lock_biome's veto) by is_seed_biome().
    literal_pairs = frame.count('"StarterForest", "Village"')
    assert literal_pairs <= 1, (
        f'"StarterForest", "Village" appears {literal_pairs}x — it must live only in '
        "SEED_BIOMES, or the lists drift apart again"
    )


def test_nothing_irreversible_happens_before_the_frame_agrees() -> None:
    """The ordering bug: liquidation used to run BEFORE lock_biome's veto, so a
    refused cull still banked the payout and released the biome's terminals."""
    body = src(FARM).split("func remove_biome()")[1].split("\nfunc ")[0]
    lock_at = body.find("lock_biome(")
    liquidate_at = body.find("_liquidate_biome_resources(")
    release_at = body.find("_release_terminals_in_biome(")
    assert lock_at != -1 and liquidate_at != -1 and release_at != -1, "remove_biome shape changed"
    assert lock_at < liquidate_at, (
        "lock_biome must be consulted BEFORE credits are liquidated — otherwise a refusal "
        "leaves a half-destroyed biome and a paid-out player"
    )
    assert lock_at < release_at, (
        "lock_biome must be consulted BEFORE terminals are released"
    )


def test_cull_refusal_quotes_the_real_reason() -> None:
    """A rule refusal that says 'nothing valid to act on here' reads as 'no guard
    exists' — which is how a tester files the hard rule as missing."""
    qii = src(QII)
    assert '"remove_biome":' in qii, "remove_biome needs its own block-reason arm"
    arm = qii.split('"remove_biome":')[1].split('"inject_icon"')[0]
    assert "can_remove_biome()" in arm, (
        "the toast must quote Farm's own gate message, not the generic fallback"
    )


# ── Ruling (b): Act-0 tutorial steps retire at act >= 2 ─────────────────────

def test_retire_is_a_general_quest_field_not_a_tutorial_branch() -> None:
    quest = src(QUEST)
    assert '"retire_predicates"' in quest, (
        "retirement belongs on the canonical quest schema so any source can declare it"
    )


def test_no_second_retire_spelling_survives() -> None:
    """`expires` was declared in three places and read in none. Leaving a dead
    retire flag beside a live one is the duplicate-authority trap."""
    for path in (QUEST, PIPELINE):
        assert '"expires"' not in src(path), (
            f"{path.name} still declares a dead `expires` flag alongside retire_predicates"
        )


def test_act_predicate_is_registered_and_uses_the_act_authority() -> None:
    qm = src(QM)
    assert '"act_at_least"' in qm, "act_at_least must be a registered predicate type"
    assert "FLAG_PREDICATE_TYPES" in qm
    types_block = qm.split("const FLAG_PREDICATE_TYPES := [")[1].split("]")[0]
    assert "act_at_least" in types_block, (
        "act_at_least must be in FLAG_PREDICATE_TYPES or it is never routed"
    )
    assert "StoryAtlas.current_act(" in qm, (
        "the act must come from StoryAtlas.current_act — the contiguous-prefix authority — "
        "not a fresh reading of story_flags_fired"
    )


def test_retirement_is_not_a_failure() -> None:
    qm = src(QM)
    assert "func retire_quest(" in qm, "retirement needs its own terminal"
    body = qm.split("func retire_quest(")[1].split("\nfunc ")[0]
    assert "_apply_standing_deltas" not in body, (
        "retiring an outgrown tutorial step must not dock standing — that is fail_quest's "
        "job and outgrowing a step is not a broken promise"
    )
    assert "active_quests.erase(" in body, (
        "it must actually LEAVE active_quests: any TUTORIAL entry there outranks every arc "
        "quest in UIProgression._objective_rank, so merely hiding it in the board would "
        "leave the objective banner hijacked"
    )


def test_sweep_runs_even_without_a_live_biome() -> None:
    """_physics_process returns early when current_biome is null — which is exactly
    the state a freshly-loaded save is in, and exactly when a stale step is back."""
    body = src(QM).split("func _physics_process(")[1].split("\nfunc ")[0]
    sweep_at = body.find("_sweep_retired_quests()")
    guard_at = body.find("if current_biome == null")
    assert sweep_at != -1, "_physics_process must sweep retirements"
    assert guard_at != -1, "the current_biome guard moved — recheck this ordering"
    assert sweep_at < guard_at, (
        "the retire sweep must run ABOVE the current_biome early-return, or retirement "
        "stalls on exactly the fresh-load frames it is needed for"
    )


@pytest.mark.parametrize("act", [2])
def test_tutorial_steps_are_stamped_once_in_their_own_loader(act: int) -> None:
    qm = src(QM)
    assert f"const TUTORIAL_RETIRE_ACT := {act}" in qm, "the act threshold needs one named home"
    loader = qm.split("func _load_tutorial_arc()")[1].split("\nfunc ")[0]
    assert "retire_predicates" in loader and "TUTORIAL_RETIRE_ACT" in loader, (
        "stamp the default in the tutorial's own loader beside chain_unlocks — not repeated "
        "in every step of tutorial_arc.json, and not as an is-tutorial branch in shared code"
    )
