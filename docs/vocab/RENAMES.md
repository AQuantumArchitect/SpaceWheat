# Icon renames, 2026-11-16

Every icon now has one name, the same in `factions.json` and `icons.json`, and unique
across the vocabulary. This table lists every pair whose name changed in at least one
file. Sorted by the new name. The data is `tools/vocab/renames.json`; regenerate with
`python tools/vocab/apply_names.py`. Pairs are north/south: the south pole is what the
word provides.

Rule of choice, in order: keep a name that was already unique and consistent; where
the two files disagreed, pick by meaning (the `icons.json` name usually won because it
was the specific one: the faction listings had been filled with a few shared generic
names); where pairs shared a name, the pair that best fits it keeps it and the others
get their own.

82 pairs renamed.

| New name | Pair | factions.json (before) | icons.json (before) | Owner | Reason |
|---|---|---|---|---|---|
| **Accumulate** | ⚡/🔋 | Power | Accumulate | orphaned_icons | icons.json name; lightning stored in the cell; Power stays with Kilowatt Collective's 🔋/⚙ |
| **Amplify** | 📡/🔊 | Signal | Amplify | Resonance Dancers | icons.json name; Resonance Dancers' dish that yields the loudspeaker |
| **Anchorage** | 🚢/⚓ | Fleet | (no entry) | Quay Rooks | Quay Rooks' ship comes to anchor; Fleet stays with 🚀/🛸 |
| **Barter** | 💱/🕴 | Exchange | Barter | orphaned_icons | icons.json name; Exchange stays with Market Spirits' 📦/🏚 |
| **Bloodline** | ⚜/🩸 | Nobility | Bloodline | orphaned_icons | icons.json name; Nobility stays with the Throne's ⚜/👥 |
| **Bridge** | 🌉/🔥 | Crossing | Bridge | Lamplighters | icons.json name; Crossing stays with Nexus Wardens' 🚪/🗝 |
| **Checkpoint** | 🏁/🧂 | Contraband | Checkpoint | orphaned_icons | icons.json name; the flag post where salt is stopped |
| **Chronicle** | 🗃/♟ | Archive | Chronicle | orphaned_icons | icons.json name |
| **Cinder** | 🔥/🪨 | Magma | Cinder | Forgewright Union | icons.json name; Magma stays with Volcanic Foundry's 🌋/🔥 |
| **Clasp** | 🧷/🧿 | Ward | Clasp | Veiled Sisters | icons.json name; Ward stays with Hearth Witches' 🕯/🧿 |
| **Clockwork** | ⏰/⚙ | Mechanism | Clockwork | Timekeepers | icons.json name; a clock that yields gearwork; frees Mechanism for ⚙/🔩 |
| **Cobweb** | 🕸/🕯 | Vigil | Cobweb | orphaned_icons | icons.json name |
| **Colony** | 🧪/🧫 | Culture | Colony | Quarantine Sealwrights | icons.json name; Culture stays with Flesh Architects' 🩸/🧫 |
| **Confession** | ⛪/🗝 | Vigil | Confession | Iron Confessors | icons.json name; Iron Confessors' own word |
| **Consecration** | 🕯/🔥 | Vigil | Consecration | Sacred Flame Keepers | icons.json name; Vigil stays with Keepers of Silence's 🧘/🕯 |
| **Contagion** | 🦗/🧬 | Vector | Contagion | Quarantine Sealwrights | icons.json name; Vector stays with Plague Vectors' 🐝/💀 |
| **Countersign** | 📜/🖋 | Decree | Decree | Ink Wardens | Ink Wardens sign where indicated: the paper calls for the pen; frees Decree for 📜/⚖ (icons.json said Decree) |
| **Decree** | 📜/⚖ | Decree | Edict | The Indelible Precept | the name the game shows and HyperDuster's overlay uses (icons.json said Edict); the written order yields law |
| **Dominion** | ⚜/⚖ | Authority | Dominion | orphaned_icons | icons.json name; the lily yields the scales of rule |
| **Double** | 🪞/👤 | Reflection | Double | Veiled Sisters | icons.json name; Reflection stays with House of Thorns' 🪞/⚖ |
| **Draft** | 💨/🏭 | Drive | Draft | orphaned_icons | icons.json name; Drive stays with Tinker Team's 🚐/⚙ |
| **Electrify** | 💎/⚡ | Spark | Electrify | Gearwright Circle | icons.json name; Spark stays with Reality Midwives' 🌠/⚡ |
| **Enforcement** | 🚔/🔓 | Authority | Enforcement | orphaned_icons | icons.json name |
| **Entangle** | 🕷/🐛 | Predation | Entangle | orphaned_icons | icons.json name |
| **Epoch** | ⏳/🕰 | Witness | Epoch | orphaned_icons | icons.json name; Witness stays with Mossline Brokers' 🧫/🧿 |
| **EuAnaerobe** | 🦠/💀 | Contagion; EuAnaerobe | EuAnaerobe | Plague Vectors; Twilight Recyclers | icons.json name and Twilight Recyclers' listing, in the Eu- family with EuPhotobloom; Plague Vectors listed Contagion |
| **Fanfare** | 📯/🏁 | Signal | Fanfare | Lamplighters | icons.json name; the horn that raises the flag |
| **Flash** | 💫/🔊 | Spark | Flash | orphaned_icons | icons.json name; Spark stays with Reality Midwives' 🌠/⚡ |
| **Forage** | 🌿/🌾 | Forage; Pasture | Forage | Hearth Witches; Swift Herd | icons.json name and Hearth Witches' listing; Pasture stays with 🧭/🌾 |
| **Freight** | 🧂/🛶 | Cargo | (no entry) | Salt Runners | Salt Runners' salt pays for the boat; Cargo stays with Quay Rooks' 🚢/💰 |
| **Frequency** | 📡/👘 | Signal | Frequency | Seamstress Syndicate | icons.json name; Seamstress Syndicate's coded cloth |
| **Gale** | ⚔/🌬 | Strike | Gale | Locusts | icons.json name; Strike stays with Fencebreakers' ⚔/🧨 |
| **Geode** | 🪨/💎 | Forge | (no entry) | Volcanic Foundry | Volcanic Foundry's rock that yields crystal; Forge stays with Symphony Smiths' 🔨/⚙ |
| **Glimmer** | 📡/✨ | Signal | Glimmer | orphaned_icons | icons.json name; Signal stays with 📡/📶 |
| **Guard** | ⚔/🛡 | Combat; Guard | Guard | Iron Shepherds; Scythe Provosts | icons.json name and HyperDuster's; Scythe Provosts' listing said Combat |
| **Haul** | 🌾/🏜 | Cargo | Haul | orphaned_icons | icons.json name; grain carried out across the dunes |
| **Hollow** | 🕸/🌑 | Void | Hollow | Memory Weavers | icons.json name; Void stays with Black Horizon's 🕳/🪐 |
| **Illuminate** | 🧿/🔦 | Ward | Illuminate | Lantern Cant | icons.json name; Lantern Cant's light-code |
| **Inscription** | 🪨/📜 | Record | Inscription | Salt Scribes | icons.json name; Salt Scribes cut the record in stone |
| **Interval** | ⌛/⏰ | Cycle | Interval | orphaned_icons | icons.json name; Cycle stays with Pack Lords' 💀/🌱 |
| **Irrigation** | 🪣/🌾 | Harvest | (no entry) | Irrigation Jury | Irrigation Jury's bucket that yields grain; Harvest stays with Verdant Pulse's 🌾/🍂 |
| **Lamppost** | 🪔/📯 | Relay | Lamppost | orphaned_icons | icons.json name; the lamp that sounds the horn |
| **Larder** | 🥣/🫙 | Harvest | Larder | orphaned_icons | icons.json name; the bowl filled into jars |
| **Leavings** | 🧤/🗑 | Salvage | (no entry) | The Scavenged Psithurism | the Scavenged Psithurism's hand gathers what is left; Salvage stays with Bone Merchants' 🦴/💰 (HyperDuster; Gleaning is taken) |
| **Logbook** | 📒/📋 | Record | Logbook | orphaned_icons | icons.json name; Record stays with Ledger Bailiffs' 📘/💸 |
| **Loop** | 🔌/♻ | Circuit | Loop | Tinker Team | icons.json name; Circuit stays with Kilowatt Collective's 🔌/☀ |
| **Luminary** | 💫/🏮 | Lantern | Luminary | Void Troubadours | icons.json name; Lantern stays with Lantern Cant's 🏮/🕯 |
| **Mandate** | 💊/📦 | Decree | Mandate | The Sovereign Ukase | icons.json name; the Ukase's supply order |
| **Market** | 🧺/💰 | Commerce | Market | orphaned_icons | icons.json name; owner kept Commerce for ⚖/💰 and asked to rename the other |
| **Martyr** | 🩸/🚀 | Sacrifice | Martyr | orphaned_icons | icons.json name; Sacrifice stays with Children of the Ember's ⚔/🩸 |
| **Mechanism** | ⚙/🔩 | Machinery; Mechanism | Mechanism | Gearwright Circle; Obsidian Will; Forgewright Union | icons.json name; Gearwright Circle and Obsidian Will listed Machinery |
| **Memorial** | 🫥/🪦 | Absence | Memorial | Memory Weavers | icons.json name; Absence stays with Chorus of Oblivion's 🫥/🕯 |
| **Moonfall** | 🌙/🍂 | Harvest | Moonfall | Phase Keepers | icons.json name; Phase Keepers' moon brings the leaf-fall |
| **Null** | 🔇/🌑 | Silence | Null | orphaned_icons | icons.json name; Silence stays with Symphony Smiths' 🔇/❄ |
| **Pursuit** | 🐑/🐺 | Predation | Pursuit | orphaned_icons | icons.json name; Predation stays with the Throne's 🦅/🩸 |
| **Rainfall** | 💧/🌧 | Water | (no entry) | Irrigation Jury | Irrigation Jury's water returned as rain; Water stays with Hearth Keepers' 💧/🏜 |
| **Repository** | 💾/🗝 | Archive | Repository | Memory Merchants | icons.json name; Archive stays with Chronicle Keepers' 🗃/📖 |
| **Rupture** | 🕳/⚡ | Singularity | Rupture | orphaned_icons | icons.json name; Singularity stays with Black Horizon's 🌀/⚫ |
| **Satellite** | 🛰/⭐ | Orbit | Satellite | orphaned_icons | icons.json name; Orbit stays with Starforge Reliquary's 🌀/🌙 |
| **Search** | 🔓/🔍 | Tradecraft | (no entry) | Salt Runners | Salt Runners: the opened lock yields the search; Tradecraft stays with ⛓/🔓 |
| **Sentinel** | 🤖/🛡 | Guard | Sentinel | Iron Confessors | icons.json name; Guard stays with ⚔/🛡 |
| **Shrine** | 🧿/🏮 | Ward | Shrine | orphaned_icons | icons.json name |
| **Signal** | 📡/📶 | Signal; Uplink | Signal | Engram Freighters; Relay Lattice | icons.json name and Engram Freighters' listing; Relay Lattice listed Uplink |
| **Sluice** | 💧/⛓ | Channel | (no entry) | Salt Runners | Salt Runners' water held behind chains and gates; Channel stays with 🛶/💧 |
| **Socket** | 🔌/⚡ | Circuit | Socket | orphaned_icons | icons.json name |
| **Spore** | 🌾/🍄 | Harvest | Spore | orphaned_icons | icons.json name; grain that yields fungus |
| **Sprout** | 🫧/🌿 | Cycle | Sprout | orphaned_icons | icons.json name; Cycle stays with 💀/🌱 |
| **Surf** | 🌊/🪨 | Tide | Surf | orphaned_icons | icons.json name; Tide stays with The Submersed's 🌊/🐠 |
| **Surveillance** | 🕵/⛓ | Contraband | Surveillance | Salt-Runners | icons.json name; the watcher yields the chain |
| **Tally** | 🛶/📋 | Manifest | (no entry) | Quay Rooks | Quay Rooks' dockside count of what the boat carries; Manifest stays with Nexus Wardens' 🛂/📋 |
| **Tether** | 🧿/🪢 | Ward | Tether | orphaned_icons | icons.json name |
| **Tithe** | 🔔/🗝 | Toll | Tithe | Knot-Shriners | icons.json name; Toll stays with Station Lords' 🚀/💰 (HyperDuster) |
| **Toil** | 🧤/🏭 | Labor | Toil | orphaned_icons | icons.json name; the gloved hand that keeps the factory: one of the three Labors |
| **Tower** | 📯/🗼 | Relay | Tower | orphaned_icons | icons.json name; the horn answered from the tower |
| **Trap** | 🪤/🪝 | Snare | Trap | orphaned_icons | icons.json name; Snare stays with Clan of the Hidden Root's 🪨/🪤 |
| **Treasury** | 🏛/💰 | Vault | Treasury | Market Spirits | icons.json name; Vault stays with House Adamant's 💰/🔒 |
| **Tune** | 🎵/🧩 | Broadcast | Tune | orphaned_icons | icons.json name; Broadcast stays with Symphony Smiths' 💎/📡 |
| **Usury** | 💰/🪝 | Ledger | (no entry) | Quay Rooks | Quay Rooks' coin that sets the hook; Ledger stays with Archivists' 📜/💰 (Debt is taken) |
| **Vestige** | 💀/⚱ | Aftermath | Vestige | orphaned_icons | icons.json name; Aftermath stays with Brotherhood of Ash's ⚱/🌫 |
| **Viaduct** | 🌉/🪔 | Crossing; Viaduct | Viaduct | Lamplighters; orphaned_icons | icons.json name and one of its two listings |
| **Woodcutting** | 👥/🪓 | Labor | (no entry) | Hearth Keepers | the second Labor: Hearth Keepers' people take up the axe for the hearth, feeding Lumber 🪓/🪵; Labor stays with 👥/🍞 |
| **Yarn** | 🧵/🧶 | Thread | Yarn | Seamstress Syndicate | icons.json name; Thread stays with Knot-Shriners' 🧵/🪡 |
