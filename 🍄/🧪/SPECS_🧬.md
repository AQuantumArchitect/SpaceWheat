# 🧬 Stress Test Specifications

## Test Coverage

### ✅ Buffer Invalidation (YES)

**Phases 1 & 4**: Invalidate biome 0 and biome 3 buffers

```gdscript
func _invalidate_biome(index: int):
    var biome = batcher.biomes[index]
    var biome_name = _get_biome_name(biome)

    # Clear buffer completely
    batcher.frame_buffers[biome_name] = []
    batcher.buffer_cursors[biome_name] = 0
```

**Tracked Metrics:**
- `min_depth` before/after (minimum buffer depth across all biomes)
- `fib_index` before/after (Fibonacci escalation index)
- Expected: depth drops to 0 for invalidated biome
- Expected: escalation should trigger if depth < 1×batch

### ✅ In-Flight Biome Construction (YES)

**Phases 2,3,5,6**: Toggle biomes OFF/ON (destroy/recreate)

```gdscript
func _toggle_biome(keycode: int):
    var active_count_before = batcher.biomes.size()
    test_scene._toggle_biome_visibility(keycode)  # Async!
    await get_tree().process_frame
    var active_count_after = batcher.biomes.size()
```

**Construction Process:**
1. **OFF (Destroy)**:
   - Unregister from batcher
   - Wait for in-flight threads to complete
   - Free quantum computer resources
   - Remove visualization nodes from force graph
   - Active count: 6 → 5

2. **ON (Recreate)**:
   - Pick random biome from pool
   - Build quantum computer (async)
   - Register with batcher
   - Create visualization nodes
   - Add to force graph
   - Active count: 5 → 6

**Tracked Metrics:**
- Active biome count before/after each toggle
- Thread completion (via batcher cleanup)
- No tracking of construction time (should add!)

### ❌ Construction Time Tracking (MISSING)

**Gap**: We don't track how long biome construction takes

**Should track:**
- Time from toggle ON to biome fully registered
- C++ lookahead engine rebuild time
- Force graph node creation time

---

## Results Tracking

### Per-Phase Metrics

```gdscript
func _print_phase_summary():
    # Collected at end of each phase
    - Biomes active count
    - Buffer depth (minimum across all biomes)
    - Fib index (escalation level)
    - Refill count (total since start)
```

### Final Report

```gdscript
func _print_final_report():
    - Total frames executed
    - Active biomes count
    - Buffer depth
    - Fib index
    - Total refills
    - Avg batch time (ms)
    - List of active biomes
```

### Bash Script Tracking

```bash
# Pattern matching in 🍄/🧪/🧬.sh
grep -E "═|─|📍|🔄|💥|🔴|🟢|🎯|📊|📈|✅|❌|⚠️|ESCALATE|DE-ESCALATE|ERROR|WARNING|leak"
```

**Counts:**
- Escalation events: `grep -c "\[ESCALATE\]"`
- De-escalation events: `grep -c "\[DE-ESCALATE\]"`
- Errors: `grep -c "ERROR:"`
- Memory leaks: `grep -c "Leaked instance"`

### ❌ Missing Metrics

1. **Per-biome buffer depths** (only tracks minimum)
2. **Construction timing** (how long to rebuild biome)
3. **Force graph update time** (when nodes added/removed)
4. **Thread wait time** (when toggling OFF)
5. **Escalation success rate** (invalidations → escalations)

---

## Force Graph Calculation Complexity

### Algorithm Analysis

```gdscript
func _update_gdscript(delta: float, active_nodes: Array, biomes: Dictionary):
    # Main loop: O(n)
    for node in active_nodes:
        # Coupling forces: O(n)
        for other in active_nodes:
            if same_biome(node, other):
                calculate_spring_force()  # Hamiltonian + MI boost

        # Repulsion: O(n)
        for other in active_nodes:
            calculate_repulsion()  # Inverse-square

        # Momentum: O(1)
        calculate_momentum()
```

**Time Complexity: O(n²)** where n = total nodes across all biomes

### Performance Scaling

#### Node Counts by Biome Type

From test output:
- **CyberDebtMegacity**: 32 qubits → 32 nodes → 5 registers
- **StellarForges**: 8 qubits → 8 nodes → 3 registers
- **VolcanicWorlds**: 8 qubits → 8 nodes → 3 registers
- **BioticFlux**: 8 qubits → 8 nodes → 3 registers
- **FungalNetworks**: 16 qubits → 16 nodes → 4 registers
- **TidalPools**: 64 qubits → 64 nodes → 6 registers

**Average**: ~23 nodes/biome (median: 12 nodes/biome)

### Scaling Comparison

| Biomes | Total Nodes | Force Calcs/Frame | Relative Cost | FPS @ 60Hz Budget |
|--------|-------------|-------------------|---------------|-------------------|
| 1      | 23          | 529               | 1×            | 300+ FPS          |
| 2      | 46          | 2,116             | 4×            | 200+ FPS          |
| 4      | 92          | 8,464             | 16×           | 120+ FPS          |
| 6      | 138         | 19,044            | 36×           | 80-120 FPS        |
| 8      | 184         | 33,856            | 64×           | 50-80 FPS         |
| 10     | 230         | 52,900            | 100×          | 30-50 FPS         |

**Formula**: Cost = n² where n = biomes × avg_nodes_per_biome

### 1 Biome vs 10 Biomes Specs

#### 1 Biome (Baseline)
- **Nodes**: ~23 (varies by biome type)
- **Force calculations**: 529/frame
- **Force graph time**: ~0.5ms @ 60 FPS
- **Expected FPS**: 300+ (bottleneck: rendering)
- **Memory**: ~100KB for force graph

#### 10 Biomes (Max Stress)
- **Nodes**: ~230
- **Force calculations**: 52,900/frame
- **Force graph time**: ~8-12ms @ 60 FPS
- **Expected FPS**: 30-50 (bottleneck: force calculations)
- **Memory**: ~1MB for force graph

**Key Difference**: **100× more force calculations** (quadratic scaling)

### Backend Optimizations

#### Native C++ Backend (if available)
```gdscript
func _update_native(delta: float, nodes: Array, biomes: Dictionary):
    # Calls into C++ for vectorized force calculations
    # ~5-10× faster than GDScript
```

- **1 biome**: ~0.1ms (negligible)
- **10 biomes**: ~1-2ms (still fast)
- **Speedup**: 5-10× over GDScript

#### GPU Backend (if available)
```gdscript
func _update_gpu(delta: float, nodes: Array, biomes: Dictionary):
    # GPU compute shader for parallel force calculations
    # ~20-50× faster than GDScript
```

- **1 biome**: <0.05ms (negligible)
- **10 biomes**: ~0.3-0.5ms (very fast)
- **Speedup**: 20-50× over GDScript

### Actual Performance (from test)

**6 Biomes (138 nodes)**:
- Force graph: Not separately profiled
- Total frame time: ~7ms
- FPS: 143 (bottle neck: bubble rendering @ 7.3ms)
- **Conclusion**: Force graph is NOT the bottleneck at 6 biomes

**Projected 10 Biomes**:
- Force calculations: ~10-12ms (GDScript) or ~1-2ms (C++)
- Bubble rendering: ~12-15ms (scales linearly with nodes)
- **Total**: ~25-30ms/frame
- **FPS**: ~30-40 (below 60 FPS target)

### Optimization Opportunities

1. **Spatial Partitioning**: Grid or quadtree to reduce O(n²) → O(n log n)
2. **Distance Culling**: Skip force calculations beyond threshold
3. **Per-Biome Islands**: Only calculate inter-biome forces for "bridged" qubits
4. **GPU Compute**: Move force calculations to GPU (biggest win)
5. **LOD System**: Reduce node count for distant/inactive biomes

---

## Test Duration

**Total**: ~15.5 seconds
- Stabilize: 3.0s
- Invalidate_0: 2.5s
- Toggle_1_OFF: 1.0s
- Toggle_1_ON: 2.5s
- Invalidate_3: 2.5s
- Toggle_2_OFF: 1.0s
- Toggle_2_ON: 2.5s
- Complete: 1.0s

**Timeout**: 30s (allows for slow startup)

---

## Recommendations

### High Priority

1. **Add construction time tracking**
   ```gdscript
   var construction_start_time = Time.get_ticks_msec()
   # ... build biome ...
   var construction_time = Time.get_ticks_msec() - construction_start_time
   print("   Construction time: %dms" % construction_time)
   ```

2. **Track per-biome buffer depths**
   ```gdscript
   for biome in batcher.biomes:
       var state = batcher._get_biome_buffer_state(biome)
       print("   %s: depth=%d" % [state.biome_name, state.depth])
   ```

3. **Add escalation success tracking**
   ```gdscript
   var invalidations = 0
   var escalations_triggered = 0
   # ... in _invalidate_biome() ...
   if fib_after > fib_before:
       escalations_triggered += 1
   ```

### Medium Priority

4. **Profile force graph during toggle**
5. **Test with 8-10 biomes** to verify scaling
6. **Add GPU backend test** if available

### Low Priority

7. **Test different biome size combinations**
8. **Measure memory usage per phase**
9. **Add visual output (screenshots) for manual review**
