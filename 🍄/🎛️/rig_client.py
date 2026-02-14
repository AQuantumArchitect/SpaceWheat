#!/usr/bin/env python3
import json
import os
import select
import signal
import subprocess
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

from milk_hunt_paths import APP_NAME, rig_queue_file, rig_results_file, runner_root, xdg_root


class RigClient:
    def __init__(self, *, xdg: Optional[Path] = None, root_from_file: Optional[Path] = None) -> None:
        self.app_name = APP_NAME
        self.xdg_root = xdg if xdg is not None else xdg_root()
        self.runner_root = runner_root(from_file=root_from_file)
        self.project_root = self.runner_root.parent.parent
        self.start_script = self.runner_root / "\U0001F7E2.sh"
        self.queue_script = self.runner_root / "\u270D\ufe0f.sh"
        self.queue_file = rig_queue_file(xdg=self.xdg_root, app_name=self.app_name)
        self.results_file = rig_results_file(xdg=self.xdg_root, app_name=self.app_name)

    @staticmethod
    def safe_print(msg: str) -> None:
        print(msg, flush=True)

    @staticmethod
    def json_load_lines(path: Path) -> List[Dict[str, Any]]:
        if not path.exists():
            return []
        out: List[Dict[str, Any]] = []
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            raw = raw.strip()
            if not raw:
                continue
            try:
                out.append(json.loads(raw))
            except json.JSONDecodeError:
                out.append({"ok": False, "error": "bad_json_line", "raw": raw})
        return out

    def clear_rig_files(self) -> None:
        self.queue_file.parent.mkdir(parents=True, exist_ok=True)
        for p in (self.queue_file, self.results_file):
            if p.exists():
                p.unlink()

    @staticmethod
    def find_listener_pids() -> List[int]:
        try:
            proc = subprocess.run(
                ["pgrep", "-f", "Tests/rig_listener.gd"],
                capture_output=True,
                text=True,
                check=False,
            )
        except FileNotFoundError:
            return []
        out: List[int] = []
        for line in proc.stdout.splitlines():
            line = line.strip()
            if line.isdigit():
                out.append(int(line))
        return out

    @staticmethod
    def kill_existing_listeners() -> None:
        for pid in RigClient.find_listener_pids():
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    def start_listener(self, *, load_slot: Optional[int] = None, scenario_id: str = "default") -> subprocess.Popen:
        env = os.environ.copy()
        env["XDG_ROOT"] = str(self.xdg_root)
        if load_slot is not None:
            env["RIG_LOAD_SLOT"] = str(load_slot)
        env["RIG_SCENARIO"] = scenario_id
        return subprocess.Popen(
            [str(self.start_script)],
            cwd=str(self.project_root),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
        )

    @staticmethod
    def wait_for_ready(proc: subprocess.Popen, timeout_s: float = 60.0) -> List[str]:
        started = time.time()
        seen: List[str] = []
        while time.time() - started < timeout_s:
            if proc.poll() is not None:
                break
            if not proc.stdout:
                time.sleep(0.05)
                continue
            readable, _, _ = select.select([proc.stdout], [], [], 0.1)
            if not readable:
                continue
            line = proc.stdout.readline()
            if not line:
                continue
            line = line.rstrip("\n")
            seen.append(line)
            if "Rig ready. Waiting for turns in:" in line:
                return seen
        return seen

    def queue_turn(self, payload: Dict[str, Any]) -> None:
        env = os.environ.copy()
        env["XDG_ROOT"] = str(self.xdg_root)
        raw = json.dumps(payload, ensure_ascii=False)
        subprocess.run(
            [str(self.queue_script), raw],
            cwd=str(self.project_root),
            env=env,
            check=True,
            capture_output=True,
            text=True,
        )

    def wait_for_turn(self, turn_id: int, timeout_s: float = 10.0) -> Optional[Dict[str, Any]]:
        started = time.time()
        while time.time() - started < timeout_s:
            for row in reversed(self.json_load_lines(self.results_file)):
                turn = row.get("turn")
                if isinstance(turn, (int, float)) and int(turn) == turn_id:
                    return row
            time.sleep(0.1)
        return None

    def run_turn(
        self,
        turn_id: int,
        action: str,
        *,
        timeout_s: float = 10.0,
        delay_s: float = 0.0,
        **kwargs: Any,
    ) -> Dict[str, Any]:
        payload: Dict[str, Any] = {"turn": turn_id, "action": action}
        payload.update(kwargs)
        self.queue_turn(payload)
        result = self.wait_for_turn(turn_id, timeout_s=timeout_s)
        if result is None:
            return {"ok": False, "turn": turn_id, "action": action, "error": "timeout_waiting_for_result"}
        if delay_s > 0.0:
            time.sleep(delay_s)
        return result

    @staticmethod
    def terminate_listener(proc: Optional[subprocess.Popen], timeout_s: float = 5.0) -> None:
        if proc is None or proc.poll() is not None:
            return
        proc.terminate()
        try:
            proc.wait(timeout=timeout_s)
        except subprocess.TimeoutExpired:
            proc.kill()
