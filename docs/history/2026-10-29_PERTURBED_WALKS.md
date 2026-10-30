# 2026-10-29: perturbed walks (a player who strays off the banner)

`banner_follow.py` presses exactly what the banner names, in the order the spec
expects, so the guide never met a state it did not plan for. A human does that
and also pokes around. `🍄/🧪/perturbed_walk.py` is `banner_follow` plus seeded
off-script keys (explore/strike/gather any plot, swap hats and hat modes, track
or incorporate early, pause, clock, marks, board and menu visits, accept or
abandon or dismiss, reap, and a roulette of any hat verb with or without the
confirm chord). On a stall it saves the game, records the guide's account, the
quests, the wallet and the overlay stack, and tests whether ESC clears it.

    python3 🍄/🧪/perturbed_walk.py --seed 7 --rate 0.3 --minutes 14 \
        --save-dir /tmp/stalls --out /tmp/stalls/s7.json

Run 3-4 at once (about 450 MB each). A straight walk finishes in about 8
minutes; under heavy deviation it takes 14-18, so give it `--minutes 14+`.

## What it found (each fixed, each a state the straight walk never reached)

| Stall | Cause | Fix |
|---|---|---|
| Banner says Claim, R does nothing | Charge tab drawn once; chips declared once. A beat turned ready later, the row still read 0% and R was gated "nothing on R here" | Charge and Arc tabs re-declare chips and re-render when rows change, on reopen, on re-pressing the open tab |
| `woodlot_wakes` asks for a word never taught; banner shows a stale "[C] then [R] Claim" | One Dismiss on the Arc discarded "The Teaching" (lumber_flows), which teaches the word. Its child fired anyway; the guide had no step and fell back to the legacy line | A beat other beats require (a gate) cannot be dismissed; an old dismissal of a gate no longer counts and the offer is not swept (saves heal on load); the guide walks `ranked_beats()` so a beat with no step hands the banner to the next |
| Deliver/Claim on Commitments does nothing | `[2]` History view survives closing the board; R acts on Active only | Opening the board resets to Active; the guide presses `[1]` when the view is History |
| `Plant [R]` fires "Stay Home" | The Icon hat was left in its mirror mode; same key, other verb | The guide treats a hat's mode as part of wearing it: `[hat] [1]` |
| `Explore [F]` repeats and nothing changes | An armed Trim/Cull/Break confirm owns F ("any other key cancels"); F would have confirmed a destructive action | The armed confirm is a surface (`field:confirm`); the guide leads with `close [ESC]` |

| `Reap the season` repeats into "Nothing to reap" | Every explored plot had been gathered back to fog (or time paused) | The guide checks the reap precondition and explores (or resumes) first |
| `Explore [F]` does nothing | A tracked loop keeps Ace F as Fast-Fwd | The guide incorporates a ripe loop or stops tracking before it names Explore |
| `plot [G], Explore [F]` repeats | With no plot focused the guide judged the wrong plot; the focus test trusted a lagging `current_biome` | `_strike_once` judges the plot it names; the focus test asks the grid which biome owns the picked plot |

## Still open

- Seed 62 (saves `stall_seed62_stuck_t45` in a perturbed run at rate 0.45)
  stalls in the first minute on `plot [G], Explore [F]`: after G the chip reads
  Fast-Fwd, Q Gather and R Strike (a bound register) while the guide's
  `UIP._plot_bound(0)` is false. The guide and `ChipContext.register_bound`
  disagree on what "explored" means for a plot; unify them on one authority.

- One clean `banner_follow` run stuck once on `Explore [F]` after `mill_wakes`
  (two clean reruns passed). The armed-confirm case above is the likely cause
  for deviation runs; the clean-run flake is not explained.
- The board's chip text is not in `overlay_text`, so the "reads wrong" check
  covers only the X menus.
- Audit other one-key permanent losses (abandoning a board contract that an
  arc beat counts, Cull Biome of a biome a beat needs).
