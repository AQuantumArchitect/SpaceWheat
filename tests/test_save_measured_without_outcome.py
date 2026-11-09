"""A bound plot saved with measurement MEMORY must not load as a corrupt terminal.

Overnight wave 4 (2026-11-09), two sensors independently: a StarterForest plot with a
live register, a banked strike and an earlier collapse's ghost was saved as
`has_been_measured: true` with no `measured_outcome`. Load bound the terminal and
called mark_measured(""), so every Q/R on it answered "✗ Terminal in invalid state:
INVALID: measured but no outcome recorded" while the banner kept naming Gather [Q] —
a soft-lock, and the banked 💀 could never be gathered.
"""
from conftest import read_source

SER = "Core/GameState/GameStateSerializer.gd"


def test_load_never_marks_a_live_terminal_measured_without_an_outcome() -> None:
    src = read_source(SER)
    assert 'if outcome != "" and plot.terminal and plot.terminal.is_bound:' in src
    assert "plot.terminal.mark_measured(outcome, probability)" in src


def test_save_keeps_a_bound_plots_ghost_under_its_own_keys() -> None:
    src = read_source(SER)
    assert 'plot_data["memory_outcome"]' in src
    assert 'plot_data.get("memory_outcome", "")' in src


def test_terminal_still_rejects_measured_without_outcome() -> None:
    # The validator is the alarm that caught this; it must stay strict.
    src = read_source("Core/GameMechanics/Terminal.gd")
    assert src.count('return "INVALID: measured but no outcome recorded"') == 2
