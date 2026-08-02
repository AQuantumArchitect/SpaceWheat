#!/usr/bin/env python3
"""Fractal icon-world test drive via SpaceWheat instrument rig."""
from __future__ import annotations

import json
import os
import shutil
import sys
import time
from pathlib import Path

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).resolve().parents[2]))
sys.path.insert(0, str(ROOT / "🍄" / "🎛️"))

from rig_client import RigClient  # type: ignore  # noqa: E402

VITALS = Path(os.environ.get(
    "BUTLER_VITALS",
    "/mnt/c/Users/Luke Spooner/ws-win/yurt-sync/commons/vitals",
))


def main() -> int:
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    print("starting listener…", flush=True)
    proc = c.start_listener(scenario_id=os.environ.get("RIG_SCENARIO", "demos_normal"))
    try:
        c.wait_for_ready(proc, timeout_s=int(os.environ.get("RIG_READY_TIMEOUT", "300")))
        turn = 1

        def go(action: str, **kw):
            nonlocal turn
            print(f"\n=== turn {turn} {action} {kw} ===", flush=True)
            r = c.run_turn(turn, action, **kw)
            turn += 1
            print(json.dumps(r, indent=2, ensure_ascii=False)[:5000], flush=True)
            return r

        go("instrument_state")
        go("resource_snapshot")
        # fund inject cost (sprout + energy poles)
        go("set_resource", emoji="🌱", amount=50)
        go("set_resource", emoji="⚡", amount=50)
        go("set_resource", emoji="☀", amount=20)
        r_inj = go("inject_icon", biome="StarterForest", north="☀", south="⚡")
        if not ((r_inj or {}).get("inject_result") or {}).get("success"):
            # fallback: auto-pick injectable icon
            r_inj = go("inject_icon", biome="StarterForest")
        inj = (r_inj or {}).get("inject_result") or {}
        print("inject summary:", json.dumps(inj, ensure_ascii=False)[:1200], flush=True)

        r_atlas = go("fractal_atlas")
        reg = 0
        if isinstance(inj, dict):
            reg = int(inj.get("qubit_index", -1))
            fr = inj.get("fractal") if isinstance(inj.get("fractal"), dict) else {}
            if reg < 0:
                reg = int(fr.get("register_id", 0) or 0)
            if reg < 0:
                reg = 0
        r_enter = go("enter_icon", biome="StarterForest", register_id=reg)
        r_atlas2 = go("fractal_atlas")
        r_asc = go("ascend_fractal")
        r_atlas3 = go("fractal_atlas")

        # Prefer full atlas from last successful fractal_atlas turn
        for blob in (r_atlas3, r_atlas2, r_atlas):
            fa = (blob or {}).get("fractal_atlas") or {}
            atlas = fa.get("atlas") if isinstance(fa, dict) else None
            if isinstance(atlas, dict) and atlas.get("schema") == "fractal_atlas/v1":
                dest = VITALS / "fractal_atlas.json"
                # preserve swarm_overlay from example if present
                existing = {}
                if dest.is_file():
                    try:
                        existing = json.loads(dest.read_text(encoding="utf-8"))
                    except Exception:
                        existing = {}
                if "swarm_overlay" in existing and "swarm_overlay" not in atlas:
                    atlas["swarm_overlay"] = existing["swarm_overlay"]
                dest.write_text(json.dumps(atlas, indent=2, ensure_ascii=False), encoding="utf-8")
                print("wrote live atlas ->", dest, flush=True)
                break
        else:
            user_atlas = Path(os.environ.get(
                "GODOT_USER_DIR",
                str(ROOT / ".godot/godot/app_userdata/SpaceWheat - Quantum Farm"),
            )) / "fractal_atlas.json"
            if user_atlas.is_file() and VITALS.is_dir():
                shutil.copy2(user_atlas, VITALS / "fractal_atlas.json")
                print("copied user atlas -> vitals", flush=True)

        go("stop")
        ok_enter = False
        if isinstance(r_enter, dict):
            ei = r_enter.get("enter_icon") or {}
            ok_enter = bool(ei.get("success"))
        ok_inj = bool(isinstance(inj, dict) and inj.get("success"))
        print("\nDRIVE COMPLETE inject_ok=", ok_inj, "enter_ok=", ok_enter, flush=True)
        return 0 if (ok_inj or ok_enter) else 2
    finally:
        try:
            c.terminate_listener(proc)
        except Exception as e:
            print("terminate:", e, flush=True)
        time.sleep(0.5)


if __name__ == "__main__":
    raise SystemExit(main())
