#!/usr/bin/env python3
"""Strict follower — the memoryless player, with no model behind it.

Presses ONLY the first [bracketed] key the ▸ banner names (with its SHIFT /
CTRL+SHIFT modifier), one press per look; waits 10 s when the banner names no
key. Stops when the banner line repeats 10 looks in a row (24 for wait /
ripening lines) and prints the last 40 distinct banner lines. That repeat is
the signature of a guide loop a memoryless player cannot escape: tonight it
found the selected-row no-op, the Loom clear-marks loop and the Icon⇄Ace
ping-pong, at zero token cost.

    python3 🍄/🧪/strict_follow.py <seat> <checkpoint|--fresh> <max_presses> [--until TEXT]

--patience N waits N looks on a wait line before calling it stuck (default 24).

--until TEXT stops (and banks <seat>_until) the first time the banner contains
TEXT: the way to cut a checkpoint right at a lesson for off-path probes.

Seats run in their own lane via player_seat.py (start/look/press/wait/bank/stop).
Banks <seat>_end at the end.
"""
import json, re, subprocess, sys
seat, ckpt, steps = sys.argv[1], sys.argv[2], int(sys.argv[3])
until = sys.argv[sys.argv.index("--until") + 1] if "--until" in sys.argv else ""
# --patience N: wait/ripening looks before a repeat counts as stuck (default 24,
# about 4 min). The player lane (RIG_DISABLE_LOOKAHEAD=0) ripens 5× slower than
# the rig, so a human-speed run needs more (2026-11-11: a Blood Ledger loop took
# 1–4 min to cross its threshold).
patience = int(sys.argv[sys.argv.index("--patience") + 1]) if "--patience" in sys.argv else 24
def run(*a):
    r = subprocess.run(["sh", "-c", " ".join(["python3", "'🍄/🧪/player_seat.py'"] + [f"'{x}'" for x in a])], capture_output=True, text=True, encoding="utf-8")
    try: return json.loads(r.stdout.strip().splitlines()[-1])
    except Exception: return {"raw": r.stdout[-300:] + r.stderr[-300:]}
run("start", seat, "--fresh") if ckpt == "--fresh" else run("start", seat, "--fresh", "--checkpoint", ckpt)
same, last, presses, waits, changes = 0, None, 0, 0, []
recent = []
for i in range(steps):
    d = run("look", seat, "--no-graph")
    t = d.get("screen_text", [])
    ban = next((l for l in t if l.startswith("▸")), "")
    if ban != last: changes.append(ban)
    if until and until in ban:
        print("UNTIL hit after", presses, "presses:", ban)
        b = run("bank", seat, seat + "_until"); print("bank", b.get("flags"))
        run("stop", seat); sys.exit(0)
    same = same + 1 if ban == last else 0
    last = ban
    recent = (recent + [ban])[-20:]
    if len(recent) == 20 and len(set(recent)) <= 2 and not any(("wait" in x) or ("ripening" in x) for x in recent):
        print("STUCK (ping-pong) after", presses, "presses:", " ⇄ ".join(sorted(set(recent))))
        break
    waity = ("wait" in ban) or ("ripening" in ban)
    if same >= (patience if waity else 10):
        print("STUCK after", presses, "presses,", waits, "waits:", ban); break
    m = re.search(r"(CTRL\+SHIFT |SHIFT )?\[([^\]\s]{1,8})\]", ban)
    if not m:
        run("wait", seat, "10"); waits += 1; continue
    mod, k = (m.group(1) or "").strip(), m.group(2)
    k = {"ESC": "escape", ";": "semicolon", "'": "apostrophe", "=": "equal"}.get(k, k.lower())
    run(*(["press", seat, k] + (["--shift"] if "SHIFT" in mod else []) + (["--ctrl"] if "CTRL" in mod else [])))
    presses += 1
else:
    print("budget out after", presses, "presses,", waits, "waits; last:", last)
b = run("bank", seat, seat + "_end"); print("bank", b.get("flags"))
run("stop", seat)
print("--- distinct banner lines in order (last 40) ---")
for c in changes[-40:]: print(c)
