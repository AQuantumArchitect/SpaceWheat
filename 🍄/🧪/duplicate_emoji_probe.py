#!/usr/bin/env python3
"""Duplicate-emoji refactor probe: the SAME icon pair injected twice is legal.

Owner ruling: "we can have duplicate emojis... there is nothing stopping that
mechanically." A shared pole label is degeneracy — ρ and the evolution are
qubit-indexed. This probe verifies the bookkeeping end to end:

  1. boot demos_normal headless;
  2. inject the SAME icon pair into one biome twice (rig inject_icon with an
     explicit north/south — second call used to be rejected already_in_biome);
  3. qubit count grows by exactly +2;
  4. get_all_populations stays coherent (entropy_snapshot: S finite, purity
     trace-sane, summed populations feed a finite surprisal price);
  5. H rebuild sane (hamiltonian_stats: finite Frobenius norm, dim == 2^n);
  6. save_game_path → load_game_path round-trips with both duplicate qubits
     intact (grid_snapshot + per-biome qubit counts equal before/after) AND
     the load path itself rebuilds H over the restored runtime-injected
     layout (dim == 2^n immediately after load — path-load family #5 fix in
     GameStateSerializer._restore_single_biome_state; the old stale-H-on-load
     gap was bisected 2026-07-14 with a unique-icon control). A third
     injection then proves further rebuilds atop the RESTORED duplicate
     layout stay sane: dim doubles, Frobenius finite;
  7. measuring EACH duplicate plot works (probe_cycle with explicit register;
     plot_idx ≡ register_id) and yields one of the axis emojis.

Run: python3 "🍄/🧪/duplicate_emoji_probe.py"
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_turn = [100]
FAILURES = []


def t():
    _turn[0] += 1
    return _turn[0]


def check(cond, label, detail=""):
    mark = "PASS" if cond else "FAIL"
    print(f"  {mark}  {label}" + (f"  [{detail}]" if detail and not cond else ""))
    if not cond:
        FAILURES.append(label)
    return cond


def main():
    os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    # Lookahead batcher ON: it re-registers a structurally-changed biome and
    # pushes fresh viz metadata (axes for the new registers) — same lane the
    # live game runs and the lane inject_probe.py proved out.
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})

    def go(a, **k):
        return c.run_turn(t(), a, timeout_s=90, **k)

    def qubit_count(bn):
        return len(go("berry_state", biome=bn).get("qubits", []))

    try:
        c.wait_for_ready(proc, timeout_s=180)

        # ── Pick a target biome (fewest qubits) and its first realized axis ──
        grid_before = go("grid_snapshot").get("grid", {})
        biomes = list(grid_before.get("biomes", []))
        check(bool(biomes), "grid has biomes", str(grid_before))
        counts = {}
        for bn in biomes:
            n = qubit_count(bn)
            if n > 0:
                counts[bn] = n
        check(bool(counts), "found live biomes", str(biomes))
        # Prefer a regular multi-qubit biome (TheDemos is the 1-qubit seat).
        regular = {bn: n for bn, n in counts.items() if n >= 2} or counts
        target = min(regular, key=regular.get)
        n0 = counts[target]
        # The icon pair to duplicate: the player's first KNOWN icon (boot seed).
        # Injecting the SAME pair twice makes registers n0 and n0+1 exact
        # duplicates of each other (and of any existing instance of the pair).
        known = go("known_icons").get("icons", [])
        known = [i for i in known if isinstance(i, dict) and i.get("north") and i.get("south")]
        check(bool(known), "player knows at least one icon", str(known))
        north = str(known[0]["north"])
        south = str(known[0]["south"])
        print(f"target biome: {target} (qubits={n0}); duplicating axis {north}/{south}")

        # Headroom: cap is loaded config; raise it so two injections always fit.
        go("configure_economy", overrides={"max_biome_qubits": max(12, n0 + 4)})

        # ── Inject the SAME pair twice ──
        for i in (1, 2):
            go("add_resource", emoji=south, amount=200)
            go("add_resource", emoji="🌱", amount=200)
            res = go("inject_icon", biome=target, north=north, south=south)
            inj = res.get("inject_result", {})
            check(inj.get("success", False), f"inject #{i} of {north}/{south} accepted",
                  str(inj))

        # Let the batcher re-register the grown biome and push fresh viz
        # metadata (register→axis map for the new duplicate qubits).
        go("time_skip", phrames=60)
        n2 = qubit_count(target)
        check(n2 == n0 + 2, f"qubit count {n0} → {n2} (+2)", f"got {n2}")

        # ── Populations / entropy coherent under summed degenerate marginals ──
        rows = go("entropy_snapshot").get("entropy_snapshot", [])
        row = next((r for r in rows if r.get("biome") == target), {})
        S = float(row.get("S", -1.0))
        purity = float(row.get("purity", -1.0))
        price = float(row.get("sample_price", -1.0))
        check(S == S and S >= 0.0, f"entropy finite and ≥0 (S={S:.4f})", str(row))
        check(0.0 <= purity <= 1.01, f"purity trace-sane ({purity:.4f})", str(row))
        check(price == price and price >= 0.0,
              f"surprisal price finite off summed pmax ({price:.4f})", str(row))

        # ── H rebuild sane ──
        hs = go("hamiltonian_stats", biome=target)
        frob = float(hs.get("frobenius", -1.0))
        dim = int(hs.get("dim", -1))
        check(dim == 2 ** n2, f"H dim {dim} == 2^{n2}", str(hs))
        check(frob == frob and 0.0 < frob < 1e9, f"H Frobenius finite ({frob:.4f})", str(hs))

        # ── Save/load round-trip keeps both duplicate qubits ──
        save_path = "user://duplicate_emoji_probe_save.tres"  # ResourceSaver needs .tres
        saved = go("save_game_path", path=save_path)
        check(bool(saved.get("saved", False)), "save_game_path succeeded", str(saved))
        counts_before = {bn: qubit_count(bn) for bn in counts}
        loaded = go("load_game_path", path=save_path)
        check(bool(loaded.get("loaded", False)), "load_game_path succeeded", str(loaded))
        grid_after = go("grid_snapshot").get("grid", {})
        check(grid_after.get("plot_count") == grid_before.get("plot_count")
              and sorted(grid_after.get("biomes", [])) == sorted(grid_before.get("biomes", [])),
              "grid_snapshot equal before/after load")
        counts_after = {bn: qubit_count(bn) for bn in counts}
        check(counts_after.get(target) == n2,
              f"{target} still has {n2} qubits after load (duplicates intact)",
              str(counts_after))
        check(counts_after == counts_before, "all biome qubit counts round-trip",
              f"{counts_before} vs {counts_after}")
        # Path-load family #5 fix: the load path detects the operator/register
        # dim mismatch and fires the CANONICAL builder rebuild during restore —
        # H must be at the restored dim IMMEDIATELY, no later rebuild needed.
        hs2 = go("hamiltonian_stats", biome=target)
        frob2 = float(hs2.get("frobenius", -1.0))
        check(int(hs2.get("dim", -1)) == 2 ** n2,
              f"post-load H rebuilt on restore: dim {hs2.get('dim')} == 2^{n2}", str(hs2))
        check(frob2 == frob2 and 0.0 < frob2 < 1e9,
              f"post-load H Frobenius finite ({frob2:.4f})", str(hs2))

        # ── Post-load rebuild must handle the RESTORED duplicate layout ──
        # A third injection of the SAME pair triggers a full H+L rebuild from
        # the restored register map (now containing the two duplicate axes).
        go("configure_economy", overrides={"max_biome_qubits": max(12, n2 + 2)})
        go("add_resource", emoji=south, amount=200)
        go("add_resource", emoji="🌱", amount=200)
        inj3 = go("inject_icon", biome=target, north=north, south=south).get("inject_result", {})
        check(inj3.get("success", False), "inject #3 after load accepted", str(inj3))
        n3 = qubit_count(target)
        check(n3 == n2 + 1, f"qubit count after load-inject {n2} → {n3} (+1)", f"got {n3}")
        go("time_skip", phrames=60)
        hs3 = go("hamiltonian_stats", biome=target)
        frob3 = float(hs3.get("frobenius", -1.0))
        check(int(hs3.get("dim", -1)) == 2 ** n3,
              f"H rebuilt over restored duplicates: dim {hs3.get('dim')} == 2^{n3}", str(hs3))
        check(frob3 == frob3 and 0.0 < frob3 < 1e9,
              f"post-load H Frobenius finite ({frob3:.4f})", str(hs3))

        # ── Measure EACH duplicate plot (plot_idx ≡ register_id) ──
        go("add_resource", emoji="💰", amount=500)
        go("add_resource", emoji="🌾", amount=500)
        for reg in (n2 - 2, n2 - 1, n3 - 1):
            pc = go("probe_cycle", biome=target, register=reg, full=True)
            probe = pc.get("probe", {})
            ok = bool(probe.get("success", False))
            outcome = str(probe.get("measure", {}).get("outcome", ""))
            got_reg = int(probe.get("measure", {}).get("register_id", -1))
            check(ok, f"probe_cycle on duplicate register {reg} succeeded", str(probe))
            if ok:
                check(got_reg == reg, f"measured register {got_reg} == requested {reg}")
                check(outcome in (north, south),
                      f"register {reg} outcome {outcome} ∈ {{{north},{south}}}")

        print()
        if FAILURES:
            print(f"✗ duplicate_emoji_probe: {len(FAILURES)} FAILURES: {FAILURES}")
        else:
            print("✓ duplicate_emoji_probe: ALL CHECKS PASSED")
    finally:
        go("stop")
        c.terminate_listener(proc)
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
