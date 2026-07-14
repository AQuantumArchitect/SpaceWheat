#!/usr/bin/env python3
"""Witness integration probe — the belief field tracks real play, live.

Boots a headless demos_normal game and PLAYS LIKE A PLAYER (key presses:
select plot G → F explore → R measure → Q extract; rig shortcuts like
probe_cycle bypass the player signal path and correctly leave the Witness
blind — that blindness is the parity membrane working). Asserts:

  1. Boots blank: witness_graph present, beliefs near-zero.
  2. Tracks: after real play the active biome's `outcome` |z| and
     `coverage` rise off the floor and `observes` grows — beliefs move
     ONLY because player-visible events fired.
  3. Persists: save → load round-trips the belief field (gauge equal).

Exits nonzero on any failure. ~2-3 min (one headless boot).
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def biome_role_z(graph: dict, node_name: str, role: str):
    for node in graph.get("topology", {}).get("nodes", []):
        if node.get("name") == node_name:
            for organ in node.get("organs", []):
                bloch = organ.get("bloch", {})
                if role in bloch:
                    return float(bloch[role][2])
    return None


def summary_field(graph: dict, key: str):
    for g in graph.get("globals", []):
        if g.get("type") == "summary":
            return g.get(key)
    return None


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    log_path = HERE.parent.parent / "logs" / "witness_probe_listener.log"
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            listener_log_path=log_path,
                            extra_env={"RIG_SKIP_WELCOME": "1"})
    failures = []

    def check(cond, msg):
        tag = "PASS" if cond else "FAIL"
        print(f"[{tag}] {msg}")
        if not cond:
            failures.append(msg)

    try:
        ready = c.wait_for_ready(proc, timeout_s=240)
        print("ready:", ready)

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=45, **kw)

        def press(k, settle=10):
            return t("press_key", key=k, settle_frames=settle)

        # 1 — blank boot
        wg = t("witness_graph")
        check(wg.get("ok", False) and isinstance(wg.get("witness"), dict),
              "witness_graph answers")
        graph0 = wg.get("witness", {})
        # Switch biome once (player verb) so the active context is explicit.
        press("y")
        slots = t("biome_slots")
        active = str(slots.get("active", "") or "")
        if not active:
            for s in slots.get("slots", []):
                if s.get("biome"):
                    active = str(s.get("biome"))
                    break
        node = f"biome:{active}"
        print(f"active biome: {active}")
        wg0 = t("witness_graph")
        graph0 = wg0.get("witness", {})
        z0_out = biome_role_z(graph0, node, "outcome")
        z0_cov = biome_role_z(graph0, node, "coverage")
        check(z0_out is not None, f"{node} cluster exists (active-biome mint)")
        if z0_out is not None:
            check(abs(z0_out) < 0.15, f"outcome starts near-blank (z={z0_out})")
        obs0 = summary_field(graph0, "observes") or 0

        # 2 — beliefs track real play: G select, F explore, R measure, Q extract
        for _ in range(3):
            for k in ("g", "f", "g", "r", "g", "q"):
                press(k)
        wg1 = t("witness_graph")
        graph1 = wg1.get("witness", {})
        z1_out = biome_role_z(graph1, node, "outcome")
        z1_cov = biome_role_z(graph1, node, "coverage")
        z1_yield = biome_role_z(graph1, node, "yield")
        obs1 = summary_field(graph1, "observes") or 0
        check(obs1 > obs0, f"observes grew with play ({obs0} -> {obs1})")
        check(z1_out is not None and abs(z1_out) > 0.15,
              f"outcome belief moved off the floor (|z|={abs(z1_out or 0):.3f})")
        check(z1_cov is not None and z1_cov > (z0_cov or 0.0) + 0.1,
              f"coverage rose with measurement ({z0_cov} -> {z1_cov})")
        check(z1_yield is not None and z1_yield > 0.0,
              f"yield belief moved with extraction (z={z1_yield})")

        # 3 — persistence round-trip
        save_path = "/tmp/witness_probe_save.tres"
        saved = t("save_game_path", path=save_path)
        check(saved.get("saved", False), "save_game_path saved")
        g_before = t("witness_gauge").get("gauge", {})
        loaded = t("load_game_path", path=save_path)
        check(loaded.get("loaded", loaded.get("ok", False)), "load_game_path loaded")
        g_after = t("witness_gauge").get("gauge", {})
        check(g_before.get("spec_hash") == g_after.get("spec_hash"),
              "spec hash stable across load")
        # Cluster SET and belief shape must survive; magnitudes may decay a
        # touch between the two reads (the field never stops easing).
        check(sorted(g_before.get("clusters", {}).keys())
              == sorted(g_after.get("clusters", {}).keys()),
              "cluster set survives save/load")
        drift = 0.0
        for cname, entry in g_before.get("clusters", {}).items():
            after_entry = g_after.get("clusters", {}).get(cname, {})
            for role, xyz in entry.get("bloch", {}).items():
                a_xyz = after_entry.get("bloch", {}).get(role, [0, 0, 0])
                drift = max(drift, abs(float(xyz[2]) - float(a_xyz[2])))
        check(drift < 0.05, f"beliefs survive save/load (max z drift {drift:.4f})")

        print()
        print("=" * 60)
        if failures:
            print(f"WITNESS PROBE: {len(failures)} FAILURE(S)")
            for f in failures:
                print("  ✗", f)
        else:
            print("WITNESS PROBE: ALL PASS")
        print("=" * 60)
        return 1 if failures else 0
    finally:
        c.terminate_listener(proc)


if __name__ == "__main__":
    sys.exit(main())
