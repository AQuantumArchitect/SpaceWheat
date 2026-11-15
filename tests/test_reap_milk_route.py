"""Issue #93 part 1: a reap refused for lack of 🍼 routes to the Arc.

🍼 has no Village trade, so the #87 supply route ("supply:<emoji>") cannot
rescue it. The refusal toast instead carries the "arc" route (tap → 📖 [X] →
Arc [Y]), and the Guide's reap step turns into the same walk. Both read the
wallet through StapleRescue.milk_short, so the cue is state, not a flag.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SR = ROOT / "Core" / "GameMechanics" / "StapleRescue.gd"
QII = ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd"
GUIDE = ROOT / "Core" / "Campaign" / "Guide.gd"
SHELL = ROOT / "UI" / "PlayerShell.gd"


def _fn(p: Path, name: str) -> str:
    return p.read_text(encoding="utf-8").split("func %s(" % name)[1].split("\nfunc ")[0].split("\nstatic func ")[0]


def test_milk_short_reads_the_wallet_against_the_reap_cost():
    body = _fn(SR, "milk_short")
    assert "BalanceService.get_reap_cost" in body
    assert "_get_reap_count" in body
    assert "get_resource(MILK)" in body
    src = SR.read_text(encoding="utf-8")
    assert 'const MILK := "🍼"' in src
    assert 'const MILK_ROUTE := "arc"' in src
    # 🍼 is never lent: it is not a fee-waived staple.
    assert "🍼" not in src.split("const VERB_STAPLE := ")[1].split("\n")[0]


def test_reap_refusal_routes_to_the_arc_while_short():
    body = _fn(QII, "_supply_route_for")
    assert 'action_name == "reap"' in body
    assert "StapleRescue.milk_short(farm)" in body
    assert "StapleRescue.MILK_ROUTE" in body
    # The route goes through the one refusal toast, gold (persistent).
    run = _fn(QII, "_run_action")
    assert "_toast_refusal(action_label, result, _supply_route_for(action_name" in run
    assert "show_hint(\"[color=#ff9966]✗ %s[/color]\" % msg, 3" in _fn(QII, "_toast_refusal")
    # PlayerShell resolves "arc" to the Arc door.
    assert 'route == "arc"' in _fn(SHELL, "_route_to_callable")


def test_guide_reap_step_walks_to_the_arc_while_short():
    body = _fn(GUIDE, "_reap")
    i_short = body.index("StapleRescue.milk_short(farm)")
    i_reap = body.index('"Reap the season", "ctrl+shift+F"')
    assert i_short < i_reap, "the 🍼 check must come before the reap chord"
    assert '_short_of(StapleRescue.MILK, _chord(_go("X/arc")' in body
