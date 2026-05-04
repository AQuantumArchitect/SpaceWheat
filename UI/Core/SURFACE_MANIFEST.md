# Surface Manifest

This is the current target map for the ZXCVBNM ring. If this manifest
conflicts with newer runtime code, newer overlay comments, or fresher
timestamps, treat the newer code/comments as authoritative and update this
file on the next pass.

One surface per player-facing overlay, one live instrument surface (farm).
Every entry below extends `UI/Core/Surface.gd` (or is Surface-shaped) and
emits the canonical snapshot `{surface_id, frame_id, context_id,
object_focus, visible_data, available_actions, transitions}`.

| id     | Overlay / Node                                 | Pages |
|--------|------------------------------------------------|-------|
| farm   | `UI/Core/FarmSurface.gd` (headless participant) | derived from plane: `coherent` / `dissipative` / `probe` |
| Z      | `UI/Overlays/ControlsOverlay.gd`               | `self`, `story`, `verbs`, `chatter`, `guide` |
| X      | `UI/Overlays/EscapeMenu.gd`                    | `run`, `save_load`, `accessibility`, `dev` |
| C      | `UI/Overlays/QuestBoard.gd`                    | `comfort`, `stretch`, `magnitude`, `ledger` |
| V      | `UI/Overlays/QubitAtlasOverlay.gd`             | `atoms`, `icons`, `signature`, `affinity`, `relations`, `origins` |
| B      | `UI/Overlays/BiomeInspectorOverlay.gd`         | `supports`, `whole`, `matrix`, `probabilities`, `subspace`, `eigen`, `gates`, `links` |
| N      | `UI/Overlays/InspectorOverlay.gd`              | `network`, `bridges`, `selector` |
| M      | `UI/Overlays/MapMetaOverlay.gd`                | `field`, `atlas` |

## Ring Notes

- Z is the most personal surface: self, story, introspection, and the
  experimental sociolite chatter / faction-term sculpting work.
- X is the system/meta surface around the player: run, save/load,
  accessibility, and transitional dev tools.
- C is the contract board. It consumes the N→C handoff when present and
  falls back to current-biome scope when no handoff exists. Its visible
  snapshot surfaces `scope_mode`, `scope_source`, and `scope_counterparty`.
- V is the canonical knowledge surface for atoms, icons, signature, and
  affinity. It is the vocabulary and inspection atlas.
- B is the whole-biome surface, with both the active-plot microscope and the
  whole-biome-at-once page in the same overlay.
- N is the biome network surface. Its first page is the network view; the
  selector page is a browseable biome atlas. The network page seeds C and
  exposes the selected edge in visible_data.
- M is the biome × faction map, centered on the selected biome. Its Field
  page shows native factions plus standing-backed entries; its Atlas page
  keeps the cluster view orbitable. Q / R adjust the orbit and zoom on
  that atlas only.

## Explicit Page Model

- Every surface uses TYUIOP page slots when it has enough pages to fill them.
- GHJKL; selects within the current page or page-local list.
- `[` / `]` cycle pages on the active surface.
- `,` / `.` cycle top-level overlays.

## WIP Boundaries

- B `gates` / `links` remain explicit stubs.
- V `origins` is still a design boundary, not a hard promise that every page is complete.
- Z's experimental chatter / sculpting page is intentionally in motion.
- X keeps `dev` only as a transitional page; it is not the core system surface.
- N's network-to-contract handoff is part of the intended player loop.

## Invariants

See `UI/Core/KEYBOARD_GRAMMAR.md` for the full keyboard grammar.

- **QERF is a cross of two axes.** Q/R = item axis (prev/next).
  E ↓ = pause / inspect / hold. F ↑ = play / advance / page-text.
  E and F are opposites on the *time* axis, not the depth axis.
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
- **Z reads the surface beneath itself** via
  `SurfaceRegistry.get_snapshot_beneath(self)` — never its own snapshot.

## WIP History

- B is still carrying the active-plot microscope work plus the new whole-biome
  page. That is deliberate.
- N used to own the biome map. Its selector page is now the browseable atlas;
  the network page is the handoff path.
- M is now the map of biome × faction relationships. Field details and atlas
  orbit controls are part of the surface, not separate systems.
- Z is the personal surface, not a generic help page.
- X is the system/meta surface, not a catch-all debug bucket.
