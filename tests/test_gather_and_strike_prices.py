"""The loop's two prices, and the copy that has to tell the truth about them.

Owner ruling 2026-08-25: strike drops to a flat 1👥, and gather (the `pop`
verb — Ace's Q, "Extract") stops being free and starts costing the village's
🧺. Both prices are FLAT, and PhysicsCostScaling — the hidden multiplier that
made strike charge 3👥 against a chip badge reading 1 — is deleted outright.

That is not the market going flat (the 2026-07-11 ruling: "a flat market is
dumb and boring"). It is the standing law about WHERE the chaos belongs —
"chaos in the deal, not the door." The door's price is a number a player can
read off the chip and watch leave the wallet unchanged. The deal is still
wild: the pop reward is surprisal, −kT·log p, so a rare collapse still pays
many times what a certain one does. The multiplier was taxing that same
physics a second time, invisibly, on the way in.

The copy assertions are the anti-gating law in its plainest form: three
surfaces used to promise the player that Q was "free". A price the game charges
but the guide denies is exactly the silent-hindrance case that law forbids.
"""

import json
from pathlib import Path

from conftest import ROOT, read_source

JSONL = ROOT / "Core" / "Config" / "FarmVariableGraph" / "default.jsonl"


def _action_costs() -> dict:
    costs: dict = {}
    for line in JSONL.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        row = json.loads(line)
        path = str(row.get("path", ""))
        if path.startswith("action_costs."):
            costs[path] = row.get("value")
    return costs


def test_strike_is_a_flat_single_person() -> None:
    assert _action_costs().get("action_costs.measure.👥") == 1


def test_gather_costs_a_village_basket() -> None:
    assert _action_costs().get("action_costs.pop.🧺") == 1


def test_exploring_the_basket_well_does_not_spend_bread() -> None:
    probe = read_source("Core/Actions/ProbeActions.gd")
    explore = probe.split("static func action_explore")[1].split("\nstatic func ")[0]
    assert "well" in explore
    assert 'contains("🧺")' in explore or '== "🧺"' in explore


def test_validator_allows_strike_on_basket_well() -> None:
    src = read_source("UI/Core/ActionValidator.gd")
    assert "_plot_is_basket_well" in src
    measure = src.split("static func _can_execute_measure")[1].split("static func ")[0]
    assert "_plot_is_basket_well" in measure
    assert "basket_well_grid_pos" in src


def test_striking_the_basket_well_binds_if_unexplored() -> None:
    qi = read_source("Core/Instrumentation/QuantumInstrument.gd")
    measure = qi.split("func action_measure(")[1].split("\nfunc ")[0]
    assert "action_explore" in measure
    assert 'contains("🧺")' in measure


def test_striking_the_basket_well_does_not_spend_people() -> None:
    probe = read_source("Core/Actions/ProbeActions.gd")
    measure = probe.split("static func action_measure")[1].split("\nstatic func ")[0]
    assert 'erase("👥")' in measure
    chips = read_source("Core/UI/ChipResolverRegistry.gd")
    assert 'action_name == "measure"' in chips
    assert 'erase("👥")' in chips


def test_gathering_a_basket_does_not_spend_a_basket() -> None:
    # w63: wallet 0, Village F/R/Q blocked. Commerce yields 🧺 — that
    # gather is the well, not a gift. Other pops still cost 1🧺.
    probe = read_source("Core/Actions/ProbeActions.gd")
    prep = probe.split("static func _prepare_pop_result")[1].split("\nstatic func ")[0]
    assert 'resource == "🧺"' in prep
    assert 'erase("🧺")' in prep
    assert "north_emoji" in prep or 'ax.get("north"' in prep
    chips = read_source("Core/UI/ChipResolverRegistry.gd")
    assert 'erase("🧺")' in chips
    assert "_ctx_measured_glyph" in chips


def test_the_chip_badge_and_the_wallet_agree() -> None:
    # No multiplier survives anywhere between ActionCostRuntime and the spend.
    # This is the whole point of the ruling: the badge said −1 and the wallet
    # lost 3, which EscapeMenu had already papered over with a footnote
    # ("base — scales with pair affinity") instead of fixing.
    assert not (ROOT / "Core" / "GameMechanics" / "PhysicsCostScaling.gd").exists(), (
        "the cost multiplier is deleted, not merely unreferenced"
    )
    for rel in ("Core/Actions/ProbeActions.gd", "Core/UI/ChipResolverRegistry.gd",
                "UI/Overlays/EscapeMenu.gd"):
        src = read_source(rel)
        assert "PhysicsCostScaling" not in src, rel
        assert "scales with pair affinity" not in src, rel


def test_the_chaos_stayed_in_the_deal() -> None:
    # Flattening the DOOR is only legitimate because the DEAL is still wild:
    # the pop reward is surprisal, so a rare collapse still pays many times a
    # certain one. Flattening this too would be the "dumb and boring" market.
    probe = read_source("Core/Actions/ProbeActions.gd")
    assert "EnergyPricing.surprisal_energy(" in probe


def test_the_starting_wallet_can_afford_to_gather() -> None:
    # A cost the opening scenario cannot pay is a wall, not a price.
    for rel in ("Scenarios/demos_normal.tres", "Scenarios/new_game_easy.tres"):
        src = read_source(rel)
        wallet = src.split("all_emoji_credits = {", 1)[1].split("}", 1)[0]
        assert '"🧺"' in wallet, rel
        amount = int(wallet.split('"🧺":', 1)[1].split(",", 1)[0].strip().rstrip("}"))
        assert amount >= 8, "%s starts with only %d🧺 — a few gathers, minimum" % (rel, amount)


def test_no_surface_still_promises_that_gathering_is_free() -> None:
    offenders = []
    for rel in ("UI/Overlays/WelcomeOverlay.gd", "UI/Overlays/ControlsOverlay.gd",
                "Core/GameState/ToolConfig.gd", "Core/Quests/data/tutorial_arc.json"):
        text = read_source(rel)
        for line in text.splitlines():
            low = line.strip().lower()
            # Comments are not player-facing copy; this lint is about what the
            # game SAYS, not what the source muses about ("a free cursor").
            if low.startswith("#") or "free" not in low:
                continue
            if "extract" in low or "gather" in low or "[q]" in low or "q " in low:
                offenders.append("%s: %s" % (rel, line.strip()[:110]))
    assert offenders == [], (
        "gathering costs 🧺 now — a surface that still calls it free is the "
        "anti-gating law's false-help case:\n" + "\n".join(offenders)
    )


def test_the_welcome_card_is_identity_not_a_second_door() -> None:
    # Welcome is who you are. The 1D lane auto-accepts onto the banner after
    # dismiss; pointing at Arc here was a second helper. Optional offers wait
    # on Arc for a deliberate Accept [R].
    welcome = read_source("UI/Overlays/WelcomeOverlay.gd")
    intro = read_source("Core/Story/IntroVoice.gd")
    footer = intro.split("static func welcome_footer")[1].split("static func ")[0]
    assert "Tap anywhere" in footer
    assert "Arc" not in footer
    assert "gold banner" not in footer
    assert "IntroVoice.welcome_footer()" in welcome
    for blob in (welcome, footer):
        assert "top-right" not in blob
        assert "bottom-right" not in blob
