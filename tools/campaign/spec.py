"""Campaign spec loader — shared by build.py, validate.py and the tests.

The spec (Core/Campaign/campaign.json) is the ONE authoring source for the
story. Model: Campaign > Act > Chapter > Beat.

  * A beat OPENS when every beat in `requires` is complete (and its optional
    `trigger` predicates hold — used only for player choices such as which
    village path to take).
  * An offered beat (`offer`) waits on the Arc tab for Accept, then completes
    when its `objective` holds and the player claims it.
  * A beat with no `offer` completes the moment it opens and its objective
    holds (milestones such as First Harvest).
  * `on_open` effects (standing grants, unlocks, world changes) apply when the
    beat opens.

Runtime mapping (build.py): each beat compiles to one story flag. The flag
fires when the beat opens; its arc quest is the offer, scored on the
objective; QuestManager's door rule (a child waits until the parent's arc
quest is claimed or dismissed) is exactly "requires = complete".
"""
from __future__ import annotations

import copy
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC_PATH = ROOT / "Core" / "Campaign" / "campaign.json"

# Post-game campaigns share global act numbers starting here (act = 7 + campaign_act - 1).
POSTGAME_ACT_BASE = 7


class SpecError(ValueError):
    pass


def load(path: Path | None = None) -> dict:
    return json.loads((path or SPEC_PATH).read_text(encoding="utf-8"))


def _lookup(params: dict, ref: str):
    node = params
    for part in ref[1:].split("."):
        if not isinstance(node, dict) or part not in node:
            raise SpecError(f"unknown param {ref!r}")
        node = node[part]
    if isinstance(node, dict):
        raise SpecError(f"param {ref!r} names a group, not a value")
    return node


_INTERP = re.compile(r"\{(\$[A-Za-z_][\w]*\.[\w.]+)\}")


def _fmt(v) -> str:
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v)


def resolve(obj, params: dict):
    """Deep-copy obj with every "$group.name" string replaced by its param value,
    and every "{$group.name}" inside longer text (hints, beat prose) replaced by
    the value's text — so a hint can never quote a stale threshold."""
    if isinstance(obj, dict):
        return {k: resolve(v, params) for k, v in obj.items()}
    if isinstance(obj, list):
        return [resolve(v, params) for v in obj]
    if isinstance(obj, str):
        if obj.startswith("$") and len(obj) > 1 and "." in obj and " " not in obj:
            return _lookup(params, obj)
        if "{$" in obj:
            return _INTERP.sub(lambda m: _fmt(_lookup(params, m.group(1))), obj)
    return obj


def global_act(campaign: dict, act: dict) -> int:
    if campaign.get("kind") == "postgame":
        return POSTGAME_ACT_BASE + int(act["act"]) - 1
    return int(act["act"])


def iter_beats(spec: dict, resolved: bool = True):
    """Yield (campaign, act, chapter, beat) in reading order. Beats are resolved
    (params substituted) copies when resolved=True."""
    params = spec.get("params", {})
    for camp in spec["campaigns"]:
        for act in camp["acts"]:
            for ch in act["chapters"]:
                for b in ch.get("beats", []):
                    yield camp, act, ch, (resolve(b, params) if resolved else b)


def tutorial_steps(spec: dict) -> list:
    for camp in spec["campaigns"]:
        for act in camp["acts"]:
            for ch in act["chapters"]:
                if ch.get("kind") == "tutorial":
                    return copy.deepcopy(ch["steps"])
    return []


def tutorial_chapter(spec: dict) -> dict:
    for camp in spec["campaigns"]:
        for act in camp["acts"]:
            for ch in act["chapters"]:
                if ch.get("kind") == "tutorial":
                    return ch
    return {}


def beats_by_id(spec: dict) -> dict:
    return {b["id"]: (c, a, ch, b) for c, a, ch, b in iter_beats(spec)}


def ancestors(spec: dict, beat_id: str, index: dict | None = None) -> list:
    """All beats that must be complete before beat_id opens, in a stable
    topological order (parents before children)."""
    index = index or beats_by_id(spec)
    order: list = []
    seen: set = set()

    def visit(bid: str):
        if bid in seen:
            return
        seen.add(bid)
        for r in index[bid][3].get("requires", []):
            visit(r)
        order.append(bid)

    for r in index[beat_id][3].get("requires", []):
        visit(r)
    return order
