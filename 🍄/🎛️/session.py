#!/usr/bin/env python3
"""RunSession: the LLM-playable game API for SpaceWheat.

Wraps the Godot rig IPC into a clean Python class that can be used
interactively (by an LLM) or programmatically (for balancing).

Usage (interactive / LLM):

    from session import RunSession

    s = RunSession("balanced_survival")
    s.start()

    print(s.resources())       # {👥: 300, 🌾: 300, 🍞: 160, ...}
    quests = s.offer()         # [{id, pair, reward, ...}, ...]
    s.accept(quests[0]["id"])
    s.complete(quests[0]["id"])
    s.probe()                  # {hits: 3, frontier: [...]}
    s.discover("FungalNetworks")

    print(s.found_milk)        # True/False
    print(s.steps)             # 42
    print(s.cycles)            # 7

    s.stop()

Usage (batch / balancing):

    s = RunSession("balanced_survival")
    s.start()
    result = s.autoplay(max_cycles=220)
    # result = RunnerResult with all stats
    s.stop()

Graph Tissue™ is a trademark of Luke Spooner.
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

from rig_client import RigClient
from milk_hunt_paths import xdg_root as _default_xdg
from run_executor import ensure_lane, run_seed
from schema import RunnerResult

HERE = Path(__file__).resolve().parent
SEED_SCRIPT = HERE / "milk_hunt_seed_save.py"
RUNNER_SCRIPT = HERE / "milk_hunt_runner.py"


class RunSession:
    """One game session: boot a rig, play turns, get results.

    The session manages the full lifecycle:
      1. Seed a save slot from a profile
      2. Start a Godot rig (headless)
      3. Play turns via the IPC protocol
      4. Stop the rig

    The public API is designed for two audiences:
      - LLMs: call offer(), accept(), complete(), probe(), discover()
      - Balancers: call autoplay() for hands-off batch execution
    """

    def __init__(
        self,
        profile: str,
        *,
        slot: int = 2,
        xdg: Optional[Path] = None,
        policy: str = "engine_policy",
        epsilon: float = 0.18,
        ucb_scale: float = 1.10,
        allow_injection: bool = True,
    ):
        self.profile = profile
        self.slot = slot
        self.xdg = xdg or _default_xdg()
        self._lane = ensure_lane(self.xdg)
        self.policy = policy
        self.epsilon = epsilon
        self.ucb_scale = ucb_scale
        self.allow_injection = allow_injection

        self._rig: Optional[RigClient] = None
        self._proc: Optional[subprocess.Popen] = None
        self._turn: int = 0
        self._started: bool = False
        self._found_milk: bool = False
        self._steps: int = 0
        self._cycles: int = 0
        self._biomes: List[str] = []
        self._vocab_milestones: int = 0
        self._known_icons: List[Dict[str, str]] = []
        self._t_start: float = 0.0

    # ── Lifecycle ───────────────────────────────────────────────────

    def seed(self) -> Dict[str, Any]:
        """Seed the save slot from the profile. Called automatically by start()."""
        result = run_seed(
            lane=self._lane,
            timeout_s=120,
            profile=self.profile,
            slot=self.slot,
            reuse_listener=False,
        )
        exit_code = int(result.get("exit_code", 1))
        if exit_code not in (0, 3):
            raise RuntimeError(f"Seed failed (exit={exit_code}): {str(result.get('stderr', ''))[:500]}")
        summary = result.get("summary", {})
        return summary if isinstance(summary, dict) and summary else {"ok": True, "slot": self.slot}

    def start(self) -> "RunSession":
        """Seed + boot the Godot rig. Returns self for chaining."""
        self.seed()

        self._rig = RigClient(xdg=self._lane.xdg_root)
        # Kill any stale listeners for this XDG root
        RigClient.kill_existing_listeners(xdg=self.xdg)
        time.sleep(0.5)
        self._rig.clear_rig_files()

        self._proc = self._rig.start_listener(
            load_slot=self.slot,
            allow_resource_injection=self.allow_injection,
            listener_stdout="null",
            rig_log_profile="quiet",
        )

        # Wait for rig to be ready
        lines = RigClient.wait_for_ready(
            self._proc, timeout_s=60.0, xdg=self.xdg)
        if not RigClient.ready_seen(lines):
            # Try bridge sentinel as fallback
            if not RigClient.wait_for_bridge_sentinel(timeout_s=30.0, xdg=self.xdg):
                raise RuntimeError("Rig failed to start within 60s")

        self._started = True
        self._t_start = time.time()
        self._turn = 0
        return self

    def stop(self) -> None:
        """Shut down the Godot rig gracefully."""
        if self._rig and self._started:
            try:
                self._run("stop")
            except Exception:
                pass
        RigClient.terminate_listener(self._proc)
        self._started = False

    @property
    def alive(self) -> bool:
        return self._started and self._proc is not None and self._proc.poll() is None

    def __enter__(self) -> "RunSession":
        self.start()
        return self

    def __exit__(self, *exc: Any) -> None:
        self.stop()

    # ── Low-level turn execution ────────────────────────────────────

    def _run(self, action: str, timeout_s: float = 15.0, **kwargs: Any) -> Dict[str, Any]:
        """Execute one turn on the rig and return the result."""
        if not self._rig:
            raise RuntimeError("Session not started — call start() first")
        self._turn += 1
        result = self._rig.run_turn(
            self._turn, action, timeout_s=timeout_s, **kwargs)
        if not result.get("ok", False) and result.get("error") == "timeout_waiting_for_result":
            raise TimeoutError(f"Rig timeout on turn {self._turn} action={action}")
        return result

    # ── Game state queries ──────────────────────────────────────────

    def resources(self) -> Dict[str, float]:
        """Get current resource amounts: {emoji: amount}."""
        result = self._run("policy_snapshot", include_offers=False, include_grid=False)
        payload = result.get("policy_snapshot", {})
        return payload.get("resources", {}) if isinstance(payload, dict) else {}

    def snapshot(self) -> Dict[str, Any]:
        """Get full game state snapshot."""
        result = self._run("full_snapshot", timeout_s=20.0)
        return result

    def known_icons(self) -> List[Dict[str, str]]:
        """Get known icons: [{north, south}, ...]."""
        result = self._run("policy_snapshot", include_offers=False, include_grid=False)
        payload = result.get("policy_snapshot", {})
        icons = payload.get("known_icons", []) if isinstance(payload, dict) else []
        self._known_icons = icons
        return icons

    def active_quests(self) -> List[Dict[str, Any]]:
        """Get currently active quests."""
        result = self._run("policy_snapshot", include_offers=False, include_grid=False)
        payload = result.get("policy_snapshot", {})
        return payload.get("active_quests", []) if isinstance(payload, dict) else []

    def biome_positions(self, biome: str) -> List[Any]:
        """Get plot positions in a biome."""
        result = self._run("biome_positions", biome=biome)
        return result.get("positions", [])

    # ── Game actions ────────────────────────────────────────────────

    def offer(self, **kwargs: Any) -> List[Dict[str, Any]]:
        """Generate quest offers and return them.

        This is the primary action in a quest cycle: the rig generates
        offers based on current game state.
        """
        result = self._run("offer_quests", **kwargs)
        self._steps += 1
        offers = result.get("offers", result.get("quests", []))
        return offers

    def accept(self, quest_id: str) -> Dict[str, Any]:
        """Accept a quest offer by ID."""
        result = self._run("accept_quest", quest_id=quest_id)
        self._steps += 1
        return result

    def complete(self, quest_id: str) -> Dict[str, Any]:
        """Complete a quest and claim its reward."""
        result = self._run("complete_or_claim", quest_id=quest_id)
        self._steps += 1
        # Check for milk discovery
        if result.get("found_milk_pair") or result.get("milk_found"):
            self._found_milk = True
        # Track vocab milestones
        new_pairs = result.get("new_vocab_pairs", [])
        if new_pairs:
            self._vocab_milestones += len(new_pairs)
            self._known_icons.extend(new_pairs)
        return result

    def quest_cycle(self, quest_id: str) -> Dict[str, Any]:
        """Advance the quest cycle for a specific offer."""
        result = self._run("quest_cycle", quest_id=quest_id)
        self._steps += 1
        return result

    def probe(self, **kwargs: Any) -> Dict[str, Any]:
        """Run a probe measurement cycle on the quantum grid."""
        result = self._run("probe_cycle", **kwargs)
        self._steps += 1
        return result

    def discover(self, biome: str) -> Dict[str, Any]:
        """Discover (unlock) a new biome."""
        result = self._run("discover_biome", biome=biome)
        self._steps += 1
        if result.get("ok"):
            if biome not in self._biomes:
                self._biomes.append(biome)
        return result

    def time_skip(self, phrames: int = 60, **kwargs: Any) -> Dict[str, Any]:
        """Skip forward N physics frames."""
        result = self._run("time_skip", phrames=phrames, timeout_s=30.0, **kwargs)
        self._steps += 1
        return result

    def inject_icon(self, biome: str = "") -> Dict[str, Any]:
        """Trigger a vocabulary learning event."""
        result = self._run("inject_icon", biome=biome)
        self._steps += 1
        return result

    def lindblad_drain(self, positions: Optional[List[Any]] = None) -> Dict[str, Any]:
        """Activate Lindblad drain on grid positions."""
        result = self._run("lindblad_drain", positions=positions or [])
        self._steps += 1
        return result

    def save(self, slot: Optional[int] = None) -> Dict[str, Any]:
        """Save game state to a slot."""
        return self._run("save_game", slot=slot or self.slot)

    def load(self, slot: Optional[int] = None) -> Dict[str, Any]:
        """Load game state from a slot."""
        return self._run("load_game", slot=slot or self.slot)

    # ── Cycle helpers ───────────────────────────────────────────────

    def play_cycle(self) -> Dict[str, Any]:
        """Play one full offer->accept->complete cycle.

        Returns the completion result. Automatically picks the first offer.
        """
        offers = self.offer()
        if not offers:
            return {"ok": False, "error": "no_offers"}
        quest_id = offers[0].get("id", offers[0].get("quest_id", ""))
        if not quest_id:
            return {"ok": False, "error": "no_quest_id"}
        self.accept(quest_id)
        result = self.complete(quest_id)
        self._cycles += 1
        return result

    # ── Autoplay (for balancing) ────────────────────────────────────

    def autoplay(
        self,
        max_cycles: int = 220,
        *,
        probe_every: int = 5,
        discover_threshold: int = 10,
    ) -> RunnerResult:
        """Auto-play the game up to max_cycles. Returns a RunnerResult.

        This delegates to the existing milk_hunt_runner.py to get the
        full policy engine, then parses the result.
        """
        cmd = [
            sys.executable, str(RUNNER_SCRIPT),
            "--load-slot", str(self.slot),
            "--save-slot-at-end", str(self.slot),
            "--max-loops", str(max_cycles),
            "--hunter-profile", self.profile,
            "--hunter-policy", self.policy,
            "--policy-epsilon", str(self.epsilon),
            "--policy-ucb-scale", str(self.ucb_scale),
            "--json-only",
            "--reuse-listener",
            "--console-profile", "quiet",
        ]

        env = dict(__import__("os").environ)
        env["XDG_ROOT"] = str(self.xdg)

        t0 = time.time()
        proc = subprocess.run(
            cmd, capture_output=True, text=True,
            timeout=max(300, max_cycles * 30), env=env,
        )
        elapsed = time.time() - t0

        # Parse JSON summary from runner stdout
        summary = {}
        stdout = (proc.stdout or "").strip()
        if stdout:
            for line in reversed(stdout.split("\n")):
                line = line.strip()
                if line.startswith("{"):
                    try:
                        summary = json.loads(line)
                        break
                    except json.JSONDecodeError:
                        pass

        found_milk = bool(summary.get("found_milk_pair", False))
        steps = int(summary.get("steps", summary.get("turns_executed", 0) or 0) or 0)
        cycles = int(summary.get("loops_completed", 0))
        biomes = list(summary.get("biome_discovery_order",
                                   summary.get("discovered_biomes", [])))
        vocab = len(summary.get("vocab_milestones", []))

        self._found_milk = found_milk
        self._steps += steps
        self._cycles += cycles
        self._biomes = biomes
        self._vocab_milestones = vocab

        return RunnerResult(
            profile=self.profile,
            found_milk=found_milk,
            steps=steps,
            cycles=cycles,
            biomes=biomes,
            biomes_found=len(biomes),
            vocab=vocab,
            elapsed_s=round(elapsed, 2),
            slot=self.slot,
            exit_code=proc.returncode,
            batch_summary=summary,
        )

    # ── Properties ──────────────────────────────────────────────────

    @property
    def found_milk(self) -> bool:
        return self._found_milk

    @property
    def steps(self) -> int:
        return self._steps

    @property
    def cycles(self) -> int:
        return self._cycles

    @property
    def biomes(self) -> List[str]:
        return self._biomes

    @property
    def vocab_milestones(self) -> int:
        return self._vocab_milestones

    @property
    def elapsed(self) -> float:
        if self._t_start > 0:
            return time.time() - self._t_start
        return 0.0

    def status(self) -> Dict[str, Any]:
        """Quick status summary for display."""
        return {
            "profile": self.profile,
            "found_milk": self._found_milk,
            "steps": self._steps,
            "cycles": self._cycles,
            "biomes": self._biomes,
            "vocab": self._vocab_milestones,
            "elapsed_s": round(self.elapsed, 1),
            "alive": self.alive,
        }

    def __repr__(self) -> str:
        milk = "MILK!" if self._found_milk else "hunting"
        return (f"<RunSession {self.profile} [{milk}] "
                f"steps={self._steps} cycles={self._cycles} "
                f"biomes={len(self._biomes)}>")
