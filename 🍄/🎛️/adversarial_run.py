#!/usr/bin/env python3
"""Adversarial run: chain milk hunts with Fibonacci adversary mutations.

Each cycle:
  1. Run a milk hunt with current economy costs
  2. Feed action distribution to FibonacciAdversary
  3. Mutate knobs (±1 Fibonacci step) toward φ-cascade target
  4. Write berry block to ledger
  5. Update FarmVariableGraph patch for next run
  6. Repeat

Usage:
    python3 adversarial_run.py --profile granary_scout --cycles 10
    python3 adversarial_run.py --profile granary_scout --cycles 20 --policy quantum_register
"""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

# Ensure our runner directory is on path
_RUNNER_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(_RUNNER_DIR))

from fibonacci_adversary import FibonacciAdversary, default_ledger_path, default_patch_path, default_state_path


def _project_root() -> Path:
    return _RUNNER_DIR.parent.parent


def run_milk_hunt(
    *,
    policy: str = "quantum_register",
    profile: str = "granary_scout",
    max_loops: int = 100,
    extra_env: Optional[Dict[str, str]] = None,
) -> Optional[Dict[str, Any]]:
    """Run a single milk hunt and return the summary JSON."""
    cmd = [
        sys.executable,
        str(_RUNNER_DIR / "milk_hunt_runner.py"),
        "--hunter-policy", policy,
        "--hunter-profile", profile,
        "--profile-save", profile,
        "--max-loops", str(max_loops),
        "--console-profile", "quiet",
        "--json-only",
    ]

    env = os.environ.copy()
    env["RIG_DISABLE_LOOKAHEAD"] = "1"
    if extra_env:
        env.update(extra_env)

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=600,
            cwd=str(_project_root()),
            env=env,
        )
    except subprocess.TimeoutExpired:
        return None

    # Parse the last JSON line from stdout+stderr combined
    all_output = (proc.stdout or "") + "\n" + (proc.stderr or "")
    for line in reversed(all_output.strip().splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return None


def extract_step_stats(summary: Dict[str, Any]) -> Dict[str, Any]:
    """Extract per-step stats from policy_decisions trace."""
    decisions = summary.get("policy_decisions", [])
    if not decisions:
        return {}

    total_steps = 0
    quest_steps = 0
    quest_accepted = 0
    quest_completed_after = 0
    quest_novel_vocab = 0  # steps where reward vocab was new
    quest_no_offers = 0
    rewards: List[float] = []
    per_loop: Dict[int, List[str]] = {}  # loop → [actions]
    reward_by_action: Dict[str, List[float]] = {}

    for ev in decisions:
        if ev.get("kind") == "trace_truncated":
            continue
        total_steps += 1
        action = str(ev.get("executed_action") or ev.get("selected_action", ""))
        loop = ev.get("loop", 0)
        reward = float(ev.get("reward", 0.0))

        per_loop.setdefault(loop, []).append(action)
        rewards.append(reward)
        reward_by_action.setdefault(action, []).append(reward)

        if action == "quest_cycle":
            quest_steps += 1
            if ev.get("accepted"):
                quest_accepted += 1
            if ev.get("completed_after_accept"):
                quest_completed_after += 1
            north = ev.get("accepted_offer_reward_vocab_north", "")
            south = ev.get("accepted_offer_reward_vocab_south", "")
            if north or south:
                quest_novel_vocab += 1

    # Per-loop action sequences (first 5 loops)
    loop_sequences = []
    for loop_num in sorted(per_loop.keys())[:5]:
        actions = per_loop[loop_num]
        compressed = []
        for a in actions:
            short = {"quest_cycle": "Q", "probe_cycle": "P", "lindblad_drain": "D",
                     "time_skip": "T", "discover_biome": "X", "victory_lap_partial": "V",
                     "lock_offer": "L", "channel_drain": "C"}.get(a, "?")
            compressed.append(short)
        loop_sequences.append((loop_num, "".join(compressed)))

    avg_reward = sum(rewards) / len(rewards) if rewards else 0.0
    avg_reward_by_action = {}
    for a, rs in reward_by_action.items():
        avg_reward_by_action[a] = round(sum(rs) / len(rs), 2) if rs else 0.0

    return {
        "total_steps": total_steps,
        "quest_steps": quest_steps,
        "quest_accepted": quest_accepted,
        "quest_completed_after": quest_completed_after,
        "quest_novel_vocab": quest_novel_vocab,
        "quest_accept_rate": round(quest_accepted / max(1, quest_steps), 2),
        "quest_instant_complete_rate": round(quest_completed_after / max(1, quest_accepted), 2),
        "avg_reward": round(avg_reward, 2),
        "avg_reward_by_action": avg_reward_by_action,
        "loop_sequences": loop_sequences,
    }


def format_step_stats(stats: Dict[str, Any]) -> str:
    if not stats:
        return "  (no step data)"
    lines = []
    total = stats["total_steps"]
    qs = stats["quest_steps"]
    lines.append(f"  Steps: {total}  Quest: {qs} ({qs/max(1,total)*100:.0f}%)"
                 f"  accepted={stats['quest_accepted']}"
                 f"  instant_complete={stats['quest_completed_after']}"
                 f"  novel_vocab={stats['quest_novel_vocab']}")
    lines.append(f"  Accept rate: {stats['quest_accept_rate']:.0%}"
                 f"  Instant complete rate: {stats['quest_instant_complete_rate']:.0%}"
                 f"  Avg reward: {stats['avg_reward']:+.1f}")

    # Reward by action (sorted)
    rba = stats.get("avg_reward_by_action", {})
    if rba:
        sorted_rba = sorted(rba.items(), key=lambda x: x[1], reverse=True)
        reward_parts = [f"{a[:5]}={r:+.1f}" for a, r in sorted_rba[:5]]
        lines.append(f"  Avg reward/action: {', '.join(reward_parts)}")

    # Loop sequences
    seqs = stats.get("loop_sequences", [])
    if seqs:
        seq_strs = [f"L{n}:{s}" for n, s in seqs]
        lines.append(f"  First loops: {' | '.join(seq_strs)}")

    return "\n".join(lines)


def format_mutations(mutations: List[Dict[str, Any]]) -> str:
    if not mutations:
        return "  (no mutations)"
    lines = []
    for m in mutations:
        arrow = "\u2191" if m["to_idx"] > m["from_idx"] else "\u2193"
        lines.append(
            f"  {arrow} {m['knob']:42s}  {m['from_val']:4d} \u2192 {m['to_val']:4d}  "
            f"({m['action']}, excess={m['excess']:+.3f})"
        )
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Adversarial milk hunt loop with Fibonacci mutations")
    parser.add_argument("--profile", type=str, default="granary_scout", help="World state profile")
    parser.add_argument("--policy", type=str, default="quantum_register", help="Hunter policy mode")
    parser.add_argument("--cycles", type=int, default=10, help="Number of hunt+mutate cycles")
    parser.add_argument("--max-loops", type=int, default=100, help="Max loops per hunt")
    parser.add_argument("--max-mutations", type=int, default=5, help="Max knob mutations per cycle")
    parser.add_argument("--ledger", type=Path, default=None, help="Berry ledger path")
    parser.add_argument("--state", type=Path, default=None, help="Adversary state file")
    parser.add_argument("--patch-out", type=Path, default=None, help="FarmVariableGraph patch file")
    parser.add_argument("--reset-adversary", action="store_true", help="Reset adversary to defaults before starting")
    args = parser.parse_args()

    ledger = args.ledger or default_ledger_path()
    state_path = args.state or default_state_path()
    patch_out = args.patch_out or default_patch_path()

    adv = FibonacciAdversary()
    if args.reset_adversary:
        print("[adversarial] Reset adversary to defaults")
    elif not adv.load_state_file(state_path):
        adv.load_from_ledger(ledger)

    print(f"[adversarial] Profile: {args.profile}  Policy: {args.policy}")
    print(f"[adversarial] Cycles: {args.cycles}  Max loops/hunt: {args.max_loops}")
    print(f"[adversarial] Starting cycle: {adv.cycle}  Knobs: {len(adv.knobs)}")
    print(f"[adversarial] Ledger: {ledger}")
    print()

    results: List[Dict[str, Any]] = []
    victories = 0

    for cycle_i in range(args.cycles):
        cycle_num = adv.cycle + 1
        print(f"{'='*60}")
        print(f"[cycle {cycle_num}] Running milk hunt...")

        # Write current patch before hunt
        adv.write_patch_file(patch_out)

        # Run hunt
        t0 = time.time()
        summary = run_milk_hunt(
            policy=args.policy,
            profile=args.profile,
            max_loops=args.max_loops,
        )
        elapsed = time.time() - t0

        if summary is None:
            print(f"[cycle {cycle_num}] Hunt failed (timeout or crash) after {elapsed:.1f}s")
            # Write a block with empty distribution
            empty_dist = {a: 0.0 for a in FibonacciAdversary().knobs}
            continue

        # Extract results
        found_milk = summary.get("found_milk", False)
        loops = summary.get("loops_completed", "?")
        pairs = summary.get("known_pairs_count", 0)
        action_pct = summary.get("policy_action_pct", {})

        if found_milk:
            victories += 1

        milk_str = "MILK!" if found_milk else "no milk"
        quest_pct = action_pct.get("quest_cycle", 0) * 100
        print(f"[cycle {cycle_num}] {milk_str}  loops={loops}  pairs={pairs}  quest={quest_pct:.0f}%  ({elapsed:.1f}s)")

        # Step-level stats
        step_stats = extract_step_stats(summary)
        if step_stats:
            print(format_step_stats(step_stats))

        # Compute mutations
        mutations = adv.mutate(action_pct, max_mutations=args.max_mutations)

        # Write berry block
        extra = {
            "found_milk": found_milk,
            "loops_completed": loops,
            "known_pairs_count": pairs,
            "profile": args.profile,
            "policy": args.policy,
            "elapsed_s": round(elapsed, 1),
        }
        block = adv.write_berry_block(action_pct, mutations, extra_observed=extra, ledger_path=ledger)
        kl = block["divergence"]["kl_from_golden"]

        print(f"[cycle {cycle_num}] KL={kl:.4f}  mutations={len(mutations)}")
        print(format_mutations(mutations))

        # Save state
        adv.save_state(state_path)

        results.append({
            "cycle": cycle_num,
            "found_milk": found_milk,
            "loops": loops,
            "pairs": pairs,
            "quest_pct": round(quest_pct, 1),
            "kl": round(kl, 4),
            "mutations": len(mutations),
            "elapsed_s": round(elapsed, 1),
            "accept_rate": step_stats.get("quest_accept_rate", 0),
            "instant_complete": step_stats.get("quest_instant_complete_rate", 0),
            "avg_reward": step_stats.get("avg_reward", 0),
        })
        print()

    # Summary
    print(f"{'='*60}")
    print(f"[adversarial] SUMMARY: {args.cycles} cycles, {victories} victories")
    print()
    print(f"{'Cycle':>6s} {'Milk':>6s} {'Loops':>6s} {'Pairs':>6s} {'Quest%':>7s} {'KL':>8s} {'Muts':>5s} {'Accept':>7s} {'InstCmp':>8s} {'AvgRwd':>7s} {'Time':>6s}")
    print("-" * 80)
    for r in results:
        milk_s = "YES" if r["found_milk"] else "no"
        print(f"{r['cycle']:>6d} {milk_s:>6s} {r['loops']:>6} {r['pairs']:>6d} {r['quest_pct']:>6.1f}% {r['kl']:>8.4f} {r['mutations']:>5d} {r['accept_rate']:>6.0%} {r['instant_complete']:>7.0%} {r['avg_reward']:>+6.1f} {r['elapsed_s']:>5.1f}s")

    # Show final knob deltas
    defaults = FibonacciAdversary()
    changed = []
    for path in adv.knobs:
        if adv.knobs[path]["fib_index"] != defaults.knobs[path]["fib_index"]:
            from fibonacci_adversary import fib_value
            changed.append((path, defaults.knobs[path]["fib_index"], adv.knobs[path]["fib_index"]))

    if changed:
        print()
        print("Knobs changed from default:")
        for path, old_idx, new_idx in changed:
            from fibonacci_adversary import fib_value as fv
            print(f"  {path:50s}  fib[{old_idx}]={fv(old_idx):4d} \u2192 fib[{new_idx}]={fv(new_idx):4d}")


if __name__ == "__main__":
    main()
