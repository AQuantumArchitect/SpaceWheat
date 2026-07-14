#!/usr/bin/env python3
"""Record two REAL Berry-phase tapes for umwelt's decision demo.

Drives StarterForest plot 0 twice (fresh boot each) and polls berry_state:
  loop tape:  Druid Hadamard off the pole (0,G,E) + Icon track (5,G,F) —
              the natural H evolution traces a genuine loop; the solid-angle
              integral winds toward ripeness (|γ| ≥ 2π).
  still tape: Icon track only, no Hadamard — the qubit sits at its pole, the
              Bloch path encloses nothing, γ stays ≈ 0.

Same biome, same duration, same tracking machinery — the ONLY difference is
the path's geometry. That is exactly the contrast umwelt's Berry-decision
claim needs: a choice gated on winding must flip on the first tape and
refuse on the second.

Writes <out_dir>/berry_loop.json + berry_still.json:
  {"biome": ..., "qubit": 0, "samples": [[t_phrames, gamma], ...],
   "ripe_threshold": 6.2832}

Usage: berry_tape_drive.py <out_dir> [BiomeName]
"""
import json
import sys
import tempfile
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

STEPS = 10
PHRAMES_PER_STEP = 300


def record(tape_kind: str, biome: str) -> dict:
    xdg = Path(tempfile.mkdtemp(prefix="sw_berrytape_"))
    c = RigClient(xdg=xdg)
    c.clear_rig_files()
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            listener_stdout="null",
                            extra_env={"RIG_SKIP_WELCOME": "1"})
    t = [4000]
    try:
        assert RigClient.wait_for_bridge_sentinel(timeout_s=180, xdg=c.xdg_root)

        def step(a, **k):
            t[0] += 1
            return c.run_turn(t[0], a, timeout_s=90, **k)

        def press(key, settle=6):
            t[0] += 1
            return c.run_turn(t[0], "press_key", key=key, settle_frames=settle)

        press("u")  # StarterForest tab in demos_normal order (T/Y/U)
        if tape_kind == "loop":
            press("0"); press("g"); press("e")   # Druid Hadamard off the pole
        press("5"); press("g"); press("f")       # Icon-hat Berry tracking on

        samples = [[0, 0.0]]
        threshold = 6.2832
        for i in range(STEPS):
            step("time_skip", phrames=PHRAMES_PER_STEP)
            state = step("berry_state", biome=biome)
            qubits = state.get("qubits") or [{}]
            q0 = qubits[0]
            threshold = float(q0.get("threshold", threshold))
            samples.append([(i + 1) * PHRAMES_PER_STEP, float(q0.get("phase", 0.0))])
            print(f"  {tape_kind}: t={(i + 1) * PHRAMES_PER_STEP:5d} "
                  f"gamma={samples[-1][1]:+9.4f} tracked={q0.get('tracked')}")
        return {"biome": biome, "qubit": 0, "kind": tape_kind,
                "ripe_threshold": threshold, "samples": samples}
    finally:
        RigClient.terminate_listener(proc)
        shutil.rmtree(xdg, ignore_errors=True)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    out_dir = Path(sys.argv[1])
    biome = sys.argv[2] if len(sys.argv) > 2 else "StarterForest"
    out_dir.mkdir(parents=True, exist_ok=True)
    for kind, fname in (("loop", "berry_loop.json"), ("still", "berry_still.json")):
        tape = record(kind, biome)
        (out_dir / fname).write_text(json.dumps(tape, indent=1), encoding="utf-8")
        print(f"wrote {out_dir / fname} (final gamma {tape['samples'][-1][1]:+.4f})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
