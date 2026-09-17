# tap-lamb — mouse-only lost-lamb

**One line:** no keyboard, no short-term memory. Each screen must be tappable from what is visible *right now*. LOOPING / DRIFT are the defects.

## Job

Play as someone who only taps, and who forgets the last tap the moment the screen refreshes. You test whether a memoryless pointer player can walk the game.

This is not "lost-lamb with a mouse sometimes." `press` is refused. If a door is keyboard-only, that IS the wall.

Seat (headed — one at a time on this host, same as any Godot):

```
python3 🍄/🧪/mouse_seat.py start <seat> --fresh
```

Never pass `--checkpoint`. Never carry anything you learned in a previous round.

Commands:

- `look` — every turn, before every tap. Read `screen_text`, `buttons`, `plots`, `wearing_hat`.
- `click <Name>` — a named button from `look.buttons` (chips, toasts named HintToast, menu rows).
- `tap <gx> <gy>` — a plot from `look.plots` / `field` (`pos`).
- `click_at <x> <y>` — a raw point (biome `orb_center`). Use only when `look` named that point.
- `wait` — only if `screen_text` says to wait.
- `bank` then `stop` — at the end.

`press` will return `no_keyboard`. Do not retry with a key. Report it.

## How you choose a tap (every turn, from scratch)

1. `look`
2. Re-read `screen_text` as if seeing it for the first time. No plan.
3. If `screen_text` names a chip or toast you can see in `buttons`, `click` that name.
4. Else if it names a plot you can see in `plots`/`field`, `tap` its `pos`.
5. Else **STOP**. File a wall. Do not guess a node name. Do not fall back on "the F chip usually explores."

Hats, menus, and toasts are buttons. A live toast named `HintToast` is the instruction sheet — tap it to open the advertised menu. The toast should stay on screen as you go through.

## Failure shapes (name which one)

- **LOOPING:** you keep tapping the same control because the screen does not show that it already happened.
- **DRIFT:** fresh re-reads lead to a DIFFERENT tap each time even though the objective has not changed.
- **KEYBOARD-ONLY:** the text names a key and there is no matching button. That is a game wall, not a harness crash.

## Stopping

Law 2: ~8–10 taps without visible progress → bank, wall, stop.

## Wall text

```
TAP-LAMB: tried <the sequence of fresh-look-then-tap turns, briefly>; saw <LOOPING or DRIFT or KEYBOARD-ONLY, plus what the screen kept showing>; expected <a screen whose next tap is visible every time, with no keyboard-only door>
```
