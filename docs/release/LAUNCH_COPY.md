# Launch copy

Paste-ready text for the public surfaces. The owner does the pasting and
clicking; this file is where the words live, so they change in one place.
Status words must match the README: The Demos has seven acts, validated end
to end on paper and verifiably played to the opening of Act 3; What Fades and
The Loom are in development.

## GitHub repository

**Description** (Settings → General, max 350 characters):

> A farming game where every field is a real quantum system: density
> matrices, exact unitary evolution, Born-rule harvests. Godot 4.5 + a C++
> engine. Built entirely by AI agents I directed; I wrote none of the code.

**Website:** the itch.io page, once it carries this build.

**Topics:** `godot` `godot4` `gdscript` `gdextension` `quantum-mechanics`
`quantum-computing` `density-matrix` `physics-simulation` `game`
`farming-game` `ai-agents` `agentic-coding` `claude-code`

**Social preview** (Settings → General → Social preview):
`docs/media/social_preview.png`, 1280×640. The screenshot in it is the July
store-kit frame; replace it with a frame from the first-five-minutes capture
when that exists.

**Releases.** GitHub's "latest" badge goes to the newest non-prerelease, which
is still the June `v0.2.0` (Linux only, pre-campaign). Either mark that one as
a pre-release, or cut the next build as a normal release with a version above
it (`v0.3.0`), so the download link lands on the current game.

## Release note (next build)

> **SpaceWheat v0.3.0: the main campaign, one spec, an honest ending**
>
> The Demos, the main campaign, has seven acts from the first plot to the
> ending. The story is compiled from one spec, and a validator checks that
> every act can be finished with resources a player can actually earn. Captain's Chart opens each story biome deliberately, and the Village
> market gets you out of a hole.
>
> The ending now says plainly that the two post-game campaigns, *What Fades*
> and *The Loom*, are still in development. They open after the ending with
> nothing else in the way, but they are unfinished.
>
> Windows: unzip, run `SpaceWheat.exe`. Browser: the itch.io page.
> Known issues: `docs/KNOWN_ISSUES.md`.
>
> Built entirely by AI agents I directed; how that worked, and where it
> went wrong, is in `docs/HOW_THIS_WAS_BUILT.md`.

## itch.io page

Page settings: classification Game, pricing free or donate, browser build
with **SharedArrayBuffer support ticked** (without it the game shows a
sentence saying so instead of starting; see `WEB_DOOR.md`).

**Tagline:**

> A farming game where every field is a real quantum system. Plant, measure,
> harvest, and the Born rule decides what grows.

**Body:**

> You farm a small island. Underneath, each field is an actual quantum system:
> a density matrix evolving under a Hamiltonian you build by planting, with
> an exact unitary propagator and no faked randomness. When you strike a plot
> the Born rule picks the outcome. Rarer outcomes pay more, because the
> price of a harvest is its surprisal, −kT·log p.
>
> You don't need to know any of that to play. The game teaches it one verb
> at a time, and the microscope shows the real numbers whenever you want them.
>
> **The campaign.** You are the Demos, a people learning the physics of their
> own ground while an empire measures its subjects into rigidity. You win by
> building a village whose spectral gap stays small: a plural island that
> physically cannot collapse into one shape. No dialogue tree decides it; the
> Hamiltonian you built does.
>
> **What's here.** The main campaign, seven acts written through to the
> ending (alpha: the later acts have had the least play).
> 164 biomes and 102 factions. Two post-game campaigns, *What Fades* (open
> quantum systems: decoherence, the Zeno effect) and *The Loom* (braids and
> topological protection), are **in development**: they open after the
> ending, and they are unfinished.
>
> **How it was made.** I directed AI coding agents for the whole project and
> wrote none of the code myself. Learning to work that way was the point.
> The source, the agent fleet that built and playtested it, and an honest
> account of what went wrong are on GitHub.
>
> **Alpha.** Expect rough edges. If something confuses you, say so in the
> comments: confusion reports are as useful as crash reports.

**Tags:** farming, simulation, physics, quantum, educational, singleplayer,
relaxing, godot. (No "one-finger" or "mouse-only" tag until the open mouse
gap in `KNOWN_ISSUES.md` is closed.)

**Platforms:** HTML5, Windows. Linux only once a Linux build is attached.
