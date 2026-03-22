#!/usr/bin/env python3
import os
import time
from pathlib import Path
from typing import Optional


APP_NAME = os.environ.get("APPLICATION_NAME", "SpaceWheat - Quantum Farm")
_DEFAULT_XDG_BASE = "/tmp/sw_godot_milk_hunt"


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


def _lane_token() -> str:
    token = os.environ.get("SW_RIG_LANE", "").strip()
    if token:
        return token
    token = f"lane_{os.getpid()}_{int(time.time() * 1000)}"
    os.environ["SW_RIG_LANE"] = token
    return token


def xdg_root(default: Optional[str] = None) -> Path:
    explicit = os.environ.get("XDG_ROOT", "").strip()
    if explicit:
        return Path(explicit)
    base = Path(default or _DEFAULT_XDG_BASE)
    private_root = base / _lane_token()
    os.environ["XDG_ROOT"] = str(private_root)
    return private_root


def lane_env(
    *,
    xdg: Optional[Path] = None,
    env: Optional[dict[str, str]] = None,
) -> dict[str, str]:
    out = dict(os.environ if env is None else env)
    root = Path(xdg) if xdg is not None else xdg_root()
    out["XDG_ROOT"] = str(root)
    if "SW_RIG_LANE" not in out or not str(out["SW_RIG_LANE"]).strip():
        out["SW_RIG_LANE"] = Path(root).name
    return out


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
