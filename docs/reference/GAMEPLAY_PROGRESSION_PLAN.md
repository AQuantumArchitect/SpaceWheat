# From Tests to Gameplay - Progression Plan

**Goal**: Move from direct GDScript tests to interactive gameplay with keyboard input

**Current State**: All farm machinery works in tests but not in actual game
**Target**: Full playable game with keyboard control

---

## Phase 1: Signal Cleanup & Validation

### What's Happening
- Signals are defined but not systematically tested
- Some signals may not be firing or connected
- Signal chain: Action → FarmGrid → Biome → FarmEconomy → UI (not implemented)

### Work to Do
1. **Create `test_signal_system.gd`**
   - Test each signal from GameController fires correctly
   - Test signal propagation through FarmGrid → Biome → FarmEconomy
   - Verify signal parameters match expected data
   - Create signal spy/mock to capture all emissions

2. **Create `test_farm_economy_signals.gd`**
   - Test FarmEconomy signals (wheat_changed, flour_changed, credits_changed)
   - Verify inventory updates trigger signals
   - Test multi-resource transactions (wheat→flour→credits)

3. **Create `test_biome_signal_propagation.gd`**
   - Test BiomeBase signals (qubit_created, bell_gate_created, qubit_measured)
   - Verify kitchen measurement cascades signals
   - Test entanglement signal chain

### Success Criteria
- All farm action signals firing correctly
- All economy signals firing with correct values
- All biome signals firing during quantum operations
- Signal names standardized and documented

---

## Phase 2: Farm Machinery Test Suite (High-Level Instructions)

### What's Happening
- Move from direct FarmGrid method calls to GameController actions
- GameController is the "instruction executor"
- Test that GameController → FarmGrid → Biome → Signals all work together

### Work to Do
1. **Create `test_farm_machinery.gd`**
   - Instead of `grid.plant_wheat(pos)` directly
   - Call `game_controller.build(pos, "wheat")`
   - Verify all signals fired in correct order
   - Test error cases (not enough credits, plot occupied, etc.)

2. **Test All Farm Actions via GameController**
   ```gdscript
   # Plant all crop types
   - game_controller.build(pos, "wheat")
   - game_controller.build(pos, "tomato")
   - game_controller.build(pos, "mushroom")

   # Quantum operations
   - game_controller.measure_plot(pos)
   - game_controller.harvest_plot(pos)
   - game_controller.entangle_plots(pos1, pos2)

   # Economy
   - game_controller.place_mill(pos)
   - game_controller.place_market(pos)
   - game_controller.sell_all_wheat()

   # Complex sequences
   - Plant → Entangle → Measure → Harvest
   - Plant → Grow 3 days → Harvest → Process → Sell
   ```

3. **Create Signal Spy System**
   ```gdscript
   var signal_log = []

   # Connect spy to all signals
   game_controller.action_feedback.connect(func(msg, success):
       signal_log.append({"type": "action_feedback", "msg": msg, "success": success})
   )

   # After action, verify signal_log contains expected events
   assert(signal_log[0]["type"] == "action_feedback")
   assert(signal_log[1]["type"] == "plot_planted")
   assert(signal_log[2]["type"] == "entanglement_created")
   ```

4. **Test Multi-Step Workflows**
   - Plant 3 wheat → verify all planted signals
   - Entangle first two → verify bell_gate_created signal
   - Measure one → verify cascade (both measured signals)
   - Harvest all → verify harvest yield signals
   - Process wheat → verify flour_inventory_changed signal
   - Sell flour → verify credits_changed signal

### Success Criteria
- All GameController actions testable via `game_controller.action(params)`
- All signal emissions captured and verified
- Complex workflows pass (plant → entangle → measure → harvest → process → sell)
- Error handling correct (insufficient resources, invalid state, etc.)

---

## Phase 3: Signal Spoofing (Simulating Game Events)

### What's Happening
- Create test scenarios by directly emitting signals
- Simulate game events without necessarily triggering full machinery
- Test UI responsiveness to signals alone

### Work to Do
1. **Create `test_signal_spoofing.gd`**
   - Emit signals directly without calling action methods
   - Verify UI responds correctly to signal alone
   - Test signal chain: Spoof FarmEconomy.wheat_changed → verify UI updates

2. **Signal Spoof Examples**
   ```gdscript
   # Spoof: Wheat inventory changed
   economy.wheat_changed.emit(10)

   # Spoof: Plot planted
   farm_grid.plot_planted.emit(Vector2i(0, 0))

   # Spoof: Entanglement created
   farm_grid.entanglement_created.emit(Vector2i(0, 0), Vector2i(1, 0))

   # Spoof: Measurement cascade
   biome.qubit_measured.emit(Vector2i(0, 0), "state_1")
   ```

3. **Test Signal → UI Response**
   - Emit `plot_planted` signal → verify PlotGridDisplay updates
   - Emit `wheat_changed` signal → verify inventory display updates
   - Emit `entanglement_created` signal → verify lines drawn between plots
   - Emit `qubit_measured` signal → verify plot visual changes

### Success Criteria
- UI responds to signals without actual game action
- Signals alone can drive entire gameplay display
- Signal spoofing test suite validates signal → UI pipeline

---

## Phase 4: Keyboard Input Wiring

### What's Happening
- Connect FarmInputHandler (keyboard input) → GameController (actions)
- FarmInputHandler detects key presses → emits signals → GameController listens

### Current State
- FarmInputHandler exists with tool/action system
- GameController exists with action methods
- **Gap**: FarmInputHandler doesn't call GameController

### Work to Do
1. **Modify FarmInputHandler to call GameController**
   ```gdscript
   # In _handle_action(action: String, position: Vector2i):

   var result = game_controller.build(position, action)
   if result:
       action_performed.emit(action, true, "Success")
   else:
       action_performed.emit(action, false, "Failed")
   ```

2. **Create `test_keyboard_input.gd`**
   - Instead of calling GameController directly
   - Simulate keyboard input via InputEvent
   - Verify FarmInputHandler → GameController pipeline

   ```gdscript
   var key_event = InputEventKey.new()
   key_event.keycode = KEY_1  # Select tool 1
   key_event.pressed = true
   farm_input_handler._input(key_event)

   # Verify tool changed
   assert(farm_input_handler.current_tool == 1)
   ```

3. **Wire Signal Chain**
   - FarmInputHandler.action_performed → GameController.build()
   - GameController.action_feedback → UI update signals
   - Biome/FarmGrid signals → UI display updates

4. **Test Keyboard → Action → Signal → Result**
   ```gdscript
   # Press "1" (Plant tool)
   _simulate_key(KEY_1)
   assert(farm_input_handler.current_tool == 1)

   # Press "Q" (Plant wheat on current selection)
   _simulate_key(KEY_Q)
   assert(plot_is_wheat(current_selection))
   assert(signal_log.contains("plot_planted"))
   ```

### Success Criteria
- Keyboard input triggers GameController actions
- Actions generate correct signals
- Multiple consecutive actions work (plant → entangle → measure)
- Error feedback shown when action invalid

---

## Phase 5: Simulated Keyboard Input (Automated Gameplay)

### What's Happening
- Create automated tests that play the game via simulated keyboard input
- Can script complex gameplay sequences
- Can test emergent behavior

### Work to Do
1. **Create `test_automated_gameplay.gd`**
   - Simulates entire 9-phase circuit via keyboard
   - Can test different strategies
   - Can measure performance/complexity

2. **Automated Gameplay Scripts**
   ```gdscript
   # Script: "Plant and Entangle"
   _key(KEY_1)  # Select Plant tool
   _key(KEY_T)  # Select plot 0
   _key(KEY_Q)  # Plant wheat

   _key(KEY_2)  # Select Quantum tool
   _key(KEY_T)  # Select plot 0
   _key(KEY_Y)  # Select plot 1
   _key(KEY_Q)  # Entangle them
   ```

3. **Multi-Action Sequences**
   ```gdscript
   # Circuit: Plant wheat → entangle → measure → harvest → process → sell

   # Step 1: Plant wheat in plots 0, 1, 2
   plant_crop(Vector2i(0, 0), "wheat")
   plant_crop(Vector2i(1, 0), "wheat")
   plant_crop(Vector2i(2, 0), "wheat")

   # Step 2: Entangle plots 0-1, 1-2
   entangle(Vector2i(0, 0), Vector2i(1, 0))
   entangle(Vector2i(1, 0), Vector2i(2, 0))

   # Step 3: Wait 3 days (simulated)
   wait_days(3)

   # Step 4: Measure entangled cluster
   measure(Vector2i(1, 0))  # Measures all connected

   # Step 5: Harvest
   harvest(Vector2i(0, 0))
   harvest(Vector2i(1, 0))
   harvest(Vector2i(2, 0))

   # Step 6: Verify results
   assert(inventory.wheat > 0)
   ```

4. **Create Gameplay Validators**
   - Verify economic loop closes (credits cycle)
   - Verify entanglement measurements cascade correctly
   - Test all 5 Bell states produce different outcomes
   - Test crop type switching (wheat→tomato→mushroom)

### Success Criteria
- Can write automated gameplay tests in high-level script
- Scripts execute via simulated keyboard input
- Complex sequences work (multi-step entanglement networks)
- Game state queryable and verifiable after each action

---

## Implementation Order

```
1. Signal Cleanup (Phase 1)
   ↓
2. Farm Machinery Test Suite (Phase 2)
   ↓
3. Signal Spoofing (Phase 3)
   ↓
4. Keyboard Input Wiring (Phase 4)
   ↓
5. Automated Gameplay (Phase 5)
   ↓
PLAYABLE GAME
```

---

## Test File Structure

```
test_signal_system.gd                  # Phase 1: Signal validation
test_farm_economy_signals.gd           # Phase 1: Economy signals
test_biome_signal_propagation.gd       # Phase 1: Biome signals

test_farm_machinery.gd                 # Phase 2: GameController actions
test_signal_spoofing.gd                # Phase 3: Direct signal emission

test_keyboard_input.gd                 # Phase 4: Input → Action
test_automated_gameplay.gd             # Phase 5: Full game scripts
```

---

## Success Metrics

| Phase | Metric | Target |
|-------|--------|--------|
| 1 | Signal test coverage | 100% of signals |
| 2 | GameController test coverage | 100% of public methods |
| 3 | Signal spoof scenarios | 20+ signal combinations |
| 4 | Keyboard → action latency | <100ms |
| 5 | Automated gameplay scripts | 10+ different sequences |

---

## What Each Phase Enables

- **Phase 1 Enables**: Understanding when things go wrong (signal debugging)
- **Phase 2 Enables**: Testing game logic independent of UI
- **Phase 3 Enables**: Testing UI response independent of game logic
- **Phase 4 Enables**: Keyboard-driven gameplay
- **Phase 5 Enables**: Automated testing of emergent behavior

---

## Long-Term Vision

```
Unit Tests (current)
  ↓
Farm Machinery Tests (signal-aware)
  ↓
Keyboard-Driven Tests
  ↓
Automated Gameplay Scripts
  ↓
Manual Gameplay (player controls game via keyboard)
  ↓
UI Layer (visual feedback)
  ↓
Full Polished Game
```

This progression allows each layer to be tested independently before adding the next.
