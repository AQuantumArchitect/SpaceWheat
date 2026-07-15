#!/usr/bin/env python3
"""gamma-ab — E2 of the gamma research program: decay-variant Witness organs
A/B'd on live runners.

E1 (gamma_walk.py) settled decay's meaning offline: values persist, CONFIDENCE
decays, and the right γ tracks the feed's cadence. E2 asks the online half of
the owner's question: which decay rate makes the better RUNNER — does a
faster- or slower-forgetting belief field surprise itself less and forecast
better over a real leg?

The lane (shipped with this file):
  WITNESS_GAMMA_SCALE=<s> multiplies every gamma_diss in the Witness spec at
  boot (WitnessSpec.gamma_by_role — the single authority). The gauge stamps
  the scale and now banks the surprise ledger, so every checkpoint tape is a
  self-describing E2 sample. Legs need NO extra instrumentation: fly the same
  chapter at scales {0.25, 1.0, 4.0} and bank as usual.

Scoring (per gauge tape):
  surprise ema  — innovation the field did NOT expect (lower = better model),
                  averaged over sources, weighted by n.
  decisiveness  — mean |z| across roles (a field that forgets too fast is
                  permanently agnostic; too slow, permanently opinionated).
  purity        — coherence retained.

Usage:
  gamma_ab.py report [dirs...]   score every *.witness_gauge.json found
                                 (default: 🍄/🧪/checkpoints)
  gamma_ab.py plan               print the P7 E2 leg matrix
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CHECKPOINTS = HERE.parent / "checkpoints"
LADDER = [0.25, 1.0, 4.0]


def score_gauge(path: Path) -> dict | None:
    try:
        g = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None
    clusters = g.get("clusters", {})
    if not isinstance(clusters, dict) or not clusters:
        return None
    zs: list[float] = []
    purities: list[float] = []
    for entry in clusters.values():
        purities.append(float(entry.get("purity", 0.0)))
        for xyz in entry.get("bloch", {}).values():
            if isinstance(xyz, list) and len(xyz) == 3:
                zs.append(abs(float(xyz[2])))
    surprise = g.get("surprise", {})
    s_n = sum(int(e.get("n", 0)) for e in surprise.values()) if surprise else 0
    s_ema = (sum(float(e.get("ema", 0.0)) * int(e.get("n", 0))
                 for e in surprise.values()) / s_n) if s_n else None
    return {
        "tape": str(path.name),
        "gamma_scale": float(g.get("gamma_scale", 1.0)),
        "observes": int(g.get("observes_total", 0)),
        "clusters": len(clusters),
        "surprise_ema_wmean": s_ema,
        "surprise_n": s_n,
        "decisiveness_mean_abs_z": sum(zs) / len(zs) if zs else 0.0,
        "purity_mean": sum(purities) / len(purities) if purities else 0.0,
    }


def cmd_report(dirs: list[Path]) -> dict:
    rows = []
    for d in dirs:
        for path in sorted(d.rglob("*.witness_gauge.json")):
            row = score_gauge(path)
            if row:
                rows.append(row)
    by_scale: dict[float, list[dict]] = {}
    for r in rows:
        by_scale.setdefault(r["gamma_scale"], []).append(r)
    summary = {}
    for scale in sorted(by_scale):
        group = by_scale[scale]
        emas = [r["surprise_ema_wmean"] for r in group
                if r["surprise_ema_wmean"] is not None]
        summary["%.2gx" % scale] = {
            "tapes": len(group),
            "surprise_ema": sum(emas) / len(emas) if emas else None,
            "decisiveness": sum(r["decisiveness_mean_abs_z"] for r in group) / len(group),
            "purity": sum(r["purity_mean"] for r in group) / len(group),
            "observes_total": sum(r["observes"] for r in group),
        }
    verdictable = [s for s, v in summary.items() if v["surprise_ema"] is not None]
    verdict = (min(verdictable, key=lambda s: summary[s]["surprise_ema"])
               if len(verdictable) >= 2 else
               "insufficient variants — fly the ladder (gamma_ab.py plan)")
    return {"ok": True, "tapes": rows, "by_scale": summary,
            "least_surprised_scale": verdict}


def cmd_plan() -> dict:
    return {"ok": True, "ladder": LADDER, "protocol": [
        "Each P7 chapter leg flies once per rung: WITNESS_GAMMA_SCALE=<s> in the",
        "seat/drive env (inherited by Godot; WitnessSpec reads it at cluster build).",
        "Bank normally — the gauge stamps its own scale + surprise ledger.",
        "Same chapter, same checkpoint, same press budget across rungs — the only",
        "variable is the belief field's forgetting rate. NEVER compare across",
        "chapters: surprise is cadence-relative (E1's own law).",
        "Score: gamma_ab.py report. Lower surprise_ema at healthy decisiveness",
        "(|z| not collapsed toward 0) wins. Ship the verdict to the owner before",
        "retuning the shipped spec — the 1.0 rung is the current authored organ.",
    ]}


def main() -> int:
    args = sys.argv[1:]
    cmd = args[0] if args else "report"
    if cmd == "plan":
        out = cmd_plan()
    elif cmd == "report":
        dirs = [Path(a) for a in args[1:]] or [CHECKPOINTS]
        out = cmd_report([d for d in dirs if d.is_dir()])
    else:
        out = {"ok": False, "error": "unknown command (report|plan)"}
    print(json.dumps(out, ensure_ascii=False, indent=1))
    return 0 if out.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
