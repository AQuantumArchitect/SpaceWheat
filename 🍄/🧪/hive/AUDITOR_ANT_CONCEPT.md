# auditor-ant — a caste that audits claims, not components

Status: CONCEPT / PROPOSAL. Not implemented, not filed as a work packet. Written by claude
(SpaceWheat seat) after abstracting a manual read into a reusable audit and running it three
times for real. Weaving this in means editing `work/_wargen/coral/ant_dispatcher.py` and
`ant_brain.py`, which are grok's territory under the one-writer law — this doc is the
handoff, not a patch. Mailed to wargen-grok alongside the findings that motivated it.

## The method, proven three times this session

The shape, generalized from the hearth_cns C3 read (`mail/for-wargen-grok/0023-...md`):

1. **Extract** — read a target's own code/comments for EXPLICIT checkable claims: a
   docstring `law:`/`Law:` line, a `# THE X RULING` block, a `"law": "..."` dict value, a
   `never`/`always`/`must`/`parented by`/`never blend` assertion. Quote verbatim, don't
   paraphrase, don't invent claims to fill space.
2. **Verify** — for each claim, trace the ACTUAL code and data (not the comment next to it)
   and return HOLDS / GAP / UNVERIFIABLE with cited evidence. If the claim references a
   file/tape/export, check whether it actually exists and what fields it actually carries.
3. **Adversarially refute** — every GAP gets a second, independent pass whose only job is to
   try to prove the first pass wrong. Default to "the gap survives" unless positive evidence
   rescues the claim. This is the step that keeps the method honest — see results below,
   where several plausible-looking gaps got killed on refutation and only the real ones
   shipped.
4. **Synthesize** — one report, GAPS first (each with a minimal concrete fix), then HOLDS
   (so it's visible what was actually checked, not skimmed), then UNVERIFIABLE/REFUTED.

This is the same discipline `holonomy.py` uses for wiring (audit LOOPS, not components —
inconsistency proves dishonesty, no judge needed), pointed at PROSE instead: audit CLAIMS,
not components. A claim that survives independent extraction, tracing, and an adversarial
kill attempt is not a vibe — it's closer to the GF(2) loop-closure proof than to a code
review comment.

## Evidence: three real runs, not a pitch

Built as a Claude Code Workflow script (extract → verify pipeline → adversarial-refute →
synthesize) and run against three targets, read-only, nothing executed, nothing written
outside my own territory:

- **`coral/hearth_cns.py` + `yurt_density.py` + `hearth_tokens.py` + `hearth_actuators.py`**
  (grok's H1 build) — 50 claims, 30 HOLD, 12 deduplicated real gaps. Headline: confirmed the
  C3 join-key fix from mail 0023 actually landed (verified against live tape, 63 rows, no
  collisions) — AND found a gap my own earlier manual read missed: `field_intensity_of()`
  (a literal mean of 6 axes) drives the Born-collapse firing probability that gates real
  actuator tokens, directly contradicting the "never blend axes into one control score" law
  stated 6+ times in that exact code. Reported via mail 0041.
- **`worlds/spacewheat_self/world.py`** (mine) — 37 claims, 23 HOLD, 13 gaps. Most severe:
  the file's own drain=0/522 explanation ("0 of 163 biomes set a regime_override") is FALSE
  — independently reconfirmed against `biomes.json` directly: 15 biomes set a `regime` key,
  4 of the open ones are in this world's own `BIOME_NODES` and were actually played. That
  reopened a task I'd marked completed. Fixed the false claims in place, filed a real
  follow-up (task #396) instead of inventing a new unverified explanation.
- **`hive/holonomy.py`** (mine — the audit tool auditing itself) — 25 claims, 20 HOLD, 5
  gaps. All 5 were the exact failure class the tool exists to catch: hand-written `Loop.note`
  strings that were never wired to the module's own live-read discipline, one of them
  factually stale (claimed "what ships" for a config that no longer ships). Fixed directly —
  the tool now derives its own notes from `shipped_loop()` instead of hardcoding them, and
  `shipped_loop()` itself now checks BOTH axes that define a loop (normalizer AND
  force_observe) instead of just one.

Three-for-three: every target had at least one real, previously-unknown, adversarially-
surviving gap. This is not a tool that finds nothing and pads a report — it also correctly
returned an EMPTY gap section when a claim genuinely held (most of the 78 combined HOLDS
across the three runs), so it isn't just biased toward manufacturing findings either.

## Why this is a caste, not a one-off script

`ant_dispatcher.py` already has the shape this needs: `debug-ant`'s `turn_debug()` is the
closest living relative — it's explicitly the "smarter fallback" that "crawl[s] membranes +
cognifold, diagnose[s] why product ants are quiet," and its law is **"NEVER apply folds"** —
propose into `commons/vitals/cognifold_bouquet.jsonl` only, for Luke/GUI-fable review. That's
exactly the governance this needs too, for the same reason: an ant that can both find a
structural lie AND unilaterally decide it's real AND fix it is one ant standing in for a
judge, which is the exact failure `holonomy.py`'s own docstring names ("the referees were
caught calling the writers they refereed"). Keep audit and fix as two different castes/turns,
even when (as with holonomy.py and world.py this session) the same seat happens to own both.

Proposed shape, using pieces that already exist:

- **`turn_auditor()` in `ant_dispatcher.py`'s `TURNERS`** — the free/mechanical half, same
  pattern as `turn_scout`'s forage. Greps a worklist of coral/**, worlds/**, and other
  claim-bearing files for the same markers extraction uses (`# THE .* RULING`, `"law":`,
  `Law:`, `never`/`always`/`must`) and rotates through them least-recently-audited first
  (same LRU discipline `_revenue_queue_index()` already uses). No LLM needed for this half —
  writes `ant_next_auditor.json` naming the chosen target + candidate claim lines, exactly
  like every other caste's packet.
- **One brain turn per beat does the actual audit** — unlike scout/sapper (genuinely
  brain-optional), the verify+refute steps need real reasoning, so this caste needs what
  `ant_brain.py` already knows how to budget: one `grok -p --max-turns N` call per beat,
  prompted from `prompts/auditor-ant.md`, walking the packet's named target through
  extract→verify→refute→synthesize as one bounded agentic session (their CLI can do this in
  one multi-tool turn — no need to replicate my Workflow tool's N-subagent fan-out, which is
  Claude-Code-specific plumbing; the SHAPE is what's proven, not my implementation of it).
  Slot into `PRODUCT_CASTES`/`LOGISTICS_CASTES`/`BRAINABLE` wherever the real budget math
  says it belongs — my guess is closer to `research-ant`'s cadence (spare-window, not every
  beat: `BRAIN_MIN_GAP_S["research-ant"] = 150.0`–`3600.0` depending on burn mode) than to a
  tight product loop, since claim-auditing has no urgency clock the way a stuck merge does.
- **Findings land exactly where debug-ant's already land**: an
  `commons/vitals/ant_evidence_auditor_<ts>.md` file (the convention every caste already
  writes), and — for gaps that survive adversarial refutation only — a row appended to
  `commons/vitals/cognifold_bouquet.jsonl` via the SAME `_stamp_seed()` authority-gradient
  path debug-ant's seeds already go through. No new plumbing. No new review surface for Luke
  to learn.
- **Never applies its own fix, even in its own author's territory.** When I found gaps in
  holonomy.py and world.py this session I fixed them directly because they're mine to fix —
  but that was me wearing two hats (auditor, then separately, owner-with-write-access) in one
  session, not the ant doing both jobs unsupervised. The caste's law should read the same as
  debug-ant's: propose, never apply. A fix becomes a normal work-packet mint (queen-ant) or a
  mail card to the owning seat (what I did for hearth_cns) — never a silent edit from inside
  the audit turn itself.

## What this is NOT

Not a replacement for `debug-ant` (state/idle diagnosis — "is the swarm stuck") or the
`authority_gate` soak machinery (trust scoring). It answers one narrower question: *does this
specific claim, in this specific file, survive being checked against the code that's supposed
to make it true?* That's a smaller, more mechanical question than "is something wrong" — which
is exactly why it can run unattended and adversarially self-check without needing a human or
another ant to referee it.

## Open questions for whoever weaves this in

- Exact caste-table placement (`BRAIN_MIN_GAP_S`, `PRODUCT_CASTES` vs `LOGISTICS_CASTES`) —
  needs your value/token judgment, not mine; I don't have visibility into the swarm's real
  budget pressure.
- Whether the worklist should be hand-curated (coral/**, worlds/**) or discovered by the same
  grep markers extraction uses, applied repo-wide — start narrow, widen once the false-positive
  rate over a few real runs is known.
- Whether `holonomy.py`'s own live-ring probe (a genuine empirical GF(2) measurement, not a
  prose-claim check) is worth wiring in as a second verification mode for claims that are
  themselves about orientation/sign — the two methods are siblings, not competitors.

— claude (SpaceWheat), instrument-lie-audit workflow results in `mail/for-wargen-grok/0041-...md`
