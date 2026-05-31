#!/usr/bin/env python3
"""batch_stats_yaml.py — SpaceWheat batch run reporter.

Reads a fib_milk_hunt run directory (or the latest one) and emits a
structured YAML readout of runner performance.  Designed for both human
review and LLM ingestion in future multi-agent competition contexts.

Usage:
    python3 batch_stats_yaml.py                          # latest run
    python3 batch_stats_yaml.py /tmp/fib_milk_hunt/run_XXXXXXXX_XXXXXX/
    python3 batch_stats_yaml.py --saves-only             # no report json needed
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import textwrap
from collections import Counter
from pathlib import Path
from typing import Any, Dict, List, Optional

OUTPUT_ROOT = Path("/tmp/fib_milk_hunt")
SAVE_DIR = OUTPUT_ROOT / "saves"

# ── Resource taxonomy for archetype detection ──────────────────────────────
_RESOURCE_TAXA: Dict[str, List[str]] = {
    "elemental": ["☀", "💧", "🔥", "🌬", "🌙", "⛰", "❄️", "⚡", "🌋", "💨", "🌊"],
    "nature":    ["🌱", "🌲", "🌿", "🍄", "🐝", "🌾", "🌹", "🍂", "🌫", "🦠", "🦋"],
    "social":    ["🏰", "⚜", "♟", "🕰", "👥", "📋", "🏛", "⚖", "🗃", "🛡"],
    "arcane":    ["📜", "🦅", "🩸", "🖋", "🔓", "✨", "🌌", "🕵️", "🔮", "🧿"],
    "material":  ["⛓", "⚔", "🔥", "💎", "💰", "💸", "🚩", "🛶", "🧊", "🧂"],
    "industrial":["⚙", "🏭", "⚱", "📿", "🤖", "🛸", "🕳", "📋", "🗃", "⛏"],
    "celestial": ["🌠", "🌌", "🛰", "🌐", "🔭", "🌀", "💫", "✨", "🌑"],
}

# ── Milk-adjacent emojis (heuristic proximity to 🍼) ───────────────────────
# These appear in known icons near the milk faction (Reality Midwives)
MILK_ADJACENT = {"🤲", "✨", "💫", "🌠", "🌌", "💃", "🎭", "🛰", "🗺", "🔭"}


# ═══════════════════════════════════════════════════════════════════════════
#  PARSING HELPERS
# ═══════════════════════════════════════════════════════════════════════════

def _find_latest_run() -> Optional[Path]:
    runs = sorted(OUTPUT_ROOT.glob("run_*"), reverse=True)
    return runs[0] if runs else None


def _load_report(run_dir: Path) -> Optional[Dict]:
    p = run_dir / "fib_hunt_report.json"
    if p.exists():
        return json.loads(p.read_text(encoding="utf-8"))
    return None


def _parse_save(path: Path) -> Dict[str, Any]:
    """Extract everything we care about from a .tres GameState save."""
    text = path.read_text(encoding="utf-8")
    out: Dict[str, Any] = {}

    # ── Unlocked biomes ────────────────────────────────────────────────────
    m = re.search(r'unlocked_biomes\s*=\s*Array\[String\]\(\[(.*?)\]\)', text)
    if m:
        out["unlocked_biomes"] = re.findall(r'"([^"]+)"', m.group(1))
    else:
        # Default seed biomes — field absent when never updated
        out["unlocked_biomes"] = ["StarterForest", "Village"]

    # Active biome name
    m2 = re.search(r'active_biome_name\s*=\s*"([^"]+)"', text)
    out["active_biome"] = m2.group(1) if m2 else "Village"

    # ── Known icons ────────────────────────────────────────────────────────
    kp_match = re.search(r'known_icons = \[(.*?)\](?=\n[a-z_])', text, re.DOTALL)
    icons: List[Dict[str, str]] = []
    if kp_match:
        norths = re.findall(r'"north":\s*"([^"]+)"', kp_match.group(1))
        souths = re.findall(r'"south":\s*"([^"]+)"', kp_match.group(1))
        icons = [{"north": n, "south": s} for n, s in zip(norths, souths)]
    out["known_icons"] = icons
    out["icons_count"] = len(icons)
    out["has_milk_pair"] = any(
        p.get("north") == "🍼" or p.get("south") == "🍼" for p in icons
    )
    # Milk-adjacent icons (icons containing emojis near Reality Midwives)
    milk_adj_icons = [
        p for p in icons
        if p.get("north") in MILK_ADJACENT or p.get("south") in MILK_ADJACENT
    ]
    out["milk_adjacent_icons"] = len(milk_adj_icons)

    # ── Resource portfolio ─────────────────────────────────────────────────
    cred_m = re.search(r'all_emoji_credits\s*=\s*\{(.*?)\}', text, re.DOTALL)
    credits: Dict[str, float] = {}
    if cred_m:
        for emoji, val in re.findall(r'"([^"]+)":\s*([\d.]+)', cred_m.group(1)):
            v = float(val)
            if v > 0:
                credits[emoji] = v
    out["resources"] = credits

    # ── Action counts from policy history ──────────────────────────────────
    action_counts: Dict[str, int] = Counter(
        re.findall(r'"action":\s*"([^"]+)"', text)
    )
    out["action_counts"] = dict(action_counts)

    # ── Lindblad drain registers ───────────────────────────────────────────
    out["drain_active_count"] = len(re.findall(r'"lindblad_drain_active":\s*true', text))
    out["drain_total_registers"] = len(re.findall(r'"lindblad_drain_active":', text))

    # ── Biome states count ─────────────────────────────────────────────────
    biome_state_m = text.find('biome_states = {')
    if biome_state_m >= 0:
        section = text[biome_state_m: biome_state_m + 6000]
        biome_keys = re.findall(r'^\s*"([A-Z][a-zA-Z]+)"\s*:', section, re.MULTILINE)
        out["loaded_biomes"] = biome_keys
    else:
        out["loaded_biomes"] = []

    return out


# ═══════════════════════════════════════════════════════════════════════════
#  ANALYSIS HELPERS
# ═══════════════════════════════════════════════════════════════════════════

def _archetype(resources: Dict[str, float]) -> str:
    """Classify resource portfolio into a named archetype."""
    top = {e for e, _ in sorted(resources.items(), key=lambda x: -x[1])[:15]}
    scores: Dict[str, int] = {t: 0 for t in _RESOURCE_TAXA}
    for taxon, emojis in _RESOURCE_TAXA.items():
        scores[taxon] = sum(1 for e in emojis if e in top)
    best = max(scores, key=lambda k: scores[k])
    second = sorted(scores, key=lambda k: -scores[k])[1]
    if scores[best] <= 1:
        return "generalist"
    if scores[second] >= scores[best] - 1:
        return f"{best}_{second}"
    return best


def _strategy_signature(ac: Dict[str, int]) -> str:
    total = sum(ac.values())
    if total == 0:
        return "inactive"
    quest_frac = ac.get("quest_cycle", 0) / total
    discovers = ac.get("discover_biome", 0)
    drains = ac.get("lindblad_drain", 0)
    probes = ac.get("probe_cycle", 0)
    if quest_frac > 0.90 and discovers == 0:
        return "pure_quest_chain"
    if discovers >= 3:
        return "explorer_quest" if quest_frac > 0.5 else "explorer_focused"
    if drains >= 5:
        return "lindblad_architect"
    if probes >= 10:
        return "probe_harvester"
    if quest_frac > 0.80:
        return "quest_dominant"
    return "balanced"


def _flags(save: Dict, report_char: Optional[Dict]) -> List[str]:
    flags = []
    ac = save.get("action_counts", {})
    discovers = ac.get("discover_biome", 0)
    drains = ac.get("lindblad_drain", 0)
    probes = ac.get("probe_cycle", 0)
    icons = save.get("icons_count", 0)
    milk = save.get("has_milk_pair", False)

    if discovers == 0:
        flags.append("no_biome_discovery")
    if drains == 0:
        flags.append("no_lindblad_drains")
    if probes == 0:
        flags.append("no_probe_cycles")
    if icons >= 80 and not milk:
        flags.append("high_pairs_no_milk")
    if icons >= 60 and not milk and discovers == 0:
        flags.append("possible_vocab_deadend")
    if save.get("milk_adjacent_icons", 0) > 0 and not milk:
        flags.append("milk_adjacent_but_not_found")
    if milk:
        flags.append("milk_achieved")
    return flags


def _resource_summary(resources: Dict[str, float], top_n: int = 8) -> Dict:
    if not resources:
        return {"portfolio_size": 0, "top": {}, "archetype": "empty"}
    top = sorted(resources.items(), key=lambda x: -x[1])[:top_n]
    return {
        "portfolio_size": len(resources),
        "archetype": _archetype(resources),
        "top": {e: int(v) for e, v in top},
        "dominant_emoji": top[0][0],
        "dominant_amount": int(top[0][1]),
    }


def _milk_path_summary(save: Dict) -> Dict:
    icons = save.get("known_icons", [])
    milk = save.get("has_milk_pair", False)
    milk_adj = save.get("milk_adjacent_icons", 0)
    total = save.get("icons_count", 0)

    comment = ""
    if milk:
        comment = "Milk pair (🍼/🤲) present in known vocabulary."
    elif milk_adj > 0:
        comment = (
            f"{milk_adj} milk-adjacent icons learned — close to Reality Midwives "
            "faction but did not complete the milk pair quest."
        )
    elif total >= 60:
        comment = (
            f"{total} icons but no milk-adjacent vocabulary — "
            "policy may not be routing through 🍼-path factions."
        )
    else:
        comment = "Insufficient icons to reach milk faction territory."

    return {
        "reached": milk,
        "icons_total": total,
        "milk_adjacent_icons": milk_adj,
        "comment": comment,
    }


# ═══════════════════════════════════════════════════════════════════════════
#  YAML EMITTER
# Writes hand-crafted YAML with inline comments — no external dependency.
# ═══════════════════════════════════════════════════════════════════════════

def _q(s: str) -> str:
    """Quote a string value for YAML (single-quotes)."""
    return f"'{s}'"


def _emit(lines: List[str], indent: int, text: str, comment: str = "") -> None:
    prefix = "  " * indent
    if comment:
        lines.append(f"{prefix}{text}  # {comment}")
    else:
        lines.append(f"{prefix}{text}")


def _emit_comment(lines: List[str], indent: int, text: str) -> None:
    prefix = "  " * indent
    lines.append(f"{prefix}# {text}")


def _emit_blank(lines: List[str]) -> None:
    lines.append("")


def _list_inline(items: List[str]) -> str:
    if not items:
        return "[]"
    quoted = ", ".join(f"'{x}'" for x in items)
    return f"[{quoted}]"


def _dict_inline(d: Dict) -> str:
    if not d:
        return "{}"
    parts = [f"'{k}': {v}" for k, v in d.items()]
    return "{" + ", ".join(parts) + "}"


def generate_yaml(
    report: Optional[Dict],
    saves: Dict[str, Dict],
    run_dir: Optional[Path],
) -> str:
    lines: List[str] = []

    # ── File header ─────────────────────────────────────────────────────
    lines.append("# ═══════════════════════════════════════════════════════════════════")
    lines.append("# SpaceWheat — Fibonacci Milk Hunt Batch Report")
    lines.append("# ═══════════════════════════════════════════════════════════════════")
    lines.append("#")
    lines.append("# PURPOSE")
    lines.append("#   Documents a batch run of AI policy runners competing to find the")
    lines.append("#   milk vocabulary pair (🍼/🤲).  Intended for human review and LLM")
    lines.append("#   ingestion when designing new characters, policies, or comparing")
    lines.append("#   strategies across runs.")
    lines.append("#")
    lines.append("# GAME MECHANICS PRIMER")
    lines.append("#   - runners learn emoji vocabulary PAIRS through faction quests")
    lines.append("#   - 🍼 (milk) is the terminal goal pair — hidden in the Reality")
    lines.append("#     Midwives faction, reachable only through a webway of faction")
    lines.append("#     co-memberships (the 'milk graph')")
    lines.append("#   - actions: quest_cycle (learn vocab), probe_cycle (harvest"),
    lines.append("#     resources), lindblad_drain (stabilise biome quantum state),")
    lines.append("#     discover_biome (unlock new biome), time_skip, quest_cycle")
    lines.append("#   - policy: quantum_register — 3-qubit density matrix over 8")
    lines.append("#     actions; Hamiltonian = economy pressure, Lindblad = reward")
    lines.append("# ═══════════════════════════════════════════════════════════════════")
    _emit_blank(lines)

    # ── Batch section ────────────────────────────────────────────────────
    _emit(lines, 0, "batch:")
    if report:
        ts = report.get("timestamp", "unknown")
        run_id = run_dir.name if run_dir else "unknown"
        _emit(lines, 1, f"run_id: {_q(run_id)}")
        _emit(lines, 1, f"timestamp: {_q(ts)}")
        _emit(lines, 1, f"policy_type: {_q(report.get('policy', 'unknown'))}")
        sched = report.get("fib_schedule", [])
        _emit(lines, 1, f"schedule: {sched}",
              "loops per round — Fibonacci escalation")
        target = report.get("milk_target", "?")
        n_chars = len(report.get("characters", {}))
        _emit(lines, 1, f"target: {_q(f'{target}/{n_chars} characters find milk pair')}")
        milk_count = report.get("milk_count", 0)
        achieved = report.get("target_achieved", False)
        result_str = "ACHIEVED" if achieved else "NOT_REACHED"
        _emit(lines, 1, f"result: {result_str}")
        _emit(lines, 1, f"milk_found_count: {milk_count}")
        _emit(lines, 1, f"characters_count: {n_chars}")
        _emit(lines, 1, f"total_wall_time_s: {report.get('total_elapsed_s', '?')}")
    else:
        _emit(lines, 1, "run_id: 'unknown'")
        _emit(lines, 1, "note: 'no report JSON found — save-only mode'")
    _emit_blank(lines)

    # ── Per-character section ────────────────────────────────────────────
    _emit(lines, 0, "characters:")
    _emit_blank(lines)

    char_names = list(saves.keys())
    for char_name in char_names:
        save = saves[char_name]
        report_char = (report or {}).get("characters", {}).get(char_name)

        ac = save.get("action_counts", {})
        total_actions = sum(ac.values())
        biomes = save.get("unlocked_biomes", [])
        resources = save.get("resources", {})
        res_summary = _resource_summary(resources)
        milk_summary = _milk_path_summary(save)
        flags = _flags(save, report_char)
        strategy = _strategy_signature(ac)
        archetype = res_summary.get("archetype", "unknown")

        # Outcome numbers
        if report_char:
            loops_total = report_char.get("cumulative_loops", 0)
            time_total = report_char.get("cumulative_time_s", 0)
            milk_found = report_char.get("found_milk", False)
        else:
            loops_total = "?"
            time_total = "?"
            milk_found = save.get("has_milk_pair", False)

        # Discovery count = biomes beyond the default 2 (StarterForest, Village)
        default_biomes = {"StarterForest", "Village"}
        discovered_new = [b for b in biomes if b not in default_biomes]

        _emit(lines, 1, f"{char_name}:")
        _emit_blank(lines)
        _emit_comment(lines, 2, "─── IDENTITY ───────────────────────────────────────────")
        _emit(lines, 2, f"archetype: {_q(archetype)}",
              "derived from resource portfolio taxonomy")
        _emit(lines, 2, f"strategy_signature: {_q(strategy)}",
              "derived from action mix ratios")
        if flags:
            _emit(lines, 2, f"flags: {_list_inline(flags)}",
                  "anomalies and notable conditions")
        _emit_blank(lines)

        _emit_comment(lines, 2, "─── OUTCOME ────────────────────────────────────────────")
        _emit(lines, 2, f"milk_found: {'true' if milk_found else 'false'}")
        _emit(lines, 2, f"total_loops: {loops_total}")
        _emit(lines, 2, f"icons_learned: {save.get('icons_count', '?')}")
        _emit(lines, 2, f"total_time_s: {time_total}")
        _emit_blank(lines)

        _emit_comment(lines, 2, "─── EXPLORATION ────────────────────────────────────────")
        _emit(lines, 2, f"biomes_discovered_total: {len(biomes)}",
              "includes initial starter biomes")
        _emit(lines, 2, f"biomes_newly_unlocked: {len(discovered_new)}",
              "beyond StarterForest + Village")
        if biomes:
            _emit(lines, 2, f"biome_list: {_list_inline(biomes)}")
        _emit(lines, 2, f"active_biome_at_save: {_q(save.get('active_biome', '?'))}")
        loaded = save.get("loaded_biomes", [])
        if loaded:
            _emit(lines, 2, f"biomes_loaded_in_memory: {_list_inline(loaded)}")
        _emit_blank(lines)

        _emit_comment(lines, 2, "─── ACTION BREAKDOWN ───────────────────────────────────")
        _emit_comment(lines, 2, "counts include all logged actions in policy history")
        _emit(lines, 2, "action_counts:")
        action_keys = [
            "quest_cycle", "probe_cycle", "lindblad_drain",
            "discover_biome", "quest_cycle", "time_skip",
            "victory_lap_partial", "lindblad_drain",
        ]
        for ak in action_keys:
            v = ac.get(ak, 0)
            if v > 0 or ak in ("quest_cycle", "probe_cycle", "lindblad_drain", "discover_biome"):
                pct = f"{100*v/total_actions:.0f}%" if total_actions > 0 else "—"
                _emit(lines, 3, f"{ak}: {v}", pct)
        _emit(lines, 3, f"total_logged: {total_actions}")
        _emit_blank(lines)

        _emit_comment(lines, 2, "─── LINDBLAD DRAINS ────────────────────────────────────")
        drain_placed = ac.get("lindblad_drain", 0)
        drain_active = save.get("drain_active_count", 0)
        total_regs = save.get("drain_total_registers", 0)
        _emit(lines, 2, "lindblad:")
        _emit(lines, 3, f"actions_placed: {drain_placed}",
              "times lindblad_drain was executed")
        _emit(lines, 3, f"active_at_save: {drain_active}",
              "registers with active drain at time of save")
        _emit(lines, 3, f"total_registers_tracked: {total_regs}")
        if drain_placed == 0:
            _emit(lines, 3, "comment: 'no drains placed this run — policy chose quest-only path'")
        elif drain_active == 0 and drain_placed > 0:
            _emit(lines, 3, "comment: 'drains placed but expired before save — transient use'")
        else:
            _emit(lines, 3, f"comment: '{drain_placed} drains placed, {drain_active} persisted to save'")
        _emit_blank(lines)

        _emit_comment(lines, 2, "─── RESOURCE PORTFOLIO ─────────────────────────────────")
        _emit_comment(lines, 2, "all_emoji_credits: cumulative resource income across entire run")
        _emit(lines, 2, "resources:")
        _emit(lines, 3, f"portfolio_size: {res_summary['portfolio_size']}",
              "distinct emoji types with non-zero balance")
        _emit(lines, 3, f"archetype: {_q(res_summary.get('archetype', 'unknown'))}",
              "dominant resource taxonomy cluster")
        if res_summary.get("top"):
            _emit(lines, 3, f"dominant_resource: {_q(res_summary.get('dominant_emoji','?'))}",
                  f"top earner at {res_summary.get('dominant_amount','?')} credits")
            _emit(lines, 3, f"top_resources: {_dict_inline(res_summary['top'])}")
        _emit_blank(lines)

        _emit_comment(lines, 2, "─── MILK PATH ANALYSIS ─────────────────────────────────")
        _emit(lines, 2, "milk_path:")
        _emit(lines, 3, f"reached: {'true' if milk_summary['reached'] else 'false'}")
        _emit(lines, 3, f"pairs_total: {milk_summary['pairs_total']}")
        _emit(lines, 3, f"milk_adjacent_icons: {milk_summary['milk_adjacent_icons']}",
              "icons containing emojis near Reality Midwives faction")
        _emit(lines, 3, f"comment: {_q(milk_summary['comment'])}")
        _emit_blank(lines)

    # ── Comparative analysis section ─────────────────────────────────────
    _emit(lines, 0, "comparative_analysis:")
    _emit_comment(lines, 1, "Cross-runner patterns and strategic notes for future runs")
    _emit_blank(lines)

    if saves:
        # Explorers vs stay-at-home
        explorers = [n for n, s in saves.items()
                     if s.get("action_counts", {}).get("discover_biome", 0) >= 1]
        homebodies = [n for n in saves if n not in explorers]
        _emit(lines, 1, f"biome_explorers: {_list_inline(explorers)}",
              "ran discover_biome ≥1 time")
        _emit(lines, 1, f"biome_homebodies: {_list_inline(homebodies)}",
              "never triggered discover_biome")
        _emit_blank(lines)

        # Drain users
        drain_users = [n for n, s in saves.items()
                       if s.get("action_counts", {}).get("lindblad_drain", 0) >= 1]
        _emit(lines, 1, f"lindblad_users: {_list_inline(drain_users)}",
              "placed ≥1 Lindblad drain")
        _emit_blank(lines)

        # Milk finders
        milk_finders = [n for n, s in saves.items() if s.get("has_milk_pair")]
        holdouts = [n for n in saves if n not in milk_finders]
        _emit(lines, 1, f"milk_finders: {_list_inline(milk_finders)}")
        _emit(lines, 1, f"holdouts: {_list_inline(holdouts)}")
        _emit_blank(lines)

        # Pair counts
        _emit(lines, 1, "icons_leaderboard:")
        sorted_by_icons = sorted(saves.items(), key=lambda x: -x[1].get("icons_count", 0))
        for n, s in sorted_by_icons:
            milk_tag = " (milk✓)" if s.get("has_milk_pair") else ""
            _emit(lines, 2, f"{n}: {s.get('icons_count', '?')}{milk_tag}")
        _emit_blank(lines)

        # Strategic insights
        _emit(lines, 1, "strategic_insights:")
        insights = _derive_insights(saves, report)
        for insight in insights:
            # Emit as YAML block scalar: "- >" folded string, indented continuation
            wrapped = textwrap.wrap(insight, width=68)
            for i, line in enumerate(wrapped):
                prefix = "- " if i == 0 else "  "
                _emit(lines, 2, f"{prefix}{line}")
        _emit_blank(lines)

    # ── Footer ────────────────────────────────────────────────────────────
    lines.append("# ═══════════════════════════════════════════════════════════════════")
    lines.append("# END OF BATCH REPORT")
    lines.append("# ═══════════════════════════════════════════════════════════════════")

    return "\n".join(lines)


def _derive_insights(saves: Dict[str, Dict], report: Optional[Dict]) -> List[str]:
    insights = []

    # Biome exploration
    explorers = [(n, s) for n, s in saves.items()
                 if s.get("action_counts", {}).get("discover_biome", 0) >= 1]
    homebodies = [(n, s) for n, s in saves.items()
                  if s.get("action_counts", {}).get("discover_biome", 0) == 0]
    if len(homebodies) >= 3:
        names = [n for n, _ in homebodies]
        insights.append(
            f"{len(homebodies)}/5 runners never ran discover_biome "
            f"({', '.join(names)}). Policy may be systematically "
            "underweighting exploration — consider raising discover_biome base prior."
        )
    for n, s in explorers:
        nb = len([b for b in s.get("unlocked_biomes", [])
                  if b not in {"StarterForest", "Village"}])
        insights.append(
            f"{n} is the standout explorer: {nb} new biomes unlocked. "
            "Active biome diversity correlates with faster faction graph coverage."
        )

    # Holdouts
    holdouts = [(n, s) for n, s in saves.items() if not s.get("has_milk_pair")]
    for n, s in holdouts:
        icons = s.get("icons_count", 0)
        milkadj = s.get("milk_adjacent_icons", 0)
        ac = s.get("action_counts", {})
        discovers = ac.get("discover_biome", 0)
        if icons >= 80 and discovers == 0:
            insights.append(
                f"{n} accumulated {icons} icons with 0 biome discoveries and "
                "still has no milk — classic vocabulary dead-end signature. "
                "StarterForest + Village alone may not connect to Reality Midwives."
            )
        elif milkadj > 0:
            insights.append(
                f"{n} has {milkadj} milk-adjacent icons but never closed the "
                "🍼/🤲 pairing — likely needs one more targeted faction quest."
            )

    # Milk finders
    milk_finders = [(n, s) for n, s in saves.items() if s.get("has_milk_pair")]
    fast = [(n, s) for n, s in milk_finders
            if (report or {}).get("characters", {}).get(n, {}).get("cumulative_loops", 99) <= 2]
    if fast:
        names = [n for n, _ in fast]
        insights.append(
            f"{', '.join(names)} found milk in ≤2 loops — suggests the milk pair "
            "was already reachable in their save state going into this round. "
            "The broken milk detection in prior runs delayed the stop condition."
        )

    # Quest dominance
    quest_heavy = [(n, s) for n, s in saves.items()
                   if s.get("action_counts", {}).get("quest_cycle", 0) /
                   max(sum(s.get("action_counts", {}).values()), 1) > 0.88]
    if len(quest_heavy) == len(saves):
        insights.append(
            "All 5 runners are quest_cycle dominant (>88% of actions). "
            "Probe, drain, and discover actions are underutilised. "
            "The quantum register Hamiltonian heavily favours quest_cycle — "
            "consider reducing its base prior or adding action diversity pressure."
        )

    # Drain usage
    drain_users = [n for n, s in saves.items()
                   if s.get("action_counts", {}).get("lindblad_drain", 0) >= 1]
    if len(drain_users) <= 2:
        insights.append(
            f"Only {len(drain_users)}/5 runners used Lindblad drains, "
            "and all drains had expired by save time. Drains appear "
            "underweighted in the policy — their resource-stabilisation "
            "benefit may not be reaching the reward signal."
        )

    return insights


# ═══════════════════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════════════════

def main() -> int:
    parser = argparse.ArgumentParser(description="SpaceWheat batch YAML reporter")
    parser.add_argument(
        "run_dir", nargs="?", type=Path,
        help="Path to run directory (default: latest)"
    )
    parser.add_argument(
        "--saves-dir", type=Path, default=SAVE_DIR,
        help=f"Save file directory (default: {SAVE_DIR})"
    )
    parser.add_argument(
        "--output", "-o", type=Path, default=None,
        help="Write YAML to file instead of stdout"
    )
    args = parser.parse_args()

    # Resolve run directory
    run_dir: Optional[Path] = args.run_dir
    if run_dir is None:
        run_dir = _find_latest_run()
        if run_dir:
            print(f"# Using latest run: {run_dir.name}", file=sys.stderr)

    report = _load_report(run_dir) if run_dir else None
    if report is None and run_dir:
        print(f"# Warning: no report JSON found in {run_dir}", file=sys.stderr)

    # Determine which characters to report
    saves_dir: Path = args.saves_dir
    if not saves_dir.exists():
        print(f"Error: saves directory not found: {saves_dir}", file=sys.stderr)
        return 1

    save_files = sorted(saves_dir.glob("*.tres"))
    if not save_files:
        print(f"Error: no .tres save files found in {saves_dir}", file=sys.stderr)
        return 1

    # If report has character ordering, preserve it
    char_order: List[str] = []
    if report:
        char_order = list(report.get("characters", {}).keys())
    if not char_order:
        char_order = [f.stem for f in save_files]

    saves: Dict[str, Dict] = {}
    for name in char_order:
        path = saves_dir / f"{name}.tres"
        if path.exists():
            saves[name] = _parse_save(path)
        else:
            # Try any matching save file
            matches = list(saves_dir.glob(f"*{name}*.tres"))
            if matches:
                saves[name] = _parse_save(matches[0])
    # Include any saves not in the report order
    for f in save_files:
        if f.stem not in saves:
            saves[f.stem] = _parse_save(f)

    yaml_text = generate_yaml(report, saves, run_dir)

    if args.output:
        args.output.write_text(yaml_text + "\n", encoding="utf-8")
        print(f"Report written to {args.output}", file=sys.stderr)
    else:
        print(yaml_text)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
