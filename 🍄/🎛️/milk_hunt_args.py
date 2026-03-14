#!/usr/bin/env python3
"""Shared argparse base parser for milk hunt tools.

Usage:
    import milk_hunt_args

    parser = milk_hunt_args.make_base_parser("My tool description")
    parser.add_argument("--my-specific-flag", ...)
    args = parser.parse_args()
"""
import argparse


def make_base_parser(description: str = "Milk hunt tool") -> argparse.ArgumentParser:
    """Return an ArgumentParser pre-loaded with args shared across all milk hunt tools.

    Shared args:
      --console-profile   Verbosity profile for console output
      --load-slot         Boot from a save slot
      --load-alias        Boot from an emoji alias save path
      --profile-save      Canonical profile save path/alias
      --profile-save-index  Registry JSON path for profile-save id resolution
      --scenario-id       Scenario id (used when not loading a slot)
      --hunter-profile    Policy profile name passed to runner
      --hunter-policy     Policy mode (auto / engine_policy / quantum_register)
      --strategy          Strategy JSON path
      --strict-biome-economy / --no-strict-biome-economy
      --reuse-listener / --no-reuse-listener
                         Reuse a single rig listener across runs
    """
    parser = argparse.ArgumentParser(description=description)

    parser.add_argument(
        "--console-profile",
        choices=["quiet", "normal", "debug", "trace", "test"],
        default=None,
        help="Console verbosity profile",
    )
    parser.add_argument(
        "--load-slot",
        type=int,
        default=None,
        help="Boot the rig from a save slot",
    )
    parser.add_argument(
        "--load-alias",
        type=str,
        default=None,
        help="Load from an emoji alias save filename/path",
    )
    parser.add_argument(
        "--profile-save",
        type=str,
        default=None,
        help="Canonical profile save path/alias (skips JSON profile/world-state seeding)",
    )
    parser.add_argument(
        "--profile-save-index",
        type=str,
        default=None,
        help="Optional registry JSON path for profile-save id resolution",
    )
    parser.add_argument(
        "--scenario-id",
        type=str,
        default=None,
        help="Scenario id when not loading a slot",
    )
    parser.add_argument(
        "--hunter-profile",
        type=str,
        default=None,
        help="Policy profile name passed to runner",
    )
    parser.add_argument(
        "--hunter-policy",
        choices=["auto", "engine_policy", "quantum_register"],
        default=None,
        help="Policy mode passed to runner",
    )
    parser.add_argument(
        "--strategy",
        type=str,
        default=None,
        help="Strategy JSON path",
    )
    parser.add_argument(
        "--strict-biome-economy",
        dest="strict_biome_economy",
        action="store_true",
        help="Disable all rig-side resource injection",
    )
    parser.add_argument(
        "--no-strict-biome-economy",
        dest="strict_biome_economy",
        action="store_false",
        help="Force-enable rig-side resource injection",
    )
    parser.add_argument(
        "--reuse-listener",
        dest="reuse_listener",
        action="store_true",
        help="Reuse a single rig listener across runs",
    )
    parser.add_argument(
        "--no-reuse-listener",
        dest="reuse_listener",
        action="store_false",
        help="Do not reuse a listener across runs",
    )
    parser.set_defaults(strict_biome_economy=None, reuse_listener=None)

    return parser
