# Implementation Task List - 7-Day Roadmap

**Date**: 2025-12-13
**Project**: Quantum Farm: The Tomato Conspiracy
**Target**: Playable prototype in 7 days

## Overview

This roadmap prioritizes **playability over completeness**. Each day builds a working feature that can be tested. By day 7, the game should be playable end-to-end.

---

## DAY 1: Core Quantum Substrate (Foundation)

**Goal**: Create the 12-node tomato conspiracy network in pure GDScript

### Tasks

1. **Setup Godot 4.3+ Project Structure**
   - [ ] Create new Godot project in Linux: `QuantumFarm_Reboot/`
   - [ ] Copy `quantum_tomato_meta_state.json` to project
   - [ ] Create folder structure:
     ```
     Core/
       QuantumSubstrate/
       GameMechanics/
       Icons/
     UI/
     Assets/
     ```

2. **Implement TomatoNode Resource**
   - [ ] Create `TomatoNode.gd` (see `MIGRATION_GUIDE.md`)
   - [ ] Properties: theta, phi, q, p, energy, conspiracies
   - [ ] Methods: `get_bloch_vector()`, `evolve()`, `update_energy()`
   - [ ] Test: Create node, set state, verify energy calculation

3. **Implement TomatoConspiracyNetwork Manager**
   - [ ] Create `TomatoConspiracyNetwork.gd`
   - [ ] Load 12 nodes from `quantum_tomato_meta_state.json`
   - [ ] Create 15 entanglement connections
   - [ ] Method: `process_energy_diffusion(dt)`
   - [ ] Method: `evolve_all_nodes(dt)`
   - [ ] Test: Run 100 steps, verify energy conservation

4. **Visual Debugging Tool**
   - [ ] Create simple debug scene showing 12 nodes as circles
   - [ ] Display: node name, energy level (color-coded)
   - [ ] Display: entanglement lines between connected nodes
   - [ ] Update in real-time (call `_process()`)
   - [ ] Test: Run simulation, watch energy flow

### Success Criteria
- ✅ 12 tomato nodes loaded from JSON
- ✅ Energy diffuses through 15 connections
- ✅ Visual debugging shows network activity
- ✅ Energy is conserved (total doesn't drift)

**Estimated Time**: 6-8 hours

---

## DAY 2: Wheat Plot System (Tutorial Gameplay)

**Goal**: Implement simple wheat farming with entanglement

### Tasks

1. **Create WheatPlot Resource**
   - [ ] Create `WheatPlot.gd`
   - [ ] Dual-emoji qubit: north="🌾", south="👥"
   - [ ] Properties: theta, phi, growth_progress, berry_phase
   - [ ] Methods: `plant()`, `grow(dt)`, `harvest()`, `measure()`
   - [ ] Test: Plant, grow to 100%, harvest

2. **Create FarmGrid Manager**
   - [ ] Create `FarmGrid.gd`
   - [ ] Grid of plot positions (e.g., 5x5 = 25 plots)
   - [ ] Dictionary: plot_position -> WheatPlot
   - [ ] Method: `plant_wheat(pos)`, `get_plot(pos)`
   - [ ] Method: `create_entanglement(pos_a, pos_b)`
   - [ ] Test: Plant multiple plots, entangle, verify

3. **Wheat Growth Mechanics**
   - [ ] Base growth rate: 1% per second
   - [ ] Entanglement bonus: +20% per connection
   - [ ] Berry phase: +5% per replant cycle (stored in plot)
   - [ ] Observer penalty: -10% final yield if measured
   - [ ] Test: Compare growth rates with/without entanglement

4. **Simple Farm View Scene**
   - [ ] Create `FarmView.tscn`
   - [ ] Grid of plot sprites (empty → sprout → mature)
   - [ ] Click to plant wheat
   - [ ] Drag to create entanglement (draw line)
   - [ ] Click mature wheat to harvest
   - [ ] Test: Full plant-grow-harvest cycle

5. **Resource Economy**
   - [ ] Create `FarmEconomy.gd` singleton
   - [ ] Track: credits, wheat_inventory, wheat_price
   - [ ] Method: `purchase_seed(cost)`, `sell_wheat(amount)`
   - [ ] UI: Simple label showing credits
   - [ ] Test: Plant costs credits, harvest earns credits

### Success Criteria
- ✅ Can plant wheat in grid
- ✅ Wheat grows over time
- ✅ Entanglement increases growth rate
- ✅ Can harvest wheat for yield
- ✅ Economy tracks credits

**Estimated Time**: 8-10 hours

---

## DAY 3: Touch Interface & Polish

**Goal**: Make wheat farming feel good to play

### Tasks

1. **Touch Input System**
   - [ ] Implement tap detection (plant/harvest/measure)
   - [ ] Implement drag detection (create entanglement)
   - [ ] Implement hold detection (inspect plot details)
   - [ ] Visual feedback: touch ripple effect
   - [ ] Test on touchscreen (or simulate with mouse)

2. **Plot Inspector UI**
   - [ ] Create `PlotInspector.tscn` popup panel
   - [ ] Shows: quantum state (circle diagram), energy, growth %
   - [ ] Shows: entanglement connections (list)
   - [ ] Shows: berry phase count
   - [ ] Triggered by: hold gesture
   - [ ] Test: Hold plot, see detailed info

3. **Visual Effects**
   - [ ] Energy flow particles along entanglement lines
   - [ ] Growth animation (wheat gets taller smoothly)
   - [ ] Harvest animation (wheat disappears, numbers fly up)
   - [ ] Measurement flash (when observing)
   - [ ] Test: All animations feel smooth and responsive

4. **Audio Feedback**
   - [ ] Plant sound (soft plonk)
   - [ ] Growth sound (gentle rustle - ambient)
   - [ ] Harvest sound (satisfying chime)
   - [ ] Entanglement sound (whoosh)
   - [ ] Test: Audio enhances feel without being annoying

5. **Tutorial Messages**
   - [ ] Create `TutorialOverlay.tscn`
   - [ ] Simple text boxes with arrows
   - [ ] Sequence: "Tap to plant" → "Drag to entangle" → "Harvest when golden"
   - [ ] Dismissible (tap to continue)
   - [ ] Test: New player can follow tutorial

### Success Criteria
- ✅ Touch controls feel responsive
- ✅ Visual feedback makes actions clear
- ✅ Audio enhances experience
- ✅ Tutorial guides new players
- ✅ Wheat farming is fun!

**Estimated Time**: 6-8 hours

---

## DAY 4: Tomato Integration (Chaos Arrives)

**Goal**: Add tomato plots with conspiracy activations

### Tasks

1. **Create TomatoPlot Scene**
   - [ ] Create `TomatoPlot.gd` (wraps TomatoNode)
   - [ ] Assigned to one of 12 conspiracy nodes
   - [ ] Visual: Shows emoji transformation (e.g., 🌱→🍅)
   - [ ] Growth: Driven by conspiracy network energy
   - [ ] Test: Plant tomato, watch it grow (chaotically)

2. **Integrate Tomato Network with Farm**
   - [ ] TomatoConspiracyNetwork becomes singleton
   - [ ] Each TomatoPlot references a node in the network
   - [ ] Network evolves independently in `_process()`
   - [ ] Test: Plant multiple tomatoes, verify they're connected

3. **Conspiracy Activation System**
   - [ ] Create `ConspiracyManager.gd` singleton
   - [ ] Check energy thresholds every frame
   - [ ] Signal: `conspiracy_activated(name: String)`
   - [ ] Signal: `conspiracy_deactivated(name: String)`
   - [ ] Test: Manually set energy, verify activation

4. **Implement 3 Key Conspiracies**
   - [ ] **growth_acceleration** (seed node > 0.8)
     - Effect: Nearby wheat grows 2x faster
     - Visual: Green particle aura
   - [ ] **observer_effect** (observer node > 0.5)
     - Effect: Clicking any plot affects all tomatoes
     - Visual: Eyes appear on tomatoes
   - [ ] **tomato_hive_mind** (underground node > 1.2)
     - Effect: All tomatoes synchronize (pulsing)
     - Visual: Network lines connect all tomatoes
   - [ ] Test: Trigger each conspiracy, verify effects

5. **Contamination Mechanics**
   - [ ] When conspiracy active, can spread to nearby wheat
   - [ ] Wheat "infection": growth becomes chaotic
   - [ ] Visual: Wheat color shifts slightly (greenish tint)
   - [ ] Test: Tomato conspiracy contaminates wheat

### Success Criteria
- ✅ Can plant tomato plots
- ✅ Tomatoes grow based on conspiracy network
- ✅ 3 conspiracies activate and show effects
- ✅ Conspiracies can contaminate wheat
- ✅ Tomatoes feel "alive" and unpredictable

**Estimated Time**: 8-10 hours

---

## DAY 5: Carrion Throne & Quota System

**Goal**: Add game structure with objectives

### Tasks

1. **Create CarrionThrone Manager**
   - [ ] Create `CarrionThrone.gd` singleton
   - [ ] Stores: current level, quotas, reputation
   - [ ] Method: `send_quota()`, `check_quota_completion()`
   - [ ] Signal: `quota_received(wheat_qty, tomato_qty, time_limit)`
   - [ ] Signal: `quota_completed(success: bool)`
   - [ ] Test: Receive quota, fulfill it, get next

2. **Quota Progression System**
   - [ ] Level 1-3: Simple wheat quotas (e.g., "50 wheat")
   - [ ] Level 4-5: Timed quotas (e.g., "50 wheat in 120 seconds")
   - [ ] Level 6+: Mixed quotas (e.g., "30 wheat + 10 tomatoes")
   - [ ] Store quota data in JSON or script constant
   - [ ] Test: Progress through levels 1-6

3. **Quota UI**
   - [ ] Create `QuotaPanel.tscn`
   - [ ] Shows: current quota, progress, time remaining
   - [ ] Shows: next quota preview
   - [ ] Button: "Ship to Carrion Throne" (manual submission)
   - [ ] Auto-submit when quota met
   - [ ] Test: UI updates correctly during gameplay

4. **Narrative Messages**
   - [ ] Create `MessageOverlay.tscn` for Carrion Throne messages
   - [ ] Level 1: "Welcome, farmer. Plant wheat."
   - [ ] Level 5: "You show promise. Accept this... specimen."
   - [ ] Level 6: "Plant the tomato. This is not optional."
   - [ ] Level 10: "The conspiracies are spreading. Good."
   - [ ] Test: Messages appear at appropriate times

5. **Failure & Success States**
   - [ ] Quota failure: Lose reputation, get harder quota
   - [ ] Quota success: Gain credits, unlock features
   - [ ] Game over: Reputation reaches 0
   - [ ] Victory: Complete level 15
   - [ ] Test: Both failure and success paths

### Success Criteria
- ✅ Quota system drives gameplay
- ✅ Progression feels structured
- ✅ Narrative messages create atmosphere
- ✅ Success and failure have consequences
- ✅ Game has clear objectives

**Estimated Time**: 6-8 hours

---

## DAY 6: Icons & Advanced Mechanics

**Goal**: Implement Icons (Hamiltonians) and conspiracy discovery

### Tasks

1. **Create IconHamiltonian Base Class**
   - [ ] Create `IconHamiltonian.gd`
   - [ ] Properties: active, influence_radius, effect_strength
   - [ ] Method: `apply_effect(plot)` (override in subclasses)
   - [ ] Visual: Glow/aura effect
   - [ ] Test: Create base Icon, activate/deactivate

2. **Implement Biotic Flux Icon (Wheat)**
   - [ ] Create `BioticFluxIcon.gd` extends IconHamiltonian
   - [ ] Effect: Boosts growth rates in radius
   - [ ] Increases quantum coherence (reduces randomness)
   - [ ] Visual: Gentle green pulsing aura
   - [ ] Test: Activate near wheat, verify faster growth

3. **Implement Chaos Icon (Tomatoes)**
   - [ ] Create `ChaosIcon.gd` extends IconHamiltonian
   - [ ] Effect: Amplifies conspiracy activations
   - [ ] Increases decoherence (more chaos)
   - [ ] Visual: Swirling red vortex
   - [ ] Test: Activate near tomatoes, verify stronger effects

4. **Conspiracy Discovery System**
   - [ ] Create `ConspiracyCodex.gd` singleton
   - [ ] Track: discovered_conspiracies (list of names)
   - [ ] UI: Codex panel showing all discovered conspiracies
   - [ ] First activation: "UNKNOWN CONSPIRACY DETECTED"
   - [ ] After experimentation: Reveal name & description
   - [ ] Test: Discover all implemented conspiracies

5. **Add 3 More Conspiracies**
   - [ ] **fruit_vegetable_duality** (identity node)
     - Effect: Tomato can be harvested as fruit OR vegetable
     - UI: Choice dialog appears
   - [ ] **retroactive_ripening** (ripening node)
     - Effect: Past harvests change value
     - Visual: Storage numbers flicker
   - [ ] **ketchup_economy** (market node)
     - Effect: Tomato/wheat prices become linked
     - Visual: Price charts appear
   - [ ] Test: All 6 conspiracies work correctly

### Success Criteria
- ✅ Icons provide strategic choices
- ✅ Biotic Flux helps wheat
- ✅ Chaos Icon amplifies tomatoes
- ✅ Conspiracy discovery system works
- ✅ 6 total conspiracies implemented

**Estimated Time**: 8-10 hours

---

## DAY 7: Polish, Balance & Testing

**Goal**: Make the game playable, balanced, and fun

### Tasks

1. **Balance Pass**
   - [ ] Adjust wheat growth rates (should feel neither too slow nor instant)
   - [ ] Adjust tomato chaos (unpredictable but not frustrating)
   - [ ] Adjust quota difficulty (challenging but achievable)
   - [ ] Adjust economy (meaningful choices, not trivial)
   - [ ] Test: Play through levels 1-10, adjust numbers

2. **Tutorial Refinement**
   - [ ] Polish tutorial messages (clear, concise)
   - [ ] Add visual arrows/highlights for tutorial steps
   - [ ] Test with fresh player (or fresh save file)
   - [ ] Iterate based on confusion points
   - [ ] Test: Tutorial teaches all core mechanics

3. **Visual Polish**
   - [ ] Improve plot sprites (wheat stages, tomato stages)
   - [ ] Add background (farm landscape)
   - [ ] Polish UI panels (consistent style)
   - [ ] Particle effects for all major actions
   - [ ] Test: Game looks cohesive and appealing

4. **Audio Polish**
   - [ ] Add ambient farm sounds (birds, wind)
   - [ ] Tomato sounds (eerie, electronic)
   - [ ] Carrion Throne voice (distorted TTS or text only)
   - [ ] Music: Peaceful for wheat, ominous for tomatoes
   - [ ] Test: Audio enhances without overwhelming

5. **Bug Fixing & Edge Cases**
   - [ ] Test: Spam clicking doesn't break game
   - [ ] Test: Entanglement limit enforced (max 3 per plot)
   - [ ] Test: Can't plant without credits
   - [ ] Test: Conspiracy activation/deactivation is stable
   - [ ] Test: Game doesn't crash during quota transitions

6. **Build & Export**
   - [ ] Test: Build for Linux desktop
   - [ ] Test: Build for web (HTML5)
   - [ ] Test: Test on touchscreen device (if available)
   - [ ] Create simple README with controls
   - [ ] Test: Fresh playthrough on built version

### Success Criteria
- ✅ Game is balanced and fun to play
- ✅ Tutorial successfully teaches new players
- ✅ Visual and audio polish complete
- ✅ No major bugs
- ✅ Builds successfully for target platforms

**Estimated Time**: 8-10 hours

---

## Post-Day 7: Optional Enhancements

### Low Priority (Do Later)
- [ ] Add all 12 conspiracies (currently only 6)
- [ ] Add more levels (currently 15)
- [ ] Hardware integration (LEDs, servos - as per original prototype)
- [ ] Multiplayer/sharing (compare farms)
- [ ] More plot types (corn, carrots, etc.)
- [ ] Advanced quantum mechanics (full Gaussian CV evolution)
- [ ] Achievement system
- [ ] Leaderboards

### Future Work
- [ ] Mobile touchscreen optimization
- [ ] Steam release
- [ ] Educational mode (explicit quantum mechanics lessons)
- [ ] Mod support (custom conspiracies)

---

## Daily Checklist Template

```markdown
## Day X: [Goal]

**Start Time**: ___:___
**End Time**: ___:___
**Actual Time**: ___ hours

### Completed
- [x] Task 1
- [x] Task 2

### Blocked/Issues
- [ ] Issue 1: Description
  - Solution: ...

### Tomorrow's Priority
1. Item 1
2. Item 2

### Notes
- Any insights, learnings, or decisions made
```

---

## Risk Assessment

### High Risk
- **Quantum mechanics complexity**: Simplify ruthlessly, favor playability
- **Touch controls**: Test early and often on actual device
- **Conspiracy interactions**: Keep conspiracies independent to avoid cascade bugs

### Medium Risk
- **Performance**: 12-node simulation should be fine, but profile if slow
- **Balance**: Iterate based on playtesting, don't over-optimize early
- **Art assets**: Use placeholders (emojis) if custom art isn't ready

### Low Risk
- **GDScript migration**: Code examples provided, straightforward
- **Tutorial**: Copy successful patterns from other games
- **Economy**: Simple linear scaling works for prototype

---

## Success Metrics

### Must Have (MVP)
- ✅ 10 levels playable start to finish
- ✅ Wheat farming teaches basic quantum concepts
- ✅ Tomatoes introduce chaos/complexity
- ✅ 6 conspiracies work correctly
- ✅ Tutorial guides new players

### Nice to Have
- ✅ All 12 conspiracies implemented
- ✅ 15+ levels
- ✅ Hardware integration
- ✅ Polish and juice

### Future
- ⬜ Community sharing
- ⬜ Educational partnerships
- ⬜ Commercial release

---

## File Tracking

### Core Files to Create
```
Core/
  QuantumSubstrate/
    TomatoNode.gd ✓ Day 1
    TomatoConspiracyNetwork.gd ✓ Day 1
    ConspiracyManager.gd ✓ Day 4
    ConspiracyCodex.gd ✓ Day 6

  GameMechanics/
    WheatPlot.gd ✓ Day 2
    TomatoPlot.gd ✓ Day 4
    FarmGrid.gd ✓ Day 2
    FarmEconomy.gd ✓ Day 2

  Icons/
    IconHamiltonian.gd ✓ Day 6
    BioticFluxIcon.gd ✓ Day 6
    ChaosIcon.gd ✓ Day 6

  Authority/
    CarrionThrone.gd ✓ Day 5

UI/
  FarmView.tscn ✓ Day 2
  PlotInspector.tscn ✓ Day 3
  TutorialOverlay.tscn ✓ Day 3
  QuotaPanel.tscn ✓ Day 5
  MessageOverlay.tscn ✓ Day 5
  ConspiracyCodexPanel.tscn ✓ Day 6
```

---

## Summary

This 7-day roadmap builds a **playable quantum farming game** that teaches real quantum mechanics through engaging gameplay. Each day adds a complete, testable feature. By Day 7, you'll have a working prototype ready for playtesting and iteration.

**Key Philosophy**: Playability first, completeness second. It's better to have 6 great conspiracies than 24 broken ones.

Good luck! The quantum tomatoes are waiting. 🍅⚛️
