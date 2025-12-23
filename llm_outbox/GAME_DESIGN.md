# Game Design: Quantum Farm - The Tomato Conspiracy

**Date**: 2025-12-13
**Target Audience**: Bright 10-year-olds
**Platform**: Touchscreen (tablet/phone), desktop compatible
**Goal**: Teach real quantum mechanics through engaging gameplay

## Core Concept

**Peaceful wheat farming** meets **chaotic tomato conspiracies** in a quantum farming simulator where:
- Wheat plots teach basic quantum concepts (entanglement, superposition, measurement)
- Tomato plots introduce complexity and chaos through the 12-node conspiracy network
- Players ship produce to the "Carrion Throne" (mysterious authority demanding quotas)
- Gameplay naturally teaches quantum mechanics without explicit instruction

## Game Loop

```
TUTORIAL PHASE (Levels 1-5):
┌─────────────────────────────────────┐
│ 1. Plant wheat (🌾)                │
│ 2. Entangle plots (helps growth)    │
│ 3. Measure/observe (collapse state)  │
│ 4. Harvest when ripe                │
│ 5. Ship to Carrion Throne           │
│    → Earn credits                   │
│    → Unlock new features            │
└─────────────────────────────────────┘
                ↓
COMPLEXITY PHASE (Levels 6+):
┌─────────────────────────────────────┐
│ 1. Carrion Throne demands tomatoes │
│ 2. Plant tomatoes (🍅) - they act  │
│    weird (conspiracies activate)    │
│ 3. Tomatoes contaminate wheat       │
│ 4. Discover conspiracies through    │
│    experimentation                  │
│ 5. Learn to contain/harness chaos   │
│ 6. Master quantum farm ecosystem    │
└─────────────────────────────────────┘
```

## Wheat System (Tutorial - Peaceful Gameplay)

### Plot Structure
Each wheat plot is a **dual-emoji qubit**: 🌾👥 (Wheat/Labor)
- 🌾 state: Natural growth, slow but steady
- 👥 state: Labor-intensive, fast but drains resources
- Superposition: Plot is BOTH states simultaneously
- Measurement: Player clicks to observe, collapses to one state

### Basic Mechanics

**Planting** (Touch to plant)
- Cost: 5 credits per plot
- Action: Tap empty plot
- Effect: Wheat seed appears, enters growth cycle
- Visual: Small sprout animation

**Growth** (Automatic over time)
- Growth rate depends on:
  - Entanglement with neighbors (+20% per connection)
  - Berry phase accumulator (improves with repeated cycles at same plot)
  - Nearby conspiracies (can help or hinder)
- Visual: Wheat gradually grows taller, changes color (green → gold)
- Time: ~30-60 seconds to full maturity (scaled for fun, not realism)

**Entanglement** (Drag between plots)
- Action: Drag finger from one plot to another
- Effect: Creates quantum connection (glowing line)
- Benefit: Connected plots share growth energy
- Limit: Max 3 connections per plot (prevents overwhelming complexity)
- Visual: Animated energy particles flowing along connection

**Measurement/Observation** (Touch to observe)
- Action: Tap growing wheat
- Effect: Quantum state collapses, locks growth trajectory
- Benefit: Can check progress without harvesting
- Consequence: Reduces final yield slightly (observer effect)
- Visual: Wheat glows briefly, state indicator appears

**Harvesting** (Touch mature wheat)
- Action: Tap golden/ripe wheat
- Yield: 10-15 wheat units (random, quantum uncertainty)
- Credits: 2 credits per wheat unit
- Effect: Plot becomes empty, ready to replant
- Visual: Harvest animation, wheat units fly to storage

**Shipping** (Fulfill quotas)
- Requirement: Carrion Throne demands X wheat every Y seconds
- Action: Automatic when quota ready OR manual ship button
- Reward: Credits + reputation + unlock progress
- Failure: Reputation decreases, tougher quotas
- Visual: Wheat disappears in beam of light upward

### Wheat Icon (Hamiltonian)

**Biotic Flux Icon** 🌾✨
- Type: Peaceful growth Icon
- Effect: Amplifies growth rates in area of influence
- Encourages: Entanglement, cooperation, patience
- Visual: Gentle pulsing green aura around wheat plots
- Quantum: Increases coherence (reduces decoherence/noise)

### Tutorial Progression

**Level 1**: Plant & Harvest
- Plant 3 wheat
- Wait for growth
- Harvest when golden
- Ship to Carrion Throne

**Level 2**: Entanglement Discovery
- Plant 5 wheat
- Drag to create entanglement between 2 plots
- Observe faster growth
- Harvest and ship

**Level 3**: Observer Effect
- Plant wheat
- Click to observe during growth (shows state)
- Notice yield difference between observed vs unobserved
- Learn measurement affects outcome

**Level 4**: Berry Phase
- Replant same plots multiple times
- Notice growth improves with each cycle
- Introduce "plot memory" concept
- Harvest improved yields

**Level 5**: Icon Introduction
- Activate Biotic Flux Icon
- See area-wide growth boost
- Ship large quota
- Unlock tomato plots (ominous message from Carrion Throne)

## Tomato System (Complexity - Chaotic Gameplay)

### Tomato Structure
Each tomato plot contains a **12-node conspiracy network**
- Unlike wheat's simple qubit, tomatoes are complex entangled systems
- All 12 tomato plots share the same underlying conspiracy network
- Each plot "views" a different node of the network
- Actions on one tomato ripple through the entire system

### Plot Assignment
```
Plot 1 → seed node (🌱→🍅)
Plot 2 → observer node (👁️→📊)
Plot 3 → underground node (🕳️→🌐)
Plot 4 → genetic node (🧬→📝)
Plot 5 → ripening node (⏰→🔴)
Plot 6 → market node (💰→📈)
Plot 7 → sauce node (🍅→🍝)
Plot 8 → identity node (🤔→❓)
Plot 9 → solar node (☀️→⚡)
Plot 10 → water node (💧→🌊)
Plot 11 → meaning node (📖→💭)
Plot 12 → meta node (🔄→☯️)
```

### Tomato Mechanics

**Planting** (Mandatory from Carrion Throne)
- Cannot refuse tomato plots (plot twist: you MUST plant them)
- First tomato: Arrives at end of Level 5
- Message: "DIRECTIVE: Plant experimental crop 🍅. No refusals accepted."
- Cost: Free (suspicious...)
- Effect: Single tomato appears, conspiracy network initializes

**Growth** (Chaotic & unpredictable)
- Growth rate varies wildly based on conspiracy network energy flows
- Can grow backwards (ripening in reverse)
- Can spontaneously become overripe
- Visual: Erratic size changes, color shifting, weird effects

**Conspiracy Activation** (Emergent behavior)
Conspiracies activate when their node exceeds energy threshold:

1. **growth_acceleration** (seed node)
   - Effect: Nearby wheat grows 2x faster
   - Visual: Green sparkles
   - Good or Bad: Good for wheat, but unpredictable

2. **observer_effect** (observer node)
   - Effect: Clicking ANY plot affects ALL tomatoes
   - Visual: Eyes appear on tomatoes
   - Good or Bad: Makes measurement risky

3. **mycelial_internet** (underground node)
   - Effect: All tomato plots communicate instantly
   - Visual: Underground network lines
   - Good or Bad: Tomatoes act as one organism

4. **tomato_hive_mind** (underground node)
   - Effect: Tomatoes develop collective intelligence, start "requesting" things
   - Visual: Synchronized pulsing
   - Good or Bad: Creepy but efficient

5. **fruit_vegetable_duality** (identity node)
   - Effect: Can harvest as fruit OR vegetable (different values)
   - Visual: Tomato flickers red/green
   - Good or Bad: Player choice, optimization puzzle

6. **retroactive_ripening** (ripening node)
   - Effect: Past harvests can change quality retroactively
   - Visual: Storage flickers, numbers change
   - Good or Bad: Mind-bending, teaches quantum causality

7. **ketchup_economy** (market node)
   - Effect: Tomato value becomes linked to wheat value
   - Visual: Price charts appear
   - Good or Bad: Economic complexity

8. **tomato_simulating_tomatoes** (meta node)
   - Effect: Tomatoes create simulated copies of themselves
   - Visual: Fractal tomatoes appear
   - Good or Bad: Resource multiplication OR system crash

**Contamination** (Tomatoes affect wheat)
- Active tomato conspiracies spread to nearby wheat plots
- Wheat can become "infected" with chaotic behavior
- Player must manage contamination through:
  - Spacing (keep wheat away from tomatoes)
  - Entanglement blocking (strategic connections)
  - Rapid harvesting (before infection spreads)

**Discovery System** (Learn conspiracies)
- First activation: "UNKNOWN CONSPIRACY DETECTED"
- Player experiments to figure out what it does
- Once understood: Labeled and added to conspiracy codex
- Reward: Credits + knowledge + ability to predict

**Harvesting Tomatoes**
- Yield: Highly variable (quantum uncertainty × conspiracy chaos)
- Quality: Depends on active conspiracies
- Credits: 5-25 per tomato (way more valuable than wheat, but risky)
- Side effects: Conspiracy activations can affect other plots

### Tomato Conspiracy Icon (Hamiltonian)

**Chaos Icon** 🍅🌀
- Type: Chaotic manipulation Icon
- Effect: Amplifies conspiracy activations
- Risk/Reward: Higher yields but more unpredictable
- Visual: Swirling red vortex around tomatoes
- Quantum: Increases decoherence (more noise, more chaos)

Contrast with Biotic Flux:
- Biotic Flux = Order, growth, predictability (wheat)
- Chaos Icon = Disorder, transformation, unpredictability (tomatoes)

## Touch Interface Design

### Primary Gestures

**Tap** - Context sensitive
- Empty plot: Select plot type (wheat/tomato menu appears)
- Growing crop: Observe/measure (shows state, slight yield penalty)
- Ripe crop: Harvest (collect yield)
- Icon: Activate/deactivate Icon effect

**Drag** - Create entanglement
- Start: Touch one plot
- Move: Drag to another plot
- Release: Create entanglement connection (if allowed)
- Visual: Line follows finger, snaps into place

**Hold** - Inspect details
- Press and hold: Detailed plot info panel appears
- Shows:
  - Quantum state (θ, φ angles visualized as position on circle)
  - Energy level (bar graph)
  - Active conspiracies (list with icons)
  - Entanglement connections (highlighted)
  - Growth progress (percentage)
  - Expected yield (with uncertainty range)

**Pinch Zoom** - Navigate farm
- Pinch in: Zoom out (see more plots)
- Pinch out: Zoom in (see detail)
- Smooth zoom animation

**Swipe** - Pan camera
- Swipe: Move view across farm
- Inertia: Continues movement when released
- Boundaries: Stops at farm edges

### Visual Feedback

**Energy Flows**
- Animated particles along entanglement lines
- Direction: Flows from high energy → low energy
- Speed: Faster = more energy transfer
- Color: Green (positive) or red (negative)

**Conspiracy Activation**
- Pulsing aura around affected plots
- Conspiracy-specific colors and icons
- Sound: Subtle "activation" chime
- Particle effects for dramatic activations

**Growth Progress**
- Size: Plant gets larger as it grows
- Color: Shifts from green (young) to gold (ripe)
- Animation: Gentle swaying in wind
- Glow: Mature crops glow softly

**Quantum State Visualization**
- Circle diagram showing θ, φ position
- Dot on circle = current state
- Trail = recent history
- Uncertainty cloud = possible states

## Carrion Throne (Authority Figure)

### Character Design
- Never seen directly (voice/text only)
- Mysterious authority that demands produce
- Gradually revealed to be quantum-aware (knows about conspiracies)
- Ambiguous: Are they helping or exploiting the player?

### Quota System
**Escalating Demands**:
- Level 1-3: Simple wheat quotas (e.g., "Deliver 50 wheat")
- Level 4-5: Timed quotas (e.g., "50 wheat in 2 minutes")
- Level 6+: Mixed quotas (e.g., "30 wheat + 10 tomatoes")
- Level 8+: Conspiracy-specific quotas (e.g., "Activate fruit_vegetable_duality 3 times")

**Narrative Hooks**:
- "Your wheat shows interesting quantum properties..."
- "We require experimental crop 🍅 for research purposes."
- "The conspiracies are spreading. This is expected."
- "You're doing well. Perhaps TOO well..."
- "Welcome to the inner circle of quantum agriculture."

## Tutorial Sequence

### PHASE 1: Wheat Basics (5-10 minutes)

**Tutorial 1**: "First Harvest"
- Plant wheat in 3 marked plots
- Wait for growth (sped up for tutorial)
- Harvest when glowing
- Ship to Carrion Throne
- Reward: 50 credits

**Tutorial 2**: "Entanglement Discovery"
- Plant 5 wheat
- Game highlights two plots
- "Try connecting them" (arrow shows drag)
- Observe faster growth
- Harvest and ship
- Reward: Unlock entanglement everywhere

**Tutorial 3**: "The Observer Effect"
- Plant wheat
- Instructions: "Click during growth to check progress"
- Do this for one plot, not another
- Compare yields at harvest
- Explanation: "Observation changes outcome"
- Reward: Understanding quantum measurement

**Tutorial 4**: "Berry Phase Memory"
- "Replant the same plot 3 times"
- Notice increasing growth rate
- Explanation: "Plots remember their history"
- Reward: Unlock plot stat tracking

**Tutorial 5**: "The Biotic Flux Icon"
- Activate Icon
- See area-wide growth boost
- Massive quota fulfilled easily
- Carrion Throne message: "Impressive. Ready for Phase 2?"
- Ominous: "We have special crops for you..."

### PHASE 2: Tomato Introduction (10-15 minutes)

**Tutorial 6**: "Experimental Crop"
- DIRECTIVE appears: "Plant specimen 🍅"
- Cannot refuse (no cancel button)
- First tomato plot appears
- Grows normally at first...
- Then starts acting weird
- Message: "Interesting anomalies detected."

**Tutorial 7**: "First Conspiracy"
- Tomato energy builds up
- growth_acceleration activates
- Nearby wheat grows super fast
- "UNKNOWN CONSPIRACY DETECTED"
- Player experiments to understand
- Reward: First conspiracy logged in codex

**Tutorial 8**: "The Network Reveals Itself"
- Plant 3 more tomatoes
- They synchronize (hive_mind activation)
- Visual: Network lines appear underground
- Explanation: "They're connected"
- Carrion Throne: "Yes, they are aware."

**Tutorial 9**: "Containment Strategy"
- Wheat starts getting contaminated
- Instructions: "Keep wheat away from tomatoes"
- Learn spacing strategy
- Reward: Unlock more plot space

**Tutorial 10**: "Embrace the Chaos"
- Activate Chaos Icon
- Multiple conspiracies activate at once
- Dramatic effects, high yields
- Risk: Could cause cascade failure
- Carrion Throne: "You're ready for the truth..."

### PHASE 3: Mastery (Ongoing)

- All 12 tomato plots unlocked
- Complex quota combinations
- Conspiracy interaction optimization
- Discover all 24 conspiracies
- Endgame: Understand the full conspiracy network
- Revelation: Player is also part of the experiment

## Progression & Unlocks

### Unlock Path
```
Level 1: 3 wheat plots
Level 2: Entanglement ability
Level 3: 6 wheat plots
Level 4: Plot inspection mode
Level 5: Biotic Flux Icon, 10 wheat plots
Level 6: 1 tomato plot (forced)
Level 7: Conspiracy codex
Level 8: 3 tomato plots
Level 9: Chaos Icon
Level 10: 6 tomato plots
Level 12: 12 tomato plots (full conspiracy network)
Level 15: Endgame revelation
```

### Conspiracy Codex (Unlockable Encyclopedia)
Each discovered conspiracy gets an entry:
- Name
- Triggering node
- Effect description
- Strategic uses
- Quantum mechanics explanation (age-appropriate)
- Completion: Collectible achievement

## Quantum Mechanics Teaching

### Learning Objectives (Hidden in Gameplay)

**Superposition**:
- Wheat is 🌾 AND 👥 simultaneously
- Tomato is fruit AND vegetable simultaneously
- Kids learn: Quantum systems exist in multiple states

**Measurement/Collapse**:
- Clicking wheat forces it to choose a state
- Affects yield (observer effect)
- Kids learn: Observation changes reality

**Entanglement**:
- Connected plots help each other grow
- Tomato network acts as one system
- Kids learn: Quantum systems can be non-locally connected

**Uncertainty**:
- Harvest yield varies (10-15 wheat)
- Tomato growth is unpredictable
- Kids learn: Quantum outcomes are probabilistic

**Decoherence**:
- Conspiracies add "noise" to system
- Chaos Icon increases randomness
- Kids learn: Environment disrupts quantum states

**Berry Phase**:
- Replanting same plot improves growth
- System "remembers" previous cycles
- Kids learn: Geometric phase accumulation

**Interference**:
- Entangled plots interfere (constructive/destructive)
- Energy flows create patterns
- Kids learn: Quantum waves interfere

## Game Balance

### Economy
- Wheat: Low risk, low reward (2 credits/unit)
- Tomatoes: High risk, high reward (10-25 credits/unit)
- Quotas: Escalate to require both
- Credits: Used to unlock plots, abilities, cosmetics

### Difficulty Curve
- Levels 1-5: Learning curve (forgiving)
- Levels 6-10: Challenge ramps (require strategy)
- Levels 11+: Mastery required (optimization puzzles)

### Time Investment
- Quick session: 5-10 minutes (fulfill quota, exit)
- Medium session: 20-30 minutes (multiple levels)
- Long session: 1+ hours (conspiracy experimentation)

## Art Style

**Visual Theme**: Retro-futuristic quantum farm
- Color palette: Vibrant greens/golds (wheat), reds/purples (tomatoes)
- Style: Stylized but readable
- Emojis: Large, clear, animated
- Effects: Particle systems, glows, trails
- UI: Clean, minimalist, touchscreen-optimized

**Mood**:
- Wheat areas: Peaceful, pastoral, safe
- Tomato areas: Mysterious, energetic, slightly ominous
- Overall: Curious, educational, slightly surreal

## Audio Design

**Wheat Sounds**:
- Gentle rustling
- Soft growth chimes
- Satisfying harvest "plonk"
- Calming ambient farm sounds

**Tomato Sounds**:
- Pulsing electronic tones
- Conspiracy activation "whooshes"
- Glitchy, distorted effects
- Ominous background hum

**Carrion Throne**:
- Distorted voice (text-to-speech with effects)
- Message alert tones
- Authority/command feel

## Accessibility

- Touch targets: Large (min 44px for kids)
- Text: Large, readable fonts
- Color blind modes: Shape/pattern indicators
- Speed: Adjustable time scale
- Help: Always available
- Undo: Allow replanting without penalty in tutorial

## Victory Condition

**Multiple Endings**:
1. **Obedient Farmer**: Fulfill all quotas perfectly
   - Carrion Throne thanks you, reveals true purpose
   - "You've proven the quantum farm concept works"

2. **Chaos Master**: Activate all conspiracies
   - Carrion Throne: "You've achieved quantum mastery"
   - "The experiment is complete. You are ready."

3. **Rebel**: Refuse tomato quotas (let them expire)
   - Carrion Throne: "Disappointing but... intriguing"
   - "You've chosen your own path. Unexpected."

All endings: Unlock free play mode with all mechanics

## Next Steps

See `TASK_LIST.md` for 7-day implementation roadmap.
See `MIGRATION_GUIDE.md` for technical implementation details.
