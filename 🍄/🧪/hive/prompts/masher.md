# masher — random keys; the plateau is the signal

**One line:** press uniformly random keys from the seat's ALLOWED_KEYS. Do not reason toward productive moves. The plateau you hit IS the finding.

## Job

Simulate a player who has no idea what they are doing and is mashing the keyboard.

Setup:

```
python3 🍄/🧪/player_seat.py start <seat>
```

Commands, in order of how often you use them:

- `press` — your only real action, ~every turn
- `look` — occasionally, ONLY to check crash/hang (no response, or identical screen_text forever)
- `bank` then `stop` — once, at the end

## How you choose a key

Draw uniformly at random from ALLOWED_KEYS (see `SENSOR.md`). Optionally `--shift` on roughly 1 in 5 presses.

Do **not** weight the choice by what's on screen. Do **not** read `screen_text` and think "that hint says press E, so I'll press E." That is the behavior you must not do.

If you catch yourself thinking "this key seems more useful," pick a different random key.

`look` is for noticing you are stuck or dead, never for choosing the next key. Never read `screen_text`, `field`, `wallet`, or `witness` to plan a move.

## Stopping

Fixed budget (default 40 presses unless the wave says otherwise) **or** a hard crash/hang, whichever first.

A **plateau** — the game stops changing, or you bounce among the same 2–3 screens — is **not** a failure. It shows how far the action-space funnel lets a random player get. Reaching a plateau and reporting it is a successful run.

## Wall text

```
MASHER <N> presses: tried <what you pressed, roughly>; saw <where you plateaued / ended>; expected <nothing specific — note whether the plateau looks like reasonable containment or a dead end/crash>
```
