#!/usr/bin/env python3
"""Visual demo of the closed-system game: boot headed, play, capture PNGs."""
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

SHOTS = HERE / "demo_shots"
SHOTS.mkdir(exist_ok=True)
_turn = [0]


def nt():
    _turn[0] += 1
    return _turn[0]


def shoot(c, name, settle=1.0):
    time.sleep(settle)
    r = c.run_turn(nt(), "screenshot", path=f"user://rig/{name}.png", timeout_s=30).get("screenshot", {})
    abs_src = r.get("abs", "")
    if r.get("saved") and abs_src and Path(abs_src).exists():
        data = Path(abs_src).read_bytes()
        (SHOTS / f"{name}.png").write_bytes(data)
        print(f"  📸 {name}: {r.get('w')}x{r.get('h')} ({len(data)}B)")
    else:
        print(f"  ⚠️ {name}: {json.dumps(r)[:140]}")


def key(c, k, shift=False, settle=6):
    return c.run_turn(nt(), "press_key", key=k, shift=shift, settle_frames=settle, timeout_s=30)


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            extra_env={"RIG_RENDERING_DRIVER": "opengl3"})
    try:
        c.wait_for_ready(proc, timeout_s=180)
        time.sleep(35.0)
        print("\n─── CLOSED-SYSTEM VISUAL DEMO ───")

        # Play the sim + advance time so the bubbles develop, then capture the farm.
        key(c, "F")                                  # play
        c.run_turn(nt(), "time_skip", phrames=400, timeout_s=90)
        time.sleep(3.0)
        shoot(c, "01_farm_playing")

        # System menu (ESCAPE) — renders the session state.
        key(c, "ESCAPE"); shoot(c, "02_system_NOW")
        key(c, "O"); shoot(c, "03_system_DEV")        # Dev tab (balance/diagnostics)
        key(c, "ESCAPE")                              # close menu

        # Surface tour — each renders a full-screen overlay.
        for k, name in [("X", "04_self_story"), ("C", "05_quests"), ("V", "06_qubit_view"),
                        ("N", "07_biome_network"), ("M", "08_map")]:
            key(c, k); shoot(c, name); key(c, "ESCAPE")

        grid = c.run_turn(nt(), "grid_snapshot", timeout_s=30).get("grid", {})
        res = c.run_turn(nt(), "resource_snapshot", timeout_s=30).get("resources", {}).get("resources", {})
        print("GRID:", json.dumps(grid))
        print("RESOURCES:", json.dumps(res, ensure_ascii=False))
    finally:
        try:
            c.run_turn(9999, "stop", timeout_s=10)
        except Exception:
            pass
        c.terminate_listener(proc)
    print("\nShots in:", SHOTS)


if __name__ == "__main__":
    main()
