#!/usr/bin/env python3
"""outcome_hearth — post SpaceWheat's LIVE campaign outcomes into the hearth.

This is the grader leg of the hive's body (plan: "SpaceWheat as the hive's
body", P3 — the grader, 2026-08-01). P0 (witness_hearth.py) gives the hive
SENSING — a live density-matrix field. This module gives it GROUND TRUTH: the
same story flags / act progression / resource state the campaign-proof tests
already assert (test_story_arc_boot.py's `_wait_for_story_flag`,
act3_5_drive.py's `flags()`/`res()` helpers driving the endgame). Posting
these as `spacewheat_outcome` sensors makes the loop scoreable — the first
concrete rung for the gym-battle benchmark (#336): #265 already proved an LLM
can beat this game through the rig; this makes that a number, not an anecdote.

    game (Farm.story_flags_fired / story_log, QuantumInstrument resources)
      -> rig verbs `story_flags` + `resource_snapshot`  [rig_listener.gd:817,723]
      -> collect()                                      [this file]
      -> POST /worlds/spacewheat-self/events            [semantica_post.py:57]

Sources, read (not guessed) before writing this:
    Core/Farm.gd:31-32            story_log Array + story_flags_fired Dictionary
    Core/Story/StoryEngine.gd:143-154  _on_story_flag_fired appends {id, act,
                                   display_name, arc_beat, fired_at} to story_log
    🍄/🎛️/rig_listener.gd:817-824  "story_flags" action (read-only, exists already)
    🍄/🎛️/rig_listener.gd:723-724  "resource_snapshot" action (read-only, exists already)
    Core/Instrumentation/QuantumInstrument.gd:1044-1055  get_resource_snapshot()
    🍄/🧪/act3_5_drive.py:101-108  flags()/res() — the exact same two reads,
                                   already the endgame proof's own ground truth

Both rig actions already exist and are read-only — no new rig verb was added.
This module only converts and posts what they already expose.

DELTA STATE: "resource deltas since last read" and "flags fired this session"
both need a baseline between invocations (this is a one-shot CLI, like
witness_hearth.py — it does not run as a daemon). The baseline is cached at
hive/outcome_hearth_state.json, gitignored the same way almanac_state.pkl and
walls.jsonl already are (hive/.gitignore). A sensor's baseline is only
advanced past an entry once that entry is actually POSTED — if the hearth
goes dark mid-post, unposted deltas stay pending for the next run rather than
being silently swallowed. `act_index` is the one exception: it is a gauge
(the highest act any fired flag belongs to), re-derived fresh every run, so
it carries no baseline of its own.

OPT-IN, like every other hearth poster in this repo: set SEMANTICA_POST=1.
A dark hearth is reported honestly and never breaks the game or the caller.

Usage:
    SEMANTICA_POST=1 python3 outcome_hearth.py                    # live, from a running game
    python3 outcome_hearth.py --outcome <path.json> --dry-run     # offline, prints the payload
    python3 outcome_hearth.py --outcome <path.json>               # offline outcome, real post
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "hive"))
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))  # 🍄/🎛️ for rig_client

from witness_hearth import _slug  # noqa: E402  — reuse, don't re-derive the slugger
from semantica_post import HearthDark, post  # noqa: E402

WORLD = os.environ.get("SPACEWHEAT_WORLD", "spacewheat-self")
STATE_PATH = HERE / "hive" / "outcome_hearth_state.json"


def _emoji_slug(s: str) -> str:
    """A sensor-name fragment for resource keys, which are raw emoji
    (Core/GameMechanics/FarmEconomy.gd's economy dict is emoji-keyed, e.g.
    '🌾', '🍞' — see act3_5_drive.py:337 `bridge(emoji, amount)`).
    witness_hearth._slug strips non-ascii to '' — correct for its ascii
    biome/source names, but would collapse every emoji resource onto the same
    empty string here. Fall back to codepoints so distinct emoji stay
    distinct sensors."""
    slug = _slug(s)
    if slug:
        return slug
    return "u" + "_".join(f"{ord(ch):x}" for ch in s) if s else "unknown"


def _load_state() -> dict:
    try:
        state = json.loads(STATE_PATH.read_text(encoding="utf-8"))
        if isinstance(state, dict):
            state.setdefault("flags_fired", {})
            state.setdefault("resources", {})
            return state
    except (OSError, json.JSONDecodeError):
        pass
    return {"flags_fired": {}, "resources": {}}


def _save_state(state: dict) -> None:
    try:
        STATE_PATH.write_text(json.dumps(state, ensure_ascii=False, sort_keys=True),
                              encoding="utf-8")
    except OSError as exc:
        print(f"[outcome_hearth] could not save delta baseline: {exc}", file=sys.stderr)


def _extract_resources(resource_snapshot_row: dict) -> dict:
    """Unwrap rig_listener.gd:724's double nesting — the same unwrap
    act3_5_drive.py's res() helper performs on the live rig result."""
    r = resource_snapshot_row.get("resources") or {}
    if isinstance(r, dict) and isinstance(r.get("resources"), dict):
        r = r["resources"]
    return r if isinstance(r, dict) else {}


def collect(outcome: dict, prev_state: dict) -> tuple[dict[str, float], dict[str, dict]]:
    """Convert a live outcome read into {sensor: value} + {sensor: meta}.

    Three families, one `spacewheat_outcome_` namespace:
      spacewheat_outcome_flag_<slug(flag_id)>       — 1.0, only for flags NOT
                                                        already in prev_state
                                                        (i.e. newly fired since
                                                        the last successful post)
      spacewheat_outcome_act_index                  — highest `act` among all
                                                        currently-fired flags
                                                        (a gauge, not a delta)
      spacewheat_outcome_resource_<slug(emoji)>_delta — curr - prev, skipped
                                                        when exactly 0 (no
                                                        change is not a signal)
    """
    readings: dict[str, float] = {}
    metas: dict[str, dict] = {}

    flags_fired = outcome.get("flags_fired") or {}
    story_log = outcome.get("story_log") or []
    beat_by_id = {str(e.get("id", "")): e for e in story_log if isinstance(e, dict)}
    prev_flags = prev_state.get("flags_fired") or {}

    max_act = -1
    for fid, frame in sorted(flags_fired.items(), key=lambda kv: str(kv[0])):
        fid = str(fid)
        beat = beat_by_id.get(fid, {})
        act = int(beat.get("act", 0))
        if act > max_act:
            max_act = act
        if fid in prev_flags:
            continue  # already posted on an earlier read — never repost history
        sensor = f"spacewheat_outcome_flag_{_slug(fid)}"
        readings[sensor] = 1.0
        metas[sensor] = {"flag_id": fid, "act": act,
                         "display_name": str(beat.get("display_name", fid)),
                         "fired_at_frame": frame}

    if max_act >= 0:
        sensor = "spacewheat_outcome_act_index"
        readings[sensor] = float(max_act)
        metas[sensor] = {"flags_fired_total": len(flags_fired)}

    resources = outcome.get("resources") or {}
    prev_resources = prev_state.get("resources") or {}
    for emoji, value in resources.items():
        try:
            curr = float(value)
        except (TypeError, ValueError):
            continue
        prev = float(prev_resources.get(str(emoji), 0.0))
        delta = curr - prev
        if delta == 0.0:
            continue  # no change is not a signal — same absence discipline as
                      # witness_readings.gauge_to_readings' ABSENCE_FLOOR
        sensor = f"spacewheat_outcome_resource_{_emoji_slug(str(emoji))}_delta"
        readings[sensor] = delta
        metas[sensor] = {"emoji": str(emoji), "prev": prev, "curr": curr}

    return readings, metas


def live_outcome(timeout_s: float = 15.0) -> dict:
    """Pull flags + resources from a running game over the rig. Raises on no listener.

    ATTACH, never mint — same law as witness_hearth.live_gauge(): a bare
    RigClient() opens a fresh private lane that no running Godot is polling.
    attach_to_running_listener (rig_client.py:236) takes the lane off the live
    listener instead. Two read-only actions on the same client/lane —
    "story_flags" (rig_listener.gd:817) and "resource_snapshot"
    (rig_listener.gd:723) — both already exist and already back the endgame
    proof (act3_5_drive.py's flags()/res() helpers read exactly these).
    """
    from rig_client import RigClient  # imported lazily: offline mode needs no rig

    client = RigClient.attach_to_running_listener()
    flags_row = client.run_turn(9_900_101, "story_flags", timeout_s=timeout_s)
    if not flags_row.get("ok", False):
        raise RuntimeError(f"rig refused story_flags: {flags_row.get('error', flags_row)!r}")
    resources_row = client.run_turn(9_900_102, "resource_snapshot", timeout_s=timeout_s)
    if not resources_row.get("ok", False):
        raise RuntimeError(
            f"rig refused resource_snapshot: {resources_row.get('error', resources_row)!r}")

    return {
        "flags_fired": flags_row.get("flags_fired") or {},
        "story_log": flags_row.get("story_log") or [],
        "resources": _extract_resources(resources_row),
    }


def push(outcome: dict, *, world: str = WORLD, dry_run: bool = False) -> dict:
    """Convert and post. Returns a report; never fakes a success.

    Advances the delta baseline ONLY for sensors that actually got posted —
    a dark hearth mid-run leaves the rest pending for the next invocation
    instead of losing them.
    """
    prev_state = _load_state()
    readings, metas = collect(outcome, prev_state)
    report: dict = {"world": world, "readings": len(readings), "dry_run": dry_run}
    if dry_run:
        report["payload"] = readings
        report["ok"] = True
        return report

    default_meta = {"source": "outcome_hearth"}
    committed_flags = dict(prev_state.get("flags_fired") or {})
    committed_resources = dict(prev_state.get("resources") or {})
    flags_fired = outcome.get("flags_fired") or {}

    appended, dark = 0, []
    for sensor, value in sorted(readings.items()):
        meta = metas.get(sensor, default_meta)
        try:
            appended += post(sensor, value, meta, world=world)
        except HearthDark as exc:
            dark.append(f"{sensor}: {exc}")
            break  # the hearth is down; stop hammering it, keep the rest pending
        if sensor.startswith("spacewheat_outcome_flag_"):
            fid = meta.get("flag_id")
            if fid is not None:
                committed_flags[fid] = flags_fired.get(fid)
        elif sensor.startswith("spacewheat_outcome_resource_"):
            emoji = meta.get("emoji")
            if emoji is not None:
                committed_resources[emoji] = meta.get("curr")
        # spacewheat_outcome_act_index needs no commit — re-derived every run.

    _save_state({"flags_fired": committed_flags, "resources": committed_resources})

    report["appended"] = appended
    report["ok"] = not dark and appended == len(readings)
    if dark:
        report["dark"] = dark
    return report


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="post SpaceWheat outcome signals (flags/act/resource deltas) to the hearth")
    ap.add_argument("--outcome",
                    help="read a {flags_fired,story_log,resources} JSON from disk "
                         "instead of the live rig")
    ap.add_argument("--world", default=WORLD)
    ap.add_argument("--dry-run", action="store_true",
                    help="convert and print; post nothing (does not consume the delta baseline)")
    args = ap.parse_args(argv)

    if not args.dry_run and os.environ.get("SEMANTICA_POST") != "1":
        print("[outcome_hearth] SEMANTICA_POST != 1 — refusing to post (use --dry-run to inspect)",
              file=sys.stderr)
        return 2
    try:
        outcome = (json.loads(Path(args.outcome).read_text(encoding="utf-8"))
                  if args.outcome else live_outcome())
    except Exception as exc:
        print(json.dumps({"ok": False, "error": f"no outcome: {exc}"}, ensure_ascii=False))
        return 2

    report = push(outcome, world=args.world, dry_run=args.dry_run)
    print(json.dumps(report, ensure_ascii=False, indent=1, sort_keys=True))
    return 0 if report.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
