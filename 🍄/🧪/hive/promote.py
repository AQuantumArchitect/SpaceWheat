#!/usr/bin/env python3
"""Per-persona chapter ladder. A bot that CLEARS a chapter is promoted.

This is not a back door. The sensor still walks the live door. Promotion only
loads the save they banked after that walk — same as a player continuing.

Usage (from SpaceWheat repo root):
  python3 🍄/🧪/hive/promote.py starts [--personas a,b] [--json]
  python3 🍄/🧪/hive/promote.py apply --file /tmp/sw_promote.json
  python3 🍄/🧪/hive/promote.py record --persona earnest --chapter new_voices \\
      --outcome clear --checkpoint earnest_new_voices_clear
  python3 🍄/🧪/hive/promote.py seed
  python3 🍄/🧪/hive/promote.py sync [--personas a,b]
  python3 🍄/🧪/hive/promote.py status
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
FLAGS = REPO / "Core" / "Quests" / "data" / "story_flags.json"
CKPT = HERE.parent / "checkpoints"
LEDGER = HERE / "promotions.json"
WAVES = HERE / "waves"

CAMPAIGNS = ("demos", "loom", "lanternfall")
FORK_PREFIX = "village_path_"
OPEN_IDS = {"village_identity", "five_doors", "island_stops_asking"}
FINALE_IDS = {"ledger_opens", "edge_of_the_enclave"}
ALIASES = {
    "mill_apprentice": "village_stirs",
    "act0": "act0_fresh",
    "plant": "new_voices",
    "plant_new_voice": "new_voices",
}
# Wave 17 banks — each persona walked mill themselves. Seed once.
SEED = {
    "literalist": {
        "chapter": "new_voices",
        "checkpoint": "literalist_mill_apprentice_cleared",
        "cleared": ["act0_fresh", "village_stirs"],
    },
    "lost-lamb": {
        "chapter": "new_voices",
        "checkpoint": "lost_lamb_mill_apprentice_clear",
        "cleared": ["act0_fresh", "village_stirs"],
    },
    "earnest": {
        "chapter": "new_voices",
        "checkpoint": "earnest_mill_apprentice_clear",
        "cleared": ["act0_fresh", "village_stirs"],
    },
}


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def persona_stem(name: str) -> str:
    return name.replace("-", "_")


def band_for(fid: str, act: int) -> str:
    if fid.startswith(FORK_PREFIX):
        return "fork"
    if fid in OPEN_IDS:
        return "open"
    if fid in FINALE_IDS:
        return "finale"
    if act >= 6:
        return "endgame"
    return "spine"


def load_ladder() -> list[dict]:
    """Live-door sequence. Synthetic Act 0, then every authored arc_quest.

    Fork paths (village_path_*) stay off the required ladder — that is the
    open customization band. Lost-lamb playing around from village_identity
    is the acceptable-case success.
    """
    ladder = [{
        "id": "act0_fresh",
        "act": 0,
        "door": "Act 0 tutorial — explore, strike, gather, reap, Superpose, Bell, Wheel",
        "band": "spine",
        "aliases": ["act0"],
    }]
    raw = json.loads(FLAGS.read_text(encoding="utf-8"))
    if not isinstance(raw, list):
        return ladder
    for flag in raw:
        if not isinstance(flag, dict):
            continue
        aq = flag.get("arc_quest")
        if not isinstance(aq, dict) or not aq:
            continue
        if str(flag.get("campaign", "demos")) not in CAMPAIGNS:
            continue
        fid = str(flag.get("id", "")).strip()
        if not fid or fid.startswith(FORK_PREFIX):
            continue
        act = int(flag.get("act", 0) or 0)
        body = str(aq.get("body") or flag.get("display_name") or fid)
        entry = {
            "id": fid,
            "act": act,
            "door": body,
            "band": band_for(fid, act),
            "aliases": [],
        }
        if fid == "village_stirs":
            entry["aliases"] = ["mill_apprentice"]
        ladder.append(entry)
    return ladder


def canonical(chapter: str, ladder: list[dict] | None = None) -> str:
    chapter = (chapter or "").strip()
    if not chapter:
        return "act0_fresh"
    if chapter in ALIASES:
        return ALIASES[chapter]
    ladder = ladder if ladder is not None else load_ladder()
    for row in ladder:
        if row["id"] == chapter or chapter in row.get("aliases", []):
            return row["id"]
    return chapter


def index_of(chapter: str, ladder: list[dict]) -> int:
    cid = canonical(chapter, ladder)
    for i, row in enumerate(ladder):
        if row["id"] == cid:
            return i
    return 0


def door_of(chapter: str, ladder: list[dict]) -> dict:
    cid = canonical(chapter, ladder)
    for row in ladder:
        if row["id"] == cid:
            return row
    return {"id": cid, "act": 0, "door": cid, "band": "spine", "aliases": []}


def next_of(chapter: str, ladder: list[dict]) -> dict | None:
    i = index_of(chapter, ladder)
    if i + 1 >= len(ladder):
        return None
    return ladder[i + 1]


def load_ledger() -> dict:
    if not LEDGER.is_file():
        return {"updated": "", "personas": {}}
    try:
        data = json.loads(LEDGER.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {"updated": "", "personas": {}}
    if not isinstance(data, dict):
        return {"updated": "", "personas": {}}
    data.setdefault("personas", {})
    return data


def save_ledger(data: dict) -> None:
    data["updated"] = _now()
    LEDGER.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def checkpoint_exists(name: str) -> bool:
    if not name:
        return False
    return (CKPT / ("%s.tres" % name)).is_file()


def flags_from_tres(path: Path) -> list[str]:
    """Parse story_flags_fired keys from a campaign .tres. Empty on miss."""
    if not path or not path.is_file():
        return []
    text = path.read_text(encoding="utf-8", errors="replace")
    start = text.find("story_flags_fired = {")
    if start < 0:
        return []
    end = text.find("\n}", start)
    if end < 0:
        return []
    return re.findall(r'"([^"]+)"\s*:', text[start:end])


def checkpoint_flags(name: str) -> list[str]:
    """Flags the bank actually fired. Prefer a non-empty JSON sidecar; tres is referee."""
    if not name:
        return []
    jpath = CKPT / ("%s.json" % name)
    if jpath.is_file():
        try:
            data = json.loads(jpath.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            data = {}
        flags = data.get("flags_fired") or data.get("story_flags_fired") or []
        if isinstance(flags, list):
            kept = [str(x) for x in flags if str(x).strip()]
            if kept:
                return kept
    return flags_from_tres(CKPT / ("%s.tres" % name))


def load_children() -> dict[str, list[str]]:
    """flag id → flags that story_flag_set it. A child firing means the parent door was claimed."""
    raw = json.loads(FLAGS.read_text(encoding="utf-8"))
    kids: dict[str, list[str]] = {}
    if not isinstance(raw, list):
        return kids
    for flag in raw:
        if not isinstance(flag, dict):
            continue
        fid = str(flag.get("id", "")).strip()
        for pred in flag.get("predicates") or []:
            if isinstance(pred, dict) and pred.get("type") == "story_flag_set":
                parent = str(pred.get("id", "")).strip()
                if parent:
                    kids.setdefault(parent, []).append(fid)
    return kids


def furthest_live(fired: set[str], ladder: list[dict],
                  children: dict[str, list[str]] | None = None) -> tuple[list[str], dict]:
    """Cleared = fired ladder ids. Chapter = earliest still-open minted door.

    FLAG fire mints the door. A story_flag_set child firing means the parent
    was claimed. mill_wakes and second_loop both mint after loop_remembers —
    furthest-fired would skip Hold Commerce for Act 5. Spine-order earliest
    minted flag with no fired child is the live door.
    """
    children = children if children is not None else load_children()
    last_i = 0
    open_i = None
    cleared: list[str] = []
    for i, row in enumerate(ladder):
        fid = row["id"]
        if fid == "act0_fresh" or fid in fired:
            last_i = i
            if fid not in cleared:
                cleared.append(fid)
            if fid == "act0_fresh":
                continue
            kids = children.get(fid) or []
            # No child in the graph → cannot tell claimed from minted; skip.
            if not kids:
                continue
            if not any(k in fired for k in kids) and open_i is None:
                open_i = i
    return cleared, ladder[open_i if open_i is not None else last_i]


def newest_bank(persona: str, current: str) -> str:
    """Furthest earned bank: more flags win, then newer mtime.

    w160-r2: runner_spring_wakes_wall sat next to ledger checkpoint
    runner_the_teaching_clear because the recap bank field lagged.
    """
    stem = persona_stem(persona)
    best = current
    best_n = len(checkpoint_flags(current)) if current else -1
    best_mt = 0.0
    cur = CKPT / ("%s.tres" % current) if current else None
    if cur is not None and cur.is_file():
        best_mt = cur.stat().st_mtime
    for p in CKPT.glob(stem + "_*.tres"):
        n = p.stem
        if not (n.endswith("_clear") or n.endswith("_wall")):
            continue
        flags_n = len(checkpoint_flags(n))
        mt = p.stat().st_mtime
        if flags_n > best_n or (flags_n == best_n and mt > best_mt):
            best_n = flags_n
            best_mt = mt
            best = n
    return best


def persona_start(persona: str, ledger: dict, ladder: list[dict]) -> dict:
    row = (ledger.get("personas") or {}).get(persona) or {}
    chapter = canonical(str(row.get("chapter") or "act0_fresh"), ladder)
    ckpt = str(row.get("checkpoint") or "")
    if ckpt and not checkpoint_exists(ckpt):
        ckpt = ""
    parked = bool(row.get("parked"))
    if not parked:
        latest = newest_bank(persona, ckpt)
        if latest and checkpoint_exists(latest):
            old_n = len(checkpoint_flags(ckpt)) if ckpt else -1
            if len(checkpoint_flags(latest)) > old_n:
                ckpt = latest
        if ckpt:
            fired = set(checkpoint_flags(ckpt))
            if fired:
                _cleared, live = furthest_live(fired, ladder)
                if live:
                    chapter = str(live.get("id") or chapter)
    info = door_of(chapter, ladder)
    beaten = bool(row.get("beaten")) or info.get("id") == "the_door_stays_open"
    return {
        "persona": persona,
        "chapter": chapter,
        "checkpoint": ckpt,
        "door": info.get("door", chapter),
        "band": info.get("band", "spine"),
        "act": info.get("act", 0),
        "cleared": list(row.get("cleared") or []),
        "beaten": beaten,
        "outcome": str(row.get("outcome") or ""),
    }


def cmd_starts(personas: list[str], as_json: bool) -> int:
    ladder = load_ladder()
    ledger = load_ledger()
    starts = [persona_start(p, ledger, ladder) for p in personas]
    payload = {"starts": starts, "updated": ledger.get("updated", "")}
    if as_json:
        print(json.dumps(payload, indent=2))
        return 0
    print("persona\tchapter\tcheckpoint\tband\tdoor")
    for s in starts:
        print("\t".join([
            s["persona"], s["chapter"], s["checkpoint"] or "(fresh)",
            str(s["band"]), s["door"][:60],
        ]))
    return 0


def _first_existing_bank(checkpoint: str) -> str:
    """Recap sometimes concatenates runner multi-chapter banks with commas."""
    raw = (checkpoint or "").strip()
    if not raw:
        return ""
    parts = [p.strip() for p in raw.replace(";", ",").split(",") if p.strip()]
    for name in reversed(parts):
        stem = name.split()[0] if name else ""
        if stem and checkpoint_exists(stem):
            return stem
    return parts[-1] if parts else raw


def _record_one(persona: str, chapter: str, outcome: str, checkpoint: str,
                note: str, ladder: list[dict], ledger: dict) -> dict:
    checkpoint = _first_existing_bank(checkpoint)
    chapter = canonical(chapter, ladder)
    stem = persona_stem(persona)
    personas = ledger.setdefault("personas", {})
    row = personas.setdefault(persona, {
        "chapter": chapter,
        "checkpoint": "",
        "cleared": [],
        "outcome": "",
    })
    cleared = list(row.get("cleared") or [])
    result = {
        "persona": persona,
        "from": chapter,
        "outcome": outcome,
        "promoted": False,
        "reason": "",
    }
    if outcome == "clear":
        bank = checkpoint or ("%s_%s_clear" % (stem, chapter))
        if not checkpoint_exists(bank):
            result["reason"] = "no_bank:" + bank
            row["outcome"] = "clear_unbanked"
            return result
        if chapter not in cleared:
            cleared.append(chapter)
        nxt = next_of(chapter, ladder)
        row["cleared"] = cleared
        row["checkpoint"] = bank
        row["outcome"] = "promoted"
        if nxt is None:
            row["beaten"] = True
            row["chapter"] = chapter
            result["promoted"] = True
            result["reason"] = "beat"
            result["chapter"] = chapter
            result["checkpoint"] = bank
            result["door"] = "the game"
            result["band"] = "finale"
        else:
            row["chapter"] = nxt["id"]
            row["beaten"] = False
            result["promoted"] = True
            result["reason"] = "advanced"
            result["chapter"] = nxt["id"]
            result["checkpoint"] = bank
            result["door"] = nxt["door"]
            result["band"] = nxt["band"]
        if note:
            row["note"] = note
        _overlay_from_bank(row, result, ladder)
        return result
    if outcome in ("wall", "failed", "crash", "plateau"):
        row["outcome"] = outcome
        if checkpoint and checkpoint_exists(checkpoint):
            row["checkpoint"] = checkpoint
        row["chapter"] = chapter
        result["reason"] = "held"
        result["chapter"] = chapter
        result["checkpoint"] = str(row.get("checkpoint") or "")
        if note:
            row["note"] = note
        _overlay_from_bank(row, result, ladder)
        return result
    if outcome in ("playing", "open"):
        # Lost-lamb acceptable-case: reached open customization and is playing.
        row["outcome"] = "playing"
        if checkpoint and checkpoint_exists(checkpoint):
            row["checkpoint"] = checkpoint
        row["chapter"] = chapter
        result["reason"] = "playing"
        result["chapter"] = chapter
        result["checkpoint"] = str(row.get("checkpoint") or "")
        _overlay_from_bank(row, result, ladder)
        return result
    result["reason"] = "ignored:" + outcome
    return result


def _overlay_from_bank(row: dict, result: dict, ladder: list[dict]) -> None:
    """The bank's flags are ground truth. Recap chapter names lag."""
    bank = str(row.get("checkpoint") or "")
    if not checkpoint_exists(bank):
        return
    fired = set(checkpoint_flags(bank))
    if not fired:
        return
    cleared, live = furthest_live(fired, ladder)
    row["cleared"] = cleared
    row["chapter"] = live["id"]
    result["chapter"] = live["id"]
    result["door"] = live.get("door", live["id"])
    result["band"] = live.get("band", "spine")
    result["checkpoint"] = bank
    why = str(result.get("reason") or "")
    if why and "+synced" not in why:
        result["reason"] = why + "+synced"


def cmd_record(persona: str, chapter: str, outcome: str, checkpoint: str,
               note: str) -> int:
    ladder = load_ladder()
    ledger = load_ledger()
    result = _record_one(persona, chapter, outcome, checkpoint, note, ladder, ledger)
    save_ledger(ledger)
    print(json.dumps(result, indent=2))
    return 0 if result.get("reason") != "no_bank:" + (checkpoint or "") else 1


def cmd_apply(path: Path) -> int:
    payload = json.loads(path.read_text(encoding="utf-8"))
    stamp = str(payload.get("stamp") or "")
    markdown = str(payload.get("markdown") or "")
    rows = payload.get("rows") or []
    ladder = load_ladder()
    ledger = load_ledger()
    results = []
    promoted, walled, playing = [], [], []
    for row in rows:
        if not isinstance(row, dict):
            continue
        persona = str(row.get("persona") or "").strip()
        if not persona:
            continue
        chapter = str(row.get("chapter") or "")
        outcome = str(row.get("outcome") or "").strip().lower()
        # Recap agents sometimes write "**clear**" or "clear Act 1".
        if "beat" in outcome:
            outcome = "clear"
        elif "clear" in outcome:
            outcome = "clear"
        elif "play" in outcome:
            outcome = "playing"
        elif "wall" in outcome:
            outcome = "wall"
        elif "crash" in outcome or "fail" in outcome or "stale" in outcome:
            outcome = "failed"
        bank = str(row.get("bank") or row.get("checkpoint") or "")
        note = str(row.get("note") or "")
        result = _record_one(persona, chapter, outcome, bank, note, ladder, ledger)
        results.append(result)
        if result.get("promoted"):
            promoted.append(persona)
        elif result.get("outcome") == "playing" or result.get("reason") == "playing":
            playing.append(persona)
        elif outcome in ("wall", "failed", "crash", "plateau"):
            walled.append(persona)
    save_ledger(ledger)
    starts = [persona_start(str(r.get("persona")), ledger, ladder)
              for r in rows if isinstance(r, dict) and r.get("persona")]
    if stamp and markdown.strip():
        WAVES.mkdir(parents=True, exist_ok=True)
        (WAVES / ("%s.md" % stamp)).write_text(markdown.strip() + "\n", encoding="utf-8")
    out = {
        "ok": True,
        "stamp": stamp,
        "promoted": promoted,
        "walled": walled,
        "playing": playing,
        "results": results,
        "starts": starts,
    }
    print(json.dumps(out, indent=2))
    return 0


def cmd_seed() -> int:
    ladder = load_ladder()
    ledger = load_ledger()
    personas = ledger.setdefault("personas", {})
    missing = []
    for persona, spec in SEED.items():
        ckpt = spec["checkpoint"]
        if not checkpoint_exists(ckpt):
            missing.append("%s:%s" % (persona, ckpt))
            continue
        personas[persona] = {
            "chapter": canonical(spec["chapter"], ladder),
            "checkpoint": ckpt,
            "cleared": list(spec["cleared"]),
            "outcome": "promoted",
            "seeded_from": "wave17_mill_clear",
        }
    save_ledger(ledger)
    print(json.dumps({
        "ok": not missing,
        "seeded": list(SEED),
        "missing_banks": missing,
        "starts": [persona_start(p, ledger, ladder) for p in SEED],
    }, indent=2))
    return 0 if not missing else 1


def cmd_sync(personas: list[str]) -> int:
    """Move the promotions ledger to match banked save flags, not recap names.

    Recap agents name the chapter they were *sent* to. Saves walk past that.
    Sync reads flags_fired on the current checkpoint and sets chapter to the
    next ladder door after the furthest fired flag.
    """
    ladder = load_ladder()
    ledger = load_ledger()
    people = personas or list((ledger.get("personas") or {}).keys())
    results = []
    for persona in people:
        row = (ledger.setdefault("personas", {})).setdefault(persona, {
            "chapter": "act0_fresh",
            "checkpoint": "",
            "cleared": [],
            "outcome": "",
        })
        ckpt = newest_bank(persona, str(row.get("checkpoint") or ""))
        if not checkpoint_exists(ckpt):
            results.append({
                "persona": persona,
                "reason": "no_bank:" + ckpt,
                "promoted": False,
            })
            continue
        fired = set(checkpoint_flags(ckpt))
        if not fired:
            results.append({
                "persona": persona,
                "reason": "no_flags:" + ckpt,
                "checkpoint": ckpt,
                "promoted": False,
            })
            continue
        was = str(row.get("chapter") or "")
        cleared, nxt = furthest_live(fired, ladder)
        row["cleared"] = cleared
        row["chapter"] = nxt["id"]
        row["checkpoint"] = ckpt
        row["outcome"] = "synced"
        row["note"] = "synced from %s flags; live door %s" % (
            ckpt, nxt.get("door", nxt["id"]))
        row["beaten"] = bool(row.get("beaten")) and nxt["id"] in fired
        results.append({
            "persona": persona,
            "from": was,
            "chapter": nxt["id"],
            "door": nxt.get("door", nxt["id"]),
            "band": nxt.get("band", "spine"),
            "checkpoint": ckpt,
            "cleared": cleared,
            "reason": "synced" if was != nxt["id"] else "already",
            "promoted": was != nxt["id"],
        })
    save_ledger(ledger)
    print(json.dumps({
        "ok": True,
        "results": results,
        "starts": [persona_start(p, ledger, ladder) for p in people],
    }, indent=2))
    return 0


def cmd_status() -> int:
    ladder = load_ladder()
    ledger = load_ledger()
    print(json.dumps({
        "updated": ledger.get("updated", ""),
        "ladder_len": len(ladder),
        "open_from": "village_identity",
        "finale": "edge_of_the_enclave",
        "personas": ledger.get("personas", {}),
        "starts": [persona_start(p, ledger, ladder)
                   for p in (ledger.get("personas") or {})],
    }, indent=2))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    st = sub.add_parser("starts", help="current chapter/checkpoint per persona")
    st.add_argument("--personas", default="literalist,lost-lamb,earnest")
    st.add_argument("--json", action="store_true")

    rec = sub.add_parser("record", help="record one persona's chapter outcome")
    rec.add_argument("--persona", required=True)
    rec.add_argument("--chapter", required=True)
    rec.add_argument("--outcome", required=True)
    rec.add_argument("--checkpoint", default="")
    rec.add_argument("--note", default="")

    aply = sub.add_parser("apply", help="apply a recap JSON (rows + optional markdown)")
    aply.add_argument("--file", required=True)

    syn = sub.add_parser("sync", help="set chapter from checkpoint flags_fired")
    syn.add_argument("--personas", default="")

    sub.add_parser("seed", help="seed Act 1 clears from wave 17 banks")
    sub.add_parser("status", help="print ledger + ladder size")
    sub.add_parser("ladder", help="print the live-door ladder")

    args = ap.parse_args()
    if args.cmd == "starts":
        personas = [p.strip() for p in args.personas.split(",") if p.strip()]
        return cmd_starts(personas, args.json)
    if args.cmd == "record":
        return cmd_record(args.persona, args.chapter, args.outcome,
                          args.checkpoint, args.note)
    if args.cmd == "apply":
        return cmd_apply(Path(args.file))
    if args.cmd == "seed":
        return cmd_seed()
    if args.cmd == "sync":
        personas = [p.strip() for p in (args.personas or "").split(",") if p.strip()]
        return cmd_sync(personas)
    if args.cmd == "status":
        return cmd_status()
    if args.cmd == "ladder":
        ladder = load_ladder()
        print(json.dumps([{
            "id": r["id"], "act": r["act"], "band": r["band"], "door": r["door"],
        } for r in ladder], indent=2))
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())
