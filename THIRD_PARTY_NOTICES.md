# Third-party notices

SpaceWheat itself is MIT licensed — see `LICENSE`. The components below are
bundled in the shipped builds under their own terms. This file ships inside
every desktop archive and beside the web bundle.

---

## Twemoji — CC-BY 4.0

566 emoji tiles in `Assets/emoji_svg/` and the font `Assets/Fonts/TwemojiMozilla.ttf`
are derived from **Twemoji**.

- Graphics copyright 2020 Twitter, Inc and other contributors, maintained at
  <https://github.com/jdecked/twemoji>
- Licensed under **CC-BY 4.0**: <https://creativecommons.org/licenses/by/4.0/>
- `TwemojiMozilla.ttf` is Mozilla's colour-font build of the same artwork.

Attribution is the only condition CC-BY 4.0 imposes, and this notice is how
SpaceWheat meets it. The emoji are not incidental decoration here — they are the
game's entire visual vocabulary, so the credit is owed prominently.

## Eigen — MPL-2.0

`native/include/Eigen/` — the linear-algebra library the C++ quantum engine is
built on. Every density-matrix operation in the game runs through it.

- <https://eigen.tuxfamily.org/>
- **Mozilla Public License 2.0**: <https://mozilla.org/MPL/2.0/>

MPL-2.0 is file-level copyleft: Eigen's own sources stay under MPL-2.0, and
linking it into this project does not change SpaceWheat's license.

## Godot Engine — MIT

The runtime. Copyright (c) 2014-present Godot Engine contributors,
copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

- <https://godotengine.org/license>
- The full MIT text is already embedded in every exported binary, and the
  in-engine text is available at runtime via `Engine.get_license_text()`.

## godot-cpp — MIT

`godot-cpp/` (git submodule) — the GDExtension bindings the native engine uses.
Same MIT terms as the engine; full text at `godot-cpp/LICENSE.md`.

---

## Music

The 25 tracks in `Assets/Audio/Music/` were composed with **Suno** by Luke
Spooner, under a paid Suno plan that grants commercial use and redistribution
of the generated audio.

Recorded here because the generator is not otherwise evident from the shipped
files, and because a claim of commercial rights should name the basis it rests
on rather than leave a future reader to guess.

## Sound effects

The WAV files in `Assets/Audio/SFX/` are original to this project and are
covered by `LICENSE`.
