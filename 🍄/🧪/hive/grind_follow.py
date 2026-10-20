#!/usr/bin/env python3
"""Follow dump gold keys on a checkpoint. No LLM. No cheats.

Layer 2 of TESTING_STACK.md. Presses the first advertised farm key until
a FLAG moves, gold lies, gold freezes, or the grind press cap.

Does not boot if another hive Godot / current seat looks live.

  python3 🍄/🧪/hive/grind_follow.py literalist_timber_rhythm_wall
  python3 🍄/🧪/hive/grind_follow.py --budget 10 --bank literalist_timber_rhythm_wall
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path
import time

# Human-scale sitting. If gold still needs mash after 10 keys, fold the
# path, the mechanics, or the mill — do not raise the cap.
os.environ.setdefault("SW_PRESS_CAP", "10")

HERE = Path(__file__).resolve().parent
SEAT = HERE.parent
sys.path.insert(0, str(SEAT))
import player_seat as ps  # noqa: E402

KEY_RE = re.compile(r"\[([A-Z0-9;,'\.\-\]]+)\]")
LIE_SNIPS = (
    "empty plot",
    "gather to empty",
    "then arc",
    "[5] icon",
    "plant the mill",
    "cull woodlot",
)


def _godot_live() -> str:
    try:
        out = subprocess.check_output(
            ["pgrep", "-af", "rig_listener"], text=True, stderr=subprocess.DEVNULL
        )
    except subprocess.CalledProcessError:
        out = ""
    for line in out.splitlines():
        if "pgrep" in line:
            continue
        if "rig_listener" in line:
            return line.strip()
    return ""


def _lines(r) -> list:
    out = []
    for x in (r.get("lines") or []):
        tx = str(x.get("text", "") if isinstance(x, dict) else x).strip()
        if tx:
            out.append(tx)
    return out


def _keys_named(blob: str) -> list:
    return KEY_RE.findall(blob.upper())


def accept_row_key(blob: str) -> str:
    """Second bracket on Accept gold is the Arc/Market row (GHJKL;)."""
    keys = _keys_named(blob)
    if len(keys) >= 2:
        k, _ = first_press("[%s]" % keys[1])
        if k:
            return k
    return "g"


def first_press(blob: str) -> tuple[str | None, bool]:
    """Return (key, shift) from gold. First advertised key only."""
    shift = "SHIFT" in blob.upper()
    keys = _keys_named(blob)
    if not keys:
        if "ESC" in blob.upper():
            return "escape", False
        return None, False
    k = keys[0]
    aliases = {
        "ESCAPE": "escape",
        "ESC": "escape",
        "SEMICOLON": "semicolon",
        ";": "semicolon",
        "SPACE": "space",
        "ENTER": "enter",
        "EQUALS": "equal",
        "=": "equal",
    }
    if k in aliases:
        return aliases[k], shift
    if len(k) == 1:
        return k.lower(), shift
    return k.lower(), shift


def mill_seated(axes: list) -> bool:
    return any(("⚙" in str(ax) or "🏭" in str(ax)) for ax in axes)


def farm_gold(blob: str) -> str:
    """Prefer a field mill line over leftover 📜 Arc toasts.

    After the Captain cull chord, Chart GildedRot was honest; leftover
    [X] then Arc toasts still matched LIE_SNIPS 'then arc' and aborted.
    """
    raw = str(blob or "")
    parts = [p.strip() for p in raw.replace("\n", " | ").split("|")]
    mill = []
    for p in parts:
        if not p:
            continue
        pl = p.lower()
        if p.startswith("📜") or "opens the arc" in pl or "then arc" in pl:
            continue
        if p.startswith("⚠"):
            continue
        if p.startswith("▸"):
            mill.append(p)
    if mill:
        return mill[0]
    # Leftover unsigned Arc wait uses 📜 not ▸. Still followable.
    for p in parts:
        pl = p.lower()
        if p.startswith("📜") and ("[x]" in pl or "accept" in pl):
            return p
    return ""


def gold_is_lie(blob: str, seated: bool, flags: list | None = None) -> str:
    blob = farm_gold(blob)
    low = blob.lower()
    flags = flags or []
    if "abandon" in low:
        return "banner_abandon"
    if "cull woodlot" in low:
        return "banner_cull_woodlot"
    if seated:
        live_factory = "🏭" in blob
        for snip in LIE_SNIPS:
            if snip in low and not live_factory:
                # After island_free, lanternfall fade may plant a pole
                # into GildedRot. Village ⚙ must not brand that a lie.
                if snip == "[5] icon" and "island_free" in flags:
                    continue
                return "banner_plant_while_mill_seated:" + snip
    if "empty plot" in low and seated:
        return "banner_empty_plot_occupied"
    return ""

# Lanternfall / loom flags must not bank onto a timber_rhythm wall.
OFF_WALL_FLAGS = frozenset({
    "the_crossing",
    "the_span",
    "turned_compass",
    "lantern_wakes",
    "lantern_door",
    "lantern_teaching",
    "loom_opens",
    "close_it_upstairs",
})


def grind_one(checkpoint: str, budget: int, bank: str) -> dict:
    live = _godot_live()
    if live:
        return {
            "ok": False,
            "error": "godot_live",
            "note": live,
            "checkpoint": checkpoint,
        }
    seat = "grind_%s" % checkpoint
    start = ps.cmd_start(seat, fresh=True, checkpoint=checkpoint)
    if not start.get("ok"):
        return {"ok": False, "checkpoint": checkpoint, "error": start}
    st = ps._load_state(seat)
    c = ps._client(seat)

    def t(action, **kw):
        return ps._turn(seat, st, c, action, **kw)

    presses: list[str] = []
    golds: list[str] = []
    lie = ""
    stop = ""
    flags0: list[str] = []
    flags1: list[str] = []
    axes: list = []
    last_gold = ""
    stuck = 0

    try:
        flags_r = t("story_flags")
        flags_raw = flags_r.get("flags_fired") or flags_r.get("story_flags") or {}
        if isinstance(flags_raw, dict):
            flags0 = sorted(str(k) for k in flags_raw.keys())
        elif isinstance(flags_raw, list):
            flags0 = [str(x) for x in flags_raw]
        ad = t("atom_diversity")
        axes = list((ad.get("per_biome_axes") or {}).get("Village") or [])
        seated = mill_seated(axes)
        if not axes:
            glance = t("plot_glance")
            axes = [
                str(p.get("axis") or "")
                for p in (glance.get("plots") or [])
                if isinstance(p, dict)
                and str(p.get("biome", "")) == "Village"
                and p.get("axis")
            ]
            seated = mill_seated(axes)

        # Match dump: leftover overlay is not farm gold. Bare-field ESC
        # opens Z, so only unwind when the stack is already a room.
        # Story/X is the Arc chord — do not ESC it before I/R.
        stack = t("ui_stack")
        if int(stack.get("size") or 0) > 1:
            farm0 = _lines(t("overlay_text", under="ActFilament"))
            blob0 = " | ".join(farm0)
            if "ACCEPT" in blob0.upper() or (
                "ARC" in blob0.upper() and "[I]" in blob0.upper()
            ):
                pass
            else:
                t("press_key", key="escape", settle_frames=20)

        for i in range(max(1, budget)):
            # Do not ESC every turn — that closes Market and freezes farm
            # gold on [C]ontracts (w417 grind). Follow ActFilament in-room.
            farm = _lines(t("overlay_text", under="ActFilament"))
            blob = farm_gold(" | ".join(farm))
            # Load toasts leftover unsigned Arc before the banner poll
            # paints READY Claim. Wait one beat rather than mill [X].
            if i == 0 and (
                not farm or "THEN ARC" in blob.upper()
            ) and "CLAIM" not in blob.upper():
                for _ in range(24):
                    time.sleep(0.25)
                    farm = _lines(t("overlay_text", under="ActFilament"))
                    blob = farm_gold(" | ".join(farm))
                    if farm and "CLAIM" in blob.upper():
                        break
                    if farm and "THEN ARC" not in blob.upper():
                        break
            if not farm:
                farm = _lines(t("overlay_text", under="HintToastStack"))
                blob = farm_gold(" | ".join(farm))
            golds.append(blob)
            lie = gold_is_lie(blob, seated, flags0)
            if lie:
                stop = "lie"
                break
            key, shift = first_press(blob)
            if key == "escape" and presses and presses[-1] == "x":
                # X opened Story. Arc chord is I then R, not ESC ping-pong.
                key, shift = "i", False
            if key == "r" and "accept" in blob.lower() \
                    and "claim" not in blob.lower():
                # Arc [R] Accept needs the OPEN row (GHJKL;). Gold names
                # the waiting leftover: ▸ [R] Accept the [L] Teaching.
                # Blind G signed Sign and Settle while Fill the Urn sat on L.
                row = accept_row_key(blob)
                if not presses or presses[-1] != row:
                    key, shift = row, False
            if key == "r" and "jolt" in blob.lower() \
                    and (not presses or presses[-1] != "g"):
                # Spark hat keeps sticky focus; spark_north still no-ops
                # until G reseats the plot ring. Probe 4,g,r fired; 4,r mashed.
                key, shift = "g", False
            if key == "e" and "superpose" in blob.lower() \
                    and "urn" in blob.lower() \
                    and "e" in presses:
                # One Superpose seeds the urn gate. Remashing E is H²=I.
                key, shift = "8", False
            if not key:
                t("press_key", key="escape", settle_frames=8)
                stop = "no_followable_key"
                break
            if (
                len(presses) >= 8
                and set(presses[-8:]) <= {"c", "escape"}
                and "c" in presses[-8:]
                and "escape" in presses[-8:]
            ):
                lie = "banner_c_esc_pong"
                stop = "lie"
                break
            if blob == last_gold:
                stuck += 1
            else:
                stuck = 0
            last_gold = blob
            # Market [Q] Refresh reprints the same gold while the stall
            # rerolls. Freeze at 8 is a field lie; Refresh freeze is budget.
            # Fast-Fwd / Superpose / ripen mash is a mill lie: one Ace F
            # ripens, one Superpose seeds. Freeze at 2 so the parent folds.
            freeze_at = budget if (
                "refresh" in blob.lower()
                or "accept the teaching" in blob.lower()
                or "page for" in blob.lower()
            ) else 8
            blob_l = blob.lower()
            if (
                "fast-fwd" in blob_l
                or "superpose" in blob_l
                or "ripens" in blob_l
                or "the urn fills" in blob_l
                or "the bridge holds" in blob_l
                or "fades" in blob_l
                or "superposition holds" in blob_l
                or "collapse the rose" in blob_l
            ):
                freeze_at = 2
            if stuck >= freeze_at:
                stop = "gold_frozen"
                break
            kw = {"key": key, "settle_frames": 12}
            if "fast-fwd" in blob.lower() or "ripens" in blob.lower() \
                    or "fades" in blob.lower():
                # Ace F is 4 closed phrames. the_gray Bath needs open
                # physics_process so the watermark and T₂ actually move.
                kw["settle_frames"] = 60
            if shift:
                kw["shift"] = True
            r = t("press_key", **kw)
            presses.append(("%s+shift" % key) if shift else key)
            if isinstance(r, dict) and r.get("error") == "press_cap":
                stop = "press_cap"
                break
            ad = t("atom_diversity")
            axes = list((ad.get("per_biome_axes") or {}).get("Village") or [])
            if not axes:
                glance = t("plot_glance")
                axes = [
                    str(p.get("axis") or "")
                    for p in (glance.get("plots") or [])
                    if isinstance(p, dict)
                    and str(p.get("biome", "")) == "Village"
                    and p.get("axis")
                ]
            seated = mill_seated(axes)

        flags_r = t("story_flags")
        flags_raw = flags_r.get("flags_fired") or flags_r.get("story_flags") or {}
        if isinstance(flags_raw, dict):
            flags1 = sorted(str(k) for k in flags_raw.keys())
        elif isinstance(flags_raw, list):
            flags1 = [str(x) for x in flags_raw]
        # w479: biome [U] StarterForest is not Commitments Deliver.
        # Do not bank lanternfall/loom flags onto a timber_rhythm wall.
        new_flags = set(flags1) - set(flags0)
        spine_moved = bool(new_flags - OFF_WALL_FLAGS)
        delivered = any(
            "deliver" in str(g).lower() and "abandon" not in str(g).lower()
            for g in golds
        )
        # Open the Bank: Incorporate spends a berry without a FLAG.
        # Bank-on-FLAG only replayed Track→Fast-Fwd→R every sitting
        # (GildedRot consumed_count stayed 0). A 10-key grind must bank
        # the season it just farmed.
        berry_moved = any(
            any(
                w in str(g).lower()
                for w in ("incorporate", "[f] track", "loop ripens")
            )
            for g in golds
        )
        if bank and (spine_moved or delivered or berry_moved):
            # w420: standing grind paid ⚙×6 then 👥×5 but did not bank
            # unless a FLAG fired, so the next sitting replayed the wall.
            ps.cmd_bank(seat, bank)
    finally:
        ps.cmd_stop(seat)

    new_flags = sorted(set(flags1) - set(flags0))
    report = {
        "ok": stop not in ("lie", "no_followable_key") and not lie,
        "checkpoint": checkpoint,
        "presses": presses,
        "n_presses": len(presses),
        "golds": golds[-8:],
        "last_gold": last_gold,
        "stop": stop or "budget",
        "lie": lie,
        "mill_seated": mill_seated(axes),
        "village_axes": axes,
        "new_flags": new_flags,
        "followable": first_press(last_gold)[0],
        "clean": not lie and bool(last_gold),
    }
    return report


def main() -> int:
    args = [a for a in sys.argv[1:] if a]
    if any(a in ("-h", "--help") for a in args):
        print((__doc__ or "").strip())
        return 0
    budget = int(os.environ.get("SW_PRESS_CAP", "40"))
    bank = ""
    names: list[str] = []
    i = 0
    while i < len(args):
        if args[i] == "--budget" and i + 1 < len(args):
            budget = int(args[i + 1])
            i += 2
            continue
        if args[i] == "--bank" and i + 1 < len(args):
            bank = args[i + 1]
            i += 2
            continue
        names.append(args[i])
        i += 1
    if not names:
        names = ["literalist_timber_rhythm_wall"]
    reports = []
    rc = 0
    for name in names:
        print("=== grind %s budget=%s ===" % (name, budget), flush=True)
        r = grind_one(name, budget, bank)
        reports.append(r)
        print(json.dumps(r, ensure_ascii=False, indent=2), flush=True)
        if not r.get("ok"):
            rc = 1
    out = HERE / "waves" / "grind_latest.json"
    out.write_text(json.dumps(reports, ensure_ascii=False, indent=2), encoding="utf-8")
    print("wrote", out, flush=True)
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
