# Surface Manifest

This is the current target map for the ZXCVBNM ring. If this manifest
conflicts with newer runtime code, newer overlay comments, or fresher
timestamps, treat the newer code/comments as authoritative and update this
file on the next pass. Last reconciled against live overlay headers:
**2026-08-03** (Z/X assignments un-swapped; page lists replaced with
pointers to each overlay's own header, which is the authority — the
manifest's staleness came from duplicating them here).

One surface per player-facing overlay, one live instrument surface (farm).
Every entry below extends `UI/Core/Surface.gd` (or is Surface-shaped) and
emits the canonical snapshot `{surface_id, frame_id, context_id,
object_focus, visible_data, available_actions, transitions}`.

| id     | Overlay / Node                                 | Pages |
|--------|------------------------------------------------|-------|
| farm   | `UI/Core/FarmSurface.gd` (headless participant; same snapshot contract as UI surfaces) | derived from plane: `coherent` / `dissipative` / `probe` |
| Z      | `UI/Overlays/EscapeMenu.gd` (system)           | Now / Save / New / Balance / Dev — see EscapeMenu.gd header (`TAB_ROW`) |
| X      | `UI/Overlays/ControlsOverlay.gd` (playthrough) | Self / Story / · / Arc / Guide (U slot honestly empty) — see ControlsOverlay.gd header (`TAB_ROW`) |
| C      | `UI/Overlays/QuestBoard.gd`                    | Manifold / Market / Commitments — see QuestBoard.gd header (`TAB_ROW`; Arc moved to X) |
| V      | `UI/Overlays/QubitAtlasOverlay.gd`             | Lexicon / Affinity / Alignment / Coverage / Hints / Subspace — see QubitAtlasOverlay.gd header (`TAB_ROW`) |
| B      | `UI/Overlays/BiomeInspectorOverlay.gd`         | `supports` (single — pure visual overlay; keys forward to surface beneath) |
| N      | `UI/Overlays/InspectorOverlay.gd`              | Network / Bridges / Selector / Live / Whole / Matrix — see InspectorOverlay.gd header (`TAB_ROW`; Bridges sub-paginates G/H/J) |
| M      | `UI/Overlays/MapMetaOverlay.gd`                | Vectors / Eigenstate / Drift / Bits / Atlas / Graph — see MapMetaOverlay.gd header (`TAB_ROW`) |

## Ring Notes

- Z is the system/meta surface around the player: run ("Now"), save/load,
  new game, the live Balance tunables board, and transitional dev tools.
  (ESC also reaches it — Z + ESC share the surface.)
- X is the most personal surface: this playthrough's identity (Self),
  narrative + faction chatter feed (Story), the story-flag spine (Arc),
  and how-to-play (Guide, which absorbed the old Verbs reference).
- C is the contract board. It consumes the N→C handoff when present and
  falls back to current-biome scope when no handoff exists. Its visible
  snapshot surfaces `scope_mode`, `scope_source`, and `scope_counterparty`.
  The tabs are pipeline-aligned (manifold → market → commitments); Market
  sort modes and the Active/History commitments split are chords
  (1/2/3, 1/2) within their tabs, not extra pages. The Arc tab moved to X.
- V is the canonical knowledge surface for atoms, icons, signature, and
  affinity. It is the signature and inspection atlas.
- B is the biome microscope, **a pure visual overlay**: single page,
  no QERF chips, no TYUIOP claims, no `[`/`]` cycling. It mirrors the
  live instrument's plot selection and renders a richer view (IconCard
  + marginals strip + entanglement summary). All keys forward through
  to the surface beneath. The whole-biome / matrix / gates / links /
  subspace pages migrated to N and V; eigen and per-qubit marginals
  already live on M as Eigenstate / Bits.
- N is the biome network / dissipation surface. Its first page is the
  network view; the selector page is a browseable biome atlas. The
  network page seeds C and exposes the selected edge in visible_data.
  N now also carries `whole` (active biome's whole-summary, slot O)
  and `matrix` (density matrix, slot P), absorbed from B. The
  `bridges` page sub-paginates G/H/J between admitted-faction bridges,
  bell-gate history, and dissipation links.
- M is the biome × faction map, centered on the selected biome. In live
  code it is the affinity hypercube — the 12-D complex affinity substrate
  that holds every faction: pairwise relationships (Vectors),
  principal-axis ranking (Eigenstate), player trajectory (Drift), raw
  per-faction axis readout (Bits), the spatial cluster view (Atlas), and
  Graph. Q / R adjust the orbit and zoom on
  that atlas only.

## Explicit Page Model

- Every surface uses TYUIOP page slots when it has enough pages to fill them.
- GHJKL; selects within the current page or page-local list.
- `[` / `]` cycle pages on the active surface.
- `,` / `.` cycle top-level overlays.

## WIP Boundaries

- V `subspace` is wired to `BiomeStateViews.build_subspace_view` and
  the N `matrix` slot is the canonical density-matrix view (both
  migrated from B); follow-up work may iterate the visualization.
- The faction chatter feed lives inside X's Story tab (GHJKL; cursor into
  the feed), not as its own page; the old experimental chatter/sculpting
  page is gone from the tab row.
- Z keeps `dev` only as a transitional page; it is not the core of the
  system surface.
- N's network-to-contract handoff is part of the intended player loop.

## Invariants

See `UI/Core/KEYBOARD_GRAMMAR.md` for the full keyboard grammar.

- **QERF is the four-chip primary action row.** Q/R carry the depth
  axis (screw out / screw in). E/F carry the time axis
  (pause / inspect / hold / broker / expand vs play / advance / page-text /
  flatten). Empty chips are honest and still part of the row.
- **E pauses the sim globally** (PlayerShell-level). Every E press
  freezes evolution as a side-effect, regardless of whether the tool's
  E slot has a verb. An empty E slot is still useful — it's pause.
- **F is never pagination.** F is a verb (play / advance / page).
  Frame cycling is `[` / `]`; menu cycling is `,` / `.`.
- **No QERF "back" key.** ESC unwinds the overlay stack; ZXCVBNM
  abandons the current overlay and swaps to a new one. Between them
  the player can never get stuck.
- **Mode cycling is Tab + 5-0.** Tab advances; `5`-`0` direct-pick.
- **Frame cycling is `[` / `]`.** PlayerShell calls
  `Surface.cycle_frame(±1)` on the topmost surface. Surfaces that
  paginate within a single frame may override `cycle_frame()` to
  repurpose `[/]` to that paginator.
- **Top-level menu cycling is `,` / `.`** (PlayerShell `_cycle_menu_overlay`).
- **`'` is select / clear all.** Reserved for surfaces that expose a
  bulk-select affordance.
- **Macro/structural actions route through `MacroActions.dispatch()`**
  (`Core/GameState/MacroActions.gd`). No caller should invoke
  `action_discover_biome` etc. directly.
- **`SurfaceRegistry.get_snapshot_beneath(surface)`** is the sanctioned
  way for a surface to read the snapshot of the surface beneath it —
  never its own snapshot. As of 2026-08-03 the helper exists in
  `UI/Core/SurfaceRegistry.gd` but has no live caller (the page that
  used it retired from the tab rows); it remains the contract for any
  future surface-beneath reader.

## WIP History

- The Z/X roles settled as: Z = EscapeMenu (system: which truth — saves,
  runs, balance, dev), X = ControlsOverlay (playthrough: the current
  truth — self, story, arc, guide). An earlier pass of this manifest had
  them swapped; the overlay headers were always the authority.
- QuestBoard's pages settled as the pipeline tabs Manifold / Market /
  Commitments; the older comfort / stretch / magnitude / ledger page
  model survives only as Market sort modes (chord 1/2/3) and the
  Commitments history sub-view (chord 1/2). Arc moved to X.
- B was once a multi-frame surface (active / whole / matrix / probabilities
  / subspace / eigen / gates / links). It is now a pure visual overlay
  with one page; whole and matrix migrated to N (slots O and P),
  subspace migrated to V (slot P), gates and links became sub-sections
  of N's Bridges page (G/H/J), and eigen + marginals are covered by
  M's Eigenstate and Bits pages.
- N used to own the biome map. Its selector page is now the browseable atlas;
  the network page is the handoff and dissipation path.
- M grew from a two-page biome × faction map (field / atlas) into the
  six-tab affinity hypercube; the atlas orbit controls carried over.
