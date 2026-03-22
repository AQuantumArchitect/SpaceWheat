#!/usr/bin/env python3
"""Shared subprocess execution core for 🍄 rig tooling.

Keeps seed/run/batch wrappers on one lane-aware execution surface.
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

from milk_hunt_paths import lane_env, xdg_root


HERE = Path(__file__).resolve().parent
SEED_SCRIPT = HERE / "milk_hunt_seed_save.py"
RUNNER_SCRIPT = HERE / "milk_hunt_runner.py"
BATCH_SCRIPT = HERE / "milk_hunt_batch.py"


@dataclass(frozen=True)
class RigLane:
    xdg_root: Path

    @property
    def env(self) -> Dict[str, str]:
        return lane_env(xdg=self.xdg_root)


def ensure_lane(xdg: Optional[Path] = None) -> RigLane:
    return RigLane(Path(xdg) if xdg is not None else xdg_root())


def run_cli(
    cmd: List[str],
    *,
    lane: Optional[RigLane] = None,
    timeout_s: int = 120,
    cwd: Optional[Path] = None,
    extra_env: Optional[Dict[str, str]] = None,
    capture_output: bool = True,
) -> subprocess.CompletedProcess[str]:
    active_lane = lane or ensure_lane()
    env = active_lane.env
    if extra_env:
        for key, value in extra_env.items():
            env[str(key)] = str(value)
    return subprocess.run(
        cmd,
        capture_output=capture_output,
        text=True,
        timeout=max(1, int(timeout_s)),
        cwd=str(cwd or HERE.parent.parent),
        env=env,
        check=False,
    )


def latest_batch_summary(root: Path) -> Dict[str, Any]:
    summaries = sorted(root.rglob("batch_summary.json"))
    for path in reversed(summaries):
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
    return {}


def parse_last_json(stdout: str, stderr: str = "") -> Dict[str, Any]:
    all_output = f"{stdout or ''}\n{stderr or ''}"
    for line in reversed(all_output.strip().splitlines()):
        raw = line.strip()
        if not raw.startswith("{"):
            continue
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict):
            return payload
    return {}


def build_seed_cmd(
    *,
    slot: int,
    profile: Optional[str] = None,
    world_state: Optional[str] = None,
    character: Optional[str] = None,
    policy_mode: str = "engine_policy",
    display_mode: str = "headless",
    ready_timeout: int = 180,
    reuse_listener: bool = True,
    save_path: Optional[str] = None,
    extra_args: Optional[Iterable[str]] = None,
) -> List[str]:
    cmd: List[str] = [sys.executable, str(SEED_SCRIPT), "--slot", str(slot)]
    if character:
        cmd += ["--character", character, "--policy-mode", policy_mode]
    elif world_state:
        cmd += ["--world-state", world_state]
    elif profile:
        cmd += ["--profile", profile]
    cmd += ["--display-mode", display_mode, "--ready-timeout", str(int(ready_timeout))]
    if reuse_listener:
        cmd.append("--reuse-listener")
    if save_path:
        cmd += ["--save-path", save_path]
    if extra_args:
        cmd += list(extra_args)
    return cmd


def build_runner_cmd(
    *,
    max_loops: int,
    load_slot: Optional[int] = None,
    profile_save: Optional[str] = None,
    hunter_profile: str = "",
    hunter_policy: str = "engine_policy",
    console_profile: str = "quiet",
    extra_args: Optional[Iterable[str]] = None,
) -> List[str]:
    cmd: List[str] = [
        sys.executable,
        str(RUNNER_SCRIPT),
        "--max-loops",
        str(int(max_loops)),
        "--hunter-policy",
        hunter_policy,
        "--console-profile",
        console_profile,
    ]
    if hunter_profile:
        cmd += ["--hunter-profile", hunter_profile]
    if profile_save:
        cmd += ["--profile-save", profile_save]
    elif load_slot is not None:
        cmd += ["--load-slot", str(load_slot)]
    if extra_args:
        cmd += list(extra_args)
    return cmd


def build_batch_cmd(
    *,
    runs: int,
    max_loops: int,
    hunter_profile: str,
    hunter_policy: str,
    runtime_profile: str,
    console_profile: str,
    display_mode: str,
    policy_execution_backend: str,
    output_dir: Path,
    strict_biome_economy: bool,
    reuse_listener: bool,
    profile_save: Optional[str] = None,
    extra_args: Optional[Iterable[str]] = None,
) -> List[str]:
    cmd: List[str] = [
        sys.executable,
        str(BATCH_SCRIPT),
        "--runs",
        str(int(runs)),
        "--max-loops",
        str(int(max_loops)),
        "--hunter-profile",
        hunter_profile,
        "--hunter-policy",
        hunter_policy,
        "--runtime-profile",
        runtime_profile,
        "--console-profile",
        console_profile,
        "--display-mode",
        display_mode,
        "--policy-execution-backend",
        policy_execution_backend,
        "--output-dir",
        str(output_dir),
    ]
    cmd.append("--strict-biome-economy" if strict_biome_economy else "--no-strict-biome-economy")
    cmd.append("--reuse-listener" if reuse_listener else "--no-reuse-listener")
    if profile_save:
        cmd += ["--profile-save", profile_save]
    if extra_args:
        cmd += list(extra_args)
    return cmd


def run_seed(
    *,
    lane: Optional[RigLane] = None,
    timeout_s: int = 180,
    **kwargs: Any,
) -> Dict[str, Any]:
    cmd = build_seed_cmd(**kwargs)
    proc = run_cli(cmd, lane=lane, timeout_s=timeout_s)
    return {
        "cmd": cmd,
        "exit_code": int(proc.returncode),
        "stdout": proc.stdout,
        "stderr": proc.stderr,
        "summary": parse_last_json(proc.stdout, proc.stderr),
    }


def run_batch(
    *,
    lane: Optional[RigLane] = None,
    timeout_s: int = 240,
    extra_env: Optional[Dict[str, str]] = None,
    **kwargs: Any,
) -> Dict[str, Any]:
    output_dir = Path(kwargs["output_dir"])
    cmd = build_batch_cmd(**kwargs)
    started = time.time()
    proc = run_cli(cmd, lane=lane, timeout_s=timeout_s, extra_env=extra_env)
    elapsed = round(time.time() - started, 2)
    return {
        "cmd": cmd,
        "exit_code": int(proc.returncode),
        "stdout": proc.stdout,
        "stderr": proc.stderr,
        "elapsed_s": elapsed,
        "batch_summary": latest_batch_summary(output_dir),
    }


def run_runner(
    *,
    lane: Optional[RigLane] = None,
    timeout_s: int = 240,
    extra_env: Optional[Dict[str, str]] = None,
    **kwargs: Any,
) -> Dict[str, Any]:
    cmd = build_runner_cmd(**kwargs)
    started = time.time()
    proc = run_cli(cmd, lane=lane, timeout_s=timeout_s, extra_env=extra_env)
    elapsed = round(time.time() - started, 2)
    return {
        "cmd": cmd,
        "exit_code": int(proc.returncode),
        "stdout": proc.stdout,
        "stderr": proc.stderr,
        "elapsed_s": elapsed,
        "summary": parse_last_json(proc.stdout, proc.stderr),
    }
