#!/usr/bin/env python3
"""RunSession: the LLM-playable game API for SpaceWheat.

Wraps the Godot rig IPC into a clean Python class that can be used
interactively (by an LLM) or programmatically (for balancing).

Usage (interactive / LLM — profile mode):

    from session import RunSession

    with RunSession("balanced_survival") as s:
        print(s.resources())       # {👥: 300, 🌾: 300, 🍞: 160, ...}
        quests = s.offer()         # [{id, pair, reward, ...}, ...]
        s.accept(quests[0]["id"])
        s.complete(quests[0]["id"])
        s.probe()                  # {hits: 3, frontier: [...]}
        s.discover("FungalNetworks")
        print(s.found_milk, s.steps, s.cycles)

Usage (character mode — richer: world state + policy graph):

    with RunSession(character="granary_scout_fib", policy="quantum_register") as s:
        result = s.autoplay(max_cycles=220)
        print(result.found_milk, result.composite())

CLI modes:

    python3 session.py --profile balanced_survival --autoplay --max-cycles 50
    python3 session.py --character granary_scout_fib --demo
    python3 session.py --character village_diplomat_fib --interactive
    python3 session.py --profile balanced_survival --snapshot

Graph Tissue(TM) is a trademark of Luke Spooner.
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

from constants import MAX_LOOPS, run_timeout, TIMEOUT_FLOOR
from rig_client import RigClient
from milk_hunt_paths import xdg_root as _default_xdg
from schema import RunnerResult
from leaderboard import record_from_runner_result as _record_leaderboard

HERE = Path(__file__).resolve().parent
SEED_SCRIPT = HERE / "milk_hunt_seed_save.py"
RUNNER_SCRIPT = HERE / "milk_hunt_runner.py"


class RunSession:
    """One game session: boot a rig, play turns, get results.

    The session manages the full lifecycle:
      1. Seed a save slot from a profile or character
      2. Start a Godot rig (headless)
      3. Play turns via the IPC protocol
      4. Stop the rig

    The public API is designed for two audiences:
      - LLMs: call offer(), accept(), complete(), probe(), discover()
      - Balancers: call autoplay() for hands-off batch execution

    Two identity modes:
      - profile: world-state config only (simple)
      - character: world-state + policy graph template (richer)
    """

    def __init__(
        self,
        profile: str = "",
        *,
        character: str = "",
        slot: int = 2,
        xdg: Optional[Path] = None,
        policy: str = "engine_policy",
        epsilon: float = 0.18,
        ucb_scale: float = 1.10,
        allow_injection: bool = True,
    ):
        if not profile and not character:
            raise ValueError("Must provide either profile= or character=")
        self.profile = profile or character
        self.character = character
        self.slot = slot
        self.xdg = xdg or _default_xdg()
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
        self._known_pairs: List[Dict[str, str]] = []
        self._t_start: float = 0.0

    # ── Lifecycle ───────────────────────────────────────────────────

    @property
    def is_character(self) -> bool:
        return bool(self.character)

    def seed(self) -> Dict[str, Any]:
        """Seed the save slot from the profile/character. Called automatically by start()."""
        if self.is_character:
            cmd = [
                sys.executable, str(SEED_SCRIPT),
                "--character", self.character,
                "--slot", str(self.slot),
                "--policy-mode", self.policy,
            ]
        else:
            cmd = [
                sys.executable, str(SEED_SCRIPT),
                "--profile", self.profile,
                "--slot", str(self.slot),
            ]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if proc.returncode not in (0, 3):
            raise RuntimeError(f"Seed failed (exit={proc.returncode}): {proc.stderr[:500]}")

        # Parse JSON from stdout
        for line in reversed((proc.stdout or "").strip().split("\n")):
            line = line.strip()
            if line.startswith("{"):
                try:
                    return json.loads(line)
                except json.JSONDecodeError:
                    pass
        return {"ok": True, "slot": self.slot}

    def start(self) -> "RunSession":
        """Seed + boot the Godot rig. Returns self for chaining."""
        self.seed()

        self._rig = RigClient(xdg=self.xdg)
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
        result = self._run("resource_snapshot")
        return result.get("resources", result.get("snapshot", {}))

    def snapshot(self) -> Dict[str, Any]:
        """Get full game state snapshot."""
        result = self._run("full_snapshot", timeout_s=20.0)
        return result

    def known_vocab(self) -> List[Dict[str, str]]:
        """Get known vocabulary pairs: [{north, south}, ...]."""
        result = self._run("known_vocab_pairs")
        pairs = result.get("pairs", result.get("known_pairs", []))
        self._known_pairs = pairs
        return pairs

    def active_quests(self) -> List[Dict[str, Any]]:
        """Get currently active quests."""
        result = self._run("active_quests")
        return result.get("quests", [])

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

    def accept(self, offer_index: int) -> Dict[str, Any]:
        """Accept a quest offer by index (0-based position in offer list)."""
        result = self._run("accept_offer", offer_index=offer_index)
        self._steps += 1
        return result

    def complete(self, quest_id: int) -> Dict[str, Any]:
        """Complete a quest by quest_id (returned from accept)."""
        result = self._run("complete_or_claim", quest_id=quest_id)
        self._steps += 1
        # Check for milk discovery
        if result.get("found_milk_pair") or result.get("milk_found"):
            self._found_milk = True
        # Track vocab milestones
        new_pairs = result.get("new_vocab_pairs", [])
        if new_pairs:
            self._vocab_milestones += len(new_pairs)
            self._known_pairs.extend(new_pairs)
        return result

    def lock(self, quest_id: str) -> Dict[str, Any]:
        """Pin a quest to locked offers."""
        result = self._run("lock_offer", quest_id=quest_id)
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

    def inject_vocab(self, biome: str = "") -> Dict[str, Any]:
        """Trigger a vocabulary learning event."""
        result = self._run("inject_vocab", biome=biome)
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

    def play_cycle(self, offer_index: int = 0) -> Dict[str, Any]:
        """Play one full offer->accept->complete cycle.

        Returns the completion result. Picks offer at offer_index (default: first).
        """
        offers = self.offer()
        if not offers:
            return {"ok": False, "error": "no_offers"}
        if offer_index >= len(offers):
            offer_index = 0
        selected_offer = offers[offer_index] if isinstance(offers[offer_index], dict) else {}
        accept_result = self.accept(offer_index)
        if not accept_result.get("accepted", False):
            return {"ok": False, "error": "accept_failed", "accept_result": accept_result}
        quest_id = int(accept_result.get("quest_id", -1))
        if quest_id < 0:
            return {"ok": False, "error": "no_quest_id", "accept_result": accept_result}

        # Inject resources if needed (non-strict economy)
        if self.allow_injection:
            res = str(selected_offer.get("resource", "") or "")
            qty = int(float(selected_offer.get("quantity", 0) or 0))
            if res and qty > 0:
                self._run("add_resource", emoji=res, amount=max(qty + 50, 100))

        # Use the offer's completion_action or default
        completion_action = str(selected_offer.get("completion_action", "") or "")
        if completion_action not in ("complete_quest", "complete_or_claim"):
            offer_type = int(selected_offer.get("type", -1))
            completion_action = "complete_quest" if offer_type == 0 else "complete_or_claim"

        result = self._run(completion_action, quest_id=quest_id)
        self._steps += 1
        if result.get("found_milk_pair") or result.get("milk_found"):
            self._found_milk = True
        new_pairs = result.get("new_vocab_pairs", [])
        if new_pairs:
            self._vocab_milestones += len(new_pairs)
            self._known_pairs.extend(new_pairs)
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
            timeout=run_timeout(max_cycles, floor=TIMEOUT_FLOOR["session"]), env=env,
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

        result = RunnerResult(
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

        # Record to persistent leaderboard
        _record_leaderboard(result, layer="session",
                            default_lane=self.character or self.profile)

        return result

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
        identity = f"character={self.character}" if self.is_character else self.profile
        return (f"<RunSession {identity} [{milk}] "
                f"steps={self._steps} cycles={self._cycles} "
                f"biomes={len(self._biomes)}>")


# ═══════════════════════════════════════════════════════════════════
# CLI entry point — interactive demo and autoplay
# ═══════════════════════════════════════════════════════════════════

def _build_parser():
    import argparse
    parser = argparse.ArgumentParser(
        description="RunSession: LLM-playable SpaceWheat game interface",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""examples:
  # Autoplay a profile for 50 cycles
  python3 session.py --profile balanced_survival --autoplay --max-cycles 50

  # Autoplay a character with quantum policy
  python3 session.py --character granary_scout_fib --policy quantum_register --autoplay

  # Interactive REPL (for LLM tool-use or human exploration)
  python3 session.py --profile balanced_survival --interactive

  # Quick status check: seed + snapshot + stop
  python3 session.py --character village_diplomat_fib --snapshot

Graph Tissue(TM) is a trademark of Luke Spooner.""",
    )
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--profile", help="Profile name (world state config)")
    source.add_argument("--character", help="Character spec (world state + policy)")
    parser.add_argument("--policy", default="engine_policy",
                        choices=["engine_policy", "quantum_register"])
    parser.add_argument("--slot", type=int, default=2)

    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--autoplay", action="store_true",
                      help="Auto-play to completion via milk_hunt_runner")
    mode.add_argument("--interactive", action="store_true",
                      help="Start interactive REPL")
    mode.add_argument("--snapshot", action="store_true",
                      help="Seed, boot, print snapshot, stop")
    mode.add_argument("--demo", action="store_true",
                      help="Run a short demo: 3 cycles + probe + status")

    parser.add_argument("--max-cycles", type=int, default=MAX_LOOPS)
    return parser


def _cmd_autoplay(session: RunSession, max_cycles: int) -> None:
    """Run the full autoplay pipeline and print results."""
    print(f"  Autoplaying {session.profile} for up to {max_cycles} cycles...")
    result = session.autoplay(max_cycles=max_cycles)
    milk_str = "MILK FOUND!" if result.found_milk else "no milk"
    print(f"\n  Result: {milk_str}")
    print(f"  cycles={result.cycles}  steps={result.steps}  "
          f"biomes={result.biomes_found}  vocab={result.vocab}  "
          f"elapsed={result.elapsed_s:.1f}s")
    scores = result.scores_dict()
    print(f"  Scores: SR={scores['success_rate']:.0%}  "
          f"speed={scores['speed_score']:.2f}  "
          f"biome={scores['biome_score']:.2f}  "
          f"vocab={scores['vocab_score']:.2f}  "
          f"composite={scores['composite']:.4f}")
    print(f"\n  {json.dumps(result.to_dict(), indent=2)}")


def _cmd_snapshot(session: RunSession) -> None:
    """Boot, take a snapshot, print it, and stop."""
    res = session.resources()
    pairs = session.known_vocab()
    print(f"\n  Resources: {json.dumps(res, ensure_ascii=False)}")
    print(f"  Known pairs: {len(pairs)}")
    for p in pairs[:10]:
        print(f"    {p.get('north', '?')} <-> {p.get('south', '?')}")
    if len(pairs) > 10:
        print(f"    ... and {len(pairs) - 10} more")
    print(f"\n  Status: {json.dumps(session.status(), ensure_ascii=False)}")


def _cmd_demo(session: RunSession) -> None:
    """Run a short demo: 3 quest cycles + probe + status."""
    for i in range(3):
        print(f"\n  --- Cycle {i+1} ---")
        result = session.play_cycle()
        ok = result.get("ok", True)
        milk = result.get("found_milk_pair", False)
        print(f"  ok={ok}  milk={milk}")
        if milk:
            print("  MILK FOUND! Stopping demo.")
            break

    print(f"\n  --- Probe ---")
    probe_result = session.probe()
    print(f"  Probe: {json.dumps(probe_result, indent=2, ensure_ascii=False)[:500]}")

    res = session.resources()
    print(f"\n  Resources after demo: {json.dumps(res, ensure_ascii=False)}")
    print(f"  {session}")


def _cmd_interactive(session: RunSession) -> None:
    """Interactive REPL for LLM or human exploration."""
    print(f"\n  Interactive session started. Type commands:")
    print(f"  Commands: offer, accept <id>, complete <id>, probe, discover <biome>,")
    print(f"            resources, vocab, quests, status, save, load, skip <N>, quit")
    print()

    while session.alive:
        try:
            line = input("  > ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break
        if not line:
            continue

        parts = line.split(None, 1)
        cmd = parts[0].lower()
        arg = parts[1].strip() if len(parts) > 1 else ""

        try:
            if cmd == "quit" or cmd == "exit":
                break
            elif cmd == "offer":
                offers = session.offer()
                for o in offers:
                    qid = o.get("id", o.get("quest_id", "?"))
                    pair = o.get("pair", o.get("emoji_pair", "?"))
                    print(f"    [{qid}] {pair}")
            elif cmd == "accept":
                r = session.accept(arg)
                print(f"    {json.dumps(r, ensure_ascii=False)[:300]}")
            elif cmd == "complete":
                r = session.complete(arg)
                milk = r.get("found_milk_pair", False)
                print(f"    ok={r.get('ok', True)}  milk={milk}")
            elif cmd == "cycle":
                r = session.play_cycle()
                milk = r.get("found_milk_pair", False)
                print(f"    ok={r.get('ok', True)}  milk={milk}")
            elif cmd == "probe":
                r = session.probe()
                print(f"    {json.dumps(r, ensure_ascii=False)[:500]}")
            elif cmd == "discover":
                r = session.discover(arg)
                print(f"    {json.dumps(r, ensure_ascii=False)[:300]}")
            elif cmd == "resources" or cmd == "res":
                res = session.resources()
                print(f"    {json.dumps(res, ensure_ascii=False)}")
            elif cmd == "vocab":
                pairs = session.known_vocab()
                for p in pairs:
                    print(f"    {p.get('north', '?')} <-> {p.get('south', '?')}")
            elif cmd == "quests":
                qs = session.active_quests()
                for q in qs:
                    print(f"    {json.dumps(q, ensure_ascii=False)[:200]}")
            elif cmd == "status":
                print(f"    {json.dumps(session.status(), ensure_ascii=False)}")
            elif cmd == "save":
                r = session.save()
                print(f"    saved: {r.get('ok', True)}")
            elif cmd == "load":
                r = session.load()
                print(f"    loaded: {r.get('ok', True)}")
            elif cmd == "skip":
                n = int(arg) if arg.isdigit() else 60
                r = session.time_skip(n)
                print(f"    skipped {n} phrames")
            elif cmd == "drain":
                r = session.lindblad_drain()
                print(f"    {json.dumps(r, ensure_ascii=False)[:300]}")
            else:
                print(f"    unknown command: {cmd}")
        except Exception as exc:
            print(f"    error: {exc}")

    print(f"\n  Final: {session}")


def main() -> int:
    args = _build_parser().parse_args()

    kwargs: Dict[str, Any] = {
        "slot": args.slot,
        "policy": args.policy,
    }
    if args.character:
        kwargs["character"] = args.character
    else:
        kwargs["profile"] = args.profile

    session = RunSession(**kwargs)

    identity = args.character or args.profile
    mode = "character" if args.character else "profile"
    print(f"  RunSession: {mode}={identity}  policy={args.policy}  slot={args.slot}")

    if args.autoplay:
        # Autoplay uses its own rig via milk_hunt_runner subprocess
        session.seed()
        _cmd_autoplay(session, args.max_cycles)
        return 0

    # All other modes need a live rig
    try:
        print(f"  Booting Godot rig...")
        session.start()
        print(f"  Rig ready.\n")

        if args.snapshot:
            _cmd_snapshot(session)
        elif args.demo:
            _cmd_demo(session)
        elif args.interactive:
            _cmd_interactive(session)
        else:
            # Default: snapshot
            _cmd_snapshot(session)
    finally:
        session.stop()
        print(f"\n  Session stopped. {session}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
