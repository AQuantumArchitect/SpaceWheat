class_name FactionDatabase
extends Resource

## Complete database of 32 factions with 12-bit classification patterns
## Generated from spacewheat_factions_db_v0_4.json
## Each faction has: name, signature (emoji array), 12-bit pattern, category, description

# =============================================================================
# AXIAL SPINE METADATA
# =============================================================================

const VERSION = "0.4"

const AXES = [
	{
		"bit": 1,
		"name": "Random/Deterministic",
		"0": "🎲",
		"1": "📚"
	},
	{
		"bit": 2,
		"name": "Material/Mystical",
		"0": "🔧",
		"1": "🔮"
	},
	{
		"bit": 3,
		"name": "Common/Elite",
		"0": "🌾",
		"1": "👑"
	},
	{
		"bit": 4,
		"name": "Local/Cosmic",
		"0": "🏠",
		"1": "🌌"
	},
	{
		"bit": 5,
		"name": "Instant/Eternal",
		"0": "⚡",
		"1": "🕰️"
	},
	{
		"bit": 6,
		"name": "Physical/Mental",
		"0": "💪",
		"1": "🧠"
	},
	{
		"bit": 7,
		"name": "Crystalline/Fluid",
		"0": "💠",
		"1": "🌊"
	},
	{
		"bit": 8,
		"name": "Direct/Subtle",
		"0": "🗡️",
		"1": "🎭"
	},
	{
		"bit": 9,
		"name": "Consumptive/Providing",
		"0": "🍽️",
		"1": "🎁"
	},
	{
		"bit": 10,
		"name": "Monochrome/Prismatic",
		"0": "⬜",
		"1": "🌈"
	},
	{
		"bit": 11,
		"name": "Emergent/Imposed",
		"0": "🍄",
		"1": "🏗️"
	},
	{
		"bit": 12,
		"name": "Scattered/Focused",
		"0": "🌪️",
		"1": "🎯"
	},
]

# =============================================================================
# COSMIC MANIPULATORS (1 faction)
# =============================================================================

const RESONANCE_DANCERS = {
	"name": "Resonance Dancers",
	"signature": ["💃", "🎼", "🌟", "🌀", "🧵", "📡", "🌠", "🧿", "👁"],
	"bits": [1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
	"category": "Cosmic Manipulators",
	"description": "Ritual performers who tune social reality by moving bodies through phase, rhythm, and echo."
}

# =============================================================================
# DEFENSIVE COMMUNITIES (4 factions)
# =============================================================================

const CLAN_OF_THE_HIDDEN_ROOT = {
	"name": "Clan of the Hidden Root",
	"signature": ["🌱", "🏡", "🛡", "🧱", "🏰", "🔒", "⛓", "🌑"],
	"bits": [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0],
	"category": "Defensive Communities",
	"description": "Subterranean network that trades in seedlings, secrets, and patient infiltration."
}

const TERRARIUM_COLLECTIVE = {
	"name": "Terrarium Collective",
	"signature": ["🌿", "🔒", "🛡", "🧱", "🏰", "🏡", "⛓", "🌑"],
	"bits": [1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 1],
	"category": "Defensive Communities",
	"description": "A cooperative project of resilience-builders trying to outgrow empire through living infrastructure."
}

const VEILED_SISTERS = {
	"name": "Veiled Sisters",
	"signature": ["👤", "🌑", "🛡", "🧱", "🏰", "🕯", "🧿", "🔒"],
	"bits": [0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 0],
	"category": "Defensive Communities",
	"description": "A covert sisterhood of influence that moves through households, courts, and shrines unseen."
}

const VOID_SERFS = {
	"name": "Void Serfs",
	"signature": ["⛓", "🛡", "🧱", "🏰", "🌽", "🪐", "🔒", "🏡"],
	"bits": [0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0],
	"category": "Defensive Communities",
	"description": "Indentured laborers bound to orbital contracts, worked by distance, debt, and inaccessible law."
}

# =============================================================================
# HORROR CULTS (4 factions)
# =============================================================================

const CHORUS_OF_OBLIVION = {
	"name": "Chorus of Oblivion",
	"signature": ["⚔", "🎶", "💀", "🌀", "📡", "🧿", "🗣", "🔔", "🌙"],
	"bits": [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1],
	"category": "Horror Cults",
	"description": "A mental cosmic choir that harmonizes minds toward forgetting, surrender, and the empty note."
}

const CULT_OF_THE_DROWNED_STAR = {
	"name": "Cult of the Drowned Star",
	"signature": ["⚔", "⭐", "👁", "🧿", "💀", "🎶", "📡", "🌀", "💧"],
	"bits": [0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0],
	"category": "Horror Cults",
	"description": "A physical cosmic devotion to a sunken intelligence—pressure, drowning, and deep geometry."
}

const FLESH_ARCHITECTS = {
	"name": "Flesh Architects",
	"signature": ["⚔", "🧬", "👥", "🧿", "💀", "🎶", "📡", "🌀", "🧱"],
	"bits": [0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1],
	"category": "Horror Cults",
	"description": "Bio-engineers who sculpt bodies and habitats as living machines, optimized for survival and control."
}

const LAUGHING_COURT = {
	"name": "Laughing Court",
	"signature": ["⚔", "🎪", "💀", "🌀", "📡", "🧿", "🎶", "🃏", "👁"],
	"bits": [0, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 0],
	"category": "Horror Cults",
	"description": "Instant memetic aristocracy that topples certainty with contagious jokes and sharp, cruel delight."
}

# =============================================================================
# IMPERIAL POWERS (4 factions)
# =============================================================================

const CARRION_THRONE = {
	"name": "Carrion Throne",
	"signature": ["⚔", "💀", "🏛", "⚖", "🧾", "🛡", "💰", "🪙", "🏰", "🗝"],
	"bits": [1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1],
	"category": "Imperial Powers",
	"description": "Imperial carcass-court that turns conquest into law, tribute, and ritualized decay."
}

const GRANARY_GUILDS = {
	"name": "Granary Guilds",
	"signature": ["⚔", "💰", "🪙", "⚖", "🧾", "🏛", "🛡", "🗝", "🌽", "🏰"],
	"bits": [1, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1],
	"category": "Imperial Powers",
	"description": "Market sovereigns who decide what counts as food, what counts as debt, and who eats."
}

const HOUSE_OF_THORNS = {
	"name": "House of Thorns",
	"signature": ["🌹", "⚖", "🧾", "🏛", "🛡", "💰", "🪙", "⚔", "🏰"],
	"bits": [1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1],
	"category": "Imperial Powers",
	"description": "A noble garden of coercion: alliances, blood-vows, and barbed diplomacy in velvet gloves."
}

const STATION_LORDS = {
	"name": "Station Lords",
	"signature": ["⚔", "🏢", "⚖", "🧾", "🏛", "🛡", "💰", "🪙", "🏰", "🪐"],
	"bits": [1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1],
	"category": "Imperial Powers",
	"description": "Orbital landlords who control docks, manifests, and the choke-points between farmworld and void."
}

# =============================================================================
# LOCAL GOVERNANCE (1 faction)
# =============================================================================

const IRRIGATION_JURY = {
	"name": "Irrigation Jury",
	"signature": ["⚖", "🗝", "🧾", "🏛", "💧", "🚰", "📜", "🛡"],
	"bits": [1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 1, 1],
	"category": "Local Governance",
	"description": "Water disputes settled at knife-point."
}

# =============================================================================
# LOCAL INSTITUTIONS (4 factions)
# =============================================================================

const GEARWRIGHT_CIRCLE = {
	"name": "Gearwright Circle",
	"signature": ["⚙", "🏭", "🛠", "🧾", "🗝", "📦", "🔩", "💰"],
	"bits": [1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1],
	"category": "Local Institutions",
	"description": "Repair monopolists and machine rites."
}

const LEDGER_BAILIFFS = {
	"name": "Ledger Bailiffs",
	"signature": ["⚖", "🛡", "🗝", "🧾", "⚙", "📦", "🔩", "🛠"],
	"bits": [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1],
	"category": "Local Institutions",
	"description": "Quota enforcement and fair measure."
}

const MEASURE_SCRIBES = {
	"name": "Measure Scribes",
	"signature": ["⚖", "💰", "📦", "🧾", "🗝", "⚙", "🔔", "🔩"],
	"bits": [1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1],
	"category": "Local Institutions",
	"description": "Elite auditors of yield and debt."
}

const QUARANTINE_SEALWRIGHTS = {
	"name": "Quarantine Sealwrights",
	"signature": ["🧪", "🦗", "🧾", "🗝", "⚙", "📦", "🔩", "🛠"],
	"bits": [1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 1],
	"category": "Local Institutions",
	"description": "Pest seals, permits, and burn-marks."
}

# =============================================================================
# LOCAL INSURGENTS (1 faction)
# =============================================================================

const FENCEBREAKERS = {
	"name": "Fencebreakers",
	"signature": ["⛓", "🔥", "💀", "🧨", "🪓", "🗝", "⚔", "📣"],
	"bits": [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
	"category": "Local Insurgents",
	"description": "Rural sabotage and boundary wars."
}

# =============================================================================
# LOCAL MILITIA (1 faction)
# =============================================================================

const SCYTHE_PROVOSTS = {
	"name": "Scythe Provosts",
	"signature": ["⚔", "🛡", "⚫", "🔥", "⛓", "🏰", "🪓", "🧾"],
	"bits": [1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1],
	"category": "Local Militia",
	"description": "Enforcers for elite estates and mills."
}

# =============================================================================
# LOCAL MYSTICS (3 factions)
# =============================================================================

const HEARTH_WITCHES = {
	"name": "Hearth Witches",
	"signature": ["🕯", "🌿", "🌙", "🧿", "🌀", "🌱", "🔔", "🪬"],
	"bits": [0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0],
	"category": "Local Mystics",
	"description": "Kitchen hexes and blessing trades."
}

const KNOT_SHRINERS = {
	"name": "Knot-Shriners",
	"signature": ["🧵", "🧿", "🕯", "🌙", "🌀", "🫖", "🌱", "🔔"],
	"bits": [1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0],
	"category": "Local Mystics",
	"description": "Shrine-keepers who tie ritual knots to stabilize luck, oaths, and message integrity."
}

const MOSSLINE_BROKERS = {
	"name": "Mossline Brokers",
	"signature": ["🌿", "💰", "🕯", "🧿", "🌙", "🌀", "🌱", "🔔"],
	"bits": [0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0],
	"category": "Local Mystics",
	"description": "Grey-market dealers of spores, omens, and rumors—selling soft power by the handful."
}

# =============================================================================
# LOCAL NETWORKS (2 factions)
# =============================================================================

const LANTERN_CANT = {
	"name": "Lantern Cant",
	"signature": ["🏮", "📡", "🗣", "🧵", "🗺", "🔭", "🗝", "🪡"],
	"bits": [0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1],
	"category": "Local Networks",
	"description": "Street-visible lantern code that moves urgent news across farms, docks, and checkpoints."
}

const RELAY_LATTICE = {
	"name": "Relay Lattice",
	"signature": ["🌀", "🌟", "🗝", "📡", "🧵", "🗺", "🔭", "🪡"],
	"bits": [1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1],
	"category": "Local Networks",
	"description": "Fast messages through strange topology."
}

# =============================================================================
# LOCAL SCIENCE (1 faction)
# =============================================================================

const SEEDVAULT_CURATORS = {
	"name": "Seedvault Curators",
	"signature": ["🧬", "🗝", "🧪", "🧫", "🔩", "📦", "🌽", "🔬"],
	"bits": [1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1],
	"category": "Local Science",
	"description": "Ancient seeds, new crops, hard rules."
}

# =============================================================================
# LOCAL STREET (2 factions)
# =============================================================================

const QUAY_ROOKS = {
	"name": "Quay Rooks",
	"signature": ["🚢", "🗺", "🔭", "📡", "💰", "⛓", "🧨", "📦"],
	"bits": [0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0],
	"category": "Local Street",
	"description": "Dock gossip, maps, and opportunism."
}

const SALT_RUNNERS = {
	"name": "Salt-Runners",
	"signature": ["🚢", "⛓", "💰", "🧨", "🗺", "📡", "📦", "🗝"],
	"bits": [0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0],
	"category": "Local Street",
	"description": "Smugglers through canals and voidlocks."
}

# =============================================================================
# MERCHANTS & TRADERS (4 factions)
# =============================================================================

const BONE_MERCHANTS = {
	"name": "Bone Merchants",
	"signature": ["🦴", "💉", "🛒", "📡", "💰", "🪙", "📦", "🧾", "🗝"],
	"bits": [0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0],
	"category": "Merchants & Traders",
	"description": "Pragmatic traders of skeletal salvage: fertilizer, tools, relics, and taboo luxuries."
}

const MEMORY_MERCHANTS = {
	"name": "Memory Merchants",
	"signature": ["💰", "🪙", "📦", "📡", "🧾", "🗺", "🛂", "🧩", "🗝"],
	"bits": [1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0],
	"category": "Merchants & Traders",
	"description": "Dealers in recollection who buy, sell, and edit lived experience as a commodity."
}

const NEXUS_WARDENS = {
	"name": "Nexus Wardens",
	"signature": ["🍺", "🗝", "📡", "🧵", "💰", "🪙", "📦", "🧾", "⚖"],
	"bits": [1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0],
	"category": "Merchants & Traders",
	"description": "Gatekeepers of crossings and protocols who police how worlds connect and who may pass."
}

const SYNDICATE_OF_GLASS = {
	"name": "Syndicate of Glass",
	"signature": ["💎", "⚖", "🛸", "📡", "💰", "🪙", "📦", "🧾", "🗝"],
	"bits": [1, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1],
	"category": "Merchants & Traders",
	"description": "Brittle oligarchs of transparency and fracture—spies, mirrors, and precision cruelty."
}

# =============================================================================
# MILITANT ORDERS (4 factions)
# =============================================================================

const BROTHERHOOD_OF_ASH = {
	"name": "Brotherhood of Ash",
	"signature": ["⚔", "⚰", "⚫", "🛡", "⛓", "🔥", "🏰", "🪓"],
	"bits": [1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
	"category": "Militant Orders",
	"description": "A roaming fraternity of burn-scars and oaths, offering cleansing violence for a price."
}

const CHILDREN_OF_THE_EMBER = {
	"name": "Children of the Ember",
	"signature": ["🔥", "✊", "🛡", "⚔", "⛓", "🗝", "🏰", "🪓"],
	"bits": [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	"category": "Militant Orders",
	"description": "Fast-moving local spark-cult that spreads uprisings like wildfire through dry structures."
}

const IRON_SHEPHERDS = {
	"name": "Iron Shepherds",
	"signature": ["🛡", "🐑", "🚀", "⚔", "⛓", "🔥", "🏰", "🪓"],
	"bits": [1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1],
	"category": "Militant Orders",
	"description": "Hard-handed protectors who herd communities through danger, collecting loyalty as payment."
}

const ORDER_OF_THE_CRIMSON_SCALE = {
	"name": "Order of the Crimson Scale",
	"signature": ["⚖", "🐉", "🩸", "🛡", "⚔", "⛓", "🔥", "🏰"],
	"bits": [1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1],
	"category": "Militant Orders",
	"description": "A disciplined blood-and-balance order that enforces ‘proper’ exchange with scaled justice."
}

# =============================================================================
# MYSTIC ORDERS (4 factions)
# =============================================================================

const IRON_CONFESSORS = {
	"name": "Iron Confessors",
	"signature": ["🤖", "⛪", "🧿", "🌙", "🌀", "🛠", "🔔", "🧘"],
	"bits": [1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1],
	"category": "Mystic Orders",
	"description": "Confessional enforcers who extract truth as a resource and punish deviation with steel rituals."
}

const KEEPERS_OF_SILENCE = {
	"name": "Keepers of Silence",
	"signature": ["🧘", "♂", "⚔", "🔇", "🕯", "🧿", "🌙", "⛪"],
	"bits": [1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1],
	"category": "Mystic Orders",
	"description": "A disciplined order that weaponizes quiet: censorship, secrecy, and signal starvation."
}

const SACRED_FLAME_KEEPERS = {
	"name": "Sacred Flame Keepers",
	"signature": ["🕯", "🔥", "⛪", "🧿", "🌙", "🌀", "🔔", "🧘"],
	"bits": [1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1],
	"category": "Mystic Orders",
	"description": "Fire-priests who guard heat, furnaces, and the social right to burn or purify."
}

const YEAST_PROPHETS = {
	"name": "Yeast Prophets",
	"signature": ["🍞", "🧪", "⛪", "🕯", "🧿", "🌙", "🌀", "🔔"],
	"bits": [0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1],
	"category": "Mystic Orders",
	"description": "Fermentation mystics who treat growth, rot, and rise as the universe’s holy mathematics."
}

# =============================================================================
# SCAVENGER FACTIONS (3 factions)
# =============================================================================

const CARTOGRAPHERS = {
	"name": "Cartographers",
	"signature": ["⚔", "🗺", "🔭", "🚢", "📡", "🪓", "📦", "💀", "⛓"],
	"bits": [0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0],
	"category": "Scavenger Factions",
	"description": "Map-makers of terrain and meaning; they redraw borders by deciding what is ‘real’ on paper."
}

const LOCUSTS = {
	"name": "Locusts",
	"signature": ["⚔", "🦗", "🍃", "💀", "🪓", "📦", "🦴", "⛓", "🚢"],
	"bits": [0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0],
	"category": "Scavenger Factions",
	"description": "Biological extractors that convert ecosystems into fuel, motion, and swarming advantage."
}

const RUST_FLEET = {
	"name": "Rust Fleet",
	"signature": ["⚔", "🚢", "🦴", "⚙", "🪓", "📦", "💀", "⛓", "🔩"],
	"bits": [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0],
	"category": "Scavenger Factions",
	"description": "Salvage sailors who live on drifting wrecks, stripping value from dead ships and dead wars."
}

# =============================================================================
# ULTIMATE COSMIC ENTITIES (3 factions)
# =============================================================================

const BLACK_HORIZON = {
	"name": "Black Horizon",
	"signature": ["💀", "🌸", "🕳", "🌠", "🪐", "🌀", "👁", "⚫", "🧿", "📡"],
	"bits": [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	"category": "Ultimate Cosmic Entities",
	"description": "A cosmic gravity-well of probability: gods of drift who bend outcomes toward dark attractors."
}

const REALITY_MIDWIVES = {
	"name": "Reality Midwives",
	"signature": ["🌟", "💫", "🥚", "📡", "🕳", "🌠", "🪐", "🌀", "👁", "⚫"],
	"bits": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	"category": "Ultimate Cosmic Entities",
	"description": "Cosmic facilitators of births and collapses, guiding worlds through thresholds of form."
}

const VOID_EMPERORS = {
	"name": "Void Emperors",
	"signature": ["⚫", "🕳", "🌠", "🪐", "🌀", "👁", "🧿", "📡", "🏰"],
	"bits": [1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1],
	"category": "Ultimate Cosmic Entities",
	"description": "The old rulers of absence, shaping whole eras by deciding what cannot exist."
}

# =============================================================================
# WORKING GUILDS (6 factions)
# =============================================================================

const GRAVEDIGGERS_UNION = {
	"name": "Gravedigger's Union",
	"signature": ["⚰", "🪦", "🌙", "⚙", "🔩", "🛠", "🏭", "📦"],
	"bits": [0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1],
	"category": "Working Guilds",
	"description": "Licensed corpse-handlers who regulate burial, salvage, and the economy of remains."
}

const MILLWRIGHTS_UNION = {
	"name": "Millwright's Union",
	"signature": ["⚙", "🏭", "🔩", "🛠", "📦", "🌽", "🧾", "🗝"],
	"bits": [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
	"category": "Working Guilds",
	"description": "The people who keep the grinding engines alive—and charge for every turn of the wheel."
}

const OBSIDIAN_WILL = {
	"name": "Obsidian Will",
	"signature": ["🏭", "⚙", "🔩", "🛠", "📦", "🧾", "🗝", "🧱"],
	"bits": [1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1],
	"category": "Working Guilds",
	"description": "A cold doctrine of obedience that hardens societies into unbreakable, brittle shapes."
}

const SEAMSTRESS_SYNDICATE = {
	"name": "Seamstress Syndicate",
	"signature": ["🪡", "👘", "📐", "📡", "🧵", "⚙", "🔩", "🕯"],
	"bits": [1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1],
	"category": "Working Guilds",
	"description": "Stitchers of garments and signals, weaving rumor, code, and cloth into quiet control."
}

const SYMPHONY_SMITHS = {
	"name": "Symphony Smiths",
	"signature": ["🎵", "🔨", "⚔", "📡", "⚙", "🔩", "🛠", "🏭"],
	"bits": [1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1],
	"category": "Working Guilds",
	"description": "Artisan sound-forgers who build resonant tools, weapons, and machines that sing under load."
}

const TINKER_TEAM = {
	"name": "Tinker Team",
	"signature": ["🛠", "🚐", "⚙", "🔩", "🏭", "📦", "🧾", "🗝"],
	"bits": [0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0],
	"category": "Working Guilds",
	"description": "Local fixers and improvisers; they keep broken tech working long past its intended death."
}

# =============================================================================
# NEGATIVE SPACE (12 factions)
# =============================================================================

const NS_SENTINEL_01 = {
	"name": "NS Sentinel 01",
	"signature": ["🪐", "🌠", "⚫", "🕳", "👁", "🌀", "🧿"],
	"bits": [0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0],
	"category": "Negative Space",
	"description": "Negative-space sentinel placeholder; name and lore TBD."
}

const NS_SENTINEL_02 = {
	"name": "NS Sentinel 02",
	"signature": ["🌠", "🪐", "⚫", "🕳", "🌀", "🧿", "💫"],
	"bits": [1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0],
	"category": "Negative Space",
	"description": "Negative-space sentinel placeholder; name and lore TBD."
}

const NS_SENTINEL_03 = {
	"name": "NS Sentinel 03",
	"signature": ["⚔", "🛡", "⛓", "🔥", "💀", "🪓", "🏰"],
	"bits": [1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 1, 0],
	"category": "Negative Space",
	"description": "Negative-space sentinel placeholder; name and lore TBD."
}

const NS_SENTINEL_04 = {
	"name": "NS Sentinel 04",
	"signature": ["🧾", "📦", "💰", "🗝", "⚖", "🏛", "🔒"],
	"bits": [0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0],
	"category": "Negative Space",
	"description": "Negative-space sentinel placeholder; name and lore TBD."
}

const NS_SENTINEL_05 = {
	"name": "NS Sentinel 05",
	"signature": ["⛪", "🧪", "🧿", "🔔", "🌙", "🌀", "👁"],
	"bits": [0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1],
	"category": "Negative Space",
	"description": "Negative-space sentinel placeholder; name and lore TBD."
}

const NS_SENTINEL_06 = {
	"name": "NS Sentinel 06",
	"signature": ["⚙", "🔩", "🛠", "📦", "🧾", "🗝", "🛡"],
	"bits": [1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0],
	"category": "Negative Space",
	"description": "Negative-space sentinel placeholder; name and lore TBD."
}

const NS_SENTINEL_07 = {
	"name": "NS Sentinel 07",
	"signature": ["🪐", "🌠", "🧿", "🌀", "📡", "⛓", "💀"],
	"bits": [0, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0],
	"category": "Negative Space",
	"description": "Negative-space sentinel placeholder; name and lore TBD."
}

const NS_SENTINEL_08 = {
	"name": "NS Sentinel 08",
	"signature": ["🧿", "🌀", "👤", "🧵", "🪡", "🔇", "🌙"],
	"bits": [0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1],
	"category": "Negative Space",
	"description": "Negative-space sentinel placeholder; name and lore TBD."
}

const NS_SENTINEL_09 = {
	"name": "NS Sentinel 09",
	"signature": ["⚔", "🔒", "🧱", "🏰", "⛓", "🪓", "💰"],
	"bits": [0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0],
	"category": "Negative Space",
	"description": "Negative-space sentinel placeholder; name and lore TBD."
}

const NS_SENTINEL_10 = {
	"name": "NS Sentinel 10",
	"signature": ["🪐", "🌠", "👁", "🌀", "🧿", "📡", "🧾"],
	"bits": [0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0],
	"category": "Negative Space",
	"description": "Negative-space sentinel placeholder; name and lore TBD."
}

const NS_SENTINEL_11 = {
	"name": "NS Sentinel 11",
	"signature": ["🧿", "🌀", "📡", "💫", "🌙", "⛪", "🔔"],
	"bits": [1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1],
	"category": "Negative Space",
	"description": "Negative-space sentinel placeholder; name and lore TBD."
}

const NS_SENTINEL_12 = {
	"name": "NS Sentinel 12",
	"signature": ["🛠", "⚙", "📦", "🧾", "🗝", "⚔", "🪓"],
	"bits": [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1],
	"category": "Negative Space",
	"description": "Negative-space sentinel placeholder; name and lore TBD."
}

# =============================================================================
# ALL FACTIONS ARRAY
# =============================================================================

const ALL_FACTIONS = [
	RESONANCE_DANCERS,
	CLAN_OF_THE_HIDDEN_ROOT,
	TERRARIUM_COLLECTIVE,
	VEILED_SISTERS,
	VOID_SERFS,
	CHORUS_OF_OBLIVION,
	CULT_OF_THE_DROWNED_STAR,
	FLESH_ARCHITECTS,
	LAUGHING_COURT,
	CARRION_THRONE,
	GRANARY_GUILDS,
	HOUSE_OF_THORNS,
	STATION_LORDS,
	IRRIGATION_JURY,
	GEARWRIGHT_CIRCLE,
	LEDGER_BAILIFFS,
	MEASURE_SCRIBES,
	QUARANTINE_SEALWRIGHTS,
	FENCEBREAKERS,
	SCYTHE_PROVOSTS,
	HEARTH_WITCHES,
	KNOT_SHRINERS,
	MOSSLINE_BROKERS,
	LANTERN_CANT,
	RELAY_LATTICE,
	SEEDVAULT_CURATORS,
	QUAY_ROOKS,
	SALT_RUNNERS,
	BONE_MERCHANTS,
	MEMORY_MERCHANTS,
	NEXUS_WARDENS,
	SYNDICATE_OF_GLASS,
	BROTHERHOOD_OF_ASH,
	CHILDREN_OF_THE_EMBER,
	IRON_SHEPHERDS,
	ORDER_OF_THE_CRIMSON_SCALE,
	IRON_CONFESSORS,
	KEEPERS_OF_SILENCE,
	SACRED_FLAME_KEEPERS,
	YEAST_PROPHETS,
	CARTOGRAPHERS,
	LOCUSTS,
	RUST_FLEET,
	BLACK_HORIZON,
	REALITY_MIDWIVES,
	VOID_EMPERORS,
	GRAVEDIGGERS_UNION,
	MILLWRIGHTS_UNION,
	OBSIDIAN_WILL,
	SEAMSTRESS_SYNDICATE,
	SYMPHONY_SMITHS,
	TINKER_TEAM,
	NS_SENTINEL_01,
	NS_SENTINEL_02,
	NS_SENTINEL_03,
	NS_SENTINEL_04,
	NS_SENTINEL_05,
	NS_SENTINEL_06,
	NS_SENTINEL_07,
	NS_SENTINEL_08,
	NS_SENTINEL_09,
	NS_SENTINEL_10,
	NS_SENTINEL_11,
	NS_SENTINEL_12,
]

# =============================================================================
# FACTIONS GROUPED BY CATEGORY
# =============================================================================

static var FACTIONS_BY_CATEGORY: Dictionary = {}

static func _build_category_dict() -> Dictionary:
	"""Build dictionary of factions grouped by category"""
	var result = {}
	for faction in ALL_FACTIONS:
		var category = faction.get("category", "Uncategorized")
		if not result.has(category):
			result[category] = []
		result[category].append(faction)
	return result

static func _static_init():
	"""Initialize static data on first load"""
	FACTIONS_BY_CATEGORY = _build_category_dict()

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

static func get_faction_by_name(name: String) -> Dictionary:
	"""Find faction by name (case-insensitive)"""
	var name_lower = name.to_lower()
	for faction in ALL_FACTIONS:
		if faction["name"].to_lower() == name_lower:
			return faction
	return {}

static func get_factions_by_category(category: String) -> Array:
	"""Get all factions in a category"""
	# Ensure category dict is built
	if FACTIONS_BY_CATEGORY.is_empty():
		FACTIONS_BY_CATEGORY = _build_category_dict()

	return FACTIONS_BY_CATEGORY.get(category, [])

static func get_signature_string(faction: Dictionary, max_emojis: int = 3) -> String:
	"""Convert signature array to string (first N emojis)"""
	var sig = faction.get("signature", [])
	return "".join(sig.slice(0, max_emojis))

static func get_random_faction() -> Dictionary:
	"""Get a random faction from the database"""
	if ALL_FACTIONS.is_empty():
		return {}
	return ALL_FACTIONS[randi() % ALL_FACTIONS.size()]

static func get_random_faction_from_category(category: String) -> Dictionary:
	"""Get a random faction from a specific category"""
	var factions = get_factions_by_category(category)
	if factions.is_empty():
		return {}
	return factions[randi() % factions.size()]

static func find_similar_factions(reference: Dictionary, min_matching_bits: int = 8) -> Array:
	"""Find factions with similar bit patterns

	Args:
		reference: Reference faction to compare against
		min_matching_bits: Minimum number of matching bits (default 8)

	Returns:
		Array of {faction: Dictionary, similarity: int} sorted by similarity
	"""
	var results = []
	var ref_bits = reference.get("bits", [])

	for faction in ALL_FACTIONS:
		# Skip self
		if faction.get("name", "") == reference.get("name", ""):
			continue

		# Count matching bits
		var faction_bits = faction.get("bits", [])
		var matching = 0
		for i in range(min(ref_bits.size(), faction_bits.size())):
			if ref_bits[i] == faction_bits[i]:
				matching += 1

		# Add if meets threshold
		if matching >= min_matching_bits:
			results.append({
				"faction": faction,
				"similarity": matching
			})

	# Sort by similarity (descending)
	results.sort_custom(func(a, b): return a.similarity > b.similarity)

	return results

# Initialize static data
static func get_category_dict() -> Dictionary:
	"""Get dictionary of factions grouped by category (lazy initialization)"""
	if FACTIONS_BY_CATEGORY.is_empty():
		FACTIONS_BY_CATEGORY = _build_category_dict()
	return FACTIONS_BY_CATEGORY


static func get_faction_vocabulary(faction: Dictionary) -> Dictionary:
	"""Compute complete vocabulary for a faction

	A faction's vocabulary consists of:
	1. Axial emojis (12 emojis from their bit pattern)
	2. Signature emojis (their unique thematic cluster)

	Returns:
		{
			"axial": ["📚", "🔮", "🌾", ...],      # From bits (12 emojis)
			"signature": ["⚙", "🏭", "🔩", ...],   # From signature array
			"all": ["📚", "🔮", "🌾", "⚙", ...]    # Union (no duplicates)
		}
	"""
	var vocab = {
		"axial": _get_axial_emojis(faction.get("bits", [])),
		"signature": faction.get("signature", []).duplicate(),
		"all": []
	}

	# Combine into "all" vocabulary (no duplicates)
	var all_set = {}
	for emoji in vocab.axial:
		all_set[emoji] = true
	for emoji in vocab.signature:
		all_set[emoji] = true

	vocab.all = all_set.keys()
	return vocab


static func _get_axial_emojis(bits: Array) -> Array:
	"""Extract emojis from AXES based on faction's bit values

	Each bit selects one emoji from its corresponding axis:
	- bit[0]=1 → AXES[0]["1"] = "📚" (Deterministic)
	- bit[1]=1 → AXES[1]["1"] = "🔮" (Mystical)
	- bit[2]=0 → AXES[2]["0"] = "🌾" (Common) ← WHEAT!
	- bit[3]=1 → AXES[3]["1"] = "🌌" (Cosmic)
	...

	Example:
		bits = [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1]
		→ ["📚", "🔮", "🌾", "🌌", "⚡", "💪", "💠", "🗡️", "🍽️", "⬜", "🍄", "🎯"]
	"""
	var result = []

	for i in range(min(bits.size(), AXES.size())):
		var axis = AXES[i]
		var bit_value = bits[i]

		# Get emoji for this bit value ("0" or "1")
		var emoji = axis.get(str(bit_value), "")
		if emoji != "":
			result.append(emoji)

	return result


static func get_vocabulary_overlap(faction_vocab: Array, player_vocab: Array) -> Array:
	"""Find intersection of faction and player vocabularies

	Returns emojis that appear in BOTH vocabularies.
	This is the set of emojis that can appear in quests for this faction.
	"""
	var overlap = []
	for emoji in faction_vocab:
		if emoji in player_vocab:
			overlap.append(emoji)
	return overlap


static func get_axial_emoji_factions(emoji: String) -> Array:
	"""Find all factions that have this emoji in their axial vocabulary

	Useful for showing which factions care about a newly discovered emoji.
	"""
	var matching_factions = []

	for faction in ALL_FACTIONS:
		var axial = _get_axial_emojis(faction.get("bits", []))
		if emoji in axial:
			matching_factions.append(faction)

	return matching_factions
