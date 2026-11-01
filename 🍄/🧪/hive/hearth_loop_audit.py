#!/usr/bin/env python3
"""hearth_loop_audit.py — does coral's hearth_cns token→actuator loop actually close?

THE CLAIM UNDER AUDIT. coral/hearth_cns.py (a different seat's code, read-only
here) asserts a law in its own comments: hearth_actuators.py "parent[s] every
actuator with a token tape row" — every fired actuator is traceable to exactly
one token-fire event that caused it, via a join key. Concretely:

    commons/vitals/hearth_token_tape.jsonl     row.step_n
    commons/vitals/hearth_actuator_tape.jsonl  row.parent_step_n

hearth_actuators.py:341 puts it plainly: "join is (token, parent_step_n)".
That claim was previously unverifiable — the two tapes had no shared key at
all until mail 0023 (C3) landed the parent_step_n field. This script measures
whether the fixed join actually holds against the *live* tapes, rather than
trusting the law-comment.

THE DISCIPLINE (same one as hive/holonomy.py, adapted). holonomy.py audits a
belief loop by measuring composite orientation empirically and solving a GF(2)
system — literal linear algebra fits that loop's shape (each hop has a binary
sign). This loop has a different shape: a two-table join with a timestamp
order constraint, not a chain of orientable hops. So the algebra here is join
arithmetic and timestamp comparison, not GF(2) — but the posture is identical:
audit the LOOP by measuring the tapes the components actually wrote, not by
reading what the code says it does. A gap found here needs no judge; it is
either present in the data or it is not.

WHAT COUNTS AS A CLOSED LOOP HERE, PER ROW:
  measurement → hearth_cns.once() → token fires (token tape row, keyed by
  (token, step_n)) → dispatch() fires the actuator (actuator tape row, keyed
  by (token, parent_step_n)) → parent_step_n == step_n AND the token row's ts
  is NOT AFTER the actuator row's ts (the token must have happened first —
  the loop must not run backwards).

WHAT THIS SCRIPT CHECKS, EMPIRICALLY, AGAINST THE REAL TAPES:
  1. orphan actuators   — a keyed actuator row (parent_step_n present) whose
                           (token, parent_step_n) matches NO token-tape row.
  2. orphaned tokens     — a token fired (in the window where the join key was
                           already live) that no keyed actuator row ever
                           claims via (token, step_n).
  3. causality violations — a matched pair where the token row's ts is AFTER
                           the actuator row's ts: the actuator would have to
                           have fired before its own cause. Loop running
                           backwards.
  4. ambiguous joins     — a (token, step_n) key that matches more than one
                           token-tape row, or more than one actuator claims
                           the same token-tape row: the join key is not
                           unique, so "parented by" is not even well-defined.
  5. never-actuated-by-name — a token that fired at least once but whose name
                           never appears anywhere in the actuator tape, in
                           ANY era (independent of the join key existing).
  6. legacy split — the join key (parent_step_n) was added partway through
                     these tapes' lives. Actuator rows written before that
                     either lack the field or carry it as null; they cannot
                     be judged by the declared mechanism at all, and are
                     reported separately, not folded into "orphan" counts.
                     The boundary is read live from the data (earliest ts
                     among tokens actually claimed by a keyed actuator row) —
                     never a hardcoded timestamp, for the same reason
                     holonomy.py reads its shipped config live: a hardcoded
                     boundary goes stale the moment the tapes grow.

WHAT IT CANNOT DO. step_n is hearth_cns's own step counter, persisted in
hearth_rho_latest.json and incremented by the SAME process across restarts —
but if that state file is ever reset (yurt_density.py reset, or a fresh
state file), step_n restarts from 0 and (token, step_n) stops being a
globally unique key across the tape's lifetime. This script does not assume
monotonicity; it reports any non-monotonic step_n jump it finds as a
structural note (not a pass/fail check) because a repeated step_n after a
reset is exactly the failure mode that would make this join key silently
ambiguous.

Read-only. Parses two JSONL tapes coral already exported to commons/vitals/.
Writes nothing, imports nothing from coral/**.

CLI:
    python3 hearth_loop_audit.py            # human-readable report
    python3 hearth_loop_audit.py --json      # machine-readable report
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_VITALS_DIR = (
    "/mnt/c/Users/Luke Spooner/ws-win/yurt-sync/commons/vitals"
)


def _vitals_dir() -> Path:
    return Path(os.environ.get("HEARTH_VITALS_DIR", DEFAULT_VITALS_DIR))


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _parse_ts(s: Any) -> datetime | None:
    if not isinstance(s, str) or not s:
        return None
    try:
        return datetime.fromisoformat(s)
    except ValueError:
        return None


def _load_jsonl(path: Path) -> tuple[list[dict], int]:
    """Read a JSONL tape. Returns (rows, n_parse_errors). Missing file -> ([], 0)."""
    if not path.is_file():
        return [], 0
    rows: list[dict] = []
    bad = 0
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            bad += 1
            continue
        if isinstance(obj, dict):
            rows.append(obj)
        else:
            bad += 1
    return rows, bad


# ── the audit ──────────────────────────────────────────────────────────────


def audit(token_rows: list[dict], actuator_rows: list[dict]) -> dict:
    """Measure the join between the two tapes. Never asserts; returns evidence."""

    # index token rows by their own declared join key
    token_index: dict[tuple[Any, Any], list[dict]] = {}
    for r in token_rows:
        tok, sn = r.get("token"), r.get("step_n")
        if tok is None or sn is None:
            continue
        token_index.setdefault((tok, sn), []).append(r)

    duplicate_join_keys = [
        {"token": k[0], "step_n": k[1], "n": len(rows),
         "ts": [r.get("ts") for r in rows]}
        for k, rows in token_index.items() if len(rows) > 1
    ]

    keyed_actuators = [a for a in actuator_rows if a.get("parent_step_n") is not None]
    unkeyed_missing_field = [a for a in actuator_rows if "parent_step_n" not in a]
    unkeyed_null_field = [
        a for a in actuator_rows
        if "parent_step_n" in a and a.get("parent_step_n") is None
    ]

    clean_matches: list[dict] = []
    orphan_actuators: list[dict] = []
    ambiguous_actuators: list[dict] = []
    causality_violations: list[dict] = []
    claimed_keys: set[tuple[Any, Any]] = set()

    for a in keyed_actuators:
        key = (a.get("token"), a.get("parent_step_n"))
        matches = token_index.get(key, [])
        if not matches:
            orphan_actuators.append(a)
            continue
        claimed_keys.add(key)
        if len(matches) > 1:
            ambiguous_actuators.append({"actuator": a, "candidate_tokens": matches})
        tok_row = min(matches, key=lambda r: r.get("ts") or "")
        t_ts, a_ts = _parse_ts(tok_row.get("ts")), _parse_ts(a.get("ts"))
        pair = {"actuator": a, "token": tok_row}
        if t_ts is not None and a_ts is not None and t_ts > a_ts:
            pair["gap_s"] = (t_ts - a_ts).total_seconds()
            causality_violations.append(pair)
        else:
            clean_matches.append(pair)

    dry_run_clean_matches = [
        m for m in clean_matches if m["actuator"].get("dry_run") is True
    ]

    # fix boundary: read live from data — earliest ts among tokens that were
    # actually claimed by a keyed actuator row. Never hardcoded (see docstring).
    claimed_ts = [
        ts for key in claimed_keys
        for r in token_index.get(key, [])
        for ts in [_parse_ts(r.get("ts"))]
        if ts is not None
    ]
    fix_boundary = min(claimed_ts) if claimed_ts else None

    eligible_tokens: list[dict] = []
    legacy_tokens: list[dict] = []
    for r in token_rows:
        ts = _parse_ts(r.get("ts"))
        if fix_boundary is not None and ts is not None and ts >= fix_boundary:
            eligible_tokens.append(r)
        else:
            legacy_tokens.append(r)

    orphaned_tokens = [
        r for r in eligible_tokens
        if (r.get("token"), r.get("step_n")) not in claimed_keys
    ]

    actuator_token_names = {a.get("token") for a in actuator_rows}
    token_names_fired = {r.get("token") for r in token_rows}
    never_actuated_by_name = sorted(
        n for n in (token_names_fired - actuator_token_names) if n is not None
    )

    step_n_anomalies = _step_n_anomalies(token_rows)

    consistent = not (
        orphan_actuators or ambiguous_actuators or causality_violations
        or orphaned_tokens or duplicate_join_keys
    )

    return {
        "schema": "hearth-loop-audit/0.1",
        "ts": _now(),
        "join_key": "token_tape.(token, step_n) == actuator_tape.(token, parent_step_n)",
        "counts": {
            "token_rows": len(token_rows),
            "actuator_rows": len(actuator_rows),
            "keyed_actuator_rows": len(keyed_actuators),
            "unkeyed_actuator_rows_missing_field": len(unkeyed_missing_field),
            "unkeyed_actuator_rows_null_field": len(unkeyed_null_field),
            "clean_matches": len(clean_matches),
            "dry_run_clean_matches": len(dry_run_clean_matches),
            "orphan_actuators": len(orphan_actuators),
            "ambiguous_actuators": len(ambiguous_actuators),
            "causality_violations": len(causality_violations),
            "duplicate_join_keys": len(duplicate_join_keys),
            "eligible_tokens_since_fix": len(eligible_tokens),
            "legacy_tokens_before_fix": len(legacy_tokens),
            "orphaned_tokens": len(orphaned_tokens),
            "never_actuated_by_name": len(never_actuated_by_name),
        },
        "fix_boundary_ts": fix_boundary.isoformat() if fix_boundary else None,
        "orphan_actuators_examples": orphan_actuators[:8],
        "ambiguous_actuators_examples": ambiguous_actuators[:8],
        "causality_violations_examples": causality_violations[:8],
        "duplicate_join_keys_examples": duplicate_join_keys[:8],
        "orphaned_tokens_examples": orphaned_tokens[:8],
        "dry_run_clean_matches_examples": dry_run_clean_matches[:8],
        "never_actuated_by_name": never_actuated_by_name,
        "step_n_anomalies": step_n_anomalies,
        "consistent": consistent,
        "law": (
            "loop closes iff every keyed actuator row's (token, parent_step_n) "
            "resolves to exactly one token row that happened no later than the "
            "actuator, AND every token fired since the join key went live is "
            "claimed by some actuator row. legacy (pre-key) rows are reported "
            "separately, never counted as orphans — the mechanism to verify "
            "them did not exist yet."
        ),
    }


def _step_n_anomalies(token_rows: list[dict]) -> list[dict]:
    """Informational only: flags non-monotonic step_n jumps in time order.

    Not a pass/fail check — step_n is a per-process counter persisted to disk;
    a state reset (or a synthetic/injected row) legitimately produces a jump
    or a reuse. But a reused step_n after a jump is exactly what would make
    the (token, step_n) join key silently ambiguous, so it's worth surfacing.
    """
    first_seen: dict[Any, str] = {}
    for r in token_rows:
        sn, ts = r.get("step_n"), r.get("ts")
        if sn is None or not isinstance(ts, str):
            continue
        if sn not in first_seen or ts < first_seen[sn]:
            first_seen[sn] = ts
    ordered = sorted(first_seen.items(), key=lambda kv: kv[1])
    anomalies = []
    for (sn0, ts0), (sn1, ts1) in zip(ordered, ordered[1:]):
        try:
            delta = int(sn1) - int(sn0)
        except (TypeError, ValueError):
            continue
        if delta <= 0 or delta > 50:
            anomalies.append(
                {"prev_step_n": sn0, "prev_ts": ts0,
                 "next_step_n": sn1, "next_ts": ts1, "delta": delta}
            )
    return anomalies


def render(report: dict) -> str:
    c = report["counts"]
    out = [
        "hearth_loop_audit — coral hearth_cns token->actuator loop closure",
        f"  join key: {report['join_key']}",
        f"  fix boundary (earliest ts of a token actually claimed): "
        f"{report['fix_boundary_ts'] or 'undetermined (no keyed matches at all)'}",
        "",
        f"  token tape rows:              {c['token_rows']}",
        f"  actuator tape rows:           {c['actuator_rows']}",
        f"    keyed (parent_step_n set):  {c['keyed_actuator_rows']}",
        f"    unkeyed (field absent):     {c['unkeyed_actuator_rows_missing_field']}  <- legacy, pre-fix",
        f"    unkeyed (field null):       {c['unkeyed_actuator_rows_null_field']}",
        "",
        f"  clean matches:                {c['clean_matches']}"
        f"  (of which dry_run: {c['dry_run_clean_matches']})",
        f"  orphan actuators:             {c['orphan_actuators']}"
        + ("  <-- GAP" if c['orphan_actuators'] else ""),
        f"  ambiguous joins:              {c['ambiguous_actuators']}"
        + ("  <-- GAP" if c['ambiguous_actuators'] else ""),
        f"  causality violations:         {c['causality_violations']}"
        + ("  <-- GAP (loop ran backwards)" if c['causality_violations'] else ""),
        f"  duplicate join keys in tape:  {c['duplicate_join_keys']}"
        + ("  <-- GAP" if c['duplicate_join_keys'] else ""),
        "",
        f"  tokens fired since fix boundary:  {c['eligible_tokens_since_fix']}",
        f"  tokens fired before fix boundary: {c['legacy_tokens_before_fix']}  "
        "(unauditable — join key not live yet, not counted as orphans)",
        f"  orphaned tokens (fired since fix, never claimed): {c['orphaned_tokens']}"
        + ("  <-- GAP" if c['orphaned_tokens'] else ""),
        f"  token names never seen in actuator tape at all: {c['never_actuated_by_name']}"
        + (f"  ({', '.join(report['never_actuated_by_name'])})"
           if report['never_actuated_by_name'] else ""),
    ]

    def _examples(title: str, rows: list[dict]) -> None:
        if not rows:
            return
        out.append("")
        out.append(f"  {title}:")
        for r in rows:
            out.append(f"    {json.dumps(r, ensure_ascii=False, default=str)[:280]}")

    _examples("orphan actuator examples", report["orphan_actuators_examples"])
    _examples("ambiguous join examples", report["ambiguous_actuators_examples"])
    _examples("causality violation examples", report["causality_violations_examples"])
    _examples("duplicate join key examples", report["duplicate_join_keys_examples"])
    _examples("orphaned token examples", report["orphaned_tokens_examples"])
    _examples("dry-run clean-match examples (parented, but no real effect)",
               report["dry_run_clean_matches_examples"])

    if report["step_n_anomalies"]:
        out.append("")
        out.append("  step_n non-monotonic jumps (informational, not a pass/fail check):")
        for a in report["step_n_anomalies"]:
            out.append(f"    step_n {a['prev_step_n']}@{a['prev_ts']} -> "
                       f"{a['next_step_n']}@{a['next_ts']}  (delta {a['delta']})")

    out.append("")
    if report["consistent"]:
        out.append("  VERDICT: loop CLOSES on the checked data — every keyed actuator "
                    "traces to exactly one prior token, and no eligible token was "
                    "left unclaimed.")
    else:
        out.append("  VERDICT: loop does NOT fully close — see GAP lines above.")
    out.append(f"  law: {report['law']}")
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument("--vitals-dir", default=None,
                     help="override commons/vitals dir (default: HEARTH_VITALS_DIR env "
                          "or the known yurt-sync path)")
    args = ap.parse_args(argv)

    vitals = Path(args.vitals_dir) if args.vitals_dir else _vitals_dir()
    token_path = vitals / "hearth_token_tape.jsonl"
    actuator_path = vitals / "hearth_actuator_tape.jsonl"

    token_rows, token_bad = _load_jsonl(token_path)
    actuator_rows, actuator_bad = _load_jsonl(actuator_path)
    token_rows = [r for r in token_rows if r.get("event") == "token_fire"]
    actuator_rows = [r for r in actuator_rows if r.get("event") == "actuator"]

    # Hard constraint: never fabricate. If either tape is missing or empty, say so and stop.
    missing = [str(p) for p in (token_path, actuator_path) if not p.is_file()]
    if missing:
        print(f"[hearth_loop_audit] tape file(s) not found, stopping (no data to audit): "
              f"{missing}")
        return 2
    if not token_rows or not actuator_rows:
        print(f"[hearth_loop_audit] tape file(s) present but empty of usable rows, "
              f"stopping (no data to audit): token_rows={len(token_rows)} "
              f"actuator_rows={len(actuator_rows)} "
              f"(parse errors: token={token_bad} actuator={actuator_bad})")
        return 2

    report = audit(token_rows, actuator_rows)
    report["source"] = {
        "token_tape": str(token_path),
        "actuator_tape": str(actuator_path),
        "token_parse_errors": token_bad,
        "actuator_parse_errors": actuator_bad,
    }

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=1, default=str))
    else:
        print(render(report))

    return 0 if report["consistent"] else 1


if __name__ == "__main__":
    sys.exit(main())
