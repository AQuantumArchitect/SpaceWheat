# itch.io page

The words, settings and assets for the itch.io page, in one place. The owner
does the pasting and clicking. Status words must match the README's status
line; `LAUNCH_COPY.md` holds everything that is not the itch page.

Last checked against the game: 2026-10-19 (campaign spec, guide resolver,
`KNOWN_ISSUES.md`).

## Page settings

| Setting | Value |
|---|---|
| Slug | `spacewheat` |
| Kind of project | Downloadable, plus the browser build |
| Release status | In development |
| Pricing | No payment required, donations on (amount: owner's call). Note: "Free during alpha." |
| Visibility | **Restricted** (download keys or password) for the friends-and-family round, then **Public** |
| Browser build | Upload the web zip, tick **"This file will be played in the browser"**, viewport 1280×720, **fullscreen button on**, **"SharedArrayBuffer support" ticked**. Without that box the game shows a sentence saying so instead of starting (`WEB_DOOR.md`). |
| Downloads | Windows zip (channel `windows`) and Linux tar.gz (channel `linux`), pushed by `scripts/itch-push.sh` |
| Community | Comments on. They are the feedback channel. |

**Genre:** Simulation

**Tags (10):** farming, simulation, physics, quantum, science, educational,
singleplayer, relaxing, story-rich, mouse-only

**Inputs:** Mouse, Keyboard. **Made with:** Godot.

The whole game plays with the mouse alone: unexplored ground draws as a grey
bubble you can click, and the hats, actions and menus are all on-screen
buttons. Leave out "touch" until touch drag-select exists (`KNOWN_ISSUES.md`).

**Platforms:** HTML5, Windows, Linux. Mac players use the browser build; a
native Mac build would need signing and notarization.

## Title

SpaceWheat

## Short description (the line under the title)

> A farming game where every field is a real quantum system. Plant words,
> strike plots, and the Born rule decides what grows.

## Page body

> **You farm a small island.** Wake a plot, strike it, gather what it gave
> you, and spend the harvest on contracts, new land and new words. Fields
> drift while you watch. Rare harvests pay more, and when you're short, the
> market can get you out of a hole.
>
> **Underneath, every field is a real quantum system.** Each plot is a qubit.
> Each biome is a density matrix evolving under its own Hamiltonian, run by
> a C++ engine with an exact unitary propagator. Striking a plot is a
> measurement, and the Born rule picks the outcome: no dice, no hidden
> random table. A harvest is priced by how surprising it was, −kT·log p,
> which is why rare outcomes pay more.
>
> You don't need to know any of that to play. The game teaches one verb at
> a time, and the microscope shows the honest numbers whenever you want
> them.
>
> **You write the physics.** Factions speak in *words*: pairs of emoji that
> become a qubit when you plant them. Every word you plant adds terms to the
> Hamiltonian, so the land you farm is the one you composed. You learn new
> words by tracking a loop in the field until it ripens (a Berry phase,
> literally) and taking it in.
>
> **The campaign.** You are the Demos, a people learning the language of
> their own ground while an empire measures its subjects into one rigid
> shape. Your island stays free by staying *plural*: many modes at once,
> no single answer imposed. Whether you get there isn't decided by a
> dialogue tree. It's decided by the spectral gap of the Hamiltonian you
> actually built, and you can open the microscope and check.
>
> **Never lost.** The line at the top of the screen always names your next
> key, worked out from the story and the state of your farm. An automated
> player that presses only the keys that line names can play from a fresh
> game to the ending of The Demos. Whether the line reads clearly to a
> person is what this alpha is for.
>
> **What's here**
>
> - *The Demos*: the main campaign, seven acts from the first plot to the
>   ending
> - 164 biomes and 102 factions, each with its own words and laws
> - A hat for each kind of work: the Ace explores and strikes, the Icon
>   plants and learns words, the Captain charts new land, the Operator
>   builds entangling gates, the Druid puts plots into superposition
> - Three manual save slots and a rotating autosave
> - Two post-game campaigns, *What Fades* (decoherence, the Zeno effect) and
>   *The Loom* (braids, topological protection), **in development**: they
>   open after the ending, the game tells you so, and they are unfinished
>
> **Controls.** Mouse or keyboard, your choice. Click a bubble to pick a
> plot (grey ones are ground you haven't explored yet), click a hat, click
> an action. Or keep your hands on the keys: `G H J K L ;` pick plots, the
> number row picks your hat, `F R Q E` act, `ESC` opens the menu. The line at
> the top names keys; the hats, actions and menus it points to are on-screen
> buttons too.
>
> **Alpha.** Expect rough edges. If something confuses you or breaks, say so
> in the comments. To attach a report: `ESC`, then `O` (Dev), then
> "copy logs" (click it or press `R`). That puts your version and recent
> log on the clipboard. Confusion reports are as useful as crash reports.
>
> **How it was made.** I directed AI coding agents for the whole project
> and wrote none of the code myself. The source, the agent fleet that built
> and playtested it, and an honest account of what went wrong are on
> [GitHub](https://github.com/AQuantumArchitect/SpaceWheat).

## Install notes (each download's description field)

**Windows:** Unzip and run `SpaceWheat.exe`. Windows may warn that it's from
an unknown publisher, because the build isn't code-signed: choose *More
info*, then *Run anyway*.

**Linux:** Extract and run `SpaceWheat.x86_64` (`chmod +x` it first if your
archive tool dropped the bit).

**Browser:** Desktop Chrome, Edge or Firefox. Use the fullscreen button. The
first load downloads about 200 MB.

## Images

Captured from the current build with `🍄/🧪/shoot.py` (real gameplay, 1920×1080,
the Compatibility renderer the browser build uses), in `docs/media/screens/`.

| # | File | Why it's there |
|---|---|---|
| Cover (630×500) | `Assets/spacewheat_titlecard.png`, resized | The strongest single image the project has |
| 1 | `screens/gameplay_forest.png` | The farm as you play it: the starter forest's Bloch spheres, the hats, the top line |
| 2 | `docs/media/tap_loop.gif` | Strike → gather, moving |
| 3 | `screens/forest.png` | The same forest with the HUD off: every field is a real quantum system |
| 4 | `screens/microscope.png` | "plural — many modes coexist", the Village on the winning side |
| 5 | `screens/qubit_atlas.png` | The words you've learned |
| 6 | `screens/market.png` | The Village market and its standing trades |
| 7 | `screens/arc.png` | The Arc: the story's open doors |
| 8 | `screens/island_measured.png` | The end of The Demos |

More (every biome, the network, the hypercube, social crops and captioned
cards) comes from the same tool; see its docstring for the steps.

## Before flipping to Public

- [ ] Friends-and-family round done on the Restricted page, top problems fixed
- [ ] Current build pushed to all three channels from `main`
- [ ] Browser build opened on the live page (not just locally) and played
      past the first harvest
- [ ] README status line and this page say the same thing
