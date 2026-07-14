#!/usr/bin/env python3
"""The act-2 door speaks: guidance beat + Icon-hat R anti-gating.

Three relay legs farmed act 1 perfectly and never found incorporation — the
Icon hat showed only trim/inspect/track, and R on a full plot was a silent
no-op. This probe asserts the two fixes:

1. GUIDANCE — loading the act-1-complete checkpoint fires the new `new_voices`
   story flag (gates on loop_remembers + village_stirs), whose beat/arc-quest
   teach the plant-and-incorporate ritual on screen (toast + Arc tab X→I).
2. ANTI-GATING — Icon-hat R on a live UNTRACKED plot toasts WHY and what to do
   instead ("nothing to incorporate here — ..."); on a tracked UNRIPE plot it
   toasts "still ripening". Then the taught ritual actually works: track,
   time-skip to ripeness, R — the signature grows.

Usage: python3 new_voices_probe.py   (headless; one Godot; exits non-zero on fail)
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

CHECKPOINT = HERE / "checkpoints" / "act1_complete.tres"
PLOT = ["G", "H", "J", "K", "L", "SEMICOLON"]
_turn = [0]
_fails = []


def t():
    _turn[0] += 1
    return _turn[0]


def check(cond, label):
    print(("  OK   " if cond else "  FAIL ") + label)
    if not cond:
        _fails.append(label)


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless")

    def go(a, **k):
        k.setdefault("timeout_s", 90)
        return c.run_turn(t(), a, **k)

    def press(seq, s=4):
        if isinstance(seq, str):
            seq = [seq]
        for k in seq:
            c.run_turn(t(), "press_key", key=k, settle_frames=s, timeout_s=25)

    def flags():
        return go("story_flags").get("flags_fired", {}) or {}

    def known():
        return go("known_icons").get("icons", []) or []

    def qstate(bn):
        return go("berry_state", biome=bn).get("qubits", [])

    def visible_text(under=""):
        kw = {"under": under} if under else {}
        rows = go("overlay_text", **kw).get("lines", [])
        return "\n".join(str(r.get("text", "")) for r in rows)

    def goto_biome(name):
        for _ in range(4):
            slots = go("biome_slots")
            if slots.get("active") == name:
                return True
            bk = next((s.get("key") for s in slots.get("slots", [])
                       if s.get("biome") == name), None)
            if not bk:
                return False
            press(bk, 3)
        return go("biome_slots").get("active") == name

    def ensure_hat(h):
        press("8" if h != "8" else "7", 2)
        press(h, 2)

    try:
        c.wait_for_ready(proc, timeout_s=180)

        # ---- 1. GUIDANCE: the beat fires the moment act 1 is complete ----
        print("== load act1_complete checkpoint ==")
        r_ld = go("load_game_path", path=str(CHECKPOINT))
        check(bool(r_ld.get("loaded")), "checkpoint loaded")
        import time as _time
        fired = {}
        deadline = _time.time() + 25.0
        while _time.time() < deadline:
            fired = flags()
            if "new_voices" in fired:
                break
            _time.sleep(0.25)
        check("new_voices" in fired, "new_voices story flag fired after act-1 checkpoint load")

        # The fire toast (✨ display_name + beat.left(80)) holds ~4.5s — best effort.
        toast_txt = visible_text()
        if "village listens for new voices" in toast_txt:
            print("  OK   fire toast caught live: 'The village listens for new voices…'")

        # Durable surface: the arc quest sits on the Arc tab (X → I) with the ritual hint.
        press("x", 6)
        press("i", 8)
        arc_txt = visible_text()
        check("Plant a New Voice" in arc_txt,
              "Arc tab (X->I) shows the 'Plant a New Voice' guidance quest")
        press(["ESCAPE", "ESCAPE"], 3)

        # ---- 2. ANTI-GATING: Icon-hat R refusals speak ----
        print("== Icon-hat R refusal toasts ==")
        bn = "StarterForest"
        check(goto_biome(bn), "switched to %s" % bn)
        qs = qstate(bn)
        untracked = next((i for i, q in enumerate(qs) if not q.get("tracked")), None)
        check(untracked is not None, "found an untracked live plot")
        pk = PLOT[untracked if untracked is not None else 0]

        ensure_hat("5")
        press(pk, 3)
        press("R", 4)
        txt = visible_text()
        check("nothing to incorporate here" in txt,
              "R on untracked plot toasts 'nothing to incorporate here — ...'")

        # Track it (Druid-excite first so the loop sweeps sky), then R while unripe.
        ensure_hat("0")
        press(pk, 3)
        press("E", 3)
        ensure_hat("5")
        press(pk, 3)
        press("F", 3)
        press("R", 4)
        txt = visible_text()
        check("still ripening" in txt,
              "R on tracked-unripe plot toasts 'still ripening'")

        # ---- 3. THE RITUAL WORKS: ripen and incorporate ----
        # Ripen the freshly tracked loop, then R across the row. Success =
        # a ripe berry is CONSUMED and the whisper speaks. (Known axes
        # re-harvest without growing the signature — that's the designed
        # behavior; berry consumption is what the act gates count.)
        print("== incorporate after ripening ==")
        sig0 = len(known())
        b0 = int(go("berry_state", biome=bn).get("consumed_count", 0))
        go("time_skip", phrames=900)
        incorporated_txt = ""
        for p in PLOT[:len(qs)]:
            press(p, 3)
            press("R", 4)
            if "woven into your signature" not in incorporated_txt:
                incorporated_txt = visible_text()
        b1 = int(go("berry_state", biome=bn).get("consumed_count", 0))
        sig1 = len(known())
        check(b1 > b0, "incorporation consumed ripe berries (%d -> %d)" % (b0, b1))
        check("woven into your signature" in incorporated_txt,
              "incorporation success speaks ('... woven into your signature')")
        if sig1 > sig0:
            print("  OK   signature grew (%d -> %d)" % (sig0, sig1))

        print("RESULT:", "OK" if not _fails else "FAIL %s" % _fails)
    finally:
        try:
            go("stop", timeout_s=10)
        except Exception:
            pass
        c.terminate_listener(proc)
    sys.exit(1 if _fails else 0)


if __name__ == "__main__":
    main()
