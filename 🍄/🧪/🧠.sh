#!/usr/bin/env bash
# 🧠  Reservoir Regime Map — parametric (H × L) sweep of the broad graph
#
# The biomes' neighborhoods form reservoirs; the global coupling/rate scales are an
# EDGE-OF-CHAOS dial. Too much Hamiltonian (high H scale) → ringing/ordered; too much
# Lindblad (high L scale) → damped/frozen. Useful computation ("intelligence") lives
# in between. This sweeps the (hamiltonian_coupling_scale × lindblad_rate_scale) grid
# and reports, per regime, learning/intelligence metrics over the whole graph:
#   richness     — mean entropy        (dynamic range / state spread)
#   integration  — mean mutual info    (how much the parts share information)
#   order        — mean purity         (1 = frozen, low = lively)
# It then flags the liveliest regime (richness × integration) as a starting point.
#
# Parametric, NOT boutique: it tunes 2 global knobs over the ~4000 authored values,
# never per-edge. Canonical regime is restored when the sweep finishes.
#
# Rig harness (full boot) — see 🌡️.sh header for why standalone --script labs are dead.
#
# Usage:  bash 🍄/🧪/🧠.sh [scenario]        (default scenario: demos_normal)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"
source "$ROOT_DIR/scripts/lib/godot_runtime_env.sh"

SCENARIO="${1:-demos_normal}"
Q="$(mktemp /tmp/sw_resmap_q.XXXXXX.jsonl)"
R="$(mktemp /tmp/sw_resmap_r.XXXXXX.jsonl)"
B="$(mktemp /tmp/sw_resmap_b.XXXXXX.txt)"
: > "$Q"

echo "🧠  Reservoir Regime Map — scenario=$SCENARIO"
echo "    (parametric H × L sweep; canonical regime restored after — see header)"

RIG_SCENARIO="$SCENARIO" RIG_QUEUE_PATH="$Q" RIG_RESULT_PATH="$R" \
  sw_godot --headless --path . --script Rig/rig_listener.gd > "$B" 2>&1 &
RIG_PID=$!

cleanup() { kill -9 "$RIG_PID" 2>/dev/null; rm -f "$Q" "$R" "$B"; }
trap cleanup EXIT

for _ in $(seq 1 45); do grep -q "Rig ready" "$B" 2>/dev/null && break; sleep 1; done
if ! grep -q "Rig ready" "$B" 2>/dev/null; then
  echo "❌ rig did not reach 'Rig ready' — boot log tail:"; tail -8 "$B"; exit 1
fi

cat >> "$Q" <<'EOF'
{"turn":1,"action":"reservoir_sweep","h_scales":[0.5,1.0,2.0],"l_scales":[0.5,1.0,2.0],"phrames":400}
EOF

# The sweep rebuilds + evolves every biome at each of 9 regimes — give it room.
for _ in $(seq 1 180); do grep -q '"turn":1' "$R" 2>/dev/null && break; sleep 1; done

python3 - "$R" <<'PY'
import json, sys
rows = None
for line in open(sys.argv[1]):
    try: d = json.loads(line)
    except Exception: continue
    if "reservoir_sweep" in d:
        rows = d["reservoir_sweep"]
if not rows:
    print("\nno reservoir_sweep rows — rig may not have active biomes"); sys.exit(0)

hs = sorted({r["h"] for r in rows})
ls = sorted({r["l"] for r in rows})
cell = {(r["h"], r["l"]): r for r in rows}

def grid(metric, title):
    print("\n%s   (rows = H-coupling scale, cols = L-rate scale)" % title)
    print("        " + "".join("L=%-9.2g" % l for l in ls))
    for h in hs:
        line = "  H=%-4.2g " % h
        for l in ls:
            r = cell.get((h, l))
            line += "%-10.3f" % (r[metric] if r else float("nan"))
        print(line)

grid("richness", "richness  (mean entropy — dynamic range)")
grid("integration", "integration  (mean mutual information — info sharing)")
grid("order", "order  (mean purity — 1=frozen, low=lively)")

# Liveliest = richness × integration (rich AND integrated → edge-of-chaos candidate).
best = max(rows, key=lambda r: r["richness"] * r["integration"])
print("\n⭐ liveliest regime: H=%.2g  L=%.2g  (richness=%.3f integration=%.3f order=%.3f)"
      % (best["h"], best["l"], best["richness"], best["integration"], best["order"]))
print("   (a starting point for tuning — verify by playing, not just the score)")

# Reading the map (physics that bites here):
l_flat = all(abs(cell[(h, ls[0])]["richness"] - cell[(h, l)]["richness"]) < 1e-3
             for h in hs for l in ls)
if l_flat:
    print("\n  note: richness is flat across L — uniform Lindblad-rate scaling does NOT")
    print("  move the steady state, only the relaxation SPEED. To see L bite, probe a")
    print("  transient horizon (small phrames) or sweep the H/L RATIO, not the L scale.")
if best["integration"] < 0.02:
    print("  note: integration ≈ 0 — the active biomes are small/weakly-coupled clusters.")
    print("  Richer scenarios (bigger neighborhoods) will show real reservoir structure.")
PY
