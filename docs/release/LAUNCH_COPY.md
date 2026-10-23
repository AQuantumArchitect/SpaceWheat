# Launch copy

Paste-ready text for every public surface except the itch.io page, which
lives in `ITCH_PAGE.md`. The owner does the pasting and clicking; this file
is where the words live, so they change in one place.

Status words must match the README's status line:

> The Demos has seven acts (0–6) from the first plot to the ending. An
> automated player that presses only the keys the on-screen guide names, from
> a fresh game with nothing injected, reaches the ending in most runs. What
> Fades and The Loom open after it and are in development.

## Version

Cut the next build as **`v0.3.0-alpha`**. GitHub and itch both sort by
version, and the June `v0.2.0` (Linux only, before the campaign) is still a
normal release, so anything numbered below it looks older than it. Mark
`v0.2.0` as a pre-release as well, so GitHub's "latest" stops pointing at it.
Set `config/version` in `project.godot` to match; `itch-push.sh` uses it as
the build's version on itch.

## GitHub repository

**Description** (Settings → General, max 350 characters):

> A farming game where every field is a real quantum system: density
> matrices, exact unitary evolution, Born-rule harvests. Godot 4.5 + a C++
> engine. Built entirely by AI agents I directed; I wrote none of the code.

**Website:** the itch.io page, once it is public.

**Topics:** `godot` `godot4` `gdscript` `gdextension` `quantum-mechanics`
`quantum-computing` `density-matrix` `physics-simulation` `game`
`farming-game` `ai-agents` `agentic-coding` `claude-code`

**Social preview** (Settings → General → Social preview):
`docs/media/social_preview.png`, 1280×640. Replace its screenshot with one of
the fresh release-build captures listed in `ITCH_PAGE.md` when they exist.

## Release note (v0.3.0-alpha)

> **SpaceWheat v0.3.0-alpha: follow the line to the ending**
>
> The line at the top of the screen now always names your next key. It is
> worked out from the campaign spec and the state of your farm, by one
> resolver that the banner, the key highlight, the Arc and the story toasts
> all read. Before, each wrote its own hints and they often disagreed.
>
> How we know it works: an automated player that presses only the keys that
> line names now plays from a fresh game to the ending of The Demos in most
> runs (harvests are random, and some runs still get stuck; each one we see
> becomes a fix). Started from each of the campaign's 40 beats, it moves the
> story from 38 of them; before this build it was 2.
>
> Also in this build:
> - The main campaign, The Demos, is one spec, with a validator that checks
>   every act can be finished with resources a player can actually earn.
> - When your island goes free at the end of The Demos, the game tells you
>   plainly that the two post-game campaigns, *What Fades* and *The Loom*,
>   are still in development. They open with nothing in the way, but they
>   are unfinished.
>
> **Windows:** unzip, run `SpaceWheat.exe` (choose *More info → Run anyway*
> if Windows warns; the build isn't code-signed). **Linux:** extract, run
> `SpaceWheat.x86_64`. **Browser:** the itch.io page.
> Known issues: `docs/KNOWN_ISSUES.md`.
>
> Built entirely by AI agents I directed; how that worked, and where it went
> wrong, is in `docs/HOW_THIS_WAS_BUILT.md`.

## Friends-and-family invite

For the Restricted itch page. Fill in the link and the key or password.

> Hey! I've been making a game for a while and it's finally ready for a few
> people to try before anyone else does. It's called SpaceWheat: you farm a
> little island, and underneath, every field is a real quantum system. You
> don't need to know any physics; the game teaches it as you go.
>
> Link: [itch page] — password: [password]
> (Plays in the browser, or download for Windows/Linux.)
>
> What would help most:
> - Play for half an hour or so, longer if you're enjoying it.
> - The line at the top of the screen tells you what to press next. Tell me
>   the moment it stopped making sense, or you felt stuck. That is the most
>   useful thing you can send me.
> - If something breaks: `ESC`, then `O`, then "copy logs" and `R`, and
>   paste what's on your clipboard to me.
>
> It's an alpha, so it will be rough in places. Thank you!

## itch.io devlog (going public)

> **SpaceWheat is open: a farming game where every field is a real quantum
> system**
>
> SpaceWheat is now public as a free alpha, in your browser or on Windows
> and Linux.
>
> You farm a small island. Underneath, each plot is a qubit and each biome a
> density matrix evolving under a Hamiltonian you build by planting words.
> Striking a plot is a measurement; the Born rule decides what you harvest,
> and rare outcomes pay more because a harvest is priced by its surprisal.
>
> The main campaign, *The Demos*, runs seven acts to its ending: an island
> that stays free by staying plural, judged by the spectral gap of the
> physics you built. Two post-game campaigns are in development.
>
> Thank you to everyone who played the early build. [One sentence on the
> biggest thing their feedback changed.]
>
> It's an alpha. If something confuses you, say so in the comments; those
> reports are as useful as crash reports.

## Short post (social, forums)

> I made a farming game where every field is a real quantum system: each
> plot is a qubit, each biome a density matrix, and the Born rule decides
> what you harvest. Free alpha, plays in the browser: [itch link]
>
> Built entirely by AI agents I directed; the source and an honest write-up
> of how are on GitHub: [repo link]
