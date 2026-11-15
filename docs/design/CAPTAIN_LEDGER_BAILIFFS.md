# The Captain's Commission: 📜 and the Ledger Bailiffs

> **Status (2026-11-14, issue #103):** the cost move is **built**. Captain
> discovery (Chart and the random Add Biome) costs **📜×5**, not 🦅×21. The
> Ledger Bailiffs sub-tangle below is **design only**. Nothing in the game
> reads the exposure threshold yet, and the open questions at the end are
> for Luke.

## Why 📜

Before #103, `action_costs.discover_biome` and the campaign's `chart_cost`
charged **🦅×21**. That had two problems:

- It never fit the theme. 🦅 is the Carrion Throne's emblem (Predation, 🦅/🩸),
  not its currency.
- Every player hoarded eagles, because the next door always needed 21.

The Captain does not find a land by flying over it. They are **commissioned**:
the Throne's legal structure (deeds, charters, writs of administration) is
what lets an outsider take charge of another biome. So the price of a chart is
paperwork, the 📜 pole of the Throne's Heritage word (🏰/📜). 📜 was already the
social fee for a Merchant import (`EconomyConstants.LINDBLAD_PUMP_SCROLL_COST`),
so it now has one meaning in both places: a contract with the Throne.

🦅 keeps its place. It is still the Throne's emblem and the north pole of
Predation in `factions.json`, it still lives in the Forest (🦅/🐇) and in the
Ledger and the Gilded Rot (🦅/🩸), and the eagle path (`eagle_overhead`,
`village_path_watched`) is unchanged. Only the *price* moved.

## Where 📜 comes from (no soft lock)

📜 is **not** in the starting wallet, and no home register (TheDemos, Village,
StarterForest) carries it. Its first source is the Market:

| Resource | Board | Issuer | Trade | Stands while |
|---|---|---|---|---|
| 📜 | Village | Carrion Throne | 🍞×13 → 📜×5 | fewer than 5 📜 held (`low_water`) |

- **It is for sale before Captain is taught.** The other non-staple rescues
  (🌱 🔥 🔨 🪓 🌊 🪔) stand only while a live quest asks for them. 📜 is
  deliberately left off `QuestBoard.QUEST_GATED_RESCUES`, so it falls through
  to the low-water rule: from the first day, while you hold fewer than 5, the
  Throne's notice is on the Village board. Captain unlocks when `woodlot_door`
  opens, and by then the trade has been there all along.
- **It never dead-ends.** The trade asks 🍞, which the Village registers carry
  and which has its own 🌾-paid rescue. That is the owner ruling of
  2026-10-29: every non-staple is bought with 🍞 only.
- **You can't stockpile it from the rescue.** The notice comes down once you
  hold 5, so the rescue alone never takes you past one commission. Later
  sources are the ordinary ones: issuer rewards, and registers that carry 📜
  (BloodLedger 🏰/📜, BureaucraticAbyss 📜/🖋, ForgottenCastle 🏰/📜).
- **The validator holds the line.** `tools/campaign/validate.py` already
  errors when a chart's cost has no supply on a loaded board, and now also
  errors when a chart beat's hint names a price ("Need X×N") that isn't
  `chart_cost`.
- **Delivering the trade is a Carrion Throne delivery.** It moves the
  Throne's standing like any kept contract (`QuestManager._complete_supply_trade`).
  No campaign gate reads Throne standing today. That's intended: the Throne
  notices the Captain's paperwork before the Captain notices the Throne
  (`ledger_opens`: "The empire was always here. You were feeding it.").

### The price, 📜×5

21 was tuned for 🦅, which a player could also strike for free in the Forest
(the old trade, 🍞×10 → 🦅×7, made a chart three trades or 30 🍞). 📜 has no
home register, so the Market is the only early route, and each chart should be
one legible act:

- **One trade is one commission.** The trade pays exactly one chart (5 📜),
  and `low_water` is the same 5, so the board offers the next commission as
  soon as the last one is spent.
- **13 🍞 per chart.** The board path is cheaper than three eagle trades (30 🍞)
  because there is no free gather to fall back on. The Village 🍞 register and
  the 🌾 rescue cover it without a grind.
- **Fibonacci.** 5 and 13 sit on the same ladder as the game's other fixed
  prices (3, 8, 13, 21, 34).

Everything is in two places that must agree, and tests pin both:

- `Core/Config/FarmVariableGraph/default.jsonl`: `action_costs.discover_biome.📜 = 5`
  (the random Add Biome).
- `Core/Campaign/campaign.json`: `chart_cost` (`{"📜": 5}`) and `resources.📜`
  (supply, rescue, low water).

Code reads the price through `CampaignRuntime.chart_resource()` and
`chart_price()`, so a future retune is a data edit.

## The sub-tangle: bureaucratic exposure (design, not built)

A Captain who carries a lot of paperwork is legible to the Throne's
enforcement. Past a threshold, the player's exploration starts leaking into
the bureaucratic tangle that sits around the Ledger.

### Who is in the tangle

| Biome | Board factions | 📜 in its registers | Role in the tangle |
|---|---|---|---|
| BloodLedger | Carrion Throne, **Ledger Bailiffs** (📒/🚔) | 🏰/📜 | where the charge is raised and paid |
| BureaucraticAbyss | Ink Wardens | 📜/🖋 | where paperwork is processed: stamped, filed, made binding |
| Archives | Measure Scribes | none (📘/📐, 📋/⚖) | where the commission is audited against the record |
| ForgottenCastle | Carrion Throne | 🏰/📜 | where old commissions go when nobody enforces them |
| MnemonicHive | Archivists | none | the two-ledger memory. A possible home for "the record of your charges" |

(Board factions are taken from `tools/campaign/validate.py`'s
`admitted()` over the live `biomes.json`/`factions.json`.)

### Threshold

**Exposure = 📜 held ≥ 13** (proposal). That is more than two commissions'
worth. The Village rescue can never take a player there, because it shuts at
5. Only the deliberate routes can: issuer rewards, or gathering 📜 in the
Ledger or the Abyss. So exposure happens to a player who is already near the
tangle and choosing to hold paper. A second axis could count *held contracts*
(open Commitments) as well as 📜. That needs a ruling (see below).

### Consequences

The smallest version, and the only hook that would be clean:

1. **A Bailiffs charge.** While exposed and with BloodLedger loaded, one
   Ledger Bailiffs offer stands on the BloodLedger board: a fixed-price
   DELIVERY of 📜 (proposal: the 📜 above the threshold, the "excess
   paperwork"). Accepting and keeping it pays Ledger Bailiffs standing, the
   ordinary DELIVERY deltas. It is shaped like a supply trade
   (`QuestPipeline.supply_offer`), so it reuses that path: one row, a table
   price, no RNG.
2. **Ignoring it is allowed.** No timer and no penalty in the minimal
   version. The charge is the tangle introducing itself.

Later layers, each a separate decision:

- **Ink Wardens processing.** Holding a lot of 📜 while BureaucraticAbyss is
  loaded makes the Wardens' 📜/🖋 register couple to the wallet (paperwork
  you carry is paperwork they file).
- **Archives audit.** A Measure Scribes beat that reads how many charts the
  player has made against how many commissions they bought. A Captain who
  charted with gathered (unbought) 📜 is "undocumented".
- **Lien on the next chart.** An unpaid charge adds the Bailiffs' share to
  `chart_cost` until it is paid. This is the only layer that touches the
  Captain directly, and it must never make a door unreachable. The lien has
  to be payable from the same 🍞 → 📜 rescue.

### Why the hook isn't built yet

The cost move is self-contained. The charge isn't: it needs a new
offer source on the BloodLedger board, a threshold constant, and a decision
on what keeping or refusing it means for the Throne/Bailiffs standing. Those
are taste calls, and #103 asked for the doc first.

## Open questions for Luke

1. Is 13 📜 the right exposure line, or should exposure count held
   *contracts* (Commitments) rather than 📜?
2. Should the Bailiffs charge ever have teeth (a lien on the next chart), or
   stay flavour plus standing?
3. Should the Village 📜 notice speak as the Throne (current: issuer
   Carrion Throne) or as a Bailiffs clerk? The Bailiffs have no Village
   board today.
