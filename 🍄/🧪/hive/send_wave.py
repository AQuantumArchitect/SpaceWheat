#!/usr/bin/env python3
"""send_wave.py — emit spawn packs for 3–5 grok-4.5 sensor legs.

Sparse spawn prompt; agents fetch 🍄/🧪/hive/prompts/*.md for the rest.
Grok Build parent launches the legs (see prompts/GROK.md). No Claude.

Usage (from SpaceWheat repo root):
  python3 🍄/🧪/hive/send_wave.py --chapter act0_fresh
  python3 🍄/🧪/hive/send_wave.py --personas literalist,lost-lamb --chapter act0_fresh
  python3 🍄/🧪/hive/send_wave.py --dry-run
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]  # 🍄/🧪/hive -> repo root
PROMPTS = HERE / "prompts"
WAVES = HERE / "waves"

PERSONAS = ("masher", "literalist", "earnest", "lost-lamb", "tap-lamb")
DEFAULT_PRESSES = {
    "masher": 20,
    "literalist": 25,
    "earnest": 25,
    "lost-lamb": 20,
    "tap-lamb": 20,
}
MEMORYLESS = ("lost-lamb", "tap-lamb")
MOUSE_SEATS = ("tap-lamb",)

# Sensor class. This host's catalog is grok-4.6 / grok-4.5; no grok-mini.
MODEL = os.environ.get("HIVE_SENSOR_MODEL", "grok-4.5")
GROK = os.environ.get("GROK_BIN", shutil.which("grok") or "")


def spawn_prompt(persona: str, seat: str, chapter: str, max_presses: int, checkpoint: str) -> str:
    mouse = persona in MOUSE_SEATS
    seat_py = "🍄/🧪/mouse_seat.py" if mouse else "🍄/🧪/player_seat.py"
    ckpt = ""
    if checkpoint:
        ckpt = (
            f"Start with --checkpoint {checkpoint}. "
            "This save was earned by clearing the previous chapter — not a shortcut. "
            "Lost-lamb / tap-lamb: still look before every input; no intra-session plan.\n"
        )
    else:
        ckpt = "Start from true zero (no --checkpoint). Welcome splash may be up.\n"
    verbs = (
        "Then play that persona. press is refused — use look / click / tap / click_at.\n"
        if mouse else
        f"Then play that persona through:\n  python3 {seat_py} <cmd> {seat} ...\n"
    )
    return (
        f"You are a SpaceWheat SENSOR playtester.\n"
        f"Persona: {persona}\n"
        f"Seat: {seat}\n"
        f"Chapter: {chapter}\n"
        f"Press budget: {max_presses} (or the persona's own stop rule, whichever comes first).\n"
        f"{ckpt}\n"
        f"BEFORE any press, READ these files with the Read tool:\n"
        f"  🍄/🧪/hive/prompts/SENSOR.md\n"
        f"  🍄/🧪/hive/prompts/HOST.md\n"
        f"  🍄/🧪/hive/prompts/{persona}.md\n"
        f"Do not guess the seat CLI. Fetch it.\n\n"
        f"{verbs}"
        f"from this repo root, via {seat_py}. Report through:\n"
        f"  python3 🍄/🧪/hive/hive.py wall {chapter} --file /tmp/sw_wall_{seat}.txt\n"
        f"Bank and stop when the persona says to.\n\n"
        f"Never edit code, data, or saves. Read + Bash only.\n"
        f"When done, print an 8-line report:\n"
        f"  persona / seat / presses / outcome (wall|clear|plateau|crash)\n"
        f"  last screen_text (one line)\n"
        f"  wearing_hat / wallet snapshot\n"
        f"  wall text (or 'none')\n"
        f"  bank name / hive.py wall ok?\n"
    )


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--personas", default="masher,literalist,earnest,lost-lamb",
                    help="comma list from: " + ",".join(PERSONAS)
                    + " (tap-lamb is headed mouse_seat — opt in)")
    ap.add_argument("--chapter", default="act0_fresh")
    ap.add_argument("--checkpoint", default="",
                    help="optional save stem under 🍄/🧪/checkpoints/ (earned banks are legal for lost-lamb)")
    ap.add_argument("--max-presses", type=int, default=0,
                    help="override per-persona default budgets")
    ap.add_argument("--stamp", default="",
                    help="wave folder name (default: UTC stamp)")
    ap.add_argument("--dry-run", action="store_true",
                    help="write packs and print them; do not launch")
    ap.add_argument("--jobs", type=int, default=1,
                    help="live Godot seats at once (default 1 — four parallel boots STALE'd)")
    ap.add_argument("--sequential", action="store_true",
                    help="alias for --jobs 1")
    ap.add_argument("--model", default=MODEL,
                    help="sensor model id (default grok-4.5)")
    args = ap.parse_args()

    personas = [p.strip() for p in args.personas.split(",") if p.strip()]
    unknown = [p for p in personas if p not in PERSONAS]
    if unknown:
        print(f"unknown personas: {unknown}; known: {PERSONAS}", file=sys.stderr)
        return 2
    for p in personas:
        if not (PROMPTS / f"{p}.md").is_file() or not (PROMPTS / "SENSOR.md").is_file():
            print(f"missing prompt pack under {PROMPTS}", file=sys.stderr)
            return 2

    stamp = args.stamp or time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    wave_dir = WAVES / stamp
    wave_dir.mkdir(parents=True, exist_ok=True)

    jobs = []
    for persona in personas:
        seat = f"w_{stamp[-6:]}_{persona[:4]}"
        budget = args.max_presses or DEFAULT_PRESSES[persona]
        prompt = spawn_prompt(persona, seat, args.chapter, budget, args.checkpoint)
        log_path = wave_dir / f"{persona}.md"
        jobs.append({
            "persona": persona,
            "seat": seat,
            "chapter": args.chapter,
            "checkpoint": args.checkpoint,
            "max_presses": budget,
            "prompt": prompt,
            "log": str(log_path),
        })

    manifest = {
        "stamp": stamp,
        "chapter": args.chapter,
        "checkpoint": args.checkpoint,
        "model": args.model,
        "host": "grok-build",
        "jobs": 1 if args.sequential else max(1, int(args.jobs)),
        "repo": str(REPO),
        "legs": [{k: j[k] for k in
                  ("persona", "seat", "chapter", "checkpoint", "max_presses", "log")}
                 for j in jobs],
        "note": "Parent launches legs sequentially (prompts/GROK.md). "
                "This script writes packs; it does not spawn Godot.",
    }
    (wave_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (wave_dir / "prompts.json").write_text(
        json.dumps({j["persona"]: j["prompt"] for j in jobs}, indent=2) + "\n",
        encoding="utf-8")
    readme = [
        f"# Wave {stamp}",
        "",
        f"Model: {args.model}  Chapter: {args.chapter}  Jobs: {manifest['jobs']}",
        "",
        "Humans: this page after the run. Agents: `../../prompts/`.",
        "",
        "| Persona | Seat | Budget | Outcome | Note |",
        "|---|---|---|---|---|",
    ]
    for j in jobs:
        readme.append(f"| {j['persona']} | {j['seat']} | {j['max_presses']} |  |  |")
    readme.append("")
    (wave_dir / "README.md").write_text("\n".join(readme) + "\n", encoding="utf-8")

    print(json.dumps(manifest, indent=2))
    if args.dry_run:
        for j in jobs:
            print("---", j["persona"], j["seat"], "---")
            print(j["prompt"])
        return 0

    # Packs are the product. A local grok CLI is optional and usually absent
    # on the WSL side; the Grok Build parent launches from prompts.json.
    print(f"[send_wave] wrote {len(jobs)} packs → {wave_dir}", flush=True)
    print("[send_wave] launch from Grok Build: prompts/GROK.md (sequential grok-4.5)",
          flush=True)
    if GROK:
        print(f"[send_wave] grok CLI present at {GROK} — unused; parent launches",
              flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
