# SpaceWheat - release facts (source of truth)

| Field | Value |
|---|---|
| Display name | SpaceWheat |
| Repo / canonical folder | github.com/AQuantumArchitect/SpaceWheat - Windows `C:\Users\Luke Spooner\ws-win\SpaceWheat` (see "Location" below) |
| itch page | https://aquantumarchitect.itch.io/spacewheat |
| itch channels | `windows` (full build) |
| Web | GitHub Pages slim build (SVG only, no music): https://aquantumarchitect.github.io/SpaceWheat/ - built by `.github/workflows/pages-slim.yml` on every push to `main`, preset `Web-Slim`. Not on itch. The live site changes only through a merged PR whose CI passed. |
| Engine | Godot 4.6.2 + GDExtension `libquantummatrix` built against godot-cpp 10.0.0-stable (api_version=4.6) |
| Export presets | `Windows Desktop` (itch), `Web-Slim` (Pages, non-threaded), `Web` (threaded, unused), `Linux Desktop` |
| Native binaries | `native/bin/windows/*.dll`, `native/bin/web/libquantummatrix.wasm` (threaded) and `native/bin/web/libquantummatrix.nothreads.wasm` (Web-Slim) - rebuild on Windows with `.\scripts\build-all-platforms.ps1` (MinGW + emsdk 4.0.10); commit them, never ship uncommitted DLLs |
| Play copy | `C:\Games\SpaceWheat` (should always be an itch download or a `tools/release.ps1 -DryRun` output, never a hand build) |
| Release command | bump `config/version` in `project.godot`, commit, `git tag v<that version>` (e.g. `v0.3.1-alpha`), then `.\tools\release.ps1 -Channel windows`. Rehearse with `-DryRun` (add `-AllowUntagged` for an untagged HEAD). The script refuses a dirty tree, an untagged or mismatched tag, and a Godot that isn't 4.6.2, and checks butler before building. |
| Last verified build | `0.3.0-alpha-e74be06-20261030` on itch `windows`: downloaded 2026-10-31, byte-identical to C:\Games\SpaceWheat, launched 75 s with no crash. Gameplay NOT yet verified by a human. |

## Location
Canonical dev is **Windows**, `C:\Users\Luke Spooner\ws-win\SpaceWheat` (issue #47), in native PowerShell 7:
builds, exports and `tools/release.ps1` all run there.

- Godot: `C:\Users\Luke Spooner\Documents\antigravity_i_guess\Godot\Godot_v4.6.2-stable_win64_console.exe` (the `$GodotExe` in `tools/release.ps1`; override with env `GODOT4`).
- Native build: `.\scripts\build-all-platforms.ps1` (Windows DLL + threaded and nothreads web wasm). Toolchain: Python + `pip install scons`, MinGW-w64 (`winget install BrechtSanders.WinLibs.POSIX.UCRT`), emsdk at `C:\Users\Luke Spooner\emsdk` pinned to **4.0.10**. godot-cpp is the submodule at 10.0.0-stable, `api_version=4.6`.
- The Linux `.so` is built by `scripts/build-all-platforms.sh` (CI / a Linux box), not on Windows.
- Export from PowerShell directly: `& $env:GODOT4 --headless --path . --export-release "Windows Desktop" build\release\windows\SpaceWheat.exe` (or `"Web-Slim"`). The old WSL workaround (export inside WSL, copy out, because writing templates to `/mnt/c` failed) no longer applies.
- WSL copies (`~/ws/SpaceWheat`, `~/ws/SpaceWheat-g46`) are retired once the Windows path is verified: rename to `_archive_*`, don't delete. Playtest bots on WSL/VM keep their own clones.

## Verify checklist (after every push)
1. Download from itch (itch app or page) into a fresh folder.
2. Launch, play 2 minutes, quit.
3. Update "Last verified build" above and commit.
