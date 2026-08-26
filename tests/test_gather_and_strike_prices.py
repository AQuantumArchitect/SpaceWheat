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


def test_the_welcome_card_points_at_the_banner_that_exists() -> None:
    # The banner moved twice on 2026-08-25; the card that tells a brand-new
    # player where to look is the one place a stale corner name is fatal.
    welcome = read_source("UI/Overlays/WelcomeOverlay.gd")
    assert "gold banner (bottom-right)" in welcome
    assert "top-right" not in welcome
