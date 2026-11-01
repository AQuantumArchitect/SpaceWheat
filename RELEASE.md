# SpaceWheat - release facts (source of truth)

| Field | Value |
|---|---|
| Display name | SpaceWheat |
| Repo / canonical folder | github.com/AQuantumArchitect/SpaceWheat - WSL `~/ws/SpaceWheat` (see "Location" below) |
| itch page | https://aquantumarchitect.itch.io/spacewheat |
| itch channels | `windows` (full build) |
| Web | GitHub Pages slim build (SVG only, no music): https://aquantumarchitect.github.io/SpaceWheat/ - built by `.github/workflows/pages-slim.yml` on every push to `main`, preset `Web-Slim`. Not on itch. The live site changes only through a merged PR whose CI passed. |
| Engine | Godot 4.6.2 + GDExtension `libquantummatrix` built against godot-cpp 10.0.0-stable (api_version=4.6) |
| Export presets | `Windows Desktop` (itch), `Web-Slim` (Pages, non-threaded), `Web` (threaded, unused), `Linux Desktop` |
| Native binaries | `native/bin/windows/*.dll`, `native/bin/web/libquantummatrix.nothreads.wasm` - rebuild with `scripts/build-all-platforms.sh --windows-only` (WSL, MinGW) and em++ 4.0.10; commit them, never ship uncommitted DLLs |
| Play copy | `C:\Games\SpaceWheat` (should always be an itch download or a `tools/release.ps1 -DryRun` output, never a hand build) |
| Release command | bump `config/version` in `project.godot`, commit, `git tag v<that version>` (e.g. `v0.3.1-alpha`), then `.\tools\release.ps1 -Channel windows`. Rehearse with `-DryRun` (add `-AllowUntagged` for an untagged HEAD). The script refuses a dirty tree, an untagged or mismatched tag, and a Godot that isn't 4.6.2, and checks butler before building. |
| Last verified build | `0.3.0-alpha-e74be06-20261030` on itch `windows`: downloaded 2026-10-31, byte-identical to C:\Games\SpaceWheat, launched 75 s with no crash. Gameplay NOT yet verified by a human. |

## Location
Canonical repo is currently in WSL because the native toolchain (MinGW, emsdk) lives there. Target: one canonical folder; see the consolidation notes.

## Verify checklist (after every push)
1. Download from itch (itch app or page) into a fresh folder.
2. Launch, play 2 minutes, quit.
3. Update "Last verified build" above and commit.
