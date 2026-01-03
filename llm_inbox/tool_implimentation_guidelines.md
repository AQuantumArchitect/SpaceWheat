You want concrete implementation guidance for the incomplete SpaceWheat toolchain—especially the “research‑grade” quantum mechanics pieces (gates, measurement triggers, energy taps/pump/reset, decoherence tuning, and biome reassignment)—based on the exported design/status/architecture docs you shared. 

## What matters

* **Architectural fit:** everything must slot cleanly into the existing Input → ToolConfig → FarmInputHandler → Farm → Grid/Biomes → QuantumBath stack. 
* **Quantum invariants:** whenever you touch a density matrix, you must preserve (or explicitly re‑normalize) **trace = 1**, **Hermiticity**, and **positivity** (within numeric tolerance). 
* **Bounded complexity:** avoid any hidden O(2^N) path; the docs already flag cluster/N‑qubit blowups as a risk. 
* **Coherent semantics across tools:** Tool 2 (infrastructure/triggers) and Tool 5 (operations) must share one consistent “what is a gate?” story, or you’ll implement mutually incompatible backends.
* **Testability:** implement the math primitives first (unitary application, Lindblad channels, trigger scheduling), then wire UI actions; this matches what your testing report shows is currently missing.

## Answer

### 1) Start with shared primitives (this unlocks Tools 2/4/5/6)

Right now, multiple tools are blocked on the same missing “physics plumbing”: gate application, trigger scheduling, and consistent state transitions. Your architecture doc already points to where these belong (FarmGrid/BasePlot/QuantumBath/Farm).

#### 1.1 Implement `QuantumBath.apply_unitary(U, indices)`

You already have a per‑biome `QuantumBath` with an N×N density matrix and a ComplexMatrix math layer.

Implement a **subspace unitary embedding** so you can apply a 2×2 or 4×4 gate to selected basis indices without constructing an N×N “big U”.

Core math (density matrix update):

* Full: **ρ′ = U ρ U†**
* Embedded on a subset `S` of basis indices:

  * Update the S×S block: ρSS′ = U ρSS U†
  * Update cross blocks: ρSO′ = U ρSO and ρOS′ = ρOS U†
  * Leave OO block unchanged

Key safeguards:

* After update, **renormalize trace** to 1 (small float drift will happen).
* Optionally assert `ρ ≈ ρ†` within epsilon and clamp tiny negative eigenvalues if you have eigen decomposition available (or just tolerate small negatives and log).

This single method is the backbone for Tool 5 (gates), Tool 2 (cluster prep if you implement CZ‑chains), and potentially some Tool 4 controls if you model certain controls as unitaries rather than Lindblad channels.

**Counterpoint:** If your “basis states” in the bath are *shared emojis* (e.g., multiple plots reference the same 🌾 index), then 2‑qubit gates that assume a tensor product structure can become ill‑defined. The docs don’t guarantee “plot‑local basis indices,” only emoji basis indices. The safest MVP is to (a) restrict 2‑qubit gates to cases where the four indices are distinct, and (b) explicitly error/deny otherwise, rather than silently doing nonsense math.

#### 1.2 Define a single “GateSpec” table (arity + matrix + validation rules)

Centralize gate definitions once (e.g., in a `QuantumGateLibrary.gd` or in QuantumBath as static helpers):

* 1‑qubit: X, Z, H (2×2)
* 2‑qubit: CNOT, CZ, SWAP (4×4) 

Store:

* `arity = 1 | 2`
* `matrix = ComplexMatrix`
* `requires_same_biome = true` (strongly recommended)
* `requires_unmeasured = true` (strongly recommended)
* `requires_distinct_basis_indices = true` (for 2‑qubit, recommended)

This prevents Tool 5 and Tool 2 from duplicating definitions (and diverging).

#### 1.3 Add a minimal gate registry (even if you later change semantics)

Your Tool 2 doc already sketches this: `FarmGrid.gates_registry` + per‑plot `applied_gates`. 

Implement the registry even if you decide gates are “instantaneous,” because:

* Tool 5 has a Remove Gates action stubbed. 
* Tool 6 inspection wants to show “which gates applied.” 

Minimal schema:

* Key: either `pos` for 1‑qubit gates, or `PairKey(posA,posB)` for 2‑qubit gates
* Value: array of `{ gate_type, params, created_at_turn/time }`

Then you can decide later whether those registered gates are:

* purely informational (“history”), or
* persistent and re‑applied at specific times.

---

### 2) Tool 5 (Gates): implement backend as true unitary ops on the bath subspace

Tool 5 is “UI complete, backend stubbed,” so you’ll get the most visible progress fastest once `apply_unitary` exists.

#### Recommended design choices (to unblock implementation)

* **Gate application mechanics:** Option C (single plot for 1‑qubit; explicit pair selection for 2‑qubit). This keeps UX sane and prevents arity errors. 
* **Gate effect:** Option A (true unitaries, ρ′ = UρU†). This matches “research‑grade” intent and your existing density matrix substrate.
* **Restrictions:** enforce “no gates on measured plots” (and optionally “no stacking” for MVP). This prevents post‑measurement weirdness and keeps state tracking simple. 

#### Concrete implementation sketch

For a selected plot `pos`:

1. `plot = farm.grid.get_plot(pos)`
2. `biome = farm.grid.biomes[farm.grid.plot_biome_assignments[pos]]`
3. `bath = biome.quantum_bath`
4. `i = bath.index_of(plot.quantum_state.north_emoji)`
5. `j = bath.index_of(plot.quantum_state.south_emoji)`
6. `bath.apply_unitary([i, j], U_gate)`

For two‑plot gates (CNOT/CZ/SWAP):

* Require both plots in same biome (same bath).
* Build indices `[c0,c1,t0,t1]` where `c0/c1` are control’s (north,south), `t0/t1` target’s.
* Validate all four are distinct; if not, refuse (MVP).
* Apply `bath.apply_unitary(indices, U_4x4)`.

**Gate removal (Tool 5 R):**

* Implement as **registry cleanup only** initially:

  * remove entries for selected plot(s) from `gates_registry`
  * optionally remove “visual markers”
* Do **not** attempt to “undo” the past quantum evolution; with Lindblad noise, undo is not well-defined. (If you later implement a strict unitary‑only sandbox mode, you could support inverse‑undo, but not in the main loop.)

---

### 3) Tool 2 (Quantum): treat it as infrastructure + automation, not “more math”

Tool 2 is partially implemented: UI exists, but gate construction logic, trigger wiring, and batch measurement coordination are missing.

#### Recommended design choices

* **Gate persistence across harvest:** Option B (persist), *but* define persistence as “registry persists,” not “state magically persists.” This is mostly a data‑model choice and enables long‑term strategy.
* **Measurement triggers:** Option A (auto‑measure at maturity) first. Anything yield‑threshold/cost‑based needs prediction hooks you don’t yet have robustly. 
* **Cluster priority:** Option A (2‑qubit first). Implement clusters later after gates and triggers are stable. 
* **Gate‑measurement interaction:** Use a strict rule: “Gates only operate on unmeasured plots.” Whether you keep registry entries after measurement is a gameplay decision; the physics layer should simply skip measured plots.

#### Implementation: Measurement triggers

Add to `BasePlot`:

* `measurement_trigger: Dictionary = { "mode": "maturity", "armed": true }` (or null) 

Where to check triggers:

* Easiest is in the **Farm update loop** (centralized), not per plot, because plots may not have direct access to `Farm.measure_plot()`. Your architecture already routes control through Farm/FarmGrid. 

Trigger condition:

* `if plot.is_planted and not plot.has_been_measured and plot.is_mature() and trigger.armed: farm.measure_plot(pos)`

Edge handling:

* Avoid re‑entrancy: queue measurements and execute after the iteration, or execute in a safe phase of your tick.

#### Implementation: Batch measurement

Tool 2 R wants batch measuring; you already have per‑plot measurement working.

Implement a new API:

* `Farm.measure_plots(positions:Array[Vector2i]) -> Array[Dict]`

Suggested coordination logic:

1. Partition `positions` by biome (since each biome has its own QuantumBath).
2. For each biome group:

   * apply any queued 2‑qubit gates among those plots (if you support “apply gates at measurement time” semantics), then
   * measure plots in a deterministic order (e.g., sorted coordinates) to make outcomes reproducible under seed.

**Counterpoint:** If you intend entanglement (Tool 1) to create *measurement correlation*, then “batch measure” is the natural place to enforce “measure the whole connected component at once.” Without source, I can’t tell if your current entanglement system actually couples outcomes; but if it does, batch measurement should measure the entangled set as an atomic operation to avoid order artifacts.

#### Implementation: Cluster (Tool 2 Q)

Given the complexity warnings and the fact that Tool 1 already creates Bell φ+ entanglement, ship “Cluster Q” as:

* If 2 plots: call existing `farm.entangle_plots(pos1,pos2)` (already working).
* If 3+ plots: either refuse with a clear message (“clusters not yet supported”), or create a **restricted CZ-chain** inside the same biome by applying CZ between neighbors (only if `apply_unitary` is done).
  This keeps it bounded and still meaningful.

---

### 4) Tool 4 (Biome Control): implement energy taps as Lindblad drain channels + finish decoherence tuning

Tool 4 is the strongest “research tool” already: pump/reset exists, energy tap UI exists, decoherence tuning is partial.

#### Energy tap backend (Phase‑2 style)

Treat a tap on emoji `e` as adding a **drain Lindblad operator** that moves population/coherence from `e` into a sink state.

Canonical form:

* Choose sink basis state `|sink⟩` (you already reference sink in pump).
* Add L = √γ |sink⟩⟨e| to the bath’s Lindblad operator list for duration `T`.

Implementation pattern:

* `BiomeBase.start_energy_tap(emoji:String, rate:float, duration:float)`

  * ensures sink exists in `QuantumBath`
  * registers a timed operator in the bath (or biome)
* In `QuantumBath.evolve(dt)`:

  * apply all active Lindblad terms (including taps)
  * decrement durations and remove expired taps

This gives you:

* research‑flavored “measurement/interaction channel” control (CPTP),
* a clean way to show flux in UI later (population change of sink vs source).

#### Pump/reset correctness

Your docs claim pump/reset handlers already exist and are callable.
Double‑check the math:

* **Reset to pure:** ρ ← (1−α)ρ + α|ψ⟩⟨ψ|
* **Reset to maximally mixed:** ρ ← (1−α)ρ + α(I/N)

These are CPTP by construction and easy to test (trace stays 1; eigenvalues non‑negative).

#### Tune decoherence (Tool 4 R)

Implement as a biome‑level scalar that multiplies decoherence Lindblad rates:

* `BiomeBase.decoherence_scale` (default 1.0)
* When constructing Lindblad operators or applying them, multiply γ by this scale.

Then the Tool 4 R action can:

* set scale directly (discrete steps), or
* cycle a few presets (0.5×, 1×, 2×) for gameplay readability.

---

### 5) Tool 6 (Biome): implement reassignment as a constrained state transition + build an inspector that surfaces the right invariants

Tool 6 is UI‑ready but missing reassignment backend, clear assignment, and a real inspector.

#### Recommended design choices

* **Reassignment allowed:** Option D (temporal restriction) — only allow reassignment when plot is not planted / between cycles. This avoids unsafe mid‑evolution bath transfers. 
* **Quantum state on reassignment:** Option C (complete reset). Anything “preserve state” collides with different emoji vocabularies per biome and risks breaking bath invariants.
* **Inspect plot:** start with Option C (gameplay‑focused) *plus* an “advanced” section showing purity/basis/coherence/gates/entanglement.

#### Concrete reassignment API

Add in `FarmGrid`:

* `reassign_plot(pos, new_biome_name) -> bool`

  * validate biome exists
  * validate plot is empty/unplanted (MVP)
  * clear plot-local metadata: `has_been_measured`, triggers, entanglement links, and gates on that plot
  * set `plot_biome_assignments[pos] = new_biome_name`
  * emit a signal so UI updates

“Clear assignment” (Tool 6 E):

* simplest, deterministic: revert to the farm’s initial biome layout (store `initial_plot_biome_assignments` at init).

#### Inspector (Tool 6 R)

Implement an inspector function that returns a dict the UI can render:

* crop type, planted/measured, maturity progress
* biome name
* `north_emoji`, `south_emoji`
* `purity`, `mass`, `order/coherence`
* gates on plot (from registry)
* entanglements (neighbors / component)
* measurement trigger config

This becomes your debugging superpower; it will also make gate/tap behavior understandable without exposing raw matrices.

---

### 6) Tool 3 (Industry): keep it minimal so it doesn’t destabilize quantum work

Tool 3 is currently stubbed and needs a full design.

If your priority is “research‑grade quantum tools,” implement Industry in a way that doesn’t require new spatial systems or deep coupling:

* Placement: Option B (floating UI / non-spatial) for MVP.
* Effects: Option A (simple multipliers/bonuses) rather than direct quantum substrate manipulation.
* Persistence: removable with cost (avoids permanent regret). 

This lets you ship Industry without entangling it with the bath math until your quantum tooling is stable.

---

### 7) Recommended implementation order (minimizes rework)

This sequence matches what’s missing per status + test report.

1. **QuantumBath.apply_unitary(indices,U)** + gate library matrices
2. **Tool 5**: 1‑qubit gates (strict validation)
3. **Tool 5**: 2‑qubit gates (same biome + distinct indices; pair selection)
4. **Tool 2**: batch measurement API + wiring Tool2-R
5. **Tool 2**: measurement triggers (auto at maturity) + Tool2-E
6. **Tool 4**: energy tap drain Lindblad operators + decoherence tuning
7. **Tool 6**: reassignment (restricted/reset) + inspector
8. **Tool 3**: minimal non-spatial Industry

---

## Risks/unknowns

* Your docs describe plots as 2D projections into a biome bath; if multiple plots share the same emoji basis indices, **2‑qubit gates may be ambiguous** unless you restrict or introduce plot‑local basis state IDs.
* I can’t see the exact entanglement representation; if it affects measurement outcomes, then sequencing in batch measurement and trigger measurement can introduce artifacts unless you measure entangled components atomically.
* “Remove gates” semantics depend on whether gates are instantaneous pulses vs persistent scheduled controls; implement registry removal first, and avoid claiming it “undoes” evolution. 

## Next action

Implement `QuantumBath.apply_unitary(indices,U)` + a gate matrix library, then wire Tool 5’s Pauli‑X/H/Z to it (single‑plot validation). That single slice will immediately convert Tool 5 from “UI only” into a functioning quantum control surface and gives you the primitive needed for Tool 2 clusters and batch measurement afterward.

Confidence: **Medium** — high confidence on the architectural/mathematical approach, lower confidence on edge semantics because source-level details of entanglement and emoji index uniqueness aren’t visible in the export.
