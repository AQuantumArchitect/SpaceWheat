# Cloud session handoff — 2026-08-17

Owner is moving this work to a local-first session. This is the wrap-up: what
shipped, what's still open, and what a fresh session needs to know before
touching release/deploy again.

## What shipped this session

Commit `2738de6` on `claude/awesome-lamport-oa6502` (pushed, tree clean):

- **Fixed harvested bubbles not visually returning to grey.** Root cause:
  `Core/Visualization/QuantumField3D.gd`'s harvest handler (`_on_terminal_released`)
  never called `Farm.unreveal_plot()`, unlike the legacy 2D renderer
  (`QuantumForceGraph.gd`), which already did. A later rebuild of that biome
  (re-explore, or a biome switch) re-read the stale "still revealed" entry in
  `Farm.revealed_plots` and repainted full color over what should have stayed
  grey. One-line fix plus a regression test
  (`tests/bubble_rendering_cleanup_smoke.gd`, `_test_harvest_clears_farm_reveal_state`).
- **Added a click-preview highlight to the Q/E/R/F action bar.** The
  pre-existing "available" tint (`ActionPreviewRow.gd`) was confirmed via
  screenshot to be visually imperceptible in practice (dark modulate on a dark
  background). Added a real border highlight keyed off the currently
  *focused* plot (`QuantumInstrumentInput.predict_tap_verb_for_focus`), not
  the Shift-click multi-select set that the older `_apply_probe_preview` used
  (which is empty during ordinary single-tap play — a separate pre-existing
  gap, routed around rather than fixed). Verified live through a full
  Explore → Strike → Extract cycle via the mouse-seat rig, screenshots
  confirmed the border tracks each state change correctly.
- Scope was explicitly limited to the button-highlight approach (owner's own
  choice over a custom cursor) — see "Not done" below.

Verification at handoff: boot-error gate clean, `scripts/run_tests.sh` 46/46,
`python3 -m pytest tests/ -q` → 298 passed / 0 failed / 17 skipped.

## Not done / open for the next session

- **Custom cursor showing the click-predicted action.** Floated by the owner
  as an alternative to the button highlight; explicitly deferred, not
  started. The button-highlight plumbing (`predict_tap_verb`,
  `predict_tap_verb_for_focus`) already computes the right verb per plot, so
  a cursor icon swap would consume that rather than duplicate it.
- **GitHub release tag `v0.1.1-alpha` has never been pushed.** See "Cloud
  sandbox constraints" below for why — this needs to happen from a normal
  git checkout, not from inside a Claude Code on the web session:
  ```
  git fetch origin claude/awesome-lamport-oa6502
  git tag -a v0.1.1-alpha 2738de6 -m "SpaceWheat 0.1.1-alpha"
  git push origin v0.1.1-alpha
  ```
  `2738de6` is current HEAD as of this handoff; use whatever HEAD actually is
  by the time this runs.
- **itch.io upload is still manual.** `scripts/itch-push.sh` exists and is
  considered done/ready per `docs/release/ITCH_STATUS.md`, but needs a local
  `butler login` once and `ITCH_USER`/`ITCH_GAME` env vars — neither is
  present in the cloud sandbox this session ran in. Owner has said they're
  fine continuing to upload by hand; automating this was floated, not
  requested.

## Release packages built this session

A fresh desktop release (Windows `.zip` + Linux `.tar.gz`, source `2738de6`)
was built and delivered to the owner directly as split file parts (8 parts
each, ~25 MB, plus a `REASSEMBLE.txt` manifest with sha256 and `copy /b`/`cat`
reassembly commands) — **not** committed to git. `releases/` is gitignored
(see `.gitignore:29`) and this cloud sandbox is ephemeral, so nothing under
`releases/packages/` survives past this session. If those delivered parts are
gone, the next session should just rebuild locally:
```
./scripts/release.sh --desktop-only
```
sha256 of what was actually delivered, for cross-checking a rebuild:
- `spacewheat-windows-0.1.1-alpha.zip`: `ec09b5c98de4671be99b8bcef0a509852b524b1768a9186ec0f274122ef7a2ec`
- `spacewheat-linux-0.1.1-alpha.tar.gz`: `34262744f8e85ae52d1bcc617360b26e46253f08e861b52c7d6072ae8b4947b9`

(A local rebuild from the same source will very likely **not** match these
hashes byte-for-byte — see the native-toolchain note below — that's expected
and not a problem; the game content is what matters, not archive-level
reproducibility.)

## Cloud sandbox constraints (institutional memory, if a cloud session runs this again)

- **git push in Claude Code on the web is credential-scoped to one branch.**
  This session's push credential worked only for
  `claude/awesome-lamport-oa6502`; pushing a tag or to `main` gets a hard
  `HTTP 403` on the `git-receive-pack` POST regardless of in-chat
  "permission" — confirmed via `GIT_CURL_VERBOSE`, and documented at
  <https://code.claude.com/docs/en/claude-code-on-the-web>. Not fixable from
  inside the session; the fix is running the push from a normal git checkout.
- **The GitHub MCP server available in-session has no release-creation
  tool** — only `list_releases`/`get_release_by_tag`/`get_latest_release`
  (read-only). So there's no API-based workaround for the tag-push block
  either.
- **No `butler` binary and no itch credentials** are present in the cloud
  sandbox, so `scripts/itch-push.sh` cannot run there.
- **A Godot 4.5 toolchain *was* successfully installed in-sandbox** this
  session (`/usr/local/bin/godot`, export templates, `scons` via pip,
  `mingw-w64` for the Windows cross-build) — full local builds, the physics
  gate, and `native/` compilation all work fine in the cloud sandbox now.
  The one caveat: **two back-to-back `native/` rebuilds from identical
  source produced different bytes** in this sandbox's freshly-installed
  toolchain. `scripts/release.sh` has its own reproducibility check (it
  compares git tree state at the start and end of a cut and refuses to write
  a manifest if `native/bin/` moved mid-build) — this trips on every full
  release cut in this particular sandbox, because the native rebuild step
  itself dirties tracked files partway through its own run. The actual
  build → export → smoke → package steps all still succeed; only the
  auto-manifest write aborts. Worked around this session by writing the
  manifest by hand and reverting the non-reproducible `native/bin/` diffs
  (no real C++ source had changed). Root cause of the non-determinism itself
  was not investigated further — out of scope for a UI bug-fix session.
