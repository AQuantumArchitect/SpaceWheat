"""Screenshots of the real game, for the itch page, social posts and the README.

Boots the game HEADED under a virtual display (Xvfb, software GL; the
Compatibility renderer, the same one the browser build uses) at 1920x1080,
optionally jumps to a story beat's fixture, then runs steps in order:

  g,f h,f          press keys (comma = one chord; +g = shift+G)
  wait:N           sleep N seconds
  shot:NAME        save NAME.png to $SHOT_OUT (default releases/shots/)
  go:Biome         press that biome's slot key
  toasts           hide the hint toasts (capture-only rig verb)
  clean / dirty    hide / show toasts and the banner
  hud:0 / hud:1    hide / show every UI layer, leaving the 3D field alone
  zoom:K           move the field camera to K x its distance (0.65 is close)
  follow:FLAG:N    press what the banner names, up to N presses or FLAG
  until:TEXT:N     press what the banner names until the banner says TEXT
  act:VERB {json}  any rig verb

Examples:
  python3 🍄/🧪/shoot.py empire_imposes u wait:3 8 g,f h,f j,f k,f l,f semicolon,f \
      wait:6 toasts shot:forest_ui hud:0 zoom:0.65 shot:forest_field
  python3 🍄/🧪/shoot.py island_free toasts wait:4 shot:island_measured

Needs Xvfb and Mesa's swrast driver. Writes a temporary override.cfg (window
1920x1080) at the project root and removes it on exit.
"""
import json, os, shutil, subprocess, sys, tempfile, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = Path(os.environ.get("SHOT_OUT", str(ROOT / "releases" / "shots")))
OUT.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(ROOT / "🍄" / "🎛️"))
from rig_client import RigClient
sys.path.insert(0, str(ROOT / "🍄" / "🧪"))
import banner_follow as BF
W, H = os.environ.get("SHOT_W", "1920"), os.environ.get("SHOT_H", "1080")
OVERRIDE = ROOT / "override.cfg"
_had_override = OVERRIDE.exists()
if not _had_override:
    OVERRIDE.write_text("[display]\n\nwindow/size/window_width_override=%s\nwindow/size/window_height_override=%s\n" % (W, H))
disp = ":%d" % (90 + os.getpid() % 9)
xv = subprocess.Popen(["Xvfb", disp, "-screen", "0", "%sx%sx24" % (W, H), "-nolisten", "tcp"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(1.5)
xdg = Path(tempfile.mkdtemp(prefix="sw_shot_"))
rig = RigClient(xdg=xdg, root_from_file=ROOT / "🍄" / "🎛️" / "milk_hunt_runner.py")
rig.clear_rig_files()
env = {"RIG_UNLOCK_ALL": "0", "SW_DEBUG_READOUT": "0", "DISPLAY": disp, "RIG_RENDERING_DRIVER": os.environ.get("DRV", "opengl3")}
proc = rig.start_listener(scenario_id="demos_normal", display_mode="headed", allow_resource_injection=False,
                          listener_stdout="null", rig_log_profile="quiet", extra_env=env)
n = [0]
def t(a, timeout=240, **kw):
    n[0] += 1
    return rig.run_turn(n[0], a, timeout_s=timeout, **kw)
try:
    assert RigClient.wait_for_bridge_sentinel(timeout_s=400, xdg=rig.xdg_root), "no bridge"
    start = sys.argv[1]
    if start != "fresh":
        r = t("start_at_beat", id=start, wait_frames=300)
        print("fixture", r.get("ok"))
    print("size", t("set_window_size", w=int(W), h=int(H)).get("window_size"))
    t("press_key", key="escape", settle_frames=6)
    for step in sys.argv[2:]:
        if step.startswith("wait:"):
            time.sleep(float(step[5:])); continue
        if step.startswith("shot:"):
            name = step[5:]
            r = t("screenshot", path="user://rig/%s.png" % name)
            s = r.get("screenshot") or {}
            src = Path(s.get("abs", ""))
            if src.exists():
                shutil.copy(src, OUT / ("%s.png" % name)); print("SHOT", name, s.get("w"), s.get("h"))
            else:
                print("SHOT FAIL", name, json.dumps(r)[:300])
            continue
        if step.startswith("hud:"):
            print("hud", t("presentation", hud=step[4:] == "1").get("presentation")); continue
        if step.startswith("follow:"):  # follow:<flag>:<max presses>
            _, flag, cap = step.split(":")
            fo = BF.Follower(rig); fo.t = lambda a, timeout=60, **kw: t(a, timeout, **kw)
            pressed = 0
            while pressed < int(cap):
                if flag in (t("story_flags").get("flags_fired") or {}):
                    break
                line = (fo.banner() or [""])[0]
                ks = BF.parse_keys(line)
                if not ks:
                    time.sleep(2); pressed += 1; continue
                for k, sh in ks:
                    t("press_key", key=k, shift=sh, settle_frames=12); pressed += 1
            print("follow", flag, "fired" if flag in (t("story_flags").get("flags_fired") or {}) else "not fired", pressed); continue
        if step.startswith("go:"):  # go:<Biome> — press that biome's slot key
            slots = t("biome_slots").get("slots", [])
            print("slots", [(x.get("key"), x.get("biome")) for x in slots])
            hit = [x for x in slots if x.get("biome") == step[3:]]
            if hit:
                t("press_key", key=str(hit[0]["key"]).lower(), settle_frames=20)
            else:
                print("no slot for", step[3:])
            continue
        if step == "toasts":
            t("presentation", toasts=False); continue
        if step.startswith("until:"):  # until:<text>:<max presses> — follow the banner until it says <text>
            _, want, cap = step.split(":")
            fo = BF.Follower(rig); fo.t = lambda a, timeout=60, **kw: t(a, timeout, **kw)
            pressed = 0
            while pressed < int(cap):
                line = (fo.banner() or [""])[0]
                if want in line:
                    break
                ks = BF.parse_keys(line)
                if not ks:
                    time.sleep(2); pressed += 1; continue
                for k, sh in ks:
                    t("press_key", key=k, shift=sh, settle_frames=12); pressed += 1
            print("until", want, "->", (fo.banner() or [""])[0][:100]); continue
        if step.startswith("zoom:"):
            print("zoom", t("presentation", zoom=float(step[5:])).get("presentation")); continue
        if step == "clean":
            t("presentation", toasts=False, banner=False); continue
        if step == "dirty":
            t("presentation", toasts=True, banner=True); continue
        if step.startswith("act:"):  # raw rig verb with json args
            verb, _, js = step[4:].partition(" ")
            print(verb, json.dumps(t(verb, **(json.loads(js) if js else {})), ensure_ascii=False)[:200]); continue
        for k in step.split(","):
            sh = k.startswith("+")
            t("press_key", key=k.lstrip("+"), shift=sh, settle_frames=10)
finally:
    RigClient.terminate_listener(proc, timeout_s=5.0)
    xv.terminate()
    shutil.rmtree(xdg, ignore_errors=True)
    if not _had_override:
        OVERRIDE.unlink(missing_ok=True)
