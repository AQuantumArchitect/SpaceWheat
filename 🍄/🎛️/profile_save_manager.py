#!/usr/bin/env python3
"""Build and manage milk-hunt profile saves as canonical GameState files.

This utility converts profile JSON presets into real save files by running the
existing in-game seeding path, then copying the produced slot save into a
stable profile-save path under user://saves/profiles/.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict

from milk_hunt_io import write_json
from profiles import (
    list_names,
    default_registry_path,
    default_registry_uri,
    resolve_user_path,
    to_user_uri,
)
from run_executor import ensure_lane, run_seed


def _default_profile_save_path(profile: str) -> Path:
    return resolve_user_path(f"user://saves/profiles/{profile}.tres")


def _run_seed(profile: str, slot: int, out_path: Path, reuse_listener: bool, lane) -> None:
    result = run_seed(
        lane=lane,
        timeout_s=180,
        profile=profile,
        slot=slot,
        save_path=to_user_uri(out_path),
        reuse_listener=reuse_listener,
    )
    if int(result.get("exit_code", 1)) != 0:
        raise RuntimeError(
            "seed failed for profile '%s' (slot %d)\n%s%s"
            % (profile, slot, result.get("stdout", "") or "", result.get("stderr", "") or "")
        )


def _write_index(entries: Dict[str, str], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    payload = {"version": 1, "profiles": entries}
    write_json(out_path, payload)


def _build_one(profile: str, slot: int, output: Path, reuse_listener: bool, lane) -> Path:
    output.parent.mkdir(parents=True, exist_ok=True)
    _run_seed(profile, slot, output, reuse_listener, lane)
    if not output.exists():
        raise RuntimeError(f"expected profile save not found: {output}")
    return output


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Manage profile save files")
    sub = parser.add_subparsers(dest="cmd", required=True)

    list_cmd = sub.add_parser("list", help="List known JSON profile names")
    list_cmd.add_argument("--json", action="store_true", help="Emit JSON")

    build = sub.add_parser("build", help="Build one profile save from profile preset")
    build.add_argument("--profile", required=True, help="Profile name")
    build.add_argument("--slot", type=int, default=0, help="Temporary seed slot to use")
    build.add_argument(
        "--out",
        default="",
        help="Output save path (default: user://saves/profiles/<profile>.tres)",
    )
    build.add_argument("--reuse-listener", action="store_true", help="Reuse an existing listener")

    build_all = sub.add_parser("build-all", help="Build save files for all profiles")
    build_all.add_argument("--slot", type=int, default=0, help="Temporary seed slot to use")
    build_all.add_argument(
        "--out-dir",
        default="user://saves/profiles",
        help="Directory for profile saves (default: user://saves/profiles)",
    )
    build_all.add_argument(
        "--index-path",
        default=default_registry_uri(),
        help="Registry JSON mapping profile -> absolute path",
    )
    build_all.add_argument("--reuse-listener", action="store_true", help="Reuse an existing listener")

    return parser


def main() -> int:
    args = _build_parser().parse_args()
    lane = ensure_lane()

    if args.cmd == "list":
        names = list_names()
        if args.json:
            print(json.dumps(names, ensure_ascii=False, indent=2))
        else:
            for name in names:
                print(name)
        return 0

    if args.cmd == "build":
        out_path = resolve_user_path(args.out) if args.out else _default_profile_save_path(args.profile)
        built = _build_one(args.profile, args.slot, out_path, args.reuse_listener, lane)
        print(json.dumps({"profile": args.profile, "path": to_user_uri(built)}, ensure_ascii=False))
        return 0

    if args.cmd == "build-all":
        names = list_names()
        out_dir = resolve_user_path(args.out_dir)
        index_path = resolve_user_path(args.index_path) if args.index_path else default_registry_path()
        entries: Dict[str, str] = {}
        for name in names:
            out_path = out_dir / f"{name}.tres"
            built = _build_one(name, args.slot, out_path, args.reuse_listener, lane)
            entries[name] = to_user_uri(built)
            print(f"built {name} -> {entries[name]}", flush=True)
        _write_index(entries, index_path)
        print(f"index -> {to_user_uri(index_path)}", flush=True)
        return 0

    return 2


if __name__ == "__main__":
    sys.exit(main())
