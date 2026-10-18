#!/usr/bin/env python3
"""What a start-at-beat fixture must build, read from the spec alone.

The Python twin of Core/Campaign/CampaignFixture.gd's planning half — tests use
it to know what to expect after the `start_at_beat {id}` rig verb.

    python3 tools/campaign/fixture_order.py <beat_id>   # JSON plan for one beat
    python3 tools/campaign/fixture_order.py --chapters  # one representative beat per chapter

Plan fields:
  ancestors      beats that must be complete before <beat> opens, parents first
                 (spec.ancestors — the same DFS CampaignFixture.ancestors runs)
  doors          the ancestors whose arc quest the fixture claims
  charted        biomes an ancestor charts (the fixture loads these, slot cap
                 permitting)
  hats / menus / viz   chrome the spec says is surfaced once <beat> has opened
                 (on_open.unlock of every ancestor and of <beat> itself)
  teachings      icon pairs an ancestor's claim teaches
  auto           <beat> has no offer (it completes the moment it opens)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import spec as S  # noqa: E402

# Biomes a fresh demos_normal run already holds, and the number of biome slots
# (InputBindingRegistry.BIOME_KEYS = T Y U I O P).
SEED_BIOMES = ("TheDemos", "Village", "StarterForest")
BIOME_SLOTS = 6


def _index(spec: dict | None = None) -> dict:
    return S.beats_by_id(spec or S.load())


def ancestors(beat_id: str, spec: dict | None = None) -> list:
    spec = spec or S.load()
    return S.ancestors(spec, beat_id, _index(spec))


def plan(beat_id: str, spec: dict | None = None) -> dict:
    spec = spec or S.load()
    idx = _index(spec)
    if beat_id not in idx:
        raise KeyError(beat_id)
    anc = S.ancestors(spec, beat_id, idx)
    beat = idx[beat_id][3]
    hats, menus, viz, charted, teachings, doors = [], [], [], [], [], []
    for bid in anc + [beat_id]:
        b = idx[bid][3]
        unlock = b.get("on_open", {}).get("unlock", {})
        for kind, out in (("hats", hats), ("menus", menus), ("viz", viz)):
            for name in unlock.get(kind, []):
                if name not in out:
                    out.append(name)
        if bid == beat_id:
            continue
        if b.get("chart") and b["chart"] not in charted:
            charted.append(b["chart"])
        if b.get("offer") is not None:
            doors.append(bid)
            t = b["offer"].get("teaches")
            if t:
                teachings.append(list(t))
    reads = []
    for p in list(beat.get("objective", [])) + list(beat.get("trigger", [])):
        if isinstance(p, dict) and p.get("biome") and p["biome"] not in reads:
            reads.append(p["biome"])
    return {
        "beat": beat_id,
        "campaign": idx[beat_id][0]["id"],
        "act": int(idx[beat_id][1]["act"]),
        "chapter": idx[beat_id][2]["id"],
        "ancestors": anc,
        "doors": doors,
        "charted": charted,
        "expected_loaded": expected_loaded(charted, reads),
        "hats": hats,
        "menus": menus,
        "viz": viz,
        "teachings": teachings,
        "auto": beat.get("offer") is None,
        "has_trigger": bool(beat.get("trigger")),
        "reads_biomes": reads,
    }


def expected_loaded(charted: list, reads: list | None = None) -> list:
    """The charted biomes the fixture can fit in the free slots — those the
    beat reads first, then the most recently charted (CampaignFixture's rule)."""
    free = BIOME_SLOTS - len(SEED_BIOMES)
    order = [b for b in (reads or []) if b in charted]
    order += [b for b in reversed(charted) if b not in order]
    return [b for b in charted if b in order[:free]]


def representative_beats(spec: dict | None = None) -> list:
    """One beat per (non-tutorial) chapter across every campaign: the first
    offered, trigger-free beat in the chapter; else the first auto beat with
    nothing left to do (it opens and completes at once); else its first beat."""
    spec = spec or S.load()
    out = []
    for camp in spec["campaigns"]:
        for act in camp["acts"]:
            for ch in act["chapters"]:
                beats = ch.get("beats", [])
                if ch.get("kind") == "tutorial" or not beats:
                    continue
                pick = next((b for b in beats if b.get("offer") is not None and not b.get("trigger")),
                            None)
                if pick is None:
                    pick = next((b for b in beats if b.get("offer") is None and not b.get("objective")),
                                beats[0])
                out.append(pick["id"])
    return out


def main(argv: list) -> int:
    if not argv:
        print(__doc__)
        return 2
    if argv[0] == "--chapters":
        print(json.dumps(representative_beats(), indent=1))
        return 0
    print(json.dumps(plan(argv[0]), ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
