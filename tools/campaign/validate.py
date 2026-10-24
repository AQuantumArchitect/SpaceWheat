#!/usr/bin/env python3
"""Prove every campaign in Core/Campaign/campaign.json can be played through.

    python3 tools/campaign/validate.py            # errors + warnings, exit 1 on errors
    python3 tools/campaign/validate.py --report   # also print the per-beat supply table

No Godot needed. The checks replay the campaign beat by beat with a SUPPLY
MODEL built from the repo's own data (scenario start, biome/faction/icon
registries, the spec's teachings, plants, charts, grants and unlocks):

  structure   ids unique, requires resolve, no cycles, one root per campaign,
              act order never runs backwards, every ending reachable,
              post-game campaigns open only after the main ending
  verbs       every objective's verb (hat) is unlocked by then
  biomes      every biome an objective names is loaded by then, and every
              non-start story biome has a guaranteed Captain chart beat
  vocabulary  every planted word is known by then; Incorporate is taught
              before any objective counts berries
  supply      every resource a step spends has a live source by then, and a
              rescue offer if it is spent on the critical path
  thresholds  signature / diversity / village-ring gates sit at or below what
              the story makes reachable at that beat (with margin); standing
              ladders ask for at least one and at most `max_deliveries` kept
              deliveries beyond what the story already grants
  one ask     an offered beat's objective is not a copy of its own trigger
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import spec as S  # noqa: E402

ROOT = S.ROOT
VS = "️"


def n(e: str) -> str:
    return str(e).replace(VS, "")


# ---------------------------------------------------------------- world data

def load_world():
    factions = json.loads((ROOT / "Core/Factions/data/factions.json").read_text(encoding="utf-8"))
    biomes = json.loads((ROOT / "Core/Biomes/data/biomes.json").read_text(encoding="utf-8"))
    fs = {f["name"]: f for f in factions if isinstance(f, dict) and "name" in f}
    bs = {b["name"]: b for b in biomes if isinstance(b, dict) and "name" in b}
    pair_owners: dict = {}
    for f in fs.values():
        for ic in f.get("icons", []) or []:
            key = frozenset((n(ic["pole_0"]), n(ic["pole_1"])))
            pair_owners.setdefault(key, []).append(f["name"])
    return fs, bs, pair_owners


def boot_pairs(bs: dict, fs: dict, name: str) -> list:
    """Port of Biome.get_neighborhood_icons(): the register pairs a biome boots with."""
    b = bs.get(name)
    if not b:
        return []
    basis = {n(e) for e in b.get("emojis", [])}
    claimed: set = set()
    seen: set = set()
    out = []
    for fn in b.get("native_factions", []):
        for ic in (fs.get(fn, {}).get("icons") or []):
            p0, p1 = n(ic.get("pole_0", "")), n(ic.get("pole_1", ""))
            if not p0 or not p1 or p0 not in basis or p1 not in basis:
                continue
            if p0 in claimed or p1 in claimed:
                continue
            key = frozenset((p0, p1))
            if key in seen:
                continue
            seen.add(key)
            claimed |= {p0, p1}
            out.append((p0, p1))
    return out


def market_cloud(bs, fs, pair_owners, name: str) -> set:
    """Emojis the factions admitted in a biome can pay out (contract rewards)."""
    out = set()
    for p in boot_pairs(bs, fs, name):
        for fac in pair_owners.get(frozenset(p), []):
            out |= {n(c) for c in (fs.get(fac, {}).get("cloud") or [])}
    return out


def admitted(bs, fs, pair_owners, name: str) -> set:
    out = set()
    for p in boot_pairs(bs, fs, name):
        out |= set(pair_owners.get(frozenset(p), []))
    return out


def scenario_start(path: Path) -> dict:
    txt = path.read_text(encoding="utf-8")
    wallet = {n(k): int(v) for k, v in re.findall(r'"([^"]+)":\s*(\d+)', txt.split("tributes_paid")[0])}
    icons = [(n(a), n(b)) for a, b in re.findall(r'"north":\s*"([^"]+)",\s*"south":\s*"([^"]+)"', txt)]
    m = re.search(r'unlocked_biomes = Array\[String\]\(\[(.*?)\]\)', txt)
    biomes = re.findall(r'"([^"]+)"', m.group(1)) if m else []
    return {"wallet": wallet, "icons": icons, "biomes": biomes}


# ---------------------------------------------------------------- verbs

START_HATS = {"ace", "icon", "druid"}
GATE_HAT = {
    "measure": "ace", "reap": "ace", "hadamard": "druid", "bell": "operator", "cnot": "operator",
    "swap": "operator", "inject_icon": "icon", "spark": "spark", "drain": "merchant",
    "settle": "merchant", "gauge_flip": "operator",
}
PRED_HAT = {
    "bridge_built_gte": "spark", "bridge_braids_gte": "spark", "bridge_fused_gte": "spark",
    "biome_frozen_loops_gte": "icon", "spinor_read": "icon",
}
BERRY_TYPES = {"berry_consumed_count_gte", "berry_total_phase_gte"}


def hats_needed(pred: dict) -> set:
    t = pred.get("type", "")
    if t == "gate_sequence_contains":
        h = GATE_HAT.get(str(pred.get("gate", "")))
        return {h} if h else set()
    if t == "gate_order":
        return {GATE_HAT[g] for g in pred.get("gates", []) if g in GATE_HAT}
    if t in PRED_HAT:
        return {PRED_HAT[t]}
    if t in BERRY_TYPES:
        return {"icon"}
    return set()


# ---------------------------------------------------------------- the replay

class Report:
    def __init__(self):
        self.errors: list = []
        self.warnings: list = []

    def err(self, bid, msg):
        self.errors.append(f"{bid}: {msg}")

    def warn(self, bid, msg):
        self.warnings.append(f"{bid}: {msg}")


DELIVERY_DELTA = {"trust": 0.05, "access": 0.02}
TYPE1_DELTA = {"trust": 0.04}


def claim_delta(offer: dict) -> dict:
    t = offer.get("type", 0)
    if isinstance(t, str):
        t = 0 if t in ("DELIVERY", "DELIVER") else 1
    return DELIVERY_DELTA if int(t) == 0 else (TYPE1_DELTA if int(t) in (1, 2, 3) else {})


def validate(spec: dict, report_table: bool = False) -> Report:
    R = Report()
    fs, bs, owners = load_world()
    start = scenario_start(ROOT / "Scenarios" / "demos_normal.tres")
    params = spec.get("params", {})
    ladder = params.get("ladder", {})
    max_deliv = int(ladder.get("max_deliveries", 4))
    index = S.beats_by_id(spec)
    resources = {k: v for k, v in spec.get("resources", {}).items() if not k.startswith("_")}

    # ---------------- structure
    ids = [b["id"] for _, _, _, b in S.iter_beats(spec)]
    for bid in {i for i in ids if ids.count(i) > 1}:
        R.err(bid, "duplicate beat id")
    for c, a, ch, b in S.iter_beats(spec):
        for r in b.get("requires", []):
            if r not in index:
                R.err(b["id"], f"requires unknown beat {r!r}")
    # cycles
    state: dict = {}

    def dfs(bid, stack):
        if state.get(bid) == 1:
            R.err(bid, "dependency cycle: " + " -> ".join(stack + [bid]))
            return
        if state.get(bid) == 2 or bid not in index:
            return
        state[bid] = 1
        for r in index[bid][3].get("requires", []):
            dfs(r, stack + [bid])
        state[bid] = 2
    for bid in index:
        dfs(bid, [])
    if R.errors:
        return R

    camp_of = {bid: v[0]["id"] for bid, v in index.items()}
    main = next(c for c in spec["campaigns"] if c.get("kind", "main") == "main")
    for c, a, ch, b in S.iter_beats(spec):
        bid = b["id"]
        req = b.get("requires", [])
        gact = S.global_act(c, a)
        if not req and not (c["id"] == main["id"] and (b.get("fired_by") or a["act"] == 0)):
            R.err(bid, "has no requires — only Act-0 milestones may be roots")
        for r in req:
            rc, ra = index[r][0], index[r][1]
            if rc["id"] == c["id"]:
                if int(ra["act"]) > int(a["act"]):
                    R.err(bid, f"act {a['act']} requires {r} from a LATER act {ra['act']}")
            elif rc.get("kind", "main") != "main":
                R.err(bid, f"post-game campaigns may not feed other campaigns ({r} is {rc['id']})")
        if c.get("kind") == "postgame":
            anc = set(S.ancestors(spec, bid, index))
            if c.get("opens_after") and c["opens_after"] not in anc and bid != c.get("opens_after"):
                R.err(bid, f"post-game beat does not wait on {c['opens_after']}")
        _ = gact
    for c in spec["campaigns"]:
        end = c.get("ending")
        if not end or end not in index:
            R.err(c["id"], f"campaign ending {end!r} is not a beat")
        elif not index[end][3].get("ending"):
            R.err(end, "named as campaign ending but not marked ending: true")
    # tutorial unlock_flags
    for step in S.tutorial_steps(spec):
        for f in step.get("unlock_flags", []):
            if f not in index or not index[f][3].get("fired_by"):
                R.err(f"tutorial step {step.get('tutorial_step')}", f"unlock_flags {f!r} is not a fired_by beat")

    # ---------------- per-beat replay
    start_biomes = set(start["biomes"])
    charts = {b["chart"]: b["id"] for _, _, _, b in S.iter_beats(spec) if b.get("chart")}
    tut_hats_steps = S.tutorial_steps(spec)

    def contributions(bid: str) -> dict:
        b = index[bid][3]
        out = {"biomes": set(), "teach": [], "plants": [], "hats": set(), "standing": {}}
        for p in b.get("objective", []) + b.get("trigger", []):
            if p.get("type") == "biome_evolving":
                out["biomes"].add(p["biome"])
            if p.get("type") == "atom_in_biome":
                out["plants"].append((p["biome"], n(p["atom"])))
        if b.get("chart"):
            out["biomes"].add(b["chart"])
        off = b.get("offer")
        if off and off.get("teaches"):
            out["teach"].append(tuple(n(x) for x in off["teaches"]))
        on_open = b.get("on_open", {})
        out["hats"] |= set(on_open.get("unlock", {}).get("hats", []))
        for fac, ch in on_open.get("standing", {}).items():
            for k, v in ch.items():
                out["standing"][(fac, k)] = out["standing"].get((fac, k), 0) + v
        return out

    def add_standing(acc, fac, deltas):
        for k, v in deltas.items():
            acc[(fac, k)] = acc.get((fac, k), 0.0) + v

    # tutorial standing (every step is a claimed quest of its faction; DELIVERY default)
    tut_standing: dict = {}
    for st in tut_hats_steps:
        add_standing(tut_standing, st.get("faction", "Unknown"), DELIVERY_DELTA)

    rows = []
    for c, a, ch, b in S.iter_beats(spec):
        bid = b["id"]
        anc = S.ancestors(spec, bid, index)
        # state at OPEN: all ancestors complete (+claimed), this beat's on_open applied
        biomes = set(start_biomes)
        known = [tuple(p) for p in start["icons"]]
        plants = []
        hats = set(START_HATS)
        stand = dict(tut_standing)
        for x in anc:
            con = contributions(x)
            biomes |= con["biomes"]
            known += con["teach"]
            plants += con["plants"]
            hats |= con["hats"]
            for k, v in con["standing"].items():
                stand[k] = stand.get(k, 0) + v
            # the player MET that ancestor's standing gates (standing never decays)
            for gp in index[x][3].get("objective", []):
                if gp.get("type") == "standing_gte" and isinstance(gp.get("value"), (int, float)):
                    k = (gp["faction"], gp["channel"])
                    stand[k] = max(stand.get(k, 0.0), float(gp["value"]))
            off = index[x][3].get("offer")
            if off:
                add_standing(stand, off.get("faction", "Unknown"), claim_delta(off))
        me = contributions(bid)
        hats |= me["hats"]
        for k, v in me["standing"].items():
            stand[k] = stand.get(k, 0) + v
        own_chart = b.get("chart")
        avail_biomes = biomes | ({own_chart} if own_chart else set())
        incorporates_taught = "first_breath" in anc or bid == "first_breath"

        # vocabulary reachable: start + taught + incorporable from loaded biomes (north-uniqueness rule)
        poles: set = set()
        sig: list = []

        def learn(p):
            if p[0] in poles:
                return
            if p not in sig and (p[1], p[0]) not in sig:
                sig.append(p)
                poles.update(p)
        for p in known:
            learn(p)
        if incorporates_taught:
            for bn in sorted(avail_biomes):
                for p in boot_pairs(bs, fs, bn):
                    learn(p)
        # atoms reachable: loaded registers + plants done + any known pair
        atoms_guaranteed = set()
        for bn in avail_biomes:
            for p in boot_pairs(bs, fs, bn):
                atoms_guaranteed |= set(p)
        for bn, atom in plants:
            for p in known:
                if atom in p:
                    atoms_guaranteed |= set(p)
        atoms_reach = set(atoms_guaranteed)
        for p in sig:
            atoms_reach |= set(p)
        village_seats = len(boot_pairs(bs, fs, "Village"))
        village_planted = {atom for bn, atom in plants if bn == "Village"}
        village_guaranteed = 2 * min(6, village_seats + len(village_planted))

        # gatherable / market emojis
        gather = set()
        market = set()
        for bn in avail_biomes:
            for p in boot_pairs(bs, fs, bn):
                gather |= set(p)
            market |= market_cloud(bs, fs, owners, bn)
        # a word planted by an ancestor is a live register: both poles gather
        # from then on (learn an icon, plant it, harvest into it)
        for bn, atom in plants:
            for p in known:
                if atom in p and bn in avail_biomes:
                    gather |= set(p)
        # standing trades: always on a loaded biome's board
        for res, info in resources.items():
            for tr in info.get("trades", []):
                if tr.get("biome") in avail_biomes:
                    market.add(res)
        have_start = {k for k, v in start["wallet"].items() if v > 0}

        preds = b.get("objective", []) + b.get("trigger", [])
        for p in preds:
            t = p.get("type", "")
            # verbs
            for h in hats_needed(p):
                if h not in hats:
                    R.err(bid, f"objective needs the {h} hat, not unlocked by then")
            if t == "biome_evolving" and p["biome"] not in start_biomes:
                if "captain" not in hats:
                    R.err(bid, "charting a biome needs the captain hat")
                if p["biome"] not in charts:
                    R.err(bid, f"{p['biome']} has no guaranteed chart beat")
            # biomes
            bn = p.get("biome")
            if bn and t != "biome_evolving" and bn not in avail_biomes:
                R.err(bid, f"objective names {bn}, which is not loaded by then")
            # berries
            if t in BERRY_TYPES and not incorporates_taught:
                R.err(bid, "counts berries before Incorporate is taught (first_breath)")
            # plants
            if t == "atom_in_biome":
                atom = n(p["atom"])
                bn = p["biome"]
                if atom in {x for q in boot_pairs(bs, fs, bn) for x in q}:
                    continue
                pair = next((q for q in sig if atom in q), None)
                if pair is None:
                    R.err(bid, f"plants {atom} in {bn} but no known word carries it")
                    continue
                south = pair[1]
                for need in ("🌱", south):
                    if need not in gather | market:
                        R.err(bid, f"planting {pair[0]}/{pair[1]} costs {need}, which no loaded plot or board supplies by then")
            # thresholds
            v = p.get("value", p.get("count"))
            if t == "signature_size_gte" and isinstance(v, (int, float)):
                if v > len(sig) - 1:
                    R.err(bid, f"signature ≥ {v}, but only {len(sig)} words are reachable by then (margin 1)")
            if t == "atom_diversity_gte" and isinstance(v, (int, float)):
                if v > len(atoms_reach) - 2:
                    R.err(bid, f"diversity ≥ {v}, but only {len(atoms_reach)} atoms are reachable by then (margin 2)")
            if t == "atom_count_gte" and p.get("biome") == "Village" and isinstance(v, (int, float)):
                if v > 12 - 2:
                    R.err(bid, f"Village ring ≥ {v} leaves no room for one wasted seat (cap 12)")
                if v > village_guaranteed + 2:
                    R.warn(bid, f"Village ring ≥ {v} needs plants beyond the story's own ({village_guaranteed})")
            if t == "standing_gte" and isinstance(v, (int, float)):
                fac, chn = p["faction"], p["channel"]
                have = stand.get((fac, chn), 0.0)
                step = DELIVERY_DELTA.get(chn, 0.0)
                if step <= 0:
                    R.warn(bid, f"{fac} {chn} has no per-delivery increment; gate {v} untested")
                    continue
                need = (v - have) / step
                if need > max_deliv + 1e-9:
                    R.err(bid, f"{fac} {chn} ≥ {v}: story grants {have:.2f}, needs {need:.1f} deliveries (max {max_deliv})")
                elif need < 1 - 1e-9:
                    R.warn(bid, f"{fac} {chn} ≥ {v} is already met by story grants ({have:.2f}) — no real ask")
                off = b.get("offer") or {}
                fac_live = (fac == off.get("faction")) or any(fac in admitted(bs, fs, owners, x) for x in avail_biomes)
                if not fac_live:
                    R.err(bid, f"{fac} has no contract board in any loaded biome")
        # chart cost
        if own_chart:
            for res in spec.get("chart_cost", {}):
                if res.startswith("_"):
                    continue
                if res not in gather | market:
                    R.err(bid, f"charting costs {res}, which no loaded plot or board supplies")
        # one ask
        if b.get("offer") and b.get("trigger") and b.get("objective") == b.get("trigger"):
            R.err(bid, "objective is a copy of its own trigger")
        rows.append((S.global_act(c, a), c["id"], bid, sorted(hats), sorted(avail_biomes), len(sig),
                     len(atoms_reach), {f"{k[0][:10]}.{k[1]}": round(v, 2) for k, v in stand.items()
                                        if k[1] in ("trust", "access")}))

    # resources: every resource listed has a source somewhere and a rescue
    home = set()
    for bn in start_biomes:
        for p in boot_pairs(bs, fs, bn):
            home |= set(p)
    for res, info in resources.items():
        rescue = [t for t in info.get("trades", []) if t.get("biome") == "Village"]
        if not rescue:
            R.err(res, "spent on the story path but has no Village rescue trade")
        for tr in info.get("trades", []):
            here = {x for p in boot_pairs(bs, fs, tr.get("biome", "")) for x in p}
            for give in tr.get("give", {}):
                if give not in here | home:
                    R.err(res, f"{tr.get('biome')} trade asks for {give}, which no plot there or at home yields")
            if tr.get("biome") not in bs:
                R.err(res, f"trade names unknown biome {tr.get('biome')!r}")
    for res in spec.get("chart_cost", {}):
        if not res.startswith("_") and res not in resources:
            R.err(res, "chart cost has no resources entry (supply + rescue)")

    check_guide(spec, R)

    if report_table:
        print(f"{'act':>3} {'campaign':<11} {'beat':<24} sig atoms hats / biomes")
        for r in rows:
            print(f"{r[0]:>3} {r[1]:<11} {r[2]:<24} {r[5]:>3} {r[6]:>5} {','.join(r[3])} / {','.join(r[4])}")
    return R


# Step kinds Core/Campaign/Guide.gd implements (`kind` or `kind:arg`).
GUIDE_STEPS = {"travel", "hat", "berry", "deliver_to", "chart", "gate", "plant_atom", "plant_new",
               "learn_word", "take_door", "go", "strike", "deliver_lesson", "plot_verb", "pair_gate", "reap", "measure", "superpose", "evolve", "steer", "survey"}


def check_guide(spec: dict, R: "Report") -> None:
    """The guide block (docs/design/GUIDANCE_FROM_THE_SPEC.md): every step is a
    kind Guide.gd implements, every hat a walk names has a key, and every
    objective type the MAIN campaign uses has a walk — a main-road beat with
    no walk falls back to the legacy banner, which is how the walls came back."""
    g = spec.get("guide")
    if not g:
        R.err("guide", "campaign.json has no guide block")
        return
    km, walks = g.get("keymap", {}), g.get("walks", {})
    for wtype, steps in walks.items():
        for st in steps:
            kind, _, arg = str(st).partition(":")
            if kind not in GUIDE_STEPS:
                R.err("guide", f"walk {wtype!r} uses unknown step {st!r}")
            if kind == "hat" and arg not in km.get("hats", {}):
                R.err("guide", f"walk {wtype!r} names hat {arg!r} with no key")
    main = next(c for c in spec["campaigns"] if c.get("kind", "main") == "main")
    for c, a, ch, b in S.iter_beats(spec):
        if c["id"] != main["id"]:
            continue
        for p in b.get("objective", []):
            if p["type"] not in walks:
                R.warn(b["id"], f"objective {p['type']} has no guide walk (legacy banner)")
    for c in spec["campaigns"]:
        for a in c["acts"]:
            for ch in a["chapters"]:
                for st in ch.get("steps", []):
                    t = st.get("tutorial_teaches")
                    if t and f"lesson:{t}" not in walks:
                        R.err(t, f"Act 0 lesson {t} has no guide walk (lesson:{t})")


def main(argv):
    spec = S.load()
    R = validate(spec, "--report" in argv)
    for w in R.warnings:
        print("warn ", w)
    for e in R.errors:
        print("ERROR", e)
    print(f"{len(R.errors)} errors, {len(R.warnings)} warnings")
    return 1 if R.errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
