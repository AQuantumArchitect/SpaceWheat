"""A refused gather must not orphan the plot.

Playtest 2026-10-29: a bubble got stuck looking explored (F fast-forwards),
Strike said "Unexplored", Gather said there was nothing to gather — though
strikes were banked on it. Cause: every pop site detached the terminal from
its plot BEFORE ProbeActions.action_pop, which returns early on a refusal
(e.g. 0🧺 for the gather fee) without releasing the terminal. The pool kept
the register bound (Explore: "already explored") while plot.terminal was
null (Strike/Gather read that). Source-contract pins.
"""
import re
from pathlib import Path

QI = Path(__file__).resolve().parent.parent / "Core" / "Instrumentation" / "QuantumInstrument.gd"


def _src() -> str:
    return QI.read_text(encoding="utf-8")


def test_every_detach_before_pop_reattaches_on_failure():
    src = _src()
    sites = [m.start() for m in re.finditer(
        r"_detach_terminal_from_plot\(terminal\)\n\s*var \w+ = ProbeActions\.action_pop\(", src)]
    assert len(sites) >= 4, "expected single-plot, probe_cycle, mass-harvest and mass-pop sites (%d)" % len(sites)
    for s in sites:
        window = src[s:s + 900]
        assert "_reattach_terminal_to_plot(terminal)" in window, (
            "a refused pop must put the terminal back on its plot (orphan = dead plot)")


def test_reattach_keeps_measurement_memory():
    body = _src().split("func _reattach_terminal_to_plot(")[1].split("\nfunc ")[0]
    assert "clear_measurement_memory" not in body
    assert "plot.terminal = t" in body


SER = QI.parent.parent / "GameState" / "GameStateSerializer.gd"


def test_banked_strikes_survive_save_and_load():
    src = SER.read_text(encoding="utf-8")
    assert 'plot_data["strikes"] = plot.terminal.strikes.duplicate(true)' in src, "save must write the bank"
    restore = src.split("tp.bind_terminal(t, saved_register, saved_biome, emoji_pair)")[1][:600]
    assert 'plot_data.get("strikes"' in restore and "t.strikes = " in restore, (
        "load must restore the bank AFTER bind (bind_to_register clears strikes)")
