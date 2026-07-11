"""Single-dispatch-authority ratchet.

Owner law (2026-07-11, playtest 2): action-bar chip clicks fired every verb
TWICE because two systems were connected to the same `action_pressed` signal —
"very old slop". The fix deleted the duplicate; THIS test makes the whole bug
class a suite failure instead of a playtest discovery.

The one game:
  keyboard / chip click  → PlayerShell._route_action_key → QII.invoke_action
  bubble tap             → FarmView / PlotGridDisplay    → QII.handle_bubble_tap
  everything             → QII._run_action (the ONE mechanics tail: ledger,
                           buffer invalidation, toasts, action_performed)

Any new caller of these seams outside the whitelists below is a second game
growing inside the first. Widening a whitelist requires the same scrutiny as
raising the save floor: prove the new path routes through _run_action.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
QII = "UI/Core/QuantumInstrumentInput.gd"

# Gameplay tree = what ships and runs in a player session. The rig (🍄) drives
# the game FROM OUTSIDE via the same seams; tests/tools/gallery never run in a
# player session.
GAMEPLAY_ROOTS = [ROOT / "UI", ROOT / "Core", ROOT / "scenes"]

# pattern -> (allowed relative paths, law)
AUTHORITY_RULES = {
    # Private executor: only the authority itself may call it. The double
    # dispatch bug was UIContextController reaching into this.
    r"_perform_action\(": (
        {QII},
        "QII._perform_action is private to the authority",
    ),
    # The single mechanics tail.
    r"_run_action\(": (
        {QII},
        "QII._run_action is the ONE mechanics tail",
    ),
    # Chip clicks: exactly one connection, owned by PlayerShell.
    r"action_pressed\.connect\(": (
        {"UI/PlayerShell.gd"},
        "PlayerShell._route_action_key is the single chip-click dispatch authority",
    ),
    # Public verb entry for non-keyboard sources.
    r"\.invoke_action\(": (
        {"UI/PlayerShell.gd"},
        "only PlayerShell routes action keys into QII",
    ),
    # The one tap seam; these two are display-surface adapters, not authorities.
    r"\.handle_bubble_tap\(": (
        {"UI/FarmView.gd", "UI/PlotGridDisplay.gd"},
        "taps enter mechanics only through QII.handle_bubble_tap",
    ),
    # Direct instrument verbs from the UI layer bypass validation, costs,
    # buffer invalidation, and the dispatch ledger. ReelRunner is the one
    # named exception: a scripted capture harness (--reel=<path>) that never
    # runs in a player session and has no wallet to lie to.
    r"_instrument\.action_\w+\(": (
        {QII, "Core/Gallery/ReelRunner.gd"},
        "UI must not call QuantumInstrument verbs directly",
    ),
}


def _gameplay_gd_files():
    for base in GAMEPLAY_ROOTS:
        for path in sorted(base.rglob("*.gd")):
            yield path


def test_single_dispatch_authority():
    violations = []
    for path in _gameplay_gd_files():
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding="utf-8", errors="ignore")
        for lineno, line in enumerate(text.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            for pattern, (allowed, law) in AUTHORITY_RULES.items():
                if not re.search(pattern, stripped):
                    continue
                # A file may define/call its own seam (func lines, self-calls
                # inside the whitelisted file).
                if rel in allowed:
                    continue
                if stripped.startswith("func "):
                    continue
                violations.append(f"{rel}:{lineno}: `{stripped}` — {law}")

    assert not violations, (
        "second dispatch path detected (the double-verb slop class):\n"
        + "\n".join(violations)
    )


def test_dispatch_ledger_exists():
    """The forensics ring probes rely on (degradation_probe exactly-once check)."""
    text = (ROOT / QII).read_text(encoding="utf-8")
    assert "var dispatch_ledger" in text, "QII dispatch_ledger removed — probes blind to double-fires"
    assert text.count("dispatch_ledger.append") == 1, (
        "dispatch_ledger must be appended exactly once, inside _run_action"
    )
