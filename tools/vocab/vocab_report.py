#!/usr/bin/env python3
"""Report the state of the icon vocabulary: every ordered pole pair, its names,
owners, physics, couplings and boot biomes, and what is inconsistent.

    python tools/vocab/vocab_report.py                 # summary counts
    python tools/vocab/vocab_report.py --markdown OUT  # full tables to OUT
    python tools/vocab/vocab_report.py --json          # summary as JSON

No Godot needed. It reads the same JSON the game reads and mirrors the
registry's rules (Core/Factions/IconRegistry.gd):

  * a word is an ORDERED pair pole_0/pole_1 (north/south); the south pole is
    what the word provides; A/B and B/A can be two words;
  * emoji keys ignore U+FE0F (IconRegistry.norm_emoji);
  * the in-game name of a pair is its FIRST faction listing's name (pass 1),
    then a biomes.json listing, then the icons.json entry's name;
  * an icons.json entry whose exact pair is not registered merges into the
    REVERSED record when that one exists (find_icon_by_pair's fallback), so
    such physics lands on a word written the other way round;
  * a boot loadout is Biome.get_neighborhood_icons (ported from
    tools/campaign/validate.py's boot_pairs).

Terms used in the report:
  listing      one entry in a faction's "icons" list (faction, pair, name)
  word         a pair registered from factions.json, biomes.json or icons.json
  physics      an icons.json entry for the exact ordered pair
  collision    one name used by two or more different ordered pairs, counting
               every place a name lives (faction listings + icons.json)
  mismatch     a faction listing whose name differs from icons.json's name for
               the same ordered pair
  physics-less a faction listing with no icons.json entry in either orientation
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VS = "️"
STRONG = 0.3        # sparsity threshold: a coupling of |c| >= 0.3 counts as live
SPARSE_MAX = 5      # flag a word with more than this many live strong couplings


def n(e) -> str:
    return str(e).replace(VS, "")


def mag(v) -> float:
    if isinstance(v, (list, tuple)) and len(v) == 2:
        return (float(v[0]) ** 2 + float(v[1]) ** 2) ** 0.5
    return abs(float(v))


def _load(rel: str):
    return json.loads((ROOT / rel).read_text(encoding="utf-8"))


def load(root: Path | None = None) -> dict:
    """Read the vocabulary sources into one structure."""
    global ROOT
    if root is not None:
        ROOT = Path(root)
    factions = [f for f in _load("Core/Factions/data/factions.json") if isinstance(f, dict)]
    icons = [e for e in _load("Core/Factions/data/icons.json") if isinstance(e, dict)]
    biomes = [b for b in _load("Core/Biomes/data/biomes.json") if isinstance(b, dict)]
    axes = _load("Core/Factions/data/axes.json")
    return {"factions": factions, "icons": icons, "biomes": biomes, "axes": axes}


def analyse(data: dict) -> dict:
    factions, icons, biomes, axes = data["factions"], data["icons"], data["biomes"], data["axes"]

    listings = []                       # (faction, pair, name)
    fac_names = defaultdict(list)       # pair -> [names in faction listings]
    owners = defaultdict(list)          # pair -> [factions]
    for f in factions:
        for ic in f.get("icons", []) or []:
            p = (n(ic.get("pole_0", "")), n(ic.get("pole_1", "")))
            if not p[0] or not p[1]:
                continue
            listings.append((f["name"], p, str(ic.get("name", ""))))
            fac_names[p].append(str(ic.get("name", "")))
            if f["name"] not in owners[p]:
                owners[p].append(f["name"])

    biome_names = defaultdict(list)
    for b in biomes:
        for ic in b.get("icons", []) or []:
            p = (n(ic.get("pole_0", "")), n(ic.get("pole_1", "")))
            biome_names[p].append(str(ic.get("name", "")))

    phys_entries = defaultdict(list)    # exact pair -> [icons.json entries]
    for e in icons:
        p = (n(e.get("pole_0", "")), n(e.get("pole_1", "")))
        phys_entries[p].append(e)

    axis_pairs = {}
    for a in axes if isinstance(axes, list) else []:
        p = (n(a.get("pole_0", "")), n(a.get("pole_1", "")))
        if p[0] and p[1]:
            axis_pairs[p] = a.get("key", "")

    # Registry replay: which record does each icons.json entry's physics land on?
    registered = {}                     # pair -> source ("faction", "biome", "axis", "icons")
    for _, p, _ in listings:
        registered.setdefault(p, "faction")
    for p in biome_names:
        registered.setdefault(p, "biome")
    for p in axis_pairs:
        registered.setdefault(p, "axis")
    physics_of = {}                     # registered pair -> (entry, landed_via)
    for e in icons:
        p = (n(e["pole_0"]), n(e["pole_1"]))
        if p in registered:
            target, via = p, "exact"
        elif (p[1], p[0]) in registered:
            target, via = (p[1], p[0]), "reversed"
        else:
            registered[p] = "icons"
            target, via = p, "exact"
        if target not in physics_of:
            physics_of[target] = (e, via)

    def name_of(p):
        if fac_names.get(p):
            return fac_names[p][0]
        if biome_names.get(p):
            return biome_names[p][0]
        if p in phys_entries:
            return str(phys_entries[p][0].get("name", ""))
        if p in axis_pairs:
            return "Axis_%s" % axis_pairs[p]
        return ""

    # Couplings: out = keys of the pair's own hamiltonian_couplings; in = other
    # words whose couplings target one of this pair's atoms.
    out_c = {}
    for p, (e, _) in physics_of.items():
        out_c[p] = {n(k): v for k, v in (e.get("hamiltonian_couplings") or {}).items()}
    target_index = defaultdict(list)    # atom -> [(source pair, |c|)]
    for p, cs in out_c.items():
        for atom, v in cs.items():
            target_index[atom].append((p, mag(v)))

    # Boot loadouts
    fac_by_name = {f["name"]: f for f in factions}
    boots = {}
    for b in biomes:
        boots[b["name"]] = boot_pairs(b, fac_by_name)
    boot_biomes = defaultdict(list)
    for bn, pairs in boots.items():
        for p in pairs:
            boot_biomes[p].append(bn)

    rows = []
    for p in sorted(registered, key=lambda q: (name_of(q).lower(), q)):
        entry, via = physics_of.get(p, (None, None))
        inv = (p[1], p[0])
        cin = [s for s, _ in target_index.get(p[0], []) + target_index.get(p[1], []) if s != p]
        rows.append({
            "pair": p,
            "name": name_of(p),
            "faction_names": sorted(set(fac_names.get(p, []))),
            "icons_name": str(phys_entries[p][0].get("name", "")) if p in phys_entries else "",
            "icons_entries": len(phys_entries.get(p, [])),
            "owners": owners.get(p, []),
            "source": registered[p],
            "physics": "exact" if p in phys_entries else ("reversed" if via == "reversed" else ""),
            "rabi": float(entry.get("rabi_coupling", 0.0)) if entry else None,
            "out": len(out_c.get(p, {})),
            "in": len(set(cin)),
            "boots_in": sorted(boot_biomes.get(p, [])),
            "inverse_is_word": inv in registered and inv != p,
        })

    # Collisions: every place a name lives (faction listings + icons.json entries).
    name_pairs = defaultdict(set)
    for _, p, nm in listings:
        name_pairs[nm].add(p)
    for p, es in phys_entries.items():
        for e in es:
            name_pairs[str(e.get("name", ""))].add(p)
    collisions = {nm: sorted(ps) for nm, ps in name_pairs.items() if len(ps) > 1}
    fac_only = defaultdict(set)
    for _, p, nm in listings:
        fac_only[nm].add(p)
    fac_collisions = {nm: sorted(ps) for nm, ps in fac_only.items() if len(ps) > 1}

    mismatches = []
    for fac, p, nm in listings:
        if p in phys_entries:
            iname = str(phys_entries[p][0].get("name", ""))
            if iname != nm:
                mismatches.append((fac, p, nm, iname))
    # Two faction listings of one pair disagreeing with each other.
    listing_disagree = {p: sorted(set(v)) for p, v in fac_names.items() if len(set(v)) > 1}

    physicsless = [(fac, p, nm) for fac, p, nm in listings
                   if p not in phys_entries and (p[1], p[0]) not in phys_entries]
    reversed_only = [(fac, p, nm) for fac, p, nm in listings
                     if p not in phys_entries and (p[1], p[0]) in phys_entries]
    registered_no_physics = sorted(p for p in registered
                                   if registered[p] != "axis" and p not in physics_of)
    unowned_physics = sorted(p for p in phys_entries if p not in owners)
    dup_physics = sorted(p for p, es in phys_entries.items() if len(es) > 1)
    rabi0 = sorted(p for p in physics_of if p in phys_entries
                   and abs(float(physics_of[p][0].get("rabi_coupling", 0.0))) < 1e-12)

    # Atoms with no icon: emoji used in a biome basis, faction cloud or coupling
    # target that is not a pole of any registered word.
    poles = {a for p in registered for a in p}
    used = set()
    for b in biomes:
        used |= {n(e) for e in b.get("emojis", [])}
    for f in factions:
        used |= {n(e) for e in f.get("cloud", []) or []}
    for cs in out_c.values():
        used |= set(cs)
    atoms_no_icon = sorted(used - poles)

    # Sparsity: per word, per biome that boots it, the number of strong
    # coupling terms incident to it in that biome's boot Hamiltonian.
    sparsity = []
    for bn, pairs in boots.items():
        atoms_here = {a for q in pairs for a in q}
        for p in pairs:
            live = 0
            for atom, v in out_c.get(p, {}).items():
                if atom in atoms_here and atom not in p and mag(v) >= STRONG:
                    live += 1
            for q in pairs:
                if q == p:
                    continue
                for atom, v in out_c.get(q, {}).items():
                    if atom in p and mag(v) >= STRONG:
                        live += 1
            sparsity.append((p, bn, live))

    return {
        "rows": rows, "listings": listings, "collisions": collisions,
        "faction_collisions": fac_collisions, "mismatches": mismatches,
        "listing_disagree": listing_disagree, "physicsless": physicsless,
        "reversed_only": reversed_only, "registered_no_physics": registered_no_physics,
        "unowned_physics": unowned_physics, "dup_physics": dup_physics, "rabi0": rabi0,
        "atoms_no_icon": atoms_no_icon, "boots": boots, "sparsity": sparsity,
        "axis_pairs": axis_pairs, "name_of": {r["pair"]: r["name"] for r in rows},
    }


def boot_pairs(b: dict, fac_by_name: dict) -> list:
    """Port of Biome.get_neighborhood_icons()."""
    basis = {n(e) for e in b.get("emojis", [])}
    claimed, seen, out = set(), set(), []
    for fn in b.get("native_factions", []) or []:
        for ic in (fac_by_name.get(fn, {}).get("icons") or []):
            p0, p1 = n(ic.get("pole_0", "")), n(ic.get("pole_1", ""))
            if not p0 or not p1 or p0 not in basis or p1 not in basis:
                continue
            if p0 in claimed or p1 in claimed or (p0, p1) in seen:
                continue
            seen.add((p0, p1))
            claimed |= {p0, p1}
            out.append((p0, p1))
    return out


def summary(a: dict) -> dict:
    return {
        "words": len(a["rows"]),
        "faction_listings": len(a["listings"]),
        "icons_json_entries": sum(r["icons_entries"] for r in a["rows"]),
        "axis_only_pairs": sum(1 for r in a["rows"] if r["source"] == "axis" and not r["physics"]),
        "name_collisions": len(a["collisions"]),
        "faction_name_collisions": len(a["faction_collisions"]),
        "name_mismatches": len(a["mismatches"]),
        "listing_disagreements": len(a["listing_disagree"]),
        "physicsless_listings": len(a["physicsless"]),
        "reversed_only_listings": len(a["reversed_only"]),
        "registered_without_physics": len(a["registered_no_physics"]),
        "unowned_physics_words": len(a["unowned_physics"]),
        "duplicate_physics_entries": len(a["dup_physics"]),
        "rabi_zero_words": len(a["rabi0"]),
        "atoms_without_icon": len(a["atoms_no_icon"]),
        "sparsity_over_%d" % SPARSE_MAX: sum(1 for *_, k in a["sparsity"] if k > SPARSE_MAX),
    }


def ps(p) -> str:
    return "%s/%s" % p


def markdown(a: dict, title: str) -> str:
    s = summary(a)
    L = ["# %s" % title, "",
         "Generated by `python tools/vocab/vocab_report.py --markdown`. Do not hand-edit.", "",
         "## Counts", "", "| Measure | Count |", "|---|---:|"]
    L += ["| %s | %d |" % (k, v) for k, v in s.items()]
    L += ["", "## Name collisions (one name, two or more ordered pairs)", "",
          "| Name | Pairs |", "|---|---|"]
    L += ["| %s | %s |" % (nm, ", ".join(ps(p) for p in pp)) for nm, pp in sorted(a["collisions"].items())]
    L += ["", "## Name mismatches (faction listing vs icons.json, same ordered pair)", "",
          "| Pair | Faction | factions.json | icons.json |", "|---|---|---|---|"]
    L += ["| %s | %s | %s | %s |" % (ps(p), f, nm, inm) for f, p, nm, inm in sorted(a["mismatches"], key=lambda x: x[1])]
    L += ["", "## Physics-less faction listings (no icons.json entry either way)", "",
          "| Pair | Faction | Name |", "|---|---|---|"]
    L += ["| %s | %s | %s |" % (ps(p), f, nm) for f, p, nm in a["physicsless"]]
    L += ["", "## Listings whose physics is only written reversed", "",
          "| Pair | Faction | Name |", "|---|---|---|"]
    L += ["| %s | %s | %s |" % (ps(p), f, nm) for f, p, nm in a["reversed_only"]]
    L += ["", "## Registered words without physics (excluding axis-only pairs)", ""]
    L += ["- %s %s" % (ps(p), a["name_of"].get(p, "")) for p in a["registered_no_physics"]] or ["(none)"]
    L += ["", "## Words with Rabi 0 (no transverse term: cannot ripen, so cannot be learned)", ""]
    L += ["- %s %s" % (ps(p), a["name_of"].get(p, "")) for p in a["rabi0"]] or ["(none)"]
    L += ["", "## Atoms with no icon", "", " ".join(a["atoms_no_icon"]) or "(none)"]
    over = [(p, b, k) for p, b, k in a["sparsity"] if k > SPARSE_MAX]
    L += ["", "## Sparsity: words with more than %d live couplings of |c| >= %.1f at boot" % (SPARSE_MAX, STRONG), ""]
    L += ["- %s %s in %s: %d" % (ps(p), a["name_of"].get(p, ""), b, k) for p, b, k in sorted(over)] or ["(none)"]
    L += ["", "## Every word", "",
          "| Name | Pair | factions.json | icons.json | Owners | Physics | Rabi | Out | In | Boots in |",
          "|---|---|---|---|---|---|---:|---:|---:|---|"]
    for r in a["rows"]:
        L.append("| %s | %s | %s | %s | %s | %s | %s | %d | %d | %s |" % (
            r["name"], ps(r["pair"]), "; ".join(r["faction_names"]), r["icons_name"],
            "; ".join(r["owners"]), r["physics"] or "none",
            "" if r["rabi"] is None else "%.2f" % r["rabi"], r["out"], r["in"],
            ", ".join(r["boots_in"])))
    return "\n".join(L) + "\n"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--markdown", metavar="OUT")
    ap.add_argument("--title", default="Icon vocabulary report")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    a = analyse(load())
    s = summary(a)
    if args.markdown:
        Path(args.markdown).write_text(markdown(a, args.title), encoding="utf-8")
    if args.json:
        print(json.dumps(s, indent=2))
    else:
        for k, v in s.items():
            print("%-32s %d" % (k, v))
    return 0


if __name__ == "__main__":
    sys.exit(main())
