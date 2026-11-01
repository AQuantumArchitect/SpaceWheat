#!/usr/bin/env python3
"""Compile a spine walk from quest/flag fields.

The answer is a function of auto_accept / auto_claim, state_predicates,
reward pair, and PredicateGloss TARGETS — not of a second authored walk
table and not of hint prose.

  from spine_recipe import compile_flag, live_recipe, gold_off_spine
"""
from __future__ import annotations

import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FLAGS = ROOT / "Core" / "Quests" / "data" / "story_flags.json"
TUTORIAL = ROOT / "Core" / "Quests" / "data" / "tutorial_arc.json"
GLOSS = ROOT / "Core" / "Quests" / "PredicateGloss.gd"
TOOLCONFIG = ROOT / "Core" / "GameState" / "ToolConfig.gd"

BOOT_BIOMES = ("TheDemos", "Village", "StarterForest")
UNSIGNED_KEYS = ("X", "Y", "R", "G")
MARKET_KEYS = ("C", "Y", "U", "R", "G")
ACE_KEYS = ("8", "Q", "R", "F")
PLOT_KEYS = ("G", "H", "J", "K", "L", ";")
DISCOVER_KEYS = ("7", "R")
# Dump fails gold_off_spine only on this band until mill consumes the compiler.
STRICT_IDS = frozenset({
    "arc_handover", "village_stirs", "new_voices", "woodlot_door",
    "woodlot_wakes", "lumber_flows", "spring_door", "mill_wakes",
    "timber_rhythm",
})
HAT_FRAME_TO_KEY = {
    "spark": "4", "icon": "5", "merchant": "6", "captain": "7",
    "ace": "8", "operator": "9", "druid": "0",
}


def _load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_flags() -> list[dict]:
    raw = _load_json(FLAGS)
    return raw if isinstance(raw, list) else []


def load_tutorial() -> list[dict]:
    raw = _load_json(TUTORIAL)
    return list(raw.get("steps") or [])


def _block(src: str, const_name: str) -> str:
    m = re.search(r"const %s\s*:?=\s*\{" % const_name, src)
    if not m:
        return ""
    i = m.end() - 1
    depth = 0
    for j, ch in enumerate(src[i:], i):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return src[i : j + 1]
    return ""


def load_targets() -> dict[str, dict]:
    src = GLOSS.read_text(encoding="utf-8")
    body = _block(src, "TARGETS")
    out: dict[str, dict] = {}
    for m in re.finditer(
        r'"([a-z0-9_]+)"\s*:\s*\{([^}]*)\}',
        body,
    ):
        spec = {}
        for km in re.finditer(r'"(\w+)"\s*:\s*"([^"]*)"', m.group(2)):
            spec[km.group(1)] = km.group(2)
        out[m.group(1)] = spec
    return out


def load_gate_frames() -> dict[str, str]:
    src = GLOSS.read_text(encoding="utf-8")
    body = _block(src, "GATE_FRAMES")
    return dict(re.findall(r'"([a-z0-9_]+)"\s*:\s*"([a-z]+)"', body))


TARGETS = load_targets()
GATE_FRAMES = load_gate_frames()


def prereq_ids(flag: dict) -> list[str]:
    return [
        str(p.get("id", ""))
        for p in (flag.get("predicates") or [])
        if isinstance(p, dict) and p.get("type") == "story_flag_set" and p.get("id")
    ]


def taught_pair(quest: dict) -> tuple[str, ...]:
    seen: list[str] = []
    for k in ("reward_north", "reward_south", "reward_icon_north", "reward_icon_south"):
        g = str(quest.get(k) or "").strip()
        if g and g not in seen:
            seen.append(g)
    return tuple(seen)


def is_delivery(quest: dict) -> bool:
    if str(quest.get("resource") or "").strip() and int(quest.get("quantity") or 0) > 0:
        return True
    t = quest.get("type")
    if isinstance(t, str) and t.upper() in ("DELIVERY", "DELIVER"):
        return bool(str(quest.get("resource") or "").strip())
    return False


def auto_accept_of(quest: dict) -> bool:
    if isinstance(quest.get("auto_accept"), bool):
        return bool(quest["auto_accept"])
    if is_delivery(quest):
        return False
    return str(quest.get("source") or "") == "tutorial" or str(quest.get("category") or "") == "TUTORIAL"


def auto_claim_of(quest: dict) -> bool:
    if isinstance(quest.get("auto_claim"), bool):
        return bool(quest["auto_claim"])
    if is_delivery(quest):
        return False
    preds = quest.get("state_predicates") or []
    if str(quest.get("category") or "") == "TUTORIAL":
        return isinstance(preds, list) and bool(preds)
    return False


def _kind_for_pred(pred: dict) -> str:
    t = str(pred.get("type") or "")
    if t == "standing_gte":
        return "standing"
    if t in ("atom_in_biome", "atom_count_gte"):
        return "plant"
    if t == "biome_evolving":
        b = str(pred.get("biome") or "")
        return "discover" if b and b not in BOOT_BIOMES else "travel"
    if t == "active_biome_is":
        return "travel"
    if t in ("gate_sequence_contains", "gate_order", "lesson_receipt"):
        return "gate"
    if t in ("berry_consumed_count_gte", "berry_total_phase_gte"):
        return "berry"
    if t in ("biome_state_gte", "biome_attractor_emoji_gte", "coherence_at_least"):
        return "steer"
    if t in ("story_flag_set", "story_flag_any"):
        return "parent"
    return t or "unknown"


def kind(quest: dict) -> str:
    if is_delivery(quest):
        return "delivery"
    preds = [p for p in (quest.get("state_predicates") or []) if isinstance(p, dict)]
    if not preds:
        return "handshake"
    kinds = []
    for p in preds:
        k = _kind_for_pred(p)
        if k not in kinds:
            kinds.append(k)
    if len(kinds) == 1:
        return kinds[0]
    return "mixed"


def _hat_key(frame: str) -> str:
    return HAT_FRAME_TO_KEY.get(frame, "")


def pred_keys(pred: dict, unlocked: tuple[str, ...] = BOOT_BIOMES) -> list[str]:
    t = str(pred.get("type") or "")
    keys: list[str] = []
    if t == "biome_evolving":
        b = str(pred.get("biome") or "")
        if b and b not in unlocked and b not in BOOT_BIOMES:
            keys.extend(DISCOVER_KEYS)
            keys.extend(ACE_KEYS)
            return _uniq(keys)
    spec = TARGETS.get(t) or {}
    knd = str(spec.get("kind") or "")
    if knd == "hat":
        hk = _hat_key(str(spec.get("frame") or ""))
        if hk:
            keys.append(hk)
    elif knd == "menu":
        mk = str(spec.get("key") or "")
        if mk:
            keys.append(mk.upper())
    elif knd == "gate":
        gname = str(pred.get("gate") or "").strip().lower()
        if not gname:
            gates = pred.get("gates") or []
            if gates:
                gname = str(gates[0]).strip().lower()
        frame = GATE_FRAMES.get(gname, "")
        hk = _hat_key(frame)
        if hk:
            keys.append(hk)
    if t in ("gate_sequence_contains", "lesson_receipt"):
        g = str(pred.get("gate") or "").lower()
        rec = str(pred.get("receipt") or "")
        if g in ("explore", "batch_explore"):
            keys.append("F")
        if g in ("measure", "bell_collapse") or rec == "superpose_warmth":
            keys.extend(("R", "Q"))
        if g == "pop":
            keys.append("Q")
        if g == "hadamard":
            keys.append("E")
        if g in ("explore", "measure", "pop", "reap", "batch_explore", "bell_collapse"):
            keys.extend(ACE_KEYS)
    if t in ("atom_in_biome", "atom_count_gte"):
        keys.extend(("5", "R"))
    if t == "standing_gte":
        keys.extend(MARKET_KEYS)
    if t in ("berry_consumed_count_gte", "berry_total_phase_gte"):
        keys.extend(("5", "F", "R"))
    if t in ("active_biome_is", "biome_state_gte", "biome_attractor_emoji_gte", "biome_evolving"):
        keys.extend(ACE_KEYS)
    return _uniq(keys)


def _uniq(keys: list[str]) -> list[str]:
    out: list[str] = []
    for k in keys:
        u = str(k).upper()
        if u and u not in out:
            out.append(u)
    return out


def allowed_keys(quest: dict, unlocked: tuple[str, ...] = BOOT_BIOMES) -> list[str]:
    keys: list[str] = []
    k = kind(quest)
    if is_delivery(quest) or k == "standing":
        keys.extend(MARKET_KEYS)
        keys.extend(ACE_KEYS)
        keys.extend(PLOT_KEYS)
    if not auto_accept_of(quest) and not is_delivery(quest):
        keys.extend(UNSIGNED_KEYS)
    if k == "handshake":
        keys.extend(UNSIGNED_KEYS)
    for p in quest.get("state_predicates") or []:
        if isinstance(p, dict):
            keys.extend(pred_keys(p, unlocked))
    return _uniq(keys)


def compile_quest(quest: dict, **ctx) -> dict:
    unlocked = tuple(ctx.get("unlocked_biomes") or BOOT_BIOMES)
    return {
        "kind": kind(quest),
        "auto_accept": auto_accept_of(quest),
        "auto_claim": auto_claim_of(quest),
        "pair": list(taught_pair(quest)),
        "keys": allowed_keys(quest, unlocked),
        "predicates": [
            str(p.get("type"))
            for p in (quest.get("state_predicates") or [])
            if isinstance(p, dict)
        ],
    }


def compile_flag(flag: dict, **ctx) -> dict:
    aq = flag.get("arc_quest") if isinstance(flag.get("arc_quest"), dict) else {}
    rec = compile_quest(aq or {}, **ctx)
    rec["id"] = str(flag.get("id") or "")
    rec["display_name"] = str(flag.get("display_name") or rec["id"])
    rec["act"] = int(flag.get("act") or 0)
    rec["parents"] = prereq_ids(flag)
    rec["teaches"] = list(taught_pair(aq or {}))
    if not aq:
        rec["kind"] = "flag_only"
        rec["keys"] = []
        for p in flag.get("predicates") or []:
            if isinstance(p, dict) and p.get("type") != "story_flag_set":
                rec["keys"].extend(pred_keys(p, tuple(ctx.get("unlocked_biomes") or BOOT_BIOMES)))
        rec["keys"] = _uniq(rec["keys"])
    return rec


def poles_of(known) -> set[str]:
    poles: set[str] = set()
    for ic in known or []:
        if isinstance(ic, dict):
            for k in ("north", "south"):
                g = str(ic.get(k) or "").strip()
                if g:
                    poles.add(g)
        elif isinstance(ic, str) and ic.strip():
            poles.add(ic.strip())
    return poles


def _plant_target(flag: dict) -> tuple[str, str]:
    aq = flag.get("arc_quest") if isinstance(flag.get("arc_quest"), dict) else {}
    for p in (aq.get("state_predicates") or []):
        if isinstance(p, dict) and p.get("type") == "atom_in_biome":
            return str(p.get("atom") or ""), str(p.get("biome") or "")
    return "", ""


def _discover_biome(flag: dict) -> str:
    aq = flag.get("arc_quest") if isinstance(flag.get("arc_quest"), dict) else {}
    for p in (aq.get("state_predicates") or []):
        if isinstance(p, dict) and p.get("type") == "biome_evolving":
            b = str(p.get("biome") or "")
            if b and b not in BOOT_BIOMES:
                return b
    return ""


def _axes_in(biome: str, ctx: dict) -> list:
    per = ctx.get("biome_axes") or {}
    if biome in per:
        return list(per.get(biome) or [])
    if biome == "Village":
        return list(ctx.get("village_axes") or [])
    return []


def _tabs(ctx: dict) -> set[str]:
    names: set[str] = set()
    for t in ctx.get("biome_tabs") or []:
        if isinstance(t, dict):
            names.add(str(t.get("biome") or ""))
        elif t:
            names.add(str(t))
    return {n for n in names if n}


def quest_complete(rec: dict, flag: dict, fired: set[str], poles: set[str], ctx: dict) -> bool:
    """FLAG fire is not quest-complete. Teaching pair, planted atom, or
    discovered biome are the clocks the dump can see."""
    fid = rec.get("id") or ""
    pair = list(rec.get("teaches") or [])
    if pair and set(pair).issubset(poles):
        return True
    k = rec.get("kind")
    if k == "handshake" and fid in fired:
        return True
    if k == "plant":
        atom, biome = _plant_target(flag)
        if not atom:
            return False
        return any(atom in str(ax) for ax in _axes_in(biome, ctx))
    if k == "discover":
        biome = _discover_biome(flag)
        if not biome:
            return False
        return biome in _tabs(ctx)
    return False


def _frontier_rec(flag: dict, poles: set[str], ctx: dict) -> dict:
    rec = compile_flag(flag, **ctx)
    pair = taught_pair(flag.get("arc_quest") or {})
    rec["clock"] = (
        "unsigned_or_language" if pair and not set(pair).issubset(poles) else "work"
    )
    if rec["clock"] == "unsigned_or_language":
        rec["keys"] = _uniq(list(UNSIGNED_KEYS) + rec["keys"])
    return rec


def live_recipe(flags_fired, known_icons=None, **ctx) -> dict | None:
    """Earliest arc_quest whose work is not yet visible as complete.

    Untaught reward pairs on a fired FLAG outrank earlier field work —
    Granary standing without 🧺 in language is mill_wakes, not a leftover
    berry door. Flag-only beats (null arc_quest) belong to the tutorial.
    """
    fired = {str(x) for x in (flags_fired or [])}
    poles = poles_of(known_icons)
    flags = load_flags()
    owed: dict | None = None
    field: dict | None = None
    for flag in flags:
        fid = str(flag.get("id") or "")
        if not fid:
            continue
        parents = prereq_ids(flag)
        if fid not in fired and any(p not in fired for p in parents):
            continue
        aq = flag.get("arc_quest") if isinstance(flag.get("arc_quest"), dict) else None
        if not aq:
            continue
        rec = compile_flag(flag, **ctx)
        if quest_complete(rec, flag, fired, poles, ctx):
            continue
        pair = taught_pair(aq)
        built = _frontier_rec(flag, poles, ctx)
        if pair and not set(pair).issubset(poles):
            if owed is None:
                owed = built
            continue
        if field is None:
            field = built
    return owed or field


def gold_off_spine(recipe: dict | None, farm_keys: list[str]) -> bool:
    if not recipe or recipe.get("id") not in STRICT_IDS:
        return False
    allowed = {str(k).upper() for k in (recipe.get("keys") or [])}
    if not allowed or not farm_keys:
        return False
    gold = str(farm_keys[0]).upper()
    return gold not in allowed


def hint_keys(text: str) -> list[str]:
    return [m.upper() for m in re.findall(r"\[([A-Z0-9;,'\.\-]+)\]", str(text or "").upper())]


def hint_off_recipe(quest: dict, hint: str, **ctx) -> list[str]:
    allowed = set(allowed_keys(quest, tuple(ctx.get("unlocked_biomes") or BOOT_BIOMES)))
    # G is gold markup on Accept rows, not always a press.
    allowed.add("G")
    # SHIFT is a modifier, not a room key.
    stray = []
    for k in hint_keys(hint):
        if k in ("SHIFT", "ESC", "ESCAPE", "CTRL", "SPACE"):
            continue
        if k not in allowed:
            stray.append(k)
    return stray


def to_mermaid(limit: int | None = None) -> str:
    flags = load_flags()
    lines = ["flowchart TD", "  T0[T0 core_loop] --> T1[T1 contracts]",
             "  T1 --> T2[T2 wayfinding]", "  T2 --> T3[T3 mass_explore]",
             "  T3 --> T4[T4 superposition / loom_opens]",
             "  T4 --> T5[T5 entanglement]", "  T5 --> T6[T6 reap / first_harvest]",
             "  T6 --> arc_handover"]
    n = 0
    for flag in flags:
        fid = str(flag.get("id") or "")
        if not fid:
            continue
        if limit is not None and n >= limit:
            break
        n += 1
        rec = compile_flag(flag)
        label = "%s %s" % (fid, rec["kind"])
        if rec["teaches"]:
            label += " " + "".join(rec["teaches"])
        safe = fid
        for p in rec["parents"]:
            lines.append("  %s --> %s" % (p, safe))
        if not rec["parents"] and fid not in ("first_harvest", "loom_opens", "arc_handover"):
            lines.append("  %s[%s]" % (safe, label.replace('"', "'")))
    return "\n".join(lines) + "\n"


def compile_live_from_dump(dump: dict) -> dict | None:
    return live_recipe(
        dump.get("flags_fired") or [],
        dump.get("known_icons") or [],
        village_axes=dump.get("village_axes") or [],
        biome_tabs=dump.get("biome_tabs") or [],
    )


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "mermaid":
        print(to_mermaid())
        raise SystemExit(0)
    steps = load_tutorial()
    print("tutorial", [(s.get("tutorial_teaches"), compile_quest({**s, "category": "TUTORIAL"})) for s in steps])
    for fid in ("arc_handover", "village_stirs", "new_voices", "woodlot_door", "mill_wakes"):
        flag = next(f for f in load_flags() if f["id"] == fid)
        print(fid, compile_flag(flag))
