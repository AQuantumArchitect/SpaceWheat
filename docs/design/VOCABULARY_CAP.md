# Capping the player's vocabulary at six words

Status: **design note only. Nothing here is implemented.** Luke likes the idea
and has not decided. Issue #102 playtest notes.

## The idea

The player's vocabulary (`farm.known_icons`, the signature) holds at most **six
words**, the same size as a biome's register file (a biome seats six qubits,
`_get_max_biome_qubits()`). The player's signature then has the same shape as
the places it is planted into: one word per qubit, no more.

## What it would change

- `Farm.discover_icon` is the one door words enter by (Incorporate, faction
  teachings, rewards all pass through `PlayerProgress.discover_icon`). A cap is
  one check there, so every source is covered at once.
- Today `discorporate_icon` refuses to empty the signature, but nothing stops it
  growing. At six, learning a seventh word has to *replace* one.
- Incorporated words (`farm.incorporated_icons`) pay the ×4 strike bonus. A cap
  makes *which* six you keep a real choice.

## Open questions (Needs Luke)

1. **Full signature:** refuse the new word, or ask the player which word to
   forget? Refusing is simple but strands the Incorporate ritual, since the
   berry is consumed either way. Asking costs a small UI.
2. **Teachings:** do faction teachings (act 1) count against the six? The
   starter signature plus the first teachings may already reach it.
3. **Saves:** existing saves may hold more than six words. Grandfather them, or
   trim on load? The save format is frozen (`tests/test_save_format_freeze.py`).
4. **Gates:** several campaign gates count `signature_size`. Check that none
   asks for more than six before choosing the cap.

Nothing to build until Luke decides.
