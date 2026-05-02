# Tensor Experiment Results — Village ⊗ HearthKeepers

## What we ran

`tests/tensor_market_village_hearth.gd` builds Village (regular biome) and HearthKeepers (the first faction-biome) side by side, evolves each independently for 30 sim seconds, then samples paired emoji marginals. A simple "market price" formula reads:

```
P_market(E) = avg(P_V(E), P_HK(E))     for shared emojis
tension(E)  = |P_V(E) − P_HK(E)|
price(E)    = (1 / P_market) × QC_RATIO × (1 + tension)
```

Two scenarios: HK Lindblad authored at biome strength (1×) and 5× scaled.

## What we learned

### 1. Cross-axis bridges carry the trade signal

Emojis paired on **different qubits** in the two biomes show the strongest market response. Village pairs `(💨/🍞)` differently than HearthKeepers — Village reads 💨 alone on one qubit and 🍞 alone on another, while HK pairs them as a single qubit. Under 5× scaling:

| Emoji | side | Δ price (1× → 5×) | Δ tension |
|---|---|---|---|
| 💨 | both, cross-bridge | **+28%** | +0.235 |
| 🍞 | both, cross-bridge | **+22%** | +0.068 |
| 🔥, ❄ | both, shared-pairing | ≈0% | −0.046 |

**Implication**: when authoring a faction-biome, the most market-relevant emojis are the ones paired *differently* than the regular biomes the faction inhabits. Don't slavishly copy the regular biome's pairing — the divergence is the signal.

### 2. Shared-axis pricing is sticky

Emojis paired the same way in both biomes show low Δ-price even when tensions widen. The averaging formula cancels symmetric drift. A future bias source should read in θ-space (`asin(2P − 1)`) where sum-vs-difference distinguishes bias from tension.

### 3. Private axes are independent

Emojis only on one biome (e.g. HK's `(💧/🏜)`) drift only with their own dynamics. Drains on shared emojis don't propagate. This is correct — it confirms biome isolation.

### 4. Numeric stability ceiling

5× of the heavy-side rate (0.20 → 1.0) is right at the integrator's edge. Above that, Euler steps with `max_dt=0.02` violate ρ-positivity ("catastrophic state, recovering to steady state"). **Stay at 0.20 ceiling for faction-biomes.** Don't be tempted to go higher even if a faction "feels Lindbladian-dominant" — strengthen the Hamiltonian instead.

### 5. Gated Lindbladian saturates fast

Even at heavy-side 0.20, gated_lindblad_source terms with power=2 will pin the source emoji marginal close to its drained pole when the gate is well-populated. Use power=2 only when you genuinely want a sharp threshold (e.g. "bake bread *only when* fire is strong"). Otherwise prefer power=1.

## Author-time heuristics from these results

1. **Pick at least one cross-axis bridge** with whichever regular biome the faction inhabits. That's where the trade signal lives.
2. **Pick at least one private axis** that the regular biome doesn't have. Lets the faction express something the world doesn't see directly — a hidden internal economy.
3. **Match the regular biome's hearth/heartbeat pairing** (e.g. `🔥/❄`) for the shared-pairing axis — it makes structural reads coherent. You can still detune the JSONL self-energies and drivers to give the faction its own rhythm.
4. **Keep the gated production chain inside the faction's signature**. If a faction's `sig` is `["🔥", "❄", "💧", "🏜", "💨", "🍞"]`, then the gated source on 🍞 should gate on 🔥 and 💨 (both in sig), not on emojis the faction doesn't control.
