#!/usr/bin/env python3
"""Shared argparse base parser for milk hunt tools.

Usage:
    import milk_hunt_args

    parser = milk_hunt_args.make_base_parser("My tool description")
    parser.add_argument("--my-specific-flag", ...)
    args = parser.parse_args()

Callers with historical divergences keep their exact CLI surface via the
keyword-only hooks (SLOP_PATROL_2026-07-29 knot #25 — local behavior wins):

    only      — iterable of spec names: register just that subset of the
                shared flags (e.g. milk_hunt_seed_save uses 4 of them).
    overrides — {spec_name: {argparse_kwarg: value}} merged over the shared
                spec, so a caller keeps its local type/default/help
                (e.g. milk_hunt_runner's --strategy is a Path, not str).

Spec names are the snake_case flag names below; the on/off halves of a
boolean pair are separate names ("reuse_listener" / "no_reuse_listener").
The pair's set_defaults(None) is applied only when BOTH halves are included,
so a caller taking just --reuse-listener keeps argparse's False default.
"""
import argparse

from constants import POLICY_AUTO, POLICY_ENGINE, POLICY_QUANTUM

# Shared argument specs: (name, flags, argparse kwargs).
_BASE_SPECS = (
    ("console_profile", ("--console-profile",), dict(
        choices=["quiet", "normal", "debug", "trace", "test"],
        default=None,
        help="Console verbosity profile",
    )),
    ("load_slot", ("--load-slot",), dict(
        type=int,
        default=None,
        help="Boot the rig from a save slot",
    )),
    ("profile_save", ("--profile-save",), dict(
        type=str,
        default=None,
        help="Canonical profile save path/alias (skips JSON profile/world-state seeding)",
    )),
    ("profile_save_index", ("--profile-save-index",), dict(
        type=str,
        default=None,
        help="Optional registry JSON path for profile-save id resolution",
    )),
    ("scenario_id", ("--scenario-id",), dict(
        type=str,
        default=None,
        help="Scenario id when not loading a slot",
    )),
    ("hunter_profile", ("--hunter-profile",), dict(
        type=str,
        default=None,
        help="Policy profile name passed to runner",
    )),
    ("hunter_policy", ("--hunter-policy",), dict(
        choices=[POLICY_AUTO, POLICY_ENGINE, POLICY_QUANTUM],
        default=None,
        help="Policy mode passed to runner",
    )),
    ("display_mode", ("--display-mode",), dict(
        choices=["headless", "headed"],
        default=None,
        help="Launch the rig headless or with a visible window",
    )),
    ("policy_execution_backend", ("--policy-execution-backend",), dict(
        choices=["auto", "direct", "player_input"],
        default=None,
        help="How policy actions execute inside the rig (headed mode always uses player_input)",
    )),
    ("strategy", ("--strategy",), dict(
        type=str,
        default=None,
        help="Strategy JSON path",
    )),
    ("strict_biome_economy", ("--strict-biome-economy",), dict(
        dest="strict_biome_economy",
        action="store_true",
        help="Disable all rig-side resource injection",
    )),
    ("no_strict_biome_economy", ("--no-strict-biome-economy",), dict(
        dest="strict_biome_economy",
        action="store_false",
        help="Force-enable rig-side resource injection",
    )),
    ("reuse_listener", ("--reuse-listener",), dict(
        dest="reuse_listener",
        action="store_true",
        help="Reuse a single rig listener across runs",
    )),
    ("no_reuse_listener", ("--no-reuse-listener",), dict(
        dest="reuse_listener",
        action="store_false",
        help="Do not reuse a listener across runs",
    )),
)

# Boolean pairs whose dest defaults to None — applied only when the caller
# includes BOTH halves of the pair.
_PAIRED_DEFAULTS = (
    (("strict_biome_economy", "no_strict_biome_economy"), "strict_biome_economy"),
    (("reuse_listener", "no_reuse_listener"), "reuse_listener"),
)


def make_base_parser(
    description: str = "Milk hunt tool",
    *,
    only=None,
    overrides=None,
) -> argparse.ArgumentParser:
    """Return an ArgumentParser pre-loaded with args shared across all milk hunt tools.

    Shared args:
      --console-profile   Verbosity profile for console output
      --load-slot         Boot from a save slot
      --profile-save      Canonical profile save path/alias
      --profile-save-index  Registry JSON path for profile-save id resolution
      --scenario-id       Scenario id (used when not loading a slot)
      --hunter-profile    Policy profile name passed to runner
      --hunter-policy     Policy mode (auto / engine_policy / quantum_register)
      --display-mode      Headless or headed rig launch
      --policy-execution-backend  How policy actions execute inside the rig
      --strategy          Strategy JSON path
      --strict-biome-economy / --no-strict-biome-economy
      --reuse-listener / --no-reuse-listener
                         Reuse a single rig listener across runs

    only/overrides: see module docstring — callers keep local divergences.
    """
    all_names = {name for name, _flags, _kw in _BASE_SPECS}
    selected = all_names if only is None else set(only)
    unknown = selected - all_names
    if unknown:
        raise ValueError(f"make_base_parser: unknown spec names in only=: {sorted(unknown)}")
    over = dict(overrides or {})
    unknown_over = set(over) - all_names
    if unknown_over:
        raise ValueError(f"make_base_parser: unknown spec names in overrides=: {sorted(unknown_over)}")

    parser = argparse.ArgumentParser(description=description)
    for name, flags, kwargs in _BASE_SPECS:
        if name not in selected:
            continue
        kw = dict(kwargs)
        kw.update(over.get(name, {}))
        parser.add_argument(*flags, **kw)

    pair_defaults = {
        dest: None
        for pair, dest in _PAIRED_DEFAULTS
        if all(half in selected for half in pair)
    }
    if pair_defaults:
        parser.set_defaults(**pair_defaults)

    return parser
