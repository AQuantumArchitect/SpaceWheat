import sys, shutil
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "\U0001F344" / "\U0001F39B️"))
from rig_client import RigClient
OUT = ROOT / "logs"
_t = [0]
def turn():
    _t[0] += 1; return _t[0]
def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            listener_log_path=OUT / "carousel_listener.log", rig_log_profile="quiet")
    try:
        print("ready:", c.wait_for_ready(proc, timeout_s=160), flush=True)
        def t(a, **k): return c.run_turn(turn(), a, timeout_s=25, **k)
        def press(k, settle=6): return t("press_key", key=k, settle_frames=settle)
        def shot(name, settle=30):
            t("press_key", key="_", settle_frames=settle)  # let layout settle
            r = t("screenshot", path="user://rig/%s.png" % name, settle_frames=4)
            sc = r.get("screenshot", {}); ap = sc.get("abs", "")
            print("shot %s saved=%s" % (name, sc.get("saved")), flush=True)
            if ap and Path(ap).exists():
                shutil.copy(ap, OUT / ("%s.png" % name)); print("  -> logs/%s.png" % name, flush=True)
        press("f"); press("f"); press("f", settle=10)
        # let the cluster forces settle a good while at boot
        for _ in range(6): t("press_key", key="_", settle_frames=20)
        shot("car_boot", settle=40)
        # switch active biome to Village (Y) — carousel should rotate Village to front
        print("Y (Village):", press("y", settle=10).get("ok"), flush=True)
        for _ in range(6): t("press_key", key="_", settle_frames=20)
        shot("car_village", settle=40)
        # back to StarterForest (T)
        print("T (Forest):", press("t", settle=10).get("ok"), flush=True)
        for _ in range(6): t("press_key", key="_", settle_frames=20)
        shot("car_forest", settle=40)
    finally:
        c.terminate_listener(proc)
main()
