#!/usr/bin/env python3
"""Compile Core/Campaign/campaign.json into the runtime data files.

    python3 tools/campaign/build.py          # write the generated files
    python3 tools/campaign/build.py --check  # exit 1 if they are stale

Generated (do not hand-edit — tests/test_campaign_spec.py fails if they drift):
  Core/Quests/data/story_flags.json     one story flag per beat
  Core/Quests/data/tutorial_arc.json    the Act-0 lesson chain
  Core/Quests/data/campaign_runtime.json  campaign/act/chapter titles, UI unlock
                                         tables, chartable story biomes, resources
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import spec as S  # noqa: E402

DATA = S.ROOT / "Core" / "Quests" / "data"
OUT_FLAGS = DATA / "story_flags.json"
OUT_TUTORIAL = DATA / "tutorial_arc.json"
OUT_RUNTIME = DATA / "campaign_runtime.json"

OFFER_KEYS = ("body", "hint", "faction", "type", "category", "math_note")


def compile_flag(camp: dict, act: dict, ch: dict, b: dict) -> dict:
    preds = [{"type": "story_flag_set", "id": r} for r in b.get("requires", [])]
    preds += b.get("trigger", [])
    offer = b.get("offer")
    if offer is None:
        preds += b.get("objective", [])
    flag = {
        "id": b["id"],
        "display_name": b["display_name"],
        "act": S.global_act(camp, act),
        "campaign": camp["id"],
        "campaign_act": int(act["act"]),
        "act_title": act["title"],
        "chapter": ch["id"],
        "chapter_title": ch.get("title", ch["id"]),
        "arc_beat": b.get("beat", ""),
    }
    if "conditional_beat" in b:
        flag["conditional_beat"] = b["conditional_beat"]
    flag["predicates"] = preds
    on_open = b.get("on_open", {})
    flag["standing_grants"] = on_open.get("standing", {})
    if offer is not None:
        aq = {k: offer[k] for k in OFFER_KEYS if k in offer}
        aq["state_predicates"] = b.get("objective", [])
        teaches = offer.get("teaches")
        if teaches:
            n, s = teaches
            aq.update({"reward_north": n, "reward_south": s,
                       "reward_icon_north": n, "reward_icon_south": s})
        flag["arc_quest"] = aq
    else:
        flag["arc_quest"] = None
    for k in ("regime_changes", "physics_changes"):
        if k in on_open:
            flag[k] = on_open[k]
    for k in ("branch_group", "ending", "chart", "fired_by"):
        if k in b:
            flag[k] = b[k]
    return flag


def compile_runtime(spec: dict) -> dict:
    unlocks = {"hats": {}, "menus": {}, "viz": {}}
    charts = {}
    campaigns = []
    for camp in spec["campaigns"]:
        acts = []
        for act in camp["acts"]:
            acts.append({
                "act": int(act["act"]),
                "global_act": S.global_act(camp, act),
                "title": act["title"],
                "chapters": [{"id": ch["id"], "title": ch.get("title", ch["id"])}
                             for ch in act["chapters"]],
            })
        campaigns.append({"id": camp["id"], "title": camp["title"], "kind": camp.get("kind", "main"),
                          "status": camp.get("status", "complete"),
                          "ending": camp.get("ending", ""), "acts": acts,
                          "opens_after": camp.get("opens_after", "")})
    for camp, act, ch, b in S.iter_beats(spec):
        unlock = b.get("on_open", {}).get("unlock", {})
        for kind in ("hats", "menus", "viz"):
            for name in unlock.get(kind, []):
                unlocks[kind].setdefault(name, []).append(b["id"])
        if b.get("chart"):
            charts[b["id"]] = b["chart"]
    for kind, table in spec.get("legacy_unlocks", {}).items():
        if kind.startswith("_"):
            continue
        for name, ids in table.items():
            unlocks[kind].setdefault(name, []).extend(i for i in ids if i not in unlocks[kind].get(name, []))
    res = {k: v for k, v in spec.get("resources", {}).items() if not k.startswith("_")}
    return {
        "_generated": "from Core/Campaign/campaign.json by tools/campaign/build.py — do not edit",
        "campaigns": campaigns,
        "unlocks": unlocks,
        "menu_steps": spec.get("menu_steps", {}),
        "charts": charts,
        "chart_cost": spec.get("chart_cost", {}),
        "resources": res,
        "guide": {k: v for k, v in spec.get("guide", {}).items() if not k.startswith("_")},
    }


def compile_all(spec: dict) -> dict:
    flags = [compile_flag(c, a, ch, b) for c, a, ch, b in S.iter_beats(spec)]
    # File order is the Arc tab's documented tiebreak: act order, stable.
    flags.sort(key=lambda f: f["act"])
    tch = S.tutorial_chapter(spec)
    tutorial = {"_generated": "from Core/Campaign/campaign.json by tools/campaign/build.py — do not edit",
                "_doc": tch.get("_doc", ""),
                "steps": S.resolve(tch.get("steps", []), spec.get("params", {}))}
    return {
        OUT_FLAGS: flags,
        OUT_TUTORIAL: tutorial,
        OUT_RUNTIME: compile_runtime(spec),
    }


def dump(obj) -> str:
    return json.dumps(obj, ensure_ascii=False, indent=2) + "\n"


def main(argv: list[str]) -> int:
    spec = S.load()
    outputs = compile_all(spec)
    if "--check" in argv:
        stale = [p for p, obj in outputs.items()
                 if not p.exists() or p.read_text(encoding="utf-8") != dump(obj)]
        for p in stale:
            print(f"stale: {p.relative_to(S.ROOT)} — run python3 tools/campaign/build.py")
        return 1 if stale else 0
    for p, obj in outputs.items():
        p.write_text(dump(obj), encoding="utf-8")
        print(f"wrote {p.relative_to(S.ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
