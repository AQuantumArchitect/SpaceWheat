#!/usr/bin/env python3
"""Measure Berry-phase ripening rate in any biome, without campaign discovery.

Writes a throwaway scenario (Scenarios/_ripen_probe.tres — cleaned up after)
that boots with the target biome unlocked+active, then: Druid-Hadamard plot 0,
Icon-track it, and curve phase vs time. Settles "does this biome ripen?" in
two minutes flat (used to clear Lanternfall of a suspected content bug:
phase hit -76 rad in 1800 phrames — the endgame drive's failure was key
choreography, not physics).

Usage: python3 🍄/🧪/ripen_probe.py [BiomeName]
"""
import sys, shutil, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE.parent / "🎛️"))
from rig_client import RigClient  # noqa: E402

TARGET = sys.argv[1] if len(sys.argv) > 1 else "Lanternfall"
SCEN_ID = "_ripen_probe"
SCEN_PATH = ROOT / "Scenarios" / f"{SCEN_ID}.tres"


def main():
    base = (ROOT / "Scenarios/demos_normal.tres").read_text()
    base = base.replace('scenario_id = "demos_normal"', f'scenario_id = "{SCEN_ID}"')
    base = base.replace(
        'unlocked_biomes = Array[String](["StarterForest", "Village", "TheDemos"])',
        f'unlocked_biomes = Array[String](["StarterForest", "{TARGET}"])')
    base = base.replace('active_biome_name = "StarterForest"', f'active_biome_name = "{TARGET}"')
    SCEN_PATH.write_text(base)

    xdg = Path(tempfile.mkdtemp(prefix="sw_ripen_"))
    c = RigClient(xdg=xdg)
    c.clear_rig_files()
    proc = c.start_listener(scenario_id=SCEN_ID, listener_stdout="null")
    try:
        assert RigClient.wait_for_bridge_sentinel(timeout_s=120, xdg=c.xdg_root)
        t = [1100]

        def step(a, **k):
            t[0] += 1
            return c.run_turn(t[0], a, timeout_s=90, **k)

        def press(key, settle=4):
            t[0] += 1
            return c.run_turn(t[0], "press_key", key=key, settle_frames=settle)

        print(f"── ripening curve: {TARGET} plot 0")
        press("0"); press("G"); press("E")   # Hadamard off the pole
        press("5"); press("G"); press("F")   # Berry tracking on
        for i in range(6):
            step("time_skip", phrames=300)
            q = (step("berry_state", biome=TARGET).get("qubits") or [{}])[0]
            print(f"  t={300 * (i + 1):4d}  phase={q.get('phase', 0):+9.4f}  "
                  f"tracked={q.get('tracked')}  ripe={q.get('ripe')}")
        step("stop")
    finally:
        RigClient.terminate_listener(proc)
        shutil.rmtree(xdg, ignore_errors=True)
        SCEN_PATH.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
