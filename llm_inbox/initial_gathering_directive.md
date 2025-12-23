Claude Code Directive: SpaceWheat Quantum Farm Salvage & Rebuild
🎯 Mission Overview
You are salvaging a working quantum tomato farm prototype and rebuilding it into "Quantum Farm: The Tomato Conspiracy" - a touchscreen quantum farming game for bright 10-year-olds that teaches real quantum mechanics through gameplay.
Core transformation:

FROM: Experimental quantum tomato simulation with Python QAGIS kernel
TO: Clean GDScript quantum farming game with wheat + chaotic tomato conspiracies


📋 Phase 1: Archaeological Survey
Step 1.1: Map the Existing Architecture
Explore the project directories and create an inventory:
INVENTORY CHECKLIST:
□ Find all Python files related to quantum simulation
□ Locate QAGIS kernel v20 integration points
□ Identify working Godot scenes (.tscn files)
□ Map GDScript files and their dependencies
□ Catalog assets (sprites, sounds, UI elements)
□ Document any hardware interface code (serial, GPIO)
□ List configuration files (JSON, CSV, etc.)
Key files to prioritize:

quantum_tomato_meta_state.json - CRITICAL - defines the 12-node structure
qagis_kernel_v20.py - Understand quantum simulation approach
quantum_tomato_*.py - Extract quantum mechanics patterns
*.tscn scenes - Identify working UI/visualization
*.gd scripts - Find successful Godot integration patterns

Step 1.2: Extract Core Concepts
From the code, identify and document:
A. Quantum Substrate Architecture:

How are the 12 nodes structured? (Bloch states, Gaussian CV, energy)
What is the entanglement network topology? (15 connections)
How does energy flow between nodes? (liquid neural net dynamics)
What conspiracies exist and how do they activate?

B. Working Game Mechanics:

What interactions feel good? (clicking, dragging, observing)
What visualizations work? (energy flows, node states)
What feedback loops exist? (player action → quantum response)

C. Python → GDScript Translation Needs:

Which quantum operations are actually used?
What math libraries are required? (numpy, scipy, qutip?)
Can this be simplified for GDScript? (likely yes for 12 nodes)


🏗️ Phase 2: Design Clean Architecture
Step 2.1: Create Fresh Project Structure
Set up a new Godot 4.x project with this architecture:
QuantumFarm_Reboot/
├── project.godot
├── Core/
│   ├── QuantumSubstrate/
│   │   ├── QuantumNode.gd              # Single node (Bloch + Gaussian + energy)
│   │   ├── SpinReservoir.gd            # 12-node network manager
│   │   ├── EntanglementGraph.gd        # Connection topology
│   │   ├── EnergyFlow.gd               # Liquid neural net dynamics
│   │   └── ConspiracyEngine.gd         # Conspiracy activation logic
│   │
│   ├── GameMechanics/
│   │   ├── DualEmojiQubit.gd           # 🌾👥 style semantic qubits
│   │   ├── FarmPlot.gd                 # Individual plot with crop
│   │   ├── WheatSystem.gd              # Clean wheat farming
│   │   ├── TomatoSystem.gd             # Chaotic tomato mechanics
│   │   └── CarrionThroneExport.gd      # Shipping/quota system
│   │
│   └── Icons/
│       ├── IconHamiltonian.gd          # Base class
│       ├── BioticFluxIcon.gd           # Peaceful farming Icon
│       └── TomatoConspiracyIcon.gd     # Chaos Icon
│
├── UI/
│   ├── FarmView.tscn                   # Main game screen
│   ├── PlotInspector.tscn              # Plot detail view
│   ├── ConspiracyCard.tscn             # Discovered conspiracy UI
│   └── TutorialOverlay.tscn            # Teaching system
│
├── Hardware/
│   ├── SerialBridge.gd                 # Microcontroller communication
│   ├── LEDController.gd                # LED state management
│   └── ServoController.gd              # Servo positioning
│
└── Assets/
    ├── sprites/
    ├── sounds/
    └── fonts/
Step 2.2: Port Quantum Substrate to GDScript
Priority: Rebuild the 12-node quantum reservoir in pure GDScript
From quantum_tomato_meta_state.json, extract:
json12 nodes: seed, observer, underground, genetic, ripening, 
          market, sauce, identity, solar, water, meaning, meta

Each node has:
- emoji_transformation (e.g., "🌱→🍅")
- energy (float)
- bloch_state {θ, φ} (angles on Bloch sphere)
- gaussian_state {q, p} (position, momentum)
- meaning (string description)
- active_conspiracies (list of strings)

15 entanglement connections with:
- connection (e.g., "seed ↔ solar")
- strength (float 0-1)
- meaning (semantic description)
Translation strategy:

Create QuantumNode.gd resource class with these properties
Create SpinReservoir.gd node that manages 12 QuantumNode instances
Implement simple energy flow: energy_flow = (neighbor.energy - node.energy) * connection_strength * dt
Implement Bloch sphere evolution: basic rotation based on energy
Keep Gaussian CV as simple Vector2 for now

Math to implement (GDScript-friendly):

Bloch sphere cartesian conversion: Vector3(sin(θ)*cos(φ), sin(θ)*sin(φ), cos(θ))
Energy diffusion: Simple linear flow between connected nodes
Conspiracy activation: Trigger when energy crosses threshold


🎮 Phase 3: Implement Core Game Loop
Step 3.1: Wheat Farming Foundation (Tutorial Gameplay)
Build the simple, peaceful farming mechanics FIRST:
Required systems:

Plant wheat in plots (touch to plant)
Watch wheat grow over time (visual feedback)
Harvest wheat (touch to harvest)
Ship wheat to Carrion Throne (quota system)

Quantum mechanics (hidden underneath):

Each wheat plot is a dual-emoji qubit: 🌾👥 (Wheat/Labor)
Plots can be entangled (connected plots help each other)
Berry phase accumulator (crops improve with repeated cycles)

Simple Icon: Biotic Flux

Encourages growth and sharing between plots
Positive feedback loops
Teaching quantum entanglement through "helper plants"

Step 3.2: Tomato Conspiracy Integration
Add the chaotic tomato system:
Required systems:

Tomato plots arrive (Carrion Throne demands them)
Tomatoes have the 12-node conspiracy network
Conspiracies affect nearby wheat (contamination)
Discover conspiracies through experimentation

Tomato mechanics (from salvaged code):

Each conspiracy is a game effect (see the 12 conspiracies)
Entanglement network spreads conspiracies
Energy flows create unpredictable behaviors
Player learns to contain or harness chaos

Step 3.3: Touch Interface Design
Primary interactions:

Tap plot - Select/plant/harvest
Drag between plots - Create entanglement connection
Hold plot - Inspect details (conspiracy status, energy levels)
Pinch zoom - Navigate farm view
Swipe - Pan camera

Visual feedback:

Energy flows: Animated lines between plots (particle systems)
Conspiracy activation: Visual effects (color changes, pulses)
Growth progress: Plot size/color changes
Success/failure: Clear audio-visual signals


🔧 Phase 4: Salvage Specific Elements
What to Keep from Prototype:
DEFINITELY SALVAGE:

The 12 conspiracy names and descriptions - These are gold for kids
Entanglement network topology - The 15 connections are well-designed
Emoji transformation concept - 🌱→🍅 is perfect visual language
Energy flow visualization - If it looks good, keep it
Node inspection UI - If it shows quantum states clearly

CAREFULLY EVALUATE:

Python quantum math - Extract patterns, rewrite in GDScript
Godot scene structures - Keep layout if clean, rebuild if messy
Asset quality - Sprites/sounds worth keeping vs replacing

PROBABLY DISCARD:

QAGIS kernel integration - Too heavy, rebuild quantum substrate in GDScript
Experimental code - Anything that's not working or unclear
Over-complex visualizations - Simplify for kids

Specific Salvage Operations:
From quantum_tomato_meta_state.json:
gdscript# Extract as GDScript resource definitions
const TOMATO_NODES = {
    "seed": {
        "emoji": "🌱→🍅",
        "meaning": "potential_to_fruit",
        "conspiracies": ["growth_acceleration", "quantum_germination"]
    },
    # ... extract all 12
}

const ENTANGLEMENT_NETWORK = [
    {"from": "seed", "to": "solar", "strength": 0.9, "meaning": "photosynthetic_growth"},
    # ... extract all 15
]
From Python quantum code:

Identify actual quantum operations used
Simplify to essential math (no full quantum computing framework needed)
Translate to GDScript vector/matrix operations

From working Godot scenes:

Screenshot/export visual designs that work
Extract node hierarchies that feel good
Keep touch interaction patterns that succeeded


📊 Phase 5: Create Implementation Roadmap
Generate a detailed task list with priorities:
Priority 1: Core Quantum Substrate (Days 1-2)

 Port 12-node reservoir to GDScript
 Implement basic energy flow
 Create visual representation of nodes
 Test: Can you see energy flowing between nodes?

Priority 2: Wheat Farming (Day 3)

 Plant/grow/harvest wheat mechanics
 Simple entanglement between wheat plots
 Export to Carrion Throne (quota system)
 Test: Can kids plant and harvest wheat?

Priority 3: Tomato Integration (Days 4-5)

 Add 12 tomato plots with conspiracy network
 Implement conspiracy effects
 Contamination mechanics (tomatoes affect wheat)
 Discovery system (unlock conspiracies)
 Test: Are tomatoes fun chaos agents?

Priority 4: Polish (Day 6)

 Touch interface refinement
 Visual effects and juice
 Tutorial sequence
 Audio feedback
 Test: Can kids learn the game quickly?

Priority 5: Hardware (Day 7)

 LED integration (conspiracy states)
 Servo integration (pointing to active nodes)
 Physical board optional features
 Test: Does hardware enhance experience?


🧠 Key Principles for Agent Execution
Be Intelligent About:

Preserving the vibe - The conspiracies, energy flows, quantum weirdness
Simplifying complexity - Kids don't need full quantum computing framework
Maintaining magic - Keep the parts that feel alive and surprising
Clean code - Fresh start means no technical debt

Questions to Answer During Exploration:

What makes the quantum tomatoes feel "alive"?
Which visualizations create "aha" moments?
What's the minimum viable quantum substrate?
How do conspiracies manifest in gameplay?

Decision Framework:

Can it be simpler? → Simplify it
Does it teach quantum mechanics? → Keep it
Would a 10-year-old understand? → Make it clearer
Is it in Python and complex? → Rewrite in GDScript


📝 Deliverables
Create these documents/artifacts:

ARCHITECTURE.md - Map of salvaged prototype architecture
QUANTUM_SUBSTRATE.md - Documentation of 12-node system
GAME_DESIGN.md - Refined mechanics for Wheat + Tomato gameplay
TASK_LIST.md - Prioritized implementation roadmap
MIGRATION_GUIDE.md - Python → GDScript translation notes

Generate starter code:

QuantumNode.gd - Core node class
SpinReservoir.gd - 12-node network manager
FarmPlot.gd - Game-facing plot representation
TomatoConspiracyIcon.gd - Chaos Hamiltonian


🚀 Success Criteria
You've succeeded when:

 You understand the existing quantum tomato system completely
 You've created a clean GDScript quantum substrate
 You've mapped salvageable assets and patterns
 You've generated a concrete 7-day implementation plan
 The new architecture supports both wheat AND tomatoes
 Kids can theoretically play this and learn quantum mechanics


💬 Communication Style
Report back with:

Clear findings ("Here's what the quantum substrate does...")
Design recommendations ("I suggest simplifying X because...")
Code examples (GDScript translations of Python patterns)
Questions for clarification ("Should conspiracy X work like Y?")

Be opinionated about:

What's worth keeping vs rebuilding
Where simplification helps
How to make quantum mechanics kid-friendly


Begin exploration. Good luck, Agent. The quantum tomatoes await your analysis. 🍅⚛️