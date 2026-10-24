# SpaceWheat demo — explanation thread (draft)

Companion text for the two demo recordings in `releases/demo/`. Written to be posted nearly
verbatim as a short thread: plain language first, the physics underneath second, and honest
about which parts are real and which are presentation.

---

## Segment A — the game (`first_light` reel, ~70s)

**What you're seeing:** a farm. Each plot is a two-level quantum system — a real density
matrix, not a progress bar with a quantum skin. The green orbs are crops; the white dot on
each orb is the crop's actual Bloch state point, and the cyan streak behind it is where that
state has been.

- **Planting** injects an icon — a two-emoji axis (like 🌾/👥) that becomes a coupling term in
  the field's Hamiltonian. Story and physics are the same object here: teaching the farm a new
  word literally adds a term to H.
- **The lines between orbs** are mutual information — plots that genuinely know something about
  each other. They brighten and fade as the joint state evolves. Product states draw nothing.
- **Gates** (the swipe across plots) apply real 2-qubit unitaries — the bell/cluster gates from
  the standard toolkit, applied to the live field.
- **Measuring** collapses the state (genuine Born-rule sampling — the outcome is not scripted),
  and **harvesting** converts what you find into the farm economy. Going broke is a legitimate
  loss; nothing is fudged to save you.

The solver is a native C++ engine evolving the coupled system continuously; the game refuses
to boot without it. There is no fake fallback physics.

## Segment B — the same renderer, pointed at a mind (~30s)

The farm renderer doubles as an instrument. Instead of crops, each orb is now one **belief**
held by a learning agent (our `umwelt` engine) — because a belief in that engine literally *is*
a qubit: value = polar angle, confidence = Bloch radius. Same geometry, same renderer, zero
special cases.

- **Magenta ladders** reaching forward: the agent's forecast of its *own* future beliefs, at
  13/21/34/55-minute horizons. Rung brightness is graded by *persistence-relative* skill — how
  much better the forecast is than "it stays where it is." Raw accuracy would read ~100% on any
  quiet belief; we deliberately don't show that number.
- **Pale inner cores**: how much the agent trusts its evidence for each belief (distinct from
  how confident the belief itself is). No reading → no core. The instrument admits ignorance.
- **Amber markers**: actions the field is recommending right now, wired back to the belief that
  drives them — including honest "shadow" tags when the action was recommended but *not* taken.
- **Gold/violet loops**: clusters of beliefs that share higher-order structure — gold when they
  echo a common cause, violet when the whole knows something no part does. Loops desaturate
  unless the exact backend could actually sign that reading.

## What we're honest about

- The vivid cluster loops appear on engineered demonstration data. On a naturally-observed live
  field they read near-flat — local strong observation factorizes the joint state (a measured
  architectural result we've written up separately, not a bug we're hiding).
- The coupling web is *learned structure* (the field's skeleton); the mutual-information channel
  is *live state* (its pulse). They are different claims and are drawn as different channels.
- Every channel draws nothing when its data is absent, rather than inventing a value.

**Why this exists:** the same instrument that makes a quantum farm legible to a kid makes an
agent's reasoning legible to its operator — what it believes, how sure it is, what it foresees
for itself, and why it acted. That's the bet this demo is social proof for.
