#!/usr/bin/env python3
"""Lane A — load a wall save, dump banner/chips/Arc/Charge/Self, stop.

No persona. One Godot. Verdict: is there a single followable key for the
live door, or a HUD lie.

  python3 🍄/🧪/hive/dump_checkpoint.py literalist_the_knot_wall
  python3 🍄/🧪/hive/dump_checkpoint.py earnest_the_knot_wall
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SEAT = HERE.parent  # 🍄/🧪
ROOT = HERE.parents[2]
sys.path.insert(0, str(SEAT))
import player_seat as ps  # noqa: E402


def _first_live_beat(cspec, spec, camp, fired: set) -> tuple:
    """First unfired beat whose requires are all fired. Shared IDs already
    in fired (lantern_door/the_crossing reused from Demos) skip."""
    live = None
    n = 0
    n_fired = 0
    cid = str(camp.get("id") or "")
    for c2, act, ch, beat in cspec.iter_beats(spec):
        if str(c2.get("id") or "") != cid:
            continue
        n += 1
        bid = str(beat.get("id") or "")
        if not bid:
            continue
        if bid in fired:
            n_fired += 1
            continue
        reqs = [str(r) for r in (beat.get("requires") or [])]
        if any(r not in fired for r in reqs):
            continue
        if live is None:
            live = {
                "campaign": cid,
                "act": act.get("act"),
                "act_title": act.get("title"),
                "chapter": ch.get("id"),
                "chapter_title": ch.get("title"),
                "beat": bid,
                "offer": bool(beat.get("offer")),
            }
    return n, n_fired, live


def campaign_progress(flag_names: list) -> dict:
    """Live beat from Core/Campaign/campaign.json. After island_free, the
    first postgame campaign whose opens_after is fired (lanternfall, then
    loom). Not a second walk table."""
    tools = ROOT / "tools"
    if str(tools) not in sys.path:
        sys.path.insert(0, str(tools))
    from campaign import spec as cspec  # noqa: WPS433
    spec = cspec.load()
    fired = {str(x) for x in (flag_names or [])}
    demos = None
    for camp in spec.get("campaigns") or []:
        if str(camp.get("id") or "") == "demos":
            demos = camp
            break
    n_demos, n_fired, live = (0, 0, None)
    if demos:
        n_demos, n_fired, live = _first_live_beat(cspec, spec, demos, fired)
    ending = str((demos or {}).get("ending") or "")
    ending_fired = bool(ending) and ending in fired
    demos_block = {
        "id": "demos",
        "ending": ending,
        "ending_fired": ending_fired,
        "beats": n_demos,
        "fired": n_fired,
        "live": live,
    }
    if ending_fired:
        for camp in spec.get("campaigns") or []:
            if str(camp.get("kind") or "") != "postgame":
                continue
            gate = str(camp.get("opens_after") or "")
            if gate and gate not in fired:
                continue
            n, nf, plive = _first_live_beat(cspec, spec, camp, fired)
            if plive is None:
                continue
            out = {
                "id": str(camp.get("id") or ""),
                "ending": str(camp.get("ending") or ""),
                "ending_fired": str(camp.get("ending") or "") in fired,
                "beats": n,
                "fired": nf,
                "live": plive,
                "opens_after": gate,
                "demos": demos_block,
            }
            return out
    return demos_block


def _lines(r) -> list:
    out = []
    for x in (r.get("lines") or []):
        tx = str(x.get("text", "") if isinstance(x, dict) else x).strip()
        if tx:
            out.append(tx)
    return out


def _keys_named(blob: str) -> list:
    return re.findall(r"\[([A-Z0-9;,'\.\-\]]+)\]", blob.upper())


def dump_one(checkpoint: str, presses: list | None = None, farm_only: bool = False) -> dict:
    seat = "dump_%s" % checkpoint
    start = ps.cmd_start(seat, fresh=True, checkpoint=checkpoint)
    if not start.get("ok"):
        return {"ok": False, "checkpoint": checkpoint, "error": start}
    st = ps._load_state(seat)
    c = ps._client(seat)

    def t(action, **kw):
        return ps._turn(seat, st, c, action, **kw)

    for key in presses or []:
        t("press_key", key=str(key).lower(), settle_frames=12)

    # Close a leftover overlay. Bare-field ESC opens Z, so do not ESC
    # blindly (dump used to press ESC first and then read System chips).
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
    farm = _lines(t("overlay_text", under="ActFilament"))
    if not farm:
        farm = _lines(t("overlay_text", under="HintToastStack"))
    chips = _lines(t("overlay_text", under="ActionPreviewRow"))
    filament = farm
    confirm = t("confirm_state")
    glance = t("plot_glance")
    slots = t("biome_slots")
    ki = t("known_icons")
    known = ki.get("icons") or ki.get("known_icons") or []
    ad = t("atom_diversity")
    village_axes = list((ad.get("per_biome_axes") or {}).get("Village") or [])
    village_register_eagle = any("🦅" in str(ax) for ax in village_axes)
    flags_r = t("story_flags")
    flags_raw = flags_r.get("flags_fired") or flags_r.get("story_flags") or {}
    if isinstance(flags_raw, dict):
        flag_names = sorted(str(k) for k in flags_raw.keys())[:80]
    elif isinstance(flags_raw, list):
        flag_names = [str(x) for x in flags_raw][:80]
    else:
        flag_names = []
    berries = t("berry_state", biome="BloodLedger")
    berry_count = int(berries.get("consumed_count") or 0)
    rs = t("resource_snapshot")
    wallet = rs.get("resources") or rs.get("snapshot") or {}
    if not isinstance(wallet, dict):
        wallet = {}
    try:
        wolf = int(float(wallet.get("🐺") or 0))
    except (TypeError, ValueError):
        wolf = 0
    try:
        sprout = int(float(wallet.get("🌱") or 0))
    except (TypeError, ValueError):
        sprout = 0
    try:
        skull = int(float(wallet.get("💀") or 0))
    except (TypeError, ValueError):
        skull = 0
    try:
        hammer = int(float(wallet.get("🔨") or 0))
    except (TypeError, ValueError):
        hammer = 0
    try:
        eagle = int(float(wallet.get("🦅") or 0))
    except (TypeError, ValueError):
        eagle = 0
    try:
        rabbit = int(float(wallet.get("🐇") or 0))
    except (TypeError, ValueError):
        rabbit = 0
    try:
        desert = int(float(wallet.get("🏜") or wallet.get("🏜️") or 0))
    except (TypeError, ValueError):
        desert = 0
    try:
        fire = int(float(wallet.get("🔥") or 0))
    except (TypeError, ValueError):
        fire = 0
    village_bs = t("berry_state", biome="Village")
    village_nq = len(village_bs.get("qubits") or [])
    try:
        village_berries = int(village_bs.get("consumed_count") or 0)
    except (TypeError, ValueError):
        village_berries = 0
    tabs = [{"key": s.get("key"), "biome": s.get("biome"),
             "orb_center": s.get("orb_center")}
            for s in (slots.get("slots") or []) if s.get("biome")]
    plots = []
    for p in (glance.get("plots") or [])[:42]:
        if not isinstance(p, dict):
            continue
        plots.append({
            "key": p.get("key") or p.get("ring_key"),
            "axis": p.get("axis"),
            "empty": p.get("empty"),
            "biome": p.get("biome"),
        })
    # atom_diversity.per_biome_axes is often empty while plot_glance
    # already names Village 💰⚙. S3 mill_seated reads this field.
    if not village_axes:
        village_axes = [
            str(p.get("axis") or "")
            for p in plots
            if str(p.get("biome", "")) == "Village" and p.get("axis")
        ]
    village_register_eagle = any("🦅" in str(ax) for ax in village_axes)
    ck = t("clickables")
    buttons = ck.get("clickables") if isinstance(ck.get("clickables"), list) else []
    off = []
    for b in buttons:
        center = b.get("center") or []
        if isinstance(center, list) and len(center) >= 2:
            try:
                x, y = int(center[0]), int(center[1])
            except (TypeError, ValueError):
                continue
            if x < 0 or y < 0:
                off.append({"name": b.get("name"), "label": b.get("label"),
                            "center": [x, y]})

    arc, charge, self_tab = [], [], []
    farm_after, chips_after = farm, chips
    if not farm_only:
        t("press_key", key="x", settle_frames=10)
        t("press_key", key="i", settle_frames=10)
        arc = _lines(t("overlay_text", under="ControlsOverlay"))
        t("press_key", key="u", settle_frames=10)
        charge = _lines(t("overlay_text", under="ControlsOverlay"))
        t("press_key", key="t", settle_frames=10)
        self_tab = _lines(t("overlay_text", under="ControlsOverlay"))
        t("press_key", key="escape", settle_frames=10)
        farm_after = _lines(t("overlay_text", under="ActFilament"))
        chips_after = _lines(t("overlay_text", under="ActionPreviewRow"))

    ps.cmd_stop(seat)

    # Overlay recapture after X/U/T/ESC often stays on the overlay cue.
    # Field filament + chips are the live door (w264 dump: farm_after
    # was "ESC closes" while filament was [F] Track and followable_key
    # stole chip Q Trim).
    farm_for_keys = farm
    after_join = " | ".join(farm_after)
    first_join = " | ".join(farm)
    # First ActFilament poll can land before READY Claim / live plant paints.
    if not farm_for_keys and farm_after:
        farm_for_keys = farm_after
    first_keys = _keys_named(first_join)
    # w338: first ActFilament was [5] Icon while Village L already 🦅🐇;
    # after overlay settle gold named [L] 🦅. Prefer the field mill.
    if "🦅" in after_join and "ICON" in first_join.upper():
        farm_for_keys = farm_after
    # w479: first ActFilament [5] Icon, after overlay ▸ [L] for 🐇 0/1.
    # Keep the Forge berry stole Icon; millwright 🐇 is the field mill.
    if "🐇" in after_join and "ICON" in first_join.upper():
        farm_for_keys = farm_after
    # Banked dump: first filament [O] Lanternfall, after overlay [L] 🐇.
    # Field millwright is the door; leftover horn/lamp is a lie.
    if "island_free" not in flag_names and "🐇" in after_join and (
            first_keys[:1] == ["O"] or "LANTERNFALL" in first_join.upper()):
        farm_for_keys = farm_after
    # READY Gear-Bench: load toasts leftover unsigned Arc ([X] then Arc [I])
    # while ActFilament after overlay settle is [J]/[C] then [R] Claim.
    # Claim is the mill; leftover catalog toasts are not a second gold.
    if "CLAIM" in after_join.upper() and (
            "THEN ARC" in first_join.upper() or first_keys[:1] == ["X"]):
        farm_for_keys = farm_after
    # w352 dump: hat already captain, first gold ▸ [7] Captain, after
    # overlay ▸ [R] Add Biome — FreshwaterSpring. Prefer the field mill.
    if "ADD BIOME" in after_join.upper() and first_keys[:1] == ["7"] \
            and "CULL" not in first_join.upper() and "ADD" not in first_join.upper():
        farm_for_keys = farm_after
    farm_blob = " | ".join(farm_for_keys)
    start_blob = " | ".join(filament)
    chip_blob = " | ".join(chips)
    farm_keys = _keys_named(farm_blob)
    chip_keys = _keys_named(chip_blob)
    lies = []
    if not farm_for_keys:
        lies.append("banner_empty")
    if off:
        lies.append("off_screen_clickables")
    wind = "WIND TWICE" in " ".join(arc + charge).upper()
    if wind and "CONTRACTS" in (farm_blob + " " + start_blob).upper():
        lies.append("market_steal_while_wind_twice")
    charge_blob = " ".join(charge).upper()
    arc_blob = " ".join(arc).upper()
    if "ACCEPT ON ARC" in charge_blob and (
            "HASN'T OPENED" in arc_blob or "HAS NOT OPENED" in arc_blob):
        lies.append("empty_charge_named_accept")
    if "ADD BIOME" in farm_blob.upper() and "CULL FIRST" in chip_blob.upper():
        lies.append("banner_add_biome_chip_cull_first")
    if "EXPLORE" in farm_blob.upper() and "FAST-FWD" in chip_blob.upper():
        lies.append("banner_explore_chip_fastfwd")
    if "TRACK" in farm_blob.upper() and "FAST-FWD" in chip_blob.upper():
        lies.append("banner_track_chip_fastfwd")
    if "[Y]" in farm_blob and "MARKET" in farm_blob.upper():
        for tab in tabs:
            if str(tab.get("key")) == "Y" and str(tab.get("biome")) == "Village":
                lies.append("banner_market_y_is_village_tab")
                break
    if "STRIKE" in farm_blob.upper() and "EXPLORE" in chip_blob.upper() \
            and "STRIKE" not in chip_blob.upper():
        lies.append("banner_strike_chip_explore")
    if "NEEDS " in farm_blob.upper() and not farm_keys:
        lies.append("cost_message_no_key")
    if "INCORPORATE" in farm_blob.upper() and "TRACK FIRST" in chip_blob.upper():
        lies.append("banner_incorporate_chip_track_first")
    after_blob = " | ".join(farm_after).upper()
    if (("THEN ARC" in farm_blob.upper() or ("ARC" in farm_blob.upper() and "X" in farm_keys)
            or "THEN ARC" in after_blob or ("ARC" in after_blob and "X" in _keys_named(after_blob)))
            and ("HASN'T OPENED" in arc_blob or "HAS NOT OPENED" in arc_blob)):
        lies.append("banner_arc_empty")
    if "A NEW WORD" in farm_blob.upper() and known:
        named = farm_keys[0] if farm_keys else ""
        biome_here = str(confirm.get("active_biome") or "")
        north_here = ""
        for p in plots:
            if str(p.get("key", "")).upper() == named and str(p.get("biome", "")) == biome_here:
                axis = str(p.get("axis") or "")
                if axis:
                    north_here = axis[0]
                break
        if north_here:
            for ic in known:
                if str(ic.get("north", "")) == north_here or str(ic.get("south", "")) == north_here:
                    lies.append("banner_new_word_already_yours")
                    break
    if berry_count >= 2 and "TRACK" in farm_blob.upper() \
            and "VILLAGE" not in farm_blob.upper() and "PLANT" not in farm_blob.upper() \
            and "HOLD THE COMMONS" not in charge_blob:
        lies.append("banner_ledger_berry_done")
    hat = str(confirm.get("current_frame") or confirm.get("hat") or "").lower()
    village_empty = False
    for p in plots:
        if str(p.get("key", "")).upper() == "G" and str(p.get("biome", "")) == "Village":
            if not p.get("axis") or p.get("empty"):
                village_empty = True
            break
    if hat == "ace" and "[5]" in farm_blob and "ICON" in farm_blob.upper() \
            and "GATHER" not in farm_blob.upper() and "STRIKE" not in farm_blob.upper() \
            and "🐺" not in farm_blob and "INCORPORATE" not in farm_blob.upper() \
            and not village_empty and village_berries >= 5 \
            and farm_keys[:1] != ["5"]:
        lies.append("banner_ace_icon_pingpong")
    spring_seated = any(str(t.get("biome") or "") == "FreshwaterSpring" for t in tabs)
    blood_seated = any(str(t.get("biome") or "") == "BloodLedger" for t in tabs)
    if ("MARKET" in farm_blob.upper() or "CONTRACTS" in farm_blob.upper()) \
            and "🧊" in (farm_blob + start_blob) and not spring_seated:
        lies.append("banner_market_ice_before_spring")
    if ("MARKET" in farm_blob.upper() or farm_keys[:1] == ["C"]) \
            and not blood_seated and "BLOODLEDGER" not in farm_blob.upper() \
            and "CLAIM" not in farm_blob.upper() \
            and not ("pond_depths" in flag_names and spring_seated):
        lies.append("banner_contracts_without_bloodledger")
    village_has_eagle = False
    for p in plots:
        if str(p.get("biome", "")) != "Village":
            continue
        axis = str(p.get("axis") or "")
        if "🦅" in axis:
            village_has_eagle = True
            break
    if village_has_eagle and "[5]" in farm_blob and "ICON" in farm_blob.upper() \
            and "🦅" not in farm_blob:
        lies.append("banner_icon_while_eagle_seated")
    if village_has_eagle and not village_register_eagle:
        lies.append("viz_eagle_not_in_register")
    if village_register_eagle and "village_path_watched" not in flag_names \
            and "eagle_overhead" in flag_names and "village_identity" in flag_names \
            and village_berries >= 9:
        lies.append("eagle_in_register_flag_unfired")
    if village_empty and "GATHER" in farm_blob.upper() \
            and "ICON" not in farm_blob.upper() and "PLANT" not in farm_blob.upper():
        lies.append("banner_gather_on_empty")
    # w415: gold ▸ [H] empty plot while Village H is 💰⚙.
    if "EMPTY PLOT" in farm_blob.upper() and farm_keys:
        named = str(farm_keys[0]).upper()
        for p in plots:
            if str(p.get("biome", "")) != "Village":
                continue
            if str(p.get("key", "")).upper() != named:
                continue
            axis = str(p.get("axis") or "")
            if axis and not p.get("empty"):
                lies.append("banner_empty_plot_occupied")
            break
    # Mill in the ground (⚙ / 🏭 / 💰⚙). Gold must mill [C]ontracts, not
    # another empty / Icon plant / empty Arc.
    mill_seated = any(("⚙" in str(ax) or "🏭" in str(ax)) for ax in village_axes)
    blob_u = farm_blob.upper()
    if mill_seated:
        live_factory = "🏭" in farm_blob
        if "EMPTY PLOT" in blob_u or "GATHER TO EMPTY" in blob_u:
            if not live_factory and "banner_empty_plot_occupied" not in lies:
                lies.append("banner_plant_while_mill_seated")
        if farm_keys[:1] == ["5"] and "ICON" in blob_u:
            if not live_factory and "island_free" not in flag_names:
                lies.append("banner_icon_plant_while_mill_seated")
        # Hold Commerce / Granary teaching stays on Arc after ⚙ seats.
        # Empty catalog + gold [X] is the lie. A live Arc row is the door.
        if farm_keys[:1] == ["X"] or "THEN ARC" in blob_u:
            if "HASN'T OPENED" in arc_blob or "HAS NOT OPENED" in arc_blob \
                    or "PLANT THE MILL" in arc_blob:
                lies.append("banner_empty_arc_while_mill_seated")
        # w463: ActFilament was Village [Y] while Arc NOW was leftover
        # Plant the Mill / empty plot. Dump must fail that HUD.
        if "PLANT THE MILL" in arc_blob or (
                "EMPTY PLOT" in arc_blob and "PLANT" in arc_blob):
            lies.append("arc_plant_while_mill_seated")
        if "PLANT THE MILL" in blob_u:
            lies.append("banner_plant_the_mill_while_mill_seated")
        if rabbit < 1 and "GATHER FOR" in blob_u:
            lies.append("banner_gather_unpaid_rabbit")
        people = int(float(wallet.get("👥") or 0))
        if people < 1 and "STRIKE" in blob_u:
            # w479: 🦅/🧺/🍞 wells Strike without 👥. Village L 🦅🐇 is
            # millwright 🐇, not the Forest 👥 catch-22.
            well_axes = any(
                ("🦅" in str(ax) or "🧺" in str(ax) or "🍞" in str(ax))
                for ax in village_axes
            )
            if not (well_axes and "🐇" in farm_blob and "👥" not in farm_blob):
                lies.append("banner_strike_without_people")
        if people < 1 and "GATHER FOR" in blob_u and "👥" in farm_blob:
            lies.append("banner_gather_unmeasured_people")
        # w433: mill seated, 🐇=0, farm gold [C] while Market ESC for Refresh.
        if rabbit < 1 and farm_keys[:1] == ["C"]:
            lies.append("banner_contracts_while_rabbit_short")
        lantern_hunt = "Lanternfall" in farm_blob and "cull" not in farm_blob.lower()
        # After island_free, lanternfall IS the live campaign. Mill-seated
        # Village ⚙ must not brand honest Chart/hold-lamp gold a lie.
        if "island_free" not in flag_names:
            if rabbit < 1 and (farm_keys[:1] == ["O"] or lantern_hunt):
                lies.append("banner_lantern_while_rabbit_short")
            if farm_keys[:1] == ["O"] or lantern_hunt:
                lies.append("banner_lantern_while_mill_seated")
        if rabbit < 1 and (
            farm_keys[:1] == ["U"] or "StarterForest" in farm_blob
        ):
            lies.append("banner_forest_while_rabbit_short")
    if mill_seated and "mill_wakes" in flag_names \
            and ("HASN'T OPENED" in arc_blob or "HAS NOT OPENED" in arc_blob) \
            and ("ICON" in blob_u or "GATHER" in blob_u):
        lies.append("arc_catalog_empty_while_mill_runs")
    biome_now = str(confirm.get("active_biome") or "")
    biome_empty = False
    for p in plots:
        if str(p.get("biome", "")) != biome_now:
            continue
        if p.get("empty") or not p.get("axis"):
            biome_empty = True
            break
    if "PLANT" in farm_blob.upper() and "TRIM" not in farm_blob.upper() \
            and not biome_empty and "TRIM" in chip_blob.upper():
        lies.append("banner_plant_at_qubit_cap")
    if "TRIM" in farm_blob.upper() and wolf < 13:
        lies.append("banner_trim_wolf_short")
    if "PLANT" in farm_blob.upper() and sprout < 5:
        lies.append("banner_plant_sprout_short")
    if "PICK A SLEEPING" in farm_blob.upper():
        lies.append("banner_pick_sleeping_no_key")
    if "CANNOT HARVEST" in farm_blob.upper():
        lies.append("banner_sprout_blocked_ace")
    pressed = [str(x).lower() for x in (presses or [])]
    # Strike for 🌱 is the even-coin AFTER Superpose. Naming it before H
    # (no e in this dump) still pays 💀.
    if "STRIKE" in farm_blob.upper() and "🌱" in farm_blob and "e" not in pressed:
        lies.append("banner_strike_sprout_death_seed")
    if biome_now == "Lanternfall" and "🌱" in farm_blob \
            and "STARTERFOREST" not in farm_blob.upper():
        lies.append("banner_sprout_on_lanternfall")
    if "SUPERPOSE" in farm_blob.upper() and "e" in pressed:
        lies.append("banner_superpose_after_hadamard")
    hammer_known = False
    for ic in known:
        if str(ic.get("north", "")) == "🔨" or str(ic.get("south", "")) == "🔨":
            hammer_known = True
            break
    demos_has_hammer = False
    for p in plots:
        if str(p.get("biome", "")) != "TheDemos":
            continue
        axis = str(p.get("axis") or "")
        if "🔨" in axis:
            demos_has_hammer = True
            break
    if hammer_known and not demos_has_hammer:
        lies.append("learned_hammer_not_in_demos")
    if wolf < 13 and "TRIM" in chip_blob.upper() and "TRIM" not in farm_blob.upper():
        lies.append("chip_trim_wolf_short")
    charge_blob = " ".join(charge).upper()
    if "HOLD THE COMMONS" in charge_blob and "ACTIVE" in charge_blob \
            and "ARC" in farm_blob.upper() and "TRACK" not in farm_blob.upper() \
            and "💧" not in farm_blob:
        lies.append("banner_arc_while_commons_active")
    if "READY" in charge_blob and "ARC" in farm_blob.upper() \
            and "CHARGE" not in farm_blob.upper():
        lies.append("banner_arc_while_charge_ready")
    if "INCORPORATE" in farm_blob.upper() and "PLANT" in chip_blob.upper() \
            and "INCORPORATE" not in chip_blob.upper():
        lies.append("banner_incorporate_chip_plant")
    if "FAST-FWD" in farm_blob.upper() and "ARC" in chip_blob.upper() \
            and "FAST" not in chip_blob.upper():
        lies.append("banner_fastfwd_chip_arc")
    if "TRACK" in farm_blob.upper() and "ARC" in chip_blob.upper() \
            and "TRACK" not in chip_blob.upper():
        lies.append("banner_track_chip_arc")
    if "FAST-FWD" in farm_blob.upper() and "EXPLORE" in chip_blob.upper() \
            and "FAST" not in chip_blob.upper():
        lies.append("banner_fastfwd_chip_explore")
    if "ESC" in farm_blob.upper() and "MORE" in chip_blob.upper():
        lies.append("banner_esc_picker_more")
    if "PICK A WORD" in farm_blob.upper() and "🏰" in chip_blob:
        lies.append("banner_pick_a_word_mill")
    arc_join = " ".join(arc)
    if "📜" in arc_join and "BLOODLEDGER" in farm_blob.upper():
        lies.append("banner_field_while_arc_unsigned")
    # Unpayable [Q] Abandon is a chip, not the mill. Live campaign beat /
    # unsigned Arc outranks a 👥 2/254 stall.
    if "ABANDON" in farm_blob.upper():
        lies.append("banner_abandon")
    if "READY" in " ".join(charge).upper() and "CHARGE" not in farm_blob.upper() \
            and "CLAIM" in (farm_blob + start_blob).upper() and "CONTRACTS" in (farm_blob + start_blob).upper():
        lies.append("ready_knot_named_as_market_claim")
    if "R" in farm_keys and "R" in chip_keys:
        if "CLAIM" in farm_blob.upper() and "STRIKE" in chip_blob.upper():
            if farm_keys[:1] not in (["X"], ["C"], ["Y"]):
                lies.append("banner_R_claim_chip_R_strike")
        if "PLANT" in farm_blob.upper() and "TRACK FIRST" in chip_blob.upper():
            lies.append("banner_R_plant_chip_R_track_first")
    if "TRACK" in farm_blob.upper() and "[R] Plant" in chip_blob \
            and "TRACK FIRST" not in chip_blob.upper() \
            and "Track" not in chip_blob:
        lies.append("banner_track_chip_plant_empty")
    water_known = False
    for ic in known:
        if str(ic.get("north", "")) == "💧":
            water_known = True
            break
    if water_known and "💧" in farm_blob and ";" in farm_keys \
            and "INCORPORATE" not in farm_blob.upper() \
            and "TRACK" not in farm_blob.upper() \
            and hat == "ace":
        lies.append("banner_commons_pin_water")
    if "HOLD THE COMMONS" in charge_blob and "READY" in charge_blob \
            and "TRACK" in farm_blob.upper():
        lies.append("banner_track_while_charge_ready")
    if "NO CHARGE YET" in charge_blob and "ACCEPT" in arc_blob \
            and "CHARGE" in farm_blob.upper():
        lies.append("banner_charge_while_arc_accept")
    if "CHARGE" in farm_blob.upper() and "NO CHARGE YET" in charge_blob:
        lies.append("banner_charge_empty")
    # w350: Forest [U] for 🦅 15/21 then gold named [P] BloodLedger.
    eagle_have = re.search(r"🦅 (\d+)/21", farm_blob)
    if eagle_have and int(eagle_have.group(1)) < 21 and "BLOODLEDGER" in farm_blob.upper():
        lies.append("banner_bloodledger_while_eagle_short")
    # w355: gold Forest [U] 🦅 while Forest H empty and Village L is 🦅🐇.
    forest_h_empty = False
    village_eagle = False
    for p in plots:
        if p.get("key") == "H" and "Forest" in str(p.get("biome", "")) and not p.get("axis"):
            forest_h_empty = True
        if p.get("key") == "L" and str(p.get("biome")) == "Village" and "🦅" in str(p.get("axis") or ""):
            village_eagle = True
    if forest_h_empty and village_eagle and "STARTERFOREST" in farm_blob.upper() and "🦅" in farm_blob:
        lies.append("banner_forest_eagle_while_h_empty")
    # w362/w363: on Village L 🦅🐇 gold named [P] FreshwaterSpring.
    # Banner often omits 🦅 n/21, so wallet count is the lie detector.
    eagle_short = eagle < 21 or (eagle_have is not None and int(eagle_have.group(1)) < 21)
    if village_eagle and eagle_short \
            and ("FRESHWATERSPRING" in farm_blob.upper() or farm_keys[:1] == ["P"]) \
            and "[P]" in farm_blob:
        lies.append("banner_spring_while_village_eagle")
    # w355: pond_depths fired, FreshwaterSpring seated, gold still mills
    # Forest 🦅 n/21. That was the Add Biome cost. Live mill is Claim.
    if "pond_depths" in flag_names and spring_seated \
            and "STARTERFOREST" in farm_blob.upper() and "🦅" in farm_blob:
        lies.append("banner_stale_forest_eagle_after_spring")
    # A chord [X] then [U] then [R] is one followable path.
    # w358: [C] then [U] Commitments — [R] Claim is one path, not many keys.
    # campaign spec mill: Stay Yourself — 📖 [X], Arc [I], Accept [R]
    chord_c_claim = farm_keys[:1] == ["C"] and "COMMITMENTS" in farm_blob.upper()
    chord_arc_accept = (
        set(farm_keys) <= {"X", "I", "R"}
        and "ARC" in farm_blob.upper()
        and "ACCEPT" in farm_blob.upper()
    )
    if farm_keys[:1] == ["X"] and "CHARGE" in farm_blob.upper():
        live_key = "X"
    elif chord_c_claim:
        live_key = "C"
    elif chord_arc_accept:
        live_key = "X"
    elif len(set(farm_keys)) > 2:
        lies.append("banner_many_keys:%s" % ",".join(farm_keys))

    live_key = ""
    if not lies:
        if farm_keys:
            live_key = farm_keys[0]
        elif chip_keys:
            live_key = chip_keys[0]

    spine = None
    try:
        if str(HERE) not in sys.path:
            sys.path.insert(0, str(HERE))
        from spine_recipe import compile_live_from_dump, gold_off_spine
        spine = compile_live_from_dump({
            "flags_fired": flag_names,
            "known_icons": known,
            "village_axes": village_axes,
            "biome_tabs": tabs,
        })
        if gold_off_spine(spine, farm_keys):
            lies.append("gold_off_spine:%s!%s" % (
                (spine or {}).get("id"), farm_keys[0]))
            live_key = ""
    except Exception as exc:
        spine = {"error": str(exc)}

    camp = campaign_progress(flag_names)
    live = camp.get("live") if isinstance(camp.get("live"), dict) else {}
    mill_clean = not lies and bool(live_key)
    return {
        "ok": True,
        "checkpoint": checkpoint,
        "hat": confirm.get("current_frame"),
        "biome": confirm.get("active_biome"),
        "farm_banner": farm,
        "filament": filament,
        "chips": chips,
        "farm_after_overlay": farm_after,
        "biome_tabs": tabs,
        "plots": plots,
        "known_icons": known[:20],
        "village_axes": village_axes,
        "village_register_eagle": village_register_eagle,
        "mill_seated": mill_seated,
        "mill": {
            "schema": "game-mill-dump/0.1",
            "checkpoint": checkpoint,
            "seated": mill_seated,
            "clean": mill_clean,
            "followable_key": live_key,
            "live_beat": live.get("beat"),
            "lies": list(lies),
        },
        "flags_fired": flag_names,
        "blood_berries": berry_count,
        "village_nq": village_nq,
        "village_berries": village_berries,
        "wolf": wolf,
        "sprout": sprout,
        "skull": skull,
        "hammer": hammer,
        "eagle": eagle,
        "rabbit": rabbit,
        "desert": desert,
        "fire": fire,
        "arc": arc[:48],
        "charge": charge[:48],
        "self": self_tab[:24],
        "off_screen": off[:8],
        "farm_keys": farm_keys,
        "chip_keys": chip_keys,
        "lies": lies,
        "followable_key": live_key,
        "spine": spine,
        "campaign": camp,
        "clean": mill_clean,
    }


def main() -> int:
    args = [a for a in sys.argv[1:] if a]
    if any(a in ("-h", "--help") for a in args):
        print((__doc__ or "").strip())
        return 0
    presses: list = []
    names: list = []
    farm_only = False
    i = 0
    while i < len(args):
        if args[i] == "--press" and i + 1 < len(args):
            presses = [p.strip() for p in args[i + 1].split(",") if p.strip()]
            i += 2
            continue
        if args[i] == "--farm-only":
            farm_only = True
            i += 1
            continue
        names.append(args[i])
        i += 1
    if not names:
        names = ["literalist_the_knot_wall", "earnest_the_knot_wall"]
    reports = []
    rc = 0
    for name in names:
        print("=== dump %s presses=%s ===" % (name, presses), flush=True)
        r = dump_one(name, presses, farm_only)
        r["presses"] = presses
        reports.append(r)
        print(json.dumps(r, ensure_ascii=False, indent=2), flush=True)
        if not r.get("ok") or not r.get("clean"):
            rc = 1
    out = HERE / "waves" / "dump_latest.json"
    if any(r.get("ok") for r in reports):
        out.write_text(json.dumps(reports, ensure_ascii=False, indent=2), encoding="utf-8")
        print("wrote", out, flush=True)
    else:
        print("skip dump_latest — no successful dump", flush=True)
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
