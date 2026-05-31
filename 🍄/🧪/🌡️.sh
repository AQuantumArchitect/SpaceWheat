#!/usr/bin/env bash
# 🌡️ Entropy & Market Lab — rig-driven biome balance readout
#
# The standalone --script labs (market_flatness_lab.gd, three_biome_lab.gd, …)
# are dead: a custom-SceneTree --script run does NOT attach project autoloads,
# and absolute /root node-paths throw "outside the active scene tree", so any
# lab that calls BiomeBuilder (which resolves /root/IconRegistry) crashes. The
# rig, by contrast, does a FULL boot → active tree → everything resolves.
#
# So this lab drives the rig's read-only `entropy_snapshot` command across a
# time-skip sweep and prints, per active biome: von Neumann-style diagonal
# entropy S, kT (Boltzmann market temperature), the reap bank kT·S, and a sample
# surprisal price. Shows which biomes hold entropy (webway ≳ decay) vs decay.
#
# Usage:  bash 🍄/🧪/🌡️.sh [scenario]      (default scenario: demos_normal)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/godot_runtime_env.sh"

SCENARIO="${1:-demos_normal}"
Q="$(mktemp /tmp/sw_entlab_q.XXXXXX.jsonl)"
R="$(mktemp /tmp/sw_entlab_r.XXXXXX.jsonl)"
B="$(mktemp /tmp/sw_entlab_b.XXXXXX.txt)"
: > "$Q"

echo "🌡️  Entropy & Market Lab — scenario=$SCENARIO"
echo "    (rig harness; standalone --script labs are deprecated — see header)"

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

# Sweep the scenario's active biomes: snapshot, skip, snapshot, skip, snapshot.
# (Coverage is the scenario's loaded biomes — broader coverage would need a
# richer RIG_SCENARIO or resource injection to afford discoveries; the starter
# set is the most balance-relevant early-game readout anyway.)
cat >> "$Q" <<'EOF'
{"turn":1,"action":"entropy_snapshot"}
{"turn":2,"action":"time_skip","phrames":300}
{"turn":3,"action":"entropy_snapshot"}
{"turn":4,"action":"time_skip","phrames":1200}
{"turn":5,"action":"entropy_snapshot"}
EOF

for _ in $(seq 1 60); do grep -q '"turn":5' "$R" 2>/dev/null && break; sleep 1; done

python3 - "$R" <<'PY'
import json, sys
rows = {}
for line in open(sys.argv[1]):
    try: d = json.loads(line)
    except Exception: continue
    if "entropy_snapshot" in d:
        rows[d["turn"]] = {r["biome"]: r for r in d["entropy_snapshot"]}
ts = sorted(rows)
if not ts:
    print("no entropy_snapshot rows — rig may not have active biomes"); sys.exit(0)
biomes = sorted({b for t in ts for b in rows[t]})
print()
for b in biomes:
    cells = []
    for t in ts:
        r = rows[t].get(b)
        cells.append("S=%.2f kT=%.1f bank=%.0f price=%.1f" % (r["S"], r["kT"], r["bank_kTS"], r["sample_price"]) if r else "-")
    print("%-18s %s" % (b, "  |  ".join(cells)))
print("\n(columns = snapshots over a 0 / +300 / +1500 phrame time-skip sweep)")
PY
