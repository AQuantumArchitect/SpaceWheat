#!/usr/bin/env bash
# ⚖️  Reap Conservation Check — rig-driven kT·ΔS verification
#
# The reap "entropy bank" pays out energy for the disorder a reap actually
# consumes:  payout = kT · (S_before − S_after).  This driver proves the loop
# closes empirically. It runs the rig's `reap_probe` command (which brackets the
# REAL ProbeActions._collect_reap_rewards with S0/S1) twice, with a time-skip in
# between so each biome's webway/pump can refill S.
#
# Per biome it reports, for each probe: S0→S1, ΔS, kT, expected=kT·ΔS, and the
# credits actually paid — they should match within rounding. Then it checks
# whether S recovered between the two probes: pumped biomes (e.g. StarterForest)
# refill and pay again; pumpless biomes (e.g. BioticFlux) flatline to S≈0 and
# pay ≈0 (and raise the LindbladBuilder "no refill path" warning at build).
#
# Like 🌡️.sh, this uses the rig (full boot) — standalone --script labs are dead
# (no autoloads; absolute /root paths throw). See 🌡️.sh header for detail.
#
# Usage:  bash 🍄/🧪/⚖️.sh [scenario]      (default scenario: demos_normal)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/godot_runtime_env.sh"

SCENARIO="${1:-demos_normal}"
Q="$(mktemp /tmp/sw_reaplab_q.XXXXXX.jsonl)"
R="$(mktemp /tmp/sw_reaplab_r.XXXXXX.jsonl)"
B="$(mktemp /tmp/sw_reaplab_b.XXXXXX.txt)"
: > "$Q"

echo "⚖️  Reap Conservation Check — scenario=$SCENARIO"
echo "    (verifies credits ≈ kT·ΔS; rig harness — see header)"

RIG_SCENARIO="$SCENARIO" RIG_QUEUE_PATH="$Q" RIG_RESULT_PATH="$R" \
  sw_godot --headless --path . --script Rig/rig_listener.gd > "$B" 2>&1 &
RIG_PID=$!

cleanup() { kill -9 "$RIG_PID" 2>/dev/null; rm -f "$Q" "$R" "$B"; }
trap cleanup EXIT

# Wait for boot.
for _ in $(seq 1 45); do grep -q "Rig ready" "$B" 2>/dev/null && break; sleep 1; done
if ! grep -q "Rig ready" "$B" 2>/dev/null; then
  echo "❌ rig did not reach 'Rig ready' — boot log tail:"; tail -8 "$B"; exit 1
fi

# Probe → refill window → probe again.
cat >> "$Q" <<'EOF'
{"turn":1,"action":"reap_probe"}
{"turn":2,"action":"time_skip","phrames":600}
{"turn":3,"action":"reap_probe"}
EOF

for _ in $(seq 1 60); do grep -q '"turn":3' "$R" 2>/dev/null && break; sleep 1; done

# Surface any no-refill build warnings the lint raised.
echo
echo "── LindbladBuilder no-refill warnings ──"
grep -i "no refill path" "$B" | sed 's/^/  /' || true
grep -qi "no refill path" "$B" || echo "  (none)"

python3 - "$R" <<'PY'
import json, sys
rows = {}
for line in open(sys.argv[1]):
    try: d = json.loads(line)
    except Exception: continue
    if "reap_probe" in d:
        rows[d["turn"]] = {r["biome"]: r for r in d["reap_probe"]}
ts = sorted(rows)
if not ts:
    print("\nno reap_probe rows — rig may not have active biomes"); sys.exit(0)
biomes = sorted({b for t in ts for b in rows[t]})
print()
print("%-18s %-7s %-7s %-7s %-7s %-9s %-7s %s" % (
    "biome/probe", "S0", "S1", "dS", "kT", "expected", "credits", "match?"))
for b in biomes:
    for i, t in enumerate(ts):
        r = rows[t].get(b)
        if not r: continue
        exp, cr = r["expected"], r["credits"]
        ok = "✓" if abs(round(exp) - cr) <= max(1, round(0.05*abs(exp))) else "✗ MISMATCH"
        print("%-18s %-7.3f %-7.3f %-7.3f %-7.1f %-9.1f %-7d %s" % (
            "%s #%d" % (b, i+1), r["S0"], r["S1"], r["dS"], r["kT"], exp, cr, ok))
    # refill verdict: did S recover between probe 1's S1 and probe 2's S0?
    if len(ts) >= 2 and rows[ts[0]].get(b) and rows[ts[1]].get(b):
        s1_after = rows[ts[0]][b]["S1"]; s0_before = rows[ts[1]][b]["S0"]
        delta = s0_before - s1_after
        verdict = "S recovered (pump/webway out-paced decay)" if delta > 0.05 \
            else "S fell (decay-dominated window)"
        print("%-18s   ΔS over skip = %+.3f  → %s" % ("  "+b, delta, verdict))
print("\n(probe #N brackets a real reap; expected = kT·ΔS should match credits.")
print(" skip line: whether S recovered between probes — a runtime balance read,")
print(" NOT the refill-path test (that's the build-time LindbladBuilder lint above).)")
PY
