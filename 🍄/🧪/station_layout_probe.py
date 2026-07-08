#!/usr/bin/env python3
"""Headed: verify the Mini-Metro STATION layout (anchored drift).

Bubbles are stations now — each sits leashed (~3.5px wobble) to its plot-slot
anchor; the force soup is gone. Asserts, over a 3s settle + 3s watch window:

  1. Every active-biome bubble's screen position drifts < DRIFT_MAX px
     (wobble + ease only — no force wander).
  2. Bubble positions are pairwise distinct (no anchor pile-up).
  3. Biome switch (T→Y) settles the new biome's bubbles to a NEW stable set
     (turntable handoff works), also drift-bounded.
  4. Shots: station_boot.png, station_settled.png, station_switch.png.
"""
import sys
import math
import shutil
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

# Flex pass 2026-07-08: motion is MEANING now — correlated stations tug toward
# each other on an underdamped spring, capped at FLEX_MAX=30px + wobble. The
# assert is BOUNDED motion (identity never ambiguous), not stillness.
DRIFT_MAX = 48.0     # px: flex cap (30) + wobble + spring overshoot headroom
MIN_PAIR_DIST = 16.0  # px: stations must not pile up (flex can pull pairs closer)

_t = [0]
_fails = []


def turn():
    _t[0] += 1
    return _t[0]


def check(name, ok, detail=""):
    print("%s %s %s" % ("PASS" if ok else "FAIL", name, detail))
    if not ok:
        _fails.append(name)


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    log_path = HERE.parent.parent / "logs" / "station_layout_listener.log"
    out_dir = HERE.parent.parent / "logs"
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            listener_log_path=log_path, rig_log_profile="warn",
                            extra_env={"RIG_SKIP_WELCOME": "0"})
    try:
        ready = c.wait_for_ready(proc, timeout_s=200)
        print("ready:", ready)

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=25, **kw)

        def press(k, settle=4):
            return t("press_key", key=k, settle_frames=settle)

        def bubbles():
            r = t("bubble_state")
            out = {}
            for b in r.get("bubbles", []):
                sp = b.get("screen_pos", [0, 0])
                out[(b.get("biome", ""), int(b.get("register_id", -1)))] = (
                    float(sp[0]), float(sp[1]))
            return out

        def shot(name):
            r = t("screenshot", path="user://rig/%s.png" % name, settle_frames=4)
            abs_path = r.get("screenshot", {}).get("abs", "")
            if abs_path and Path(abs_path).exists():
                shutil.copy(abs_path, out_dir / ("%s.png" % name))
                print("shot -> logs/%s.png" % name)

        def watch_drift(label, seconds=3.0, samples=6):
            first = bubbles()
            worst = 0.0
            for _ in range(samples):
                time.sleep(seconds / samples)
                now = bubbles()
                for key, p0 in first.items():
                    if key in now:
                        p1 = now[key]
                        worst = max(worst, math.dist(p0, p1))
            check("%s drift<%.0fpx" % (label, DRIFT_MAX), worst < DRIFT_MAX,
                  "worst=%.1fpx over %d bubbles" % (worst, len(first)))
            return first

        press("f"); press("f"); press("f", settle=10)
        shot("station_boot")
        time.sleep(3.0)  # let the ease settle onto anchors

        snap = watch_drift("settled")
        shot("station_settled")

        # Pairwise distinct within each biome (no pile-up).
        by_biome = {}
        for (biome, reg), pos in snap.items():
            by_biome.setdefault(biome, []).append((reg, pos))
        min_d = 1e9
        for biome, entries in by_biome.items():
            for i in range(len(entries)):
                for j in range(i + 1, len(entries)):
                    min_d = min(min_d, math.dist(entries[i][1], entries[j][1]))
        check("no pile-up", min_d >= MIN_PAIR_DIST, "min pair dist=%.1fpx" % min_d)

        # Biome switch: turntable hands off, new biome settles.
        press("y", settle=10)
        time.sleep(3.0)
        watch_drift("post-switch")
        shot("station_switch")

        print("RESULT:", "ALL PASS" if not _fails else "FAILURES: %s" % _fails)
        sys.exit(0 if not _fails else 1)
    finally:
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
