"""'Already done' is a silent no-op, not an error (issue #85, owner call 2026-11-14).

Explore on an explored plot, Strike on a struck plot, Gather with nothing
banked, and an already-planted state return success + noop, carry no
player-facing `message`, and never reach the refusal toast. Real refusals keep
their honest sentences.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def _fn(text, head):
    return text.split(head)[1].split("\nfunc ")[0].split("\nstatic func ")[0]


def test_probe_actions_already_states_are_noops():
    p = src("Core/Actions/ProbeActions.gd")
    assert 'return {"success": true, "noop": true, "already": already, "detail": detail}' in p
    for code in ("already_bound", "already_measured"):
        assert '_noop("%s"' % code in p
        assert '"error": "%s"' % code not in p


def test_noop_carries_no_player_message():
    p = src("Core/Actions/ProbeActions.gd")
    helper = _fn(p, "static func _noop(")
    assert '"message"' not in helper


def test_already_planted_is_a_noop():
    g = src("Core/Instrumentation/Handlers/GateActionHandler.gd")
    assert '"already_planted"' in g and 'result["noop"] = true' in g
    assert 'result["error"] = "already_planted"' not in g


def test_instrument_short_circuits_noops():
    q = src("Core/Instrumentation/QuantumInstrument.gd")
    assert 'bool(result.get("noop", false)) and str(result.get("already", "")) == "already_bound"' in q
    assert q.count('if bool(result.get("noop", false)):') >= 2
    assert '"already": "already_gathered"' in q
    # an unexplored plot still gets the honest refusal
    assert '"error": "no_terminal"' in _fn(q, "func action_pop(")


def test_mass_explore_with_nothing_fresh_is_silent():
    u = src("UI/Core/QuantumInstrumentInput.gd")
    mass = _fn(u, "func _mass_explore(")
    assert "_toast_player" not in mass.split("positions.is_empty():")[-1].split("_run_shift_batch")[0]


def test_noop_logs_detail_not_toast():
    u = src("UI/Core/QuantumInstrumentInput.gd")
    log = _fn(u, "func _log_action_result(")
    assert 'result.get("noop", false)' in log and "result.get(\"detail\"" in log
