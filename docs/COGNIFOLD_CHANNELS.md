# COGNIFOLD CHANNELS — the legend

The one place every visual channel of the 3D cognifold field is explained: what you are
looking at, what data drives it, and the honesty caveat that keeps it from lying. Until
2026-08-03 this legend existed only in source-file headers; those headers remain the
code-side authority — every row cites its source. Written for a human viewer first, and
for an LLM reading a screenshot or a `cognifold_trace_v1` JSON second (the trace field
names are given so the two views cross-reference).

Two renderers share the field:

- **`Core/Visualization/QuantumField3D.gd`** — the shipped game renderer (reads
  `biome.viz_cache`).
- **`Core/Visualization/CognifoldForecastField.gd`** — the reasoning-transparency
  instrument (subclass; extra channels light up only when the viz_cache exposes
  `get_gauge`, i.e. an umwelt trace via `UmweltVizCache.gd`; the game is unaffected).

Launch the instrument: `DISPLAY=:0 godot scenes/CognifoldTraceView.tscn`
(`SW_COGNIFOLD_URL` = live daemon poll, `SW_COGNIFOLD_TRACE[_DIR]` = recorded trace /
filmstrip; defaults to the committed filmstrip).

## Base channels (game + instrument) — QuantumField3D.gd header, lines 1–44

| You see | Meaning | Data | Honesty caveat |
|---|---|---|---|
| Big billboarded emoji on a dark backing ball | The register's identity: its north-pole axis icon | `get_axis(i).north` (game: icons.json; trace: `north_emoji`) | The emoji is the *axis label*, not the state — where the belief *sits* is the dot |
| Thin biome-colour ring | Which biome/world + coherence: bright = coherent, dull = decohered | BiomeVisualTheme + `r_xy` | "One colour = one meaning" — colour never doubles for anything else |
| Thin **gold** ring growing around the orb | Ripeness/value (gold is the global value colour in every biome) | `VisualizationConstants.ripeness(p0, p1)` | Grows only with the honest ripeness math — no celebratory inflation |
| Small dot off-centre inside the orb | The **honest Bloch state point** at real (x, y, z), length = r | `theta/phi/r_bloch` (trace) / viz_cache Bloch | Confidence IS the radius: an unsure belief's dot sits near the centre |
| Fading **cyan** trail behind the dot | Where the belief has recently been (backward memory) | recent state points | A still trail means a still belief — stillness is data, not a bug |
| Steel lines between orbs, static | **Metro lines** — permanent Hamiltonian coupling (potential: what is wired to what) | icons.json H / trace edges kind `zz`/`xy`/`bridge` | Static per biome ("H only moves on incorporation"); NOT evidence the pair is currently correlated |
| **Bright mint** lines, appearing/disappearing | **Live mutual information** — beliefs *actually sharing information right now* (bits) | MI sensor / trace edges kind `"mi"` | Distinct channel from metro lines (bits ≠ \|J\|; parallel-track offset so they never overlap). Mostly absent at rest — the substrate decorrelates on observation; MI fires on transients |
| Green cone at a pole / red cone at the other | **Lindblad flow** — pump in (green, north) / drain out (red, south) | `BasePlot.lindblad_pump_active/_drain_active` | Binary flags, register-local — an arrow is presence of flow, not its magnitude |
| Themed orbs on the left rail | Sibling portals — every other ASSIGNED biome (slot order = TYUIOP; fog placeholder if not yet renderable), click to dive | ActiveBiomeManager | Navigation, not physics. Each orb carries a "Name [key]" label; a dive speaks the shared confirm tail (→ toast, Focus repoint) via `biome_confirmed` |
| Small **indigo** satellite per orb; **cyan** portal | Descend into the register's icon-world; ascend back out | FractalWorldService | Indigo is fixed ("go deeper"), never a biome hue |

## Instrument-only channels — CognifoldForecastField.gd header + constants

| You see | Meaning | Data (trace field) | Honesty caveat |
|---|---|---|---|
| **Vivid magenta** ladder climbing forward from the dot, cross-ticks at each rung | The belief's **self-forecast**: predicted future state at the 13/21/34/55-min horizons — the mirror of the cyan backward trail | `forecast[]` (`horizon_min`, `z_pred`, skill) | Boldness ∝ `skill_vs_persistence`, NOT raw skill — raw skill reads ~1.0 on any quiet belief (the persistence mirage) and would flatter a frozen field |
| Pale inner sphere at the orb's centre ("trust core") | Learned observation-trust (reliability α) for the belief's source | `reliability` | **No core where null** — absence renders as absence, never a guessed default |
| Trust core heating up / flaring | **Surprise** — recent innovation (obs disagreeing with belief) | `surprise` (innov_ema, the un-clipped sibling of reliability) | Honestly null when the trace doesn't carry it |
| **Orange** marker floating above an orb, connector + label ("harvest → ON ·shadow") | The **decision layer**: an output tendril's committed recommendation, wired to the belief that drives it | `actions[]` (`driving_register`, `shadow`, `gated`) | Ghostly when `shadow` — it decided VISIBLY but dispatched nothing; that is the "why it did NOT act" channel |
| **Gold** loop around a group of orbs | **Chorus** manifold cluster — redundancy: beliefs echoing a common cause (Ω > 0) | `manifold.clusters[]` (`grain`, `tier`) | Loops **desaturate unless `tier == "exact"`** — the cumulant proxy feels the bind (TC) but cannot sign it ("feels the bind, can't name it") |
| **Violet** loop | **Conspiracy** cluster — synergy: the whole knows what no part does (Ω < 0) | same | Same tier rule; synergy is dense-exact-only by construction |
| Pale neutral loop | Flat/unresolved cluster (pairwise-only binding) | same | Deliberately duller than either signed grain |
| **Copper arc** on a pedestal beneath the orb, deepening toward **ember** | The **Berry-phase odometer**: accumulated geometric phase γ — the belief's process *mileage* (how far it has genuinely traveled), not its position | `berry_phase` | γ mod 2π sweeps the arc; the tint deepens per full winding — a settled-looking belief can carry visible mileage. Proven geometric: a retraced path returns γ to ~1e-16 |
| Small emoji badge floating west of the orb | **Node identity** — which project/cluster this belief lives on | `node_icon` | Travels with the trace itself (never a renderer-side registry); honestly absent when the trace doesn't carry it |
| **Dark banner** across the view | The live poll is failing — daemon dead/unreachable | `CognifoldTraceView.gd` `_dark` | Distinguishes "quiet world" (legitimately still field) from "dead daemon" — both otherwise render as a still picture |

## Reading the field in one breath

Position = what I believe (pole = committed, centre = unsure). Radius = how sure. Cyan =
where I've been; magenta = where I predict I'm going, boldness = whether that prediction
beats "it stays put." Steel = what's wired; mint = what's *actually co-moving right now*.
Gold/violet loops = groups bound above pairwise. Copper = how far the belief has truly
traveled. Orange = what the mind would do about it — and ghostly orange is it choosing,
out loud, not to act.

Vocabulary rules for the glyphs themselves (poles, node icons, "transcribe don't
invent"): `umwelt/docs/VOCABULARY_CONVENTION.md`. The cross-system map of what worlds
exist and where their fields are served: `yurt/ATLAS.md`.
