#!/usr/bin/env python3
import json
import os
import select
import signal
import subprocess
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

from milk_hunt_paths import APP_NAME, rig_queue_file, rig_results_file, runner_root, user_dir, xdg_root


def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def _pid_cmdline(pid: int) -> str:
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return ""
    if not raw:
        return ""
    return raw.replace(b"\x00", b" ").decode("utf-8", errors="replace").strip().lower()


def _pid_looks_like_rig_listener(pid: int) -> bool:
    cmdline = _pid_cmdline(pid)
    if not cmdline:
        return False
    return ("godot" in cmdline) and ("tests/rig_listener.gd" in cmdline)


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
        self._results_offset: int = 0
        self._results_partial: str = ""
        self._results_by_turn: Dict[int, Dict[str, Any]] = {}
        self._latest_result_turn: int = -1

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
        self.queue_file.unlink(missing_ok=True)
        self.results_file.unlink(missing_ok=True)
        # Always clear stale sentinel for this XDG root; a fresh listener writes a new one.
        self._bridge_sentinel_path(self.xdg_root).unlink(missing_ok=True)
        self._results_offset = 0
        self._results_partial = ""
        self._results_by_turn.clear()
        self._latest_result_turn = -1

    @staticmethod
    def _bridge_sentinel_path(xdg: Optional[Path] = None) -> Path:
        return user_dir(xdg=xdg) / "rig" / "bridge_ready"

    @staticmethod
    def find_listener_pids(xdg: Optional[Path] = None) -> List[int]:
        out: List[int] = []
        try:
            proc = subprocess.run(
                ["pgrep", "-f", "Tests/rig_listener.gd"],
                capture_output=True,
                text=True,
                check=False,
            )
            for line in proc.stdout.splitlines():
                line = line.strip()
                if line.isdigit():
                    out.append(int(line))
        except FileNotFoundError:
            pass

        # Also check for phrame bridge sentinel
        sentinel = RigClient._bridge_sentinel_path(xdg=xdg)
        if sentinel.exists():
            try:
                pid = int(sentinel.read_text().strip())
                if pid > 0 and _pid_alive(pid) and _pid_looks_like_rig_listener(pid):
                    out.append(pid)
            except (ValueError, OSError):
                pass
        return out

    @staticmethod
    def _bridge_sentinel_is_ready(xdg: Optional[Path] = None) -> bool:
        sentinel = RigClient._bridge_sentinel_path(xdg=xdg)
        if sentinel.exists():
            try:
                pid = int(sentinel.read_text().strip())
                if pid > 0 and _pid_alive(pid) and _pid_looks_like_rig_listener(pid):
                    return True
            except (ValueError, OSError):
                pass
        return False

    @staticmethod
    def wait_for_bridge_sentinel(timeout_s: float = 30.0, xdg: Optional[Path] = None) -> bool:
        deadline = time.time() + timeout_s
        while time.time() < deadline:
            if RigClient._bridge_sentinel_is_ready(xdg=xdg):
                return True
            time.sleep(0.25)
        return False

    @staticmethod
    def kill_existing_listeners(xdg: Optional[Path] = None) -> None:
        for pid in RigClient.find_listener_pids(xdg=xdg):
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    def start_listener(
        self,
        *,
        load_slot: Optional[int] = None,
        scenario_id: str = "default",
        allow_resource_injection: Optional[bool] = None,
        listener_stdout: str = "file",
        listener_log_path: Optional[Path] = None,
        rig_log_profile: Optional[str] = "quiet",
        rig_log_category_levels: Optional[str] = None,
        extra_env: Optional[Dict[str, str]] = None,
    ) -> subprocess.Popen:
        env = os.environ.copy()
        env["XDG_ROOT"] = str(self.xdg_root)
        os.environ["XDG_ROOT"] = str(self.xdg_root)
        if load_slot is not None:
            env["RIG_LOAD_SLOT"] = str(load_slot)
        env["RIG_SCENARIO"] = scenario_id
        if allow_resource_injection is not None:
            env["RIG_ALLOW_RESOURCE_INJECTION"] = "1" if allow_resource_injection else "0"
        if rig_log_profile:
            env["RIG_LOG_PROFILE"] = str(rig_log_profile)
        if rig_log_category_levels:
            env["RIG_LOG_CATEGORY_LEVELS"] = str(rig_log_category_levels)
        if extra_env:
            for key, value in extra_env.items():
                if key and value is not None:
                    env[str(key)] = str(value)

        mode = (listener_stdout or "file").strip().lower()
        stdout_target: Any = subprocess.PIPE
        log_handle = None
        if mode == "null":
            stdout_target = subprocess.DEVNULL
        elif mode == "pipe":
            stdout_target = subprocess.PIPE
        else:
            log_path = (
                listener_log_path
                if listener_log_path is not None
                else self.runner_root / "logs" / "rig_listener.log"
            )
            log_path.parent.mkdir(parents=True, exist_ok=True)
            log_handle = open(log_path, "a", encoding="utf-8")
            stdout_target = log_handle

        proc = subprocess.Popen(
            [str(self.start_script)],
            cwd=str(self.project_root),
            stdout=stdout_target,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
        )
        if log_handle is not None:
            log_handle.close()
        return proc

    @staticmethod
    def wait_for_ready(proc: subprocess.Popen, timeout_s: float = 60.0, xdg: Optional[Path] = None) -> List[str]:
        started = time.time()
        seen: List[str] = []
        while time.time() - started < timeout_s:
            if RigClient._bridge_sentinel_is_ready(xdg=xdg):
                seen.append("[rig] ready via bridge sentinel")
                return seen
            if proc.poll() is not None:
                break
            if not proc.stdout:
                time.sleep(0.1)
                continue
            readable, _, _ = select.select([proc.stdout], [], [], 0.1)
            if not readable:
                continue
            line = proc.stdout.readline()
            if not line:
                continue
            line = line.rstrip("\n")
            seen.append(line)
            if RigClient.is_ready_line(line):
                return seen
        return seen

    @staticmethod
    def is_ready_line(line: str) -> bool:
        text = str(line or "")
        if "ready via bridge sentinel" in text:
            return True
        return ("Rig ready" in text) and ("Waiting for turns in:" in text)

    @staticmethod
    def ready_seen(lines: List[str]) -> bool:
        for line in lines:
            if RigClient.is_ready_line(line):
                return True
        return False

    def queue_turn(self, payload: Dict[str, Any]) -> None:
        raw = json.dumps(payload, ensure_ascii=False)
        self.queue_file.parent.mkdir(parents=True, exist_ok=True)
        with self.queue_file.open("a", encoding="utf-8") as fh:
            fh.write(raw)
            fh.write("\n")

    def _read_new_result_rows(self) -> List[Dict[str, Any]]:
        if not self.results_file.exists():
            return []
        try:
            size = self.results_file.stat().st_size
        except OSError:
            return []

        if self._results_offset > size:
            self._results_offset = 0
            self._results_partial = ""
            self._results_by_turn.clear()
            self._latest_result_turn = -1

        if self._results_offset == size:
            return []

        try:
            with self.results_file.open("r", encoding="utf-8", errors="replace") as fh:
                fh.seek(self._results_offset)
                chunk = fh.read()
                self._results_offset = fh.tell()
        except OSError:
            return []

        if not chunk:
            return []

        payload = self._results_partial + chunk
        lines = payload.splitlines(keepends=True)
        if lines and not lines[-1].endswith("\n"):
            self._results_partial = lines.pop()
        else:
            self._results_partial = ""

        out: List[Dict[str, Any]] = []
        for raw in lines:
            line = raw.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                row = {"ok": False, "error": "bad_json_line", "raw": line}
            out.append(row)
            turn = row.get("turn")
            if isinstance(turn, (int, float)):
                turn_i = int(turn)
                self._results_by_turn[turn_i] = row
                if turn_i > self._latest_result_turn:
                    self._latest_result_turn = turn_i
        self._trim_result_cache()
        return out

    def _trim_result_cache(self, max_entries: int = 4096) -> None:
        while len(self._results_by_turn) > max_entries:
            try:
                oldest = next(iter(self._results_by_turn))
            except StopIteration:
                return
            self._results_by_turn.pop(oldest, None)

    def wait_for_turn(
        self,
        turn_id: int,
        timeout_s: float = 10.0,
        progress_interval_s: float = 5.0,
    ) -> Optional[Dict[str, Any]]:
        started = time.time()
        next_report_at = started + max(0.5, progress_interval_s) if progress_interval_s > 0 else float("inf")
        while time.time() - started < timeout_s:
            for row in self._read_new_result_rows():
                turn = row.get("turn")
                if isinstance(turn, (int, float)) and int(turn) == int(turn_id):
                    return row
            cached = self._results_by_turn.get(int(turn_id))
            if cached is not None:
                return cached
            now = time.time()
            if progress_interval_s > 0 and now >= next_report_at:
                elapsed = now - started
                self.safe_print(
                    "[rig_wait] waiting turn=%d elapsed=%.1fs latest_result_turn=%d"
                    % (turn_id, elapsed, self._latest_result_turn)
                )
                next_report_at = now + max(0.5, progress_interval_s)
            time.sleep(0.2)
        return None

    def run_turn(
        self,
        turn_id: int,
        action: str,
        *,
        timeout_s: float = 10.0,
        progress_interval_s: float = 5.0,
        delay_s: float = 0.0,
        **kwargs: Any,
    ) -> Dict[str, Any]:
        payload: Dict[str, Any] = {"turn": turn_id, "action": action}
        payload.update(kwargs)
        self.queue_turn(payload)
        result = self.wait_for_turn(turn_id, timeout_s=timeout_s, progress_interval_s=progress_interval_s)
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
