#!/usr/bin/env python3
import os
from pathlib import Path
from typing import Optional


APP_NAME = os.environ.get("APPLICATION_NAME", "SpaceWheat - Quantum Farm")


def project_root() -> Path:
    env = os.environ.get("PROJECT_ROOT", "")
    if env:
        return Path(env).resolve()
    return Path(__file__).resolve().parents[2]


def runner_root(from_file: Optional[Path] = None) -> Path:
    base = Path(from_file).resolve().parent if from_file is not None else Path(__file__).resolve().parent
    if (base / "\U0001F7E2.sh").exists():
        return base
    parent = base.parent
    if (parent / "\U0001F7E2.sh").exists():
        return parent
    return Path(__file__).resolve().parent


def xdg_root(default: str = "/tmp/sw_godot_milk_hunt") -> Path:
    return Path(os.environ.get("XDG_ROOT", default))


def user_dir(xdg: Optional[Path] = None, app_name: str = APP_NAME) -> Path:
    root = xdg if xdg is not None else xdg_root()
    return root / "godot" / "app_userdata" / app_name


def rig_queue_file(xdg: Optional[Path] = None, app_name: str = APP_NAME) -> Path:
    return user_dir(xdg=xdg, app_name=app_name) / "rig" / "queue.jsonl"


def rig_results_file(xdg: Optional[Path] = None, app_name: str = APP_NAME) -> Path:
    return user_dir(xdg=xdg, app_name=app_name) / "rig" / "results.jsonl"


def resolve_user_dir_for_scan() -> Path:
    app_name = APP_NAME
    xdg = xdg_root()
    a = user_dir(xdg=xdg, app_name=app_name)
    b = project_root() / ".godot" / "godot" / "app_userdata" / app_name
    c = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local" / "share"))) / "godot" / "app_userdata" / app_name

    for candidate in (a, b, c):
        if (candidate / "rig" / "results.jsonl").exists():
            return candidate
    for candidate in (a, b):
        if candidate.exists():
            return candidate
    return c


def latest_complete_batch_dir(root: Path) -> Optional[Path]:
    if not root.exists() or not root.is_dir():
        return None
    batches = sorted([p for p in root.glob("batch_*") if p.is_dir()], key=lambda p: p.name)
    with_summary = [p for p in batches if (p / "batch_summary.json").exists()]
    if with_summary:
        return with_summary[-1]
    return batches[-1] if batches else None


def resolve_batch_summary(path: Path) -> Optional[Path]:
    if path.is_file() and path.name == "batch_summary.json":
        return path
    if path.is_dir() and (path / "batch_summary.json").exists():
        return path / "batch_summary.json"
    if path.is_dir():
        latest = latest_complete_batch_dir(path)
        if latest and (latest / "batch_summary.json").exists():
            return latest / "batch_summary.json"
    return None
