#!/usr/bin/env python3
"""hive_hands — the actuator leg of the hive's body: hearth recommendations, in shadow.

This is P2 (plan "SpaceWheat as the hive's body", task #382). P0 (witness_hearth.py)
gave the hive SENSING. P3 (outcome_hearth.py) gives it GROUND TRUTH. This module is
the third leg — the one that makes it a body rather than a telescope — but it SHIPS
INERT. It reads what the hive would do; it never does it.

    hearth /worlds/spacewheat-self/recommendations   [umweltd/worker.py:228,297]
      -> intend()                                     [this file: recommendation -> rig verb]
      -> shadow: LOG ONLY, never queued                [this file: shadow_run()]
      -> (armed: not built — see _dispatch_armed)       [rig_listener.gd:134 RIG_QUEUE_PATH]

Why "shadow" is load-bearing, not decorative:
  * Every OutputSpec on spacewheat-self defaults `shadow=True` (umwelt's own law,
    membranes/egress.py:15-17) — the engine decides every tick but dispatches
    nothing until the app flips it. GET /recommendations is a deque of exactly
    those undispatched Actions (egress.py:290-320): dataclass fields
    actuator_id, command, node, role, value, confidence, reason
    (membranes/egress.py:33-49). jsonable() turns that into a plain dict
    (umweltd/jsonutil.py) — what this file reads off the wire.
  * The trace schema (umwelt/projection/cognifold_trace.py:272-297) carries the
    same `shadow` / `gated` / `actuator_id` triple per tendril — the discipline
    that "a new output decides but does not act" is built into the format
    upstream of this file, not invented here.
  * The rig's real write path is `user://rig/queue.jsonl`, overridable via
    RIG_QUEUE_PATH (🍄/🎛️/rig_listener.gd:134 `_resolve_rig_path`). This module
    NEVER calls it. `_dispatch_armed()` below is the seam a future, separately
    reviewed patch would wire up — checked here so the flag is grep-able, but it
    raises today. Flipping HIVE_HANDS_ARMED=1 does not make this file write the
    queue; it makes it fail loudly instead. Arming is its own evidence-gated
    decision (plan P2 step 4), not a side door in this ship.

Verb vocabulary: read from 🍄/🎛️/rig_listener.gd's `match action:` block (the real
action set a queued turn may name) and UI/Core/KEYBOARD_GRAMMAR.md (what each verb
means to a player). Only verbs that actually exist in rig_listener.gd are ever named
here — see VERB_MAP.

THE UNMATCHED LAW (witness_hearth.py's discipline, carried here): a recommendation
whose actuator_id this bridge has no mapping for is REPORTED as `unmapped`, never
silently dropped. Silently-dropped signals are the exact failure meta-membrane was
built to catch.

Usage:
    python3 hive_hands.py                              # live: GET the hearth, shadow-log
    python3 hive_hands.py --world spacewheat-self       # explicit world (default)
    python3 hive_hands.py --recommendations <path.json> # offline: a JSON array of
                                                         # Action dicts, no hearth needed

No env gate is needed to READ recommendations (a GET is inert by construction — it
cannot make the game do anything). The gate that matters is HIVE_HANDS_ARMED, and it
is checked only on the write path, which this version does not implement.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Callable

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "hive"))
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))  # 🍄/🎛️ for rig_client (armed seam only)

from hearth_client import HearthDark, request  # noqa: E402

WORLD = os.environ.get("SPACEWHEAT_WORLD", "spacewheat-self")


# ─────────────────────────────────────────────────────────────────────────────
# VERB_MAP: hearth actuator_id -> (recommendation dict) -> rig command dict | None
#
# Every dict returned here is a fragment of the payload rig_client.RigClient.
# run_turn()/queue_turn() would append to queue.jsonl (rig_client.py:711:
# {"turn": ..., "action": ..., "request_id": ..., **kwargs}) — this file only
# ever builds the fragment, never the turn id, and never writes it anywhere.
#
# spacewheat-self currently declares exactly two OutputSpecs (both self/farm-root,
# both `shadow=True` by default — yurt/worlds/spacewheat_self/world.py:260-261):
#   farm_condition  node=farm role=wealth_trend  — decode=sticky (default) -> {"on": bool}
#   farm_attention  node=farm role=attention     — decode=sticky (default) -> {"on": bool}
# Neither names a specific biome or plot (they read the `farm` root node), so the
# only verbs that make sense are the ones valid with NO selection: the global
# QERF pair E/F (time axis, invariant across every hat — KEYBOARD_GRAMMAR.md
# "E <-> F — the time axis") and open_overlay (rig_listener.gd:495-501, one of
# three real overlay names: "quests" | "atlas" | "controls").
# ─────────────────────────────────────────────────────────────────────────────

def _condition_verb(rec: dict) -> dict | None:
    """farm_condition (wealth_trend). Rising -> let it run (F = play/forward).
    Falling -> pause and look (E = pause/inspect). Both are global-pause verbs
    (KEYBOARD_GRAMMAR.md's E<->F time axis) valid with no plot/biome selected —
    the only honest fit for a root-node recommendation."""
    on = (rec.get("command") or {}).get("on")
    if on is None:
        return None
    return {"action": "press_key", "key": "F" if on else "E", "settle_frames": 2}


def _attention_verb(rec: dict) -> dict | None:
    """farm_attention. High -> surface the player's own condition (open_overlay
    "controls" -> the X/self surface, rig_listener.gd:499). Low -> nothing
    defensible to fire; an honest absence, not a fabricated no-op verb."""
    on = (rec.get("command") or {}).get("on")
    if not on:
        return None
    return {"action": "open_overlay", "name": "controls"}


VERB_MAP: dict[str, Callable[[dict], dict | None]] = {
    "farm_condition": _condition_verb,
    "farm_attention": _attention_verb,
}


def _dispatch_armed(payload: dict) -> None:
    """The write path P2 deliberately does not build. HIVE_HANDS_ARMED is checked
    below so the seam is visible and grep-able (one flag to flip later) but
    flipping it TODAY still does nothing except raise. The real queue-write
    (via rig_client.RigClient.attach_to_running_listener().queue_turn(), the
    one existing queue-write authority — rig_client.py:533) belongs to a
    separate, reviewed-soak patch (plan P2 step 4), not to this ship."""
    raise RuntimeError(
        "hive_hands: HIVE_HANDS_ARMED=1 is set, but this version of hive_hands.py "
        "ships inert on purpose — the queue-write dispatcher is not implemented. "
        "Arming is its own evidence-gated decision (plan P2 step 4); build the "
        "real dispatch there, don't expect this flag alone to do it."
    )


def poll(world: str = WORLD, timeout_s: float = 20.0) -> list[dict]:
    """GET /worlds/<world>/recommendations. Raises HearthDark on any failure —
    read-only, so a dark hearth here can never break anything downstream; the
    caller is expected to catch it (see shadow_run)."""
    _, recs = request("GET", f"/worlds/{world}/recommendations", timeout=timeout_s)
    return list(recs or [])


def intend(recs: list[dict]) -> dict:
    """Map recommendations to intended rig verbs. Never touches the queue.

    Returns {"intents": [...], "unmapped": [...]} — `intents` entries are
    {"actuator_id", "node", "role", "reason", "confidence", "would_send"};
    `unmapped` is the sorted set of actuator_ids this bridge has no VERB_MAP
    entry for (THE UNMATCHED LAW — reported, never silently dropped).
    """
    intents: list[dict] = []
    unmapped: set[str] = set()
    for rec in recs:
        if not isinstance(rec, dict):
            continue
        actuator = str(rec.get("actuator_id", ""))
        mapper = VERB_MAP.get(actuator)
        if mapper is None:
            unmapped.add(actuator)
            continue
        verb = mapper(rec)
        if verb is None:
            continue  # honest absence: this recommendation's current state has no defensible verb
        intents.append({
            "actuator_id": actuator,
            "node": rec.get("node"),
            "role": rec.get("role"),
            "reason": rec.get("reason"),
            "confidence": rec.get("confidence"),
            "would_send": verb,
        })
    return {"intents": intents, "unmapped": sorted(unmapped)}


def shadow_run(world: str = WORLD) -> dict:
    """Poll the hearth, map to intended verbs, log-only. Never fakes success.

    ARMED is checked purely so its presence is visible in a report — even if
    HIVE_HANDS_ARMED=1 were set (this codebase never sets it), the loop below
    still never calls _dispatch_armed with intent to succeed; it only reports
    whether it WOULD have tried, matching every intent's `dispatched: false`."""
    armed = os.environ.get("HIVE_HANDS_ARMED") == "1"
    try:
        recs = poll(world)
    except HearthDark as exc:
        return {"ok": False, "world": world, "armed": armed, "dark": str(exc)}
    mapped = intend(recs)
    for entry in mapped["intents"]:
        entry["dispatched"] = False  # shadow: always false in this version — see _dispatch_armed
    report = {
        "ok": True,
        "world": world,
        "armed": armed,
        "recommendations": len(recs),
        "intents": mapped["intents"],
        "unmapped": mapped["unmapped"],
    }
    return report


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="poll hearth recommendations for spacewheat-self and log the rig "
                     "verbs they WOULD send — shadow only, never writes the rig queue")
    ap.add_argument("--world", default=WORLD)
    ap.add_argument("--recommendations",
                    help="read a recommendations JSON array from disk instead of "
                         "GET /worlds/<world>/recommendations (offline testing)")
    args = ap.parse_args(argv)

    if args.recommendations:
        try:
            recs = json.loads(Path(args.recommendations).read_text(encoding="utf-8"))
        except Exception as exc:
            print(json.dumps({"ok": False, "error": f"could not read {args.recommendations}: {exc}"},
                             ensure_ascii=False))
            return 2
        if not isinstance(recs, list):
            print(json.dumps({"ok": False, "error": "recommendations file must be a JSON array"},
                             ensure_ascii=False))
            return 2
        mapped = intend(recs)
        for entry in mapped["intents"]:
            entry["dispatched"] = False
        report = {"ok": True, "world": args.world, "armed": False,
                  "recommendations": len(recs), "intents": mapped["intents"],
                  "unmapped": mapped["unmapped"], "source": str(args.recommendations)}
    else:
        report = shadow_run(world=args.world)

    print(json.dumps(report, ensure_ascii=False, indent=1, sort_keys=True))
    if report.get("unmapped"):
        print(f"[hive_hands] UNMATCHED actuators (add to VERB_MAP): "
              f"{', '.join(report['unmapped'])}", file=sys.stderr)
    return 0 if report.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
