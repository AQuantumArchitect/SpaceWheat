# Release architecture

One door, two lanes, four folders. If you are cutting a release, you want
exactly one command:

```bash
./scripts/release.sh
```

That builds desktop and browser, runs every gate, packages both, and writes a
manifest naming what it produced. Everything below is what that command does
and why it is shaped this way.

---

## The door

```
scripts/release.sh                  ← cut everything, write the manifest
├── scripts/run_tests.sh                physics + smoke gate
├── scripts/validate-desktop-release.sh  DESKTOP LANE
│   ├── build-desktop-local.sh          → releases/local/{windows,linux}-native
│   ├── smoke-test-desktop-export.sh      structural + boot
│   ├── profile-export-runtime.sh       → releases/validation/<ts>/desktop/profiles
│   └── package-desktop-builds.sh       → releases/packages/*.zip, *.tar.gz
└── scripts/validate-web-release.sh      WEB LANE
    ├── build-web-local.sh              → releases/web-local
    ├── tests/test_web_extension_links.py  every wasm import resolves
    ├── gate-web-bundle.mjs               loads WITH and WITHOUT isolation headers
    ├── smoke-test-web-export.mjs         boots and plays
    └── package-web-build.sh            → releases/packages/*.zip
```

Uploading is deliberately not part of it: `scripts/itch-push.sh` reads
`releases/packages` and is run by a human who has decided to ship.

**`build-all-platforms.sh` is not this script.** It builds the three native C++
extensions and then *prints* the export commands. The name is older than the
release lanes.

## The four folders

| folder | holds | written by |
|---|---|---|
| `releases/local/` | desktop exports, one dir per platform | `build-desktop-local.sh` |
| `releases/web-local/` | the browser bundle, unzipped | `build-web-local.sh` |
| `releases/packages/` | archives + `RELEASE-*.md` manifests | the packagers, `release.sh` |
| `releases/validation/<ts>/` | every gate log from one cut | both lanes |

`releases/packages` is the only folder anything outside this repo reads. If an
artifact is not in there, it is not a release — it is a build someone left on
the floor. `releases/web-fix/`, `releases/demo/`, `releases/linux/`,
`releases/windows/` are historical scratch dirs from before this shape existed;
nothing in the repo references them.

All four paths are declared once, in `scripts/lib/release_paths.sh`. They used
to be declared inline in eight scripts as `${VAR:-…}` defaults, and two of them
drifted — see below.

## Names are derived, never typed

An archive is named from two things nobody types:

- **`config/version`** in `project.godot` — the release name, the same string
  the title screen shows. Read via `sw_project_version()`.
- **`build_id()`** in `scripts/lib/build_stamp.sh` — the short commit, plus a
  6-hex hash of the uncommitted delta when the tree is dirty.

so an artifact cannot be named something the game inside it does not claim.
`tests/test_build_identity.py` pins this for every lane.

`--version` exists and overrides the derivation. Using it reintroduces exactly
the drift the default prevents. Don't, unless you are deliberately renaming.

**Why the delta hash.** A bare `-dirty` says *that* there were edits, never
*which*. A second agent edits this repo concurrently, so a dirty tree is the
normal case, not the exception — two dirty builds an hour apart are routinely
different games and used to carry identical stamps.

**Why the moved-tree guard.** An export reads the working tree file by file over
several minutes. If the tree moves while it reads, the artifact is a blend of
two source states and no single build id describes it. Each lane records the
source id before building and re-checks it after; a build whose source moved is
refused, not labelled. When the tree is dirty at the start, `release.sh` writes
the full delta to `releases/validation/<ts>/source-delta.patch`, because the
commit alone will not reproduce that build.

## The manifest

Each cut writes `releases/packages/RELEASE-<version>-<build id>.md`: every
artifact with size and sha256, the source id and branch, which lanes ran, which
gates ran, and where the logs are. It exists because "which build is on itch"
was previously answerable only by rebuilding and comparing.

## The browser build needs the host's cooperation

The web export is threaded, so it needs `SharedArrayBuffer`, so it needs
cross-origin isolation:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

On itch that is **Embed options → Frame options → SharedArrayBuffer support**,
which only appears once a zip is marked as played in the browser. With the box
unticked the engine cannot start; the custom shell says so instead of going
black, which is what 0.1.0-alpha did.

Ticking it does **not** fix embedded Firefox: itch's isolation rides on COEP
`credentialless`, which Firefox does not implement. Popping the game out of the
frame works there. Chrome and Edge are fine embedded.

`gate-web-bundle.mjs` is the gate for this, and it is the reason the web lane
loads the bundle twice. `smoke-test-web-export.mjs` serves *with* the headers,
so it structurally cannot observe the failure that shipped.

## What this replaced

Three defects, all found 2026-08-15 while cutting a release by hand:

1. **`package-web-build.sh` defaulted to `releases/web`** while
   `build-web-local.sh` writes `releases/web-local`. The web packager pointed at
   a folder nothing has ever produced, so a bare run refused — which is why the
   web zip kept being assembled by hand, which is how three different bundles
   shipped under one name.
2. **`validate-desktop-release.sh` defaulted `VERSION_TAG` to `dev`** and
   forwarded it unconditionally, overriding the packager's derived default —
   the exact drift `DESKTOP_RELEASE_WORKFLOW.md` warns against in writing,
   performed by the orchestrator that doc describes.
3. **There was no web orchestrator and no all-platform door.** The pieces all
   existed; nothing composed them, so what got skipped on any given cut was
   invisible afterwards.

The pattern under all three: *a lane with no orchestrator gets run from memory,
and a path declared in eight places is eight opinions.*

## See also

- `docs/release/DESKTOP_RELEASE_WORKFLOW.md` — the desktop lane in detail
- `docs/release/WEB_DOOR.md` — browser gate items
- `docs/release/ITCH_PAGE.md` — store copy and assets
