# SpaceWheat Quantum↔Classical Interface Manifest (Gozintas/Gozoutas)

**Purpose:** An implementation-ready spec for a quantum-rigorous, game-readable interface across the quantum↔classical divide. Designed to be both (a) a fun factory/cultivation game and (b) a credible educational tool for quantum computing architecture.

---

## 0) Core Philosophy: The Control & Readout Loop
Everything the player does is framed as **real quantum architecture**:

1. **Prepare / Pump (Gozintas)** — spend classical resources as *work* to lower entropy and bias the bath toward target modes.
2. **Evolve / Control** — engineer **Hamiltonian (H)** and **environment (γ)** to shape coherent dynamics vs decoherence.
3. **Readout (Gozoutas)** — extract value via **instruments** (taps, selective measurement, global harvest) that obey measurement backaction.

A “run” is a quantum experiment: tune → peak → readout → reset → repeat.

---

## 1) Non‑Negotiable Physics Contract (Hard Guardrails)
### 1.1 Density matrix invariants (must hold every frame)
- **Hermitian:** ρ = ρ†
- **Trace‑1:** Tr(ρ) = 1
- **Positive semidefinite:** eigenvalues ≥ −ε (numerical tolerance)

### 1.2 Allowed state updates only
Any operation that changes ρ must be one of:
- **Unitary:** ρ ← U ρ U†
- **CPTP channel (Kraus):** ρ ← Σⱼ Kⱼ ρ Kⱼ† with Σⱼ Kⱼ†Kⱼ = I
- **Measurement instrument (Kraus + outcome):**
  - pₖ = Tr(Mₖ ρ Mₖ†)
  - ρₖ = Mₖ ρ Mₖ† / pₖ

### 1.3 Kraus Operator Implementation Notes (Do Not Skip)
**Why this exists:** the #1 failure mode for “quantum-rigorous” gameplay code is drifting into diagonal tweaks or renormalization hacks. The coder must implement the following explicitly.

#### 1.3.1 Operator splitting per tick (recommended)
Implement evolution each tick dt as **(unitary step) then (channel step)**.
- **Unitary:** rho <- U rho U† with U ~ exp(-i H dt)
- **Channels:** rho <- sum_j K_j rho K_j†, where {K_j} realizes the Lindblad effects over dt.

For small dt, the standard first-order Kraus realization of Lindblad jumps is:
- For each jump operator L_a:  K_a = sqrt(dt) * L_a
- No-jump:                 K_0 = I - (dt/2) * sum_a (L_a† L_a)
Apply: rho <- K_0 rho K_0† + sum_a K_a rho K_a†

Selective (postselected) updates are trace-decreasing until conditioned; renormalize only the selected branch.

#### 1.3.2 Canonical Kraus sets to reuse
(A) **Basis dephasing** (strength lambda in [0,1]):
- K0 = sqrt(1-lambda) * I
- Ki = sqrt(lambda) * |i><i| for each basis i

(B) **Weak projector probe (Scanner)** (strength kappa << 1 for projector P):
- K0 = sqrt(1-kappa) * I
- K1 = sqrt(kappa) * P
- K2 = sqrt(kappa) * (I-P)

(C) **Drain-to-sink tap** (rate kappa, sink |sink>):
- L_e = sqrt(kappa) * |sink><e|

(D) **Pump-from-rest** (rate Gamma, rest |r> to target |t>):
- L_t = sqrt(Gamma) * |t><r|

(E) **Reset / replacement channel** (strength alpha):
Reset is a CPTP mixing channel: rho <- (1-alpha) rho + alpha rho_ref.
- Pure reset to |0><0| has a Kraus realization:
  - K0 = sqrt(1-alpha) * I
  - Kj = sqrt(alpha) * |0><j| for all basis j

#### 1.3.3 Trace rules
- CPTP channels preserve trace by construction.
- Postselection / selective instruments require renormalizing the kept branch: rho <- rho_k / Tr(rho_k).

### 1.4 Forbidden shortcuts
- No ad‑hoc diagonal “boost/renorm hacks” that can break complete positivity.
- No global probability redistribution as a side-effect of expanding the Hilbert space.
- No “free postselection” without explicit cost/time accounting.

---

## 2) Entities & Terms
- **Bath/Biome:** global density matrix rho over emoji basis states (N <= 20).
- **Emoji mode:** basis state |e>.
- **Rest mode |r>:** designated reservoir source used by pumps (either a single basis state or a proxy set).
- **SubspaceProbe (2D viewport):** formal primitive for local visualization/control.
  - Defined by two basis indices (n,s).
  - Reduced 2x2 block: rho_sub = [[rho_nn, rho_ns],[rho_sn, rho_ss]].
  - Mass in viewport: p_sub = Tr(rho_sub) = rho_nn + rho_ss.
  - Normalized viewport state (visual only): rho_sub_norm = rho_sub / p_sub.
- **Lens/Plot:** gameplay object that owns a SubspaceProbe + local devices (pump/tap/scanner) and contributes to payouts.
- **Run:** one evolution schedule + readout (ends at Harvest-All).
- **Shot:** one measurement sample from a run.

---

## 3) Gozintas (Classical → Quantum) — Inputs as Work
Classical resources enter as **engineered dynamics**.

### 3.1 Gozinta A — Subspace Pumping (Reservoir Engineering)
**Player action:** run a powered pump to move population from “rest” into target emojis.

**Implementation (conceptual):** Lindblad jump operators that transfer probability into target.
- Pick a designated **rest** state |r⟩ (can be an explicit basis state, or a proxy set).
- For each target |t⟩, add jump:
  - Lₜ = √Γ · |t⟩⟨r|
- Γ scales with classical spend (and possibly infrastructure tier).

**Primary effect:** increases **subspace population** in chosen modes (the “stuff in the window”).

### 3.2 Gozinta B — Hamiltonian Control (Coherent Work)
**Player action:** strengthen/shape off‑diagonal couplings Hᵢⱼ to drive coherent oscillations.

**Implementation:** adjust sparse H entries (dictionary keyed by (i,j)).

### 3.3 Gozinta C — Cryo‑Tuning (Isolation)
**Player action:** pay to reduce decoherence rates γ (but never to zero).

**Implementation:** scale Lindblad noise parameters.

**Educational metric:** purity Tr(ρ²) increases when decoherence is reduced / pumping is effective.

### 3.4 Gozinta D — Reset / Cooling (Algorithmic Cooling Primitive)
A true quantum computer requires a clean reset. This is the **ultimate gozinta**.

**Player action:** spend credits to reset a chosen viewport/subspace (or the whole bath) toward a reference state.

**Mechanism (CPTP):** replacement/mixing channel:
- rho <- (1-alpha) * rho + alpha * rho_ref
- alpha scales with spend; clamp alpha <= alpha_max per tick.

**Reference options:**
- Pure reset: rho_ref = |0><0| (max order, higher cost)
- Mixed reset: rho_ref = I/N (cheap, low order)
- Viewport-only reset: apply to SubspaceProbe block (lab) or approximate via pump+dephase (kid)

**Teaching point:** purity Tr(rho^2) is expensive; reset is where classical work buys order.

### 3.5 Gozinta E — Hardware Modules (Emoji Expansion)
**Player action:** installing a new emoji into the bath is a **physical module install**.

**Hard rule:** expanding N must not redistribute existing probability.
- Expand Hilbert space by **block‑embedding** old ρ into the new basis.
- New basis state starts with 0 population unless explicitly pumped/prepared.

**Cost/time:** module install should have explicit classical cost and time.

---

## 4) Gozoutas (Quantum → Classical) — Readout Channels
All outputs are modeled as instruments with clear backaction and economics.

**Channels:**
- **Gozouta 1:** Trickle Drain (continuous taps)
- **Gozouta 1.5:** Weak Measurement Scanner (fuzzy estimate, gentle backaction)
- **Gozouta 2:** Selective Measurement (zero-fail readout via costed postselection)
- **Gozouta 3:** Harvest-All (global vector port)
All outputs are modeled as **instruments** with clear backaction and economics.

### 4.1 Gozouta 1 — Trickle Drain (Continuous Taps)
**Goal:** continuously extract resources without ending the run.

**Rigorous mechanism:** weak coupling to an output port via a **sink basis state** |sink⟩.
- For each drained emoji |e⟩, add jump:
  - Lₑ = √κ · |sink⟩⟨e|

**Yield:** classical accumulation ∝ probability flux into |sink⟩ per tick.

**Backaction:** population leaves drained modes; optional small dephasing tied to κ.

**Design note:** taps are deliberately “classical-ish” (usually no coherence bonus) unless a special interferometric tap is implemented.

---

### 4.2 Gozouta 1.5 — Weak Measurement Scanner (Fuzzy Readout)
**Goal:** provide a fuzzy estimate of the current local state while only gently disturbing coherence.

**Mechanism (CPTP):** weak projector probe with strength kappa << 1 applied to a projector P.
- K0 = sqrt(1-kappa) * I
- K1 = sqrt(kappa) * P
- K2 = sqrt(kappa) * (I-P)
- rho <- K0 rho K0† + K1 rho K1† + K2 rho K2†

**Readout:**
- HARDWARE mode: noisy click/no-click + running estimator.
- INSPECTOR mode: exact p(P)=Tr(P rho) + show SubspaceProbe rho_sub_norm.

**Backaction:** partial dephasing between P and (I-P).

---

### 4.3 Gozouta 2 — Selective Measurement (Zero-Fail Readout)
**Goal:** measure only in a chosen window/axis and never return '?'.

This is **postselection** (or a click/no-click detector).

#### 4.2.1 Measure‑Pair: `MEASURE_PAIR(north, south)`
**Returns:** north or south only.

**Projector:** P = |n⟩⟨n| + |s⟩⟨s|
- p(P) = Tr(Pρ)
- Conditional probabilities:
  - p(n|P) = ρₙₙ / p(P)
  - p(s|P) = ρₛₛ / p(P)

**No‑fail rigor rule (mandatory):** charge cost/time proportional to **1 / p(P)**.
- Interpretation: “we discard runs until the detector clicks in this channel.”
- Clamp 1/p(P) to a maximum for playability; show the clamp in lab HUD.

**Backaction modes:**
- **Kid Mode (light):** apply mild dephasing in window; avoid full collapse.
- **Lab Mode (true):** apply Kraus update for a projective measurement within the window.

#### 4.2.2 Measure‑One: `MEASURE_EMOJI(e)`
Same as above with P = |e⟩⟨e|.
- Cost/time ∝ 1/ρₑₑ.

#### 4.2.3 Optional upgrade: Click / No‑Click instrument
Replace cost‑only postselection with a real repeated measurement instrument:
- M_click = √η P
- M_noclick = √(I − ηP)
Repeat noclick updates until click.

---

### 4.4 Gozouta 3 — Harvest-All (Global Vector Port)
**Goal:** end the run with a dramatic global collapse and export the entire biome as a **multi‑field resource vector**.

#### 4.3.1 Output must be a vector port
Harvest‑All produces **all configured outputs at once**.

Define a port schema:
- A set of output channels i = 1..m
- Each channel has weights over emojis: w_i(e)
- Expected yield (Inspector / expected mode): y_i = sum_e w_i(e) * p(e)

#### 4.4.1a Joint Payout Mapping (single outcome -> many payouts)
**Goal:** one global collapse outcome informs multiple classical channels via lenses.

Let each active Lens l define a contribution vector g_l(k) for a measured outcome k (usually sparse; zero unless k is in its viewport or payout set).
- Hardware payout: y = sum_l g_l(k)
- Inspector expected payout: E[y] = sum_k p(k) * (sum_l g_l(k))

Implementation tip: precompute `outcome_emoji -> [lenses_that_pay]` so payout is O(#lenses_that_pay).

#### 4.3.2 Two readout modes
**Hardware Mode (shot‑faithful):**
- Sample a single global outcome k ~ p(k)
- Produce payout vector **f(k)**
- (Optional) Batch‑run N shots for histogram/expected payout

**Inspector Mode (simulator privilege):**
- Compute exact p(e) from ρ at readout time
- Export the exact distribution and/or expected payout vector

**UI requirement:** Inspector Mode must be explicitly labeled as simulator-only.

#### 4.3.3 End‑of‑run semantics
Harvest‑All ends the run and triggers reset/reinitialize.

---

## 5) Measurement & Backaction Policy (Modes)
Provide explicit mode flags:
- `READOUT_MODE = HARDWARE | INSPECTOR`
- `BACKACTION_MODE = KID_LIGHT | LAB_TRUE`
- `SELECTIVE_MEASURE_MODEL = POSTSELECT_COSTED | CLICK_NOCLICK`

**Key trace rule:** `_normalize_trace()` is required only after selective/trace-decreasing updates (postselection / keeping a branch). CPTP channels and non-selective instruments must preserve trace by construction.

### 5.1 Directives to Agentic Coder (Read Before Implementing)
**Icon Atomicity:** every Icon resource must carry:
- `hamiltonian_map` (sparse couplings)
- `lindblad_map` (sparse decay/pump/drain channels)

**Subspace Viewports:** replace `DualEmojiQubit` with `SubspaceProbe`.
- Must compute reduced 2x2 block rho_sub and rho_sub_norm.
- HUD must show:
  - Mass: p_sub = Tr(rho_sub)
  - Order: coherence visibility (e.g., abs(rho_ns) and/or abs(rho_ns)/p_sub)

**Unitary/CPTP Enforcement:**
- Gozintas that modify population must be CPTP (pump/reset). Control is unitary (H).
- Gozoutas must use Kraus updates: rho <- sum K_j rho K_j†.
- If an operation is selective, renormalize the branch to trace-1.

**Sparsity:** maintain H and Lindblad modifiers as sparse dictionaries for performance at N <= 20.

Defaults recommended:
- Teaching/QC default: **HARDWARE + LAB_TRUE** (with batch shortcuts available)
- Kid default: **INSPECTOR optional + KID_LIGHT**

---

## 6) Economy & Education Metrics (What players should see)
### 6.1 Two core gauges (must be in HUD)
1) **Subspace Population (Mass):** “how much stuff is in the window”
2) **Coherence Visibility (Order):** “how quantum‑ordered it is”

These should be visually distinct so players learn they’re different resources.

### 6.2 Scale wall (must be in HUD)
Add a **Simulator Cost Meter** tied to:
- Hilbert dimension N
- density matrix ops count
- number of active pumps/taps/instruments
- optional batch shots

Teaching point: classical simulation costs explode; real hardware doesn’t pay this classical cost.

---

## 7) Factory Compilation (Quantum → Classical Abstraction)
When a biome is tuned and repeatable, implement a **Compile** step:

### 7.1 What “Compile” stores
- Input recipe: gozinta settings (pump Γ, H boosts, γ tuning, modules)
- Timing schedule (control program)
- Readout configuration (ports + modes)
- Exported behavior:
  - **Inspector:** store full distribution p(e) (and derived payout vector)
  - **Hardware:** store empirical histogram from batch shots (with N and confidence)

### 7.2 What the compiled factory does
A classical component that maps classical inputs → stochastic or expected outputs.
- **Expected mode:** deterministic output vector (smooth factory gameplay)
- **Sampling mode:** draw from stored distribution (authentic stochasticity)

---

## 8) Performance Directives (N ≤ 20, sparse)
- Use sparse/dictionary representations for H and Lindblad operator definitions.
- Avoid O(N³) eigen-decompositions per frame; reserve PSD checks for tests/debug builds.
- Prefer operator splitting per tick:
  1) unitary step (approx expm or small-step integrator)
  2) channel step via Kraus/Lindblad update

---

## 9) Testing & Verification (Must ship with this)
### 9.1 Per‑frame invariants (debug/lab)
- Assert Hermitian within ε
- Assert trace within ε
- PSD check: eigenvalues ≥ −ε (periodic or on-demand)

### 9.2 Regression checks (required)
- Selective measurement cost increases as p(subspace) decreases
- Tap yield matches sink flux over time
- Module install does not redistribute existing probabilities

---

## 10) Optional “Science Spells” (Additive mechanics that teach real QC)
### 10.1 Error Mitigation Spell (Zero‑Noise Extrapolation)
- Run the same control program at scaled γ: (γ, 2γ, 3γ)
- Extrapolate observable/payout back to “γ→0” estimate
- Teach: we can mitigate noise without perfect hardware

### 10.2 Dynamical Decoupling Mini‑Game (Echo pulses)
- Provide a timed “π‑pulse” control that refocuses dephasing
- Mechanically reduces effective γ for a window if timed correctly
- Teach: control sequences fight decoherence

---

# Implementation Checklist (Do This In Order)
## Phase 1 — Core plumbing
- [ ] Mode flags: READOUT_MODE, BACKACTION_MODE, SELECTIVE_MEASURE_MODEL
- [ ] Sparse H storage + modifier hooks
- [ ] Lindblad parameter storage (γ) + scaler hooks

## Phase 2 — Gozouta 1: Tap
- [ ] Add |sink⟩ basis state (or per-port sinks)
- [ ] Implement Lindblad drain jumps Lₑ = √κ |sink⟩⟨e|
- [ ] Accumulate classical yield from sink flux

## Phase 3 — Gozouta 1.5: Scanner
- [ ] Implement weak probe Kraus channel (K0,K1,K2) for projector P
- [ ] HARDWARE: noisy estimate + running estimator; INSPECTOR: exact p(P) + rho_sub_norm

## Phase 4 — Gozouta 2: Selective measurement
- [ ] Implement POSTSELECT_COSTED for pair and emoji
- [ ] Implement cost/time multiplier = clamp(1 / p(P))
- [ ] Add Kid vs Lab backaction behavior

## Phase 5 — Harvest-All vector port
- [ ] Define port schema with weights wᵢ(e)
- [ ] Implement Inspector expected export: yᵢ = Σₑ wᵢ(e) p(e)
- [ ] Implement Hardware sampled export: sample k then payout f(k)
- [ ] End-of-run reset semantics

## Phase 6 — Gozintas (pumps, reset, modules)
- [ ] Implement reservoir pumping via Lindblad jumps into targets
- [ ] Implement reset/mixing channel (pure + mixed variants)
- [ ] Implement module install as block-embedding expansion
- [ ] Implement reservoir pumping via Lindblad jumps into targets
- [ ] Implement module install as block-embedding expansion

## Phase 6 — Compilation
- [ ] Export distributions/histograms into a factory component
- [ ] Allow expected-mode and sampling-mode factories

## Phase 7 — Rigor & teaching polish
- [ ] HUD gauges: population vs coherence
- [ ] Simulator Cost Meter
- [ ] Invariant tests + regression tests
- [ ] Optional science spells

