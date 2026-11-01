"""Campaign partition lint (docs/CAMPAIGN_SPLIT_2026-08-11.md, phase 0).

The campaign is four lanes wearing one act counter; the split's smallest first
step tags every beat with its future campaign — inert metadata until the
per-campaign directories land — and pins the partition so it cannot drift:

  (a) the partition is TOTAL and uses only the three known campaign ids;
  (b) membership follows the split doc's leaves: Lanternfall = the five
      lantern beats + all of What Fades; The Loom = braid_order/braid_word +
      all of What Connects and What Turns; The Demos = everything else;
  (c) exactly one `"ending": true` per campaign (the flag RuntimeMount's
      island_free hardcode becomes when split phase 1 lands);
  (d) every story_flag_set edge resolves INSIDE its campaign — except the
      allowlisted cross-campaign doors below, which are exactly the re-points
      split phases 2.2/2.4 must make when the side campaigns get their own
      openers. The list is a RATCHET: re-point one, remove it here; a NEW
      cross-campaign edge fails immediately.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STORY_FLAGS = ROOT / "Core" / "Quests" / "data" / "story_flags.json"

CAMPAIGNS = {"demos", "lanternfall", "loom"}

LANTERN_BEATS = {"lantern_door", "chain_ends", "lantern_teaching",
                 "lantern_wakes", "chain_flipped"}
LOOM_SPINE = {"braid_order", "braid_word"}

# The six doors between campaigns as shipped (dependent -> prereq). Under the
# split each side campaign needs its own opener; until then these edges are
# the exact re-point work items (doc: "an afternoon bought that knowledge").
TODO_CROSS_CAMPAIGN_EDGES = {
    ("lantern_door", "mill_wakes"),          # lanternfall <- demos (the old act-3 door)
    ("the_crossing", "edge_of_the_enclave"), # lanternfall <- demos (the wet-country door)
    ("braid_order", "village_identity"),     # loom <- demos (the braid lessons' hub gate)
    ("second_loop", "loop_remembers"),       # loom <- demos (needs a new Loom opener)
    ("the_span", "the_crossing"),            # loom <- lanternfall (doc: drop this dep)
    ("turned_compass", "the_crossing"),      # loom <- lanternfall (doc: drop this dep)
}

EXPECTED_ENDINGS = {
    "demos": "island_free",
    "lanternfall": "the_door_stays_open",
    "loom": "close_it_upstairs",
}


def _flags():
    return json.loads(STORY_FLAGS.read_text(encoding="utf-8"))


def _lane(display_name: str) -> str:
    for prefix, lane in (("What Survives", "survives"), ("What Connects", "connects"),
                         ("What Fades", "fades"), ("What Turns", "turns")):
        if display_name.startswith(prefix):
            return lane
    return ""


def _expected_campaign(flag: dict) -> str:
    if flag["id"] in LANTERN_BEATS or _lane(flag["display_name"]) == "fades":
        return "lanternfall"
    if flag["id"] in LOOM_SPINE or _lane(flag["display_name"]) in ("connects", "turns"):
        return "loom"
    return "demos"


def test_partition_is_total_and_known():
    for f in _flags():
        c = f.get("campaign")
        assert c in CAMPAIGNS, f"{f['id']}: campaign={c!r} — partition must be total over {CAMPAIGNS}"


def test_membership_follows_the_split_docs_leaves():
    mismatches = [(f["id"], f.get("campaign"), _expected_campaign(f))
                  for f in _flags() if f.get("campaign") != _expected_campaign(f)]
    assert not mismatches, (
        "campaign membership drifted from the split doc's leaves "
        "(id, tagged, expected): %r" % (mismatches,)
    )


def test_exactly_one_ending_per_campaign():
    endings = {}
    for f in _flags():
        if f.get("ending") is True:
            endings.setdefault(str(f.get("campaign")), []).append(f["id"])
    assert {k: sorted(v) for k, v in endings.items()} == {
        k: [v] for k, v in EXPECTED_ENDINGS.items()
    }, f"endings drifted: {endings}"


def test_story_flag_edges_resolve_in_campaign_except_known_doors():
    flags = _flags()
    campaign_of = {f["id"]: str(f.get("campaign")) for f in flags}
    cross = set()
    for f in flags:
        for p in (f.get("predicates") or []):
            if p.get("type") != "story_flag_set":
                continue
            pid = str(p.get("id"))
            if campaign_of.get(pid) != campaign_of[f["id"]]:
                cross.add((f["id"], pid))
    assert cross == TODO_CROSS_CAMPAIGN_EDGES, (
        "cross-campaign edge drift.\n"
        f"  new (must be re-pointed or allowlisted consciously): {sorted(cross - TODO_CROSS_CAMPAIGN_EDGES)}\n"
        f"  fixed (remove from allowlist): {sorted(TODO_CROSS_CAMPAIGN_EDGES - cross)}"
    )


def test_unlock_table_flags_live_in_the_demos_partition():
    """UIProgression's hat/menu/viz tables must key on Demos beats only —
    after the split a fresh Demos run never fires another campaign's flags,
    and these tables fail CLOSED (a phantom flag is a permanently lost hat).
    turned_compass (VIZ gauge_overlay) is the known exception: the overlay
    belongs to the Loom's compass lesson and MOVES with it in split phase 4;
    until then the viz simply never unlocks in a pure Demos run, which is
    correct (the lesson isn't there either)."""
    import re
    src = (ROOT / "UI" / "Core" / "UIProgression.gd").read_text(encoding="utf-8")
    campaign_of = {f["id"]: str(f.get("campaign")) for f in _flags()}
    allowed_outside = {"turned_compass"}
    for table in ("HAT_UNLOCK_FLAGS", "MENU_UNLOCK_FLAGS"):
        m = re.search(r"const %s\s*:\s*Dictionary\s*=\s*\{(.*?)\n\}" % table, src, re.S)
        assert m, f"{table} moved"
        body = re.sub(r"#[^\n]*", "", m.group(1))
        for rhs in re.findall(r':\s*("[^"]*"|\[[^\]]*\])', body):
            for fid in re.findall(r'"([^"]*)"', rhs):
                if fid == "" or fid in allowed_outside:
                    continue
                assert campaign_of.get(fid) == "demos", (
                    f"{table} keys on {fid!r} ({campaign_of.get(fid)}) — "
                    "a fresh Demos run could never unlock it after the split"
                )
