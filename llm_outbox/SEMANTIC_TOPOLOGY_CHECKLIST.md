# Semantic Topology Implementation Checklist

Quick reference for tracking implementation progress.

## Feature 1: Strange Attractor Analysis (Days 1-3)

### Files to CREATE
- [ ] `Core/QuantumSubstrate/StrangeAttractorAnalyzer.gd`
- [ ] `Core/Visualization/AttractorVisualizer3D.gd` (optional for MVP)
- [ ] `UI/Panels/AttractorPersonalityPanel.gd`
- [ ] `Tests/test_strange_attractor.gd`

### Files to MODIFY
- [ ] `Core/Environment/BiomeBase.gd` - Add attractor_analyzer field + initialization
- [ ] `Core/QuantumSubstrate/QuantumBath.gd` - Hook recording in evolution
- [ ] `UI/PlayerShell.gd` - Add attractor personality display

### Testing
- [ ] Can record trajectory for 3+ biomes
- [ ] Different biomes show different personalities
- [ ] Classification works: stable/cyclic/chaotic
- [ ] UI shows personality text

---

## Feature X: Cross-Biome Entanglement Prevention (Day 1)

### Files to MODIFY
- [ ] `Core/GameMechanics/FarmGrid.gd` - Add biome validation to create_entanglement()
- [ ] `Core/GameMechanics/FarmGrid.gd` - Add validate_entanglement_network()
- [ ] `UI/FarmInputHandler.gd` - Block entangle action across biomes
- [ ] `Core/QuantumSubstrate/QuantumComputer.gd` - Add assertion checks

### Files to CREATE
- [ ] `Tests/test_cross_biome_prevention.gd`

### Testing
- [ ] Entanglement blocked when plots have different biome_id
- [ ] UI shows error message when blocked
- [ ] Validation catches any violations
- [ ] Test passes

---

## Feature 3: Sparks System (Days 4-5)

### Files to CREATE
- [ ] `Core/QuantumSubstrate/SparkConverter.gd`
- [ ] `UI/Panels/QuantumEnergyMeter.gd`
- [ ] `Tests/test_spark_extraction.gd`

### Files to MODIFY
- [ ] `Core/QuantumSubstrate/DensityMatrix.gd` - Add compute_energy_split()
- [ ] `Core/GameState/ToolConfig.gd` - Add spark actions to Tool 4
- [ ] `UI/FarmInputHandler.gd` - Handle spark extraction action

### Testing
- [ ] Can measure imaginary/real energy split
- [ ] Extraction increases target observable
- [ ] Extraction reduces coherence
- [ ] UI shows energy meter

---

## Feature 2: Fiber Bundles (Days 6-9)

### Files to CREATE
- [ ] `Core/QuantumSubstrate/FiberBundle.gd`
- [ ] `Core/QuantumSubstrate/SemanticOctant.gd`
- [ ] `UI/Panels/SemanticContextIndicator.gd`
- [ ] `Tests/test_fiber_bundle.gd`

### Files to MODIFY
- [ ] `Core/GameState/ToolConfig.gd` - Add fiber bundle support
- [ ] `UI/FarmInputHandler.gd` - Use context-aware actions
- [ ] `UI/Panels/ActionPreviewRow.gd` - Show context variants

### Testing
- [ ] Can detect semantic octant from position
- [ ] Tools show different options per octant
- [ ] UI indicates current region
- [ ] Transitions are smooth

---

## Feature 4: Semantic Uncertainty Principle (Day 10)

### Files to CREATE
- [ ] `Core/QuantumSubstrate/SemanticUncertainty.gd`
- [ ] `UI/Panels/UncertaintyMeter.gd`
- [ ] `Tests/test_uncertainty_principle.gd`

### Files to MODIFY
- [ ] `Core/Environment/BiomeBase.gd` - Track uncertainty metrics
- [ ] `UI/PlayerShell.gd` - Add uncertainty meter to UI

### Testing
- [ ] Can compute precision and flexibility
- [ ] Product satisfies principle
- [ ] UI shows regime (crystallized/fluid/balanced)
- [ ] Description makes sense

---

## Feature 6: Symplectic Conservation (Days 11-12)

### Files to CREATE
- [ ] `Core/QuantumSubstrate/SymplecticValidator.gd`
- [ ] `Tests/test_symplectic_conservation.gd`

### Files to MODIFY
- [ ] `Core/QuantumSubstrate/QuantumComputer.gd` - Add validation hook

### Testing
- [ ] Trace conserved within 1% tolerance
- [ ] Hermiticity preserved
- [ ] No negative eigenvalues
- [ ] Can toggle validation on/off

---

## Integration Testing (Days 13-15)

### Files to CREATE
- [ ] `Tests/test_semantic_topology_integration.gd`

### Tests to Write
- [ ] Full pipeline: attractor + octant + spark + uncertainty + validation
- [ ] Cross-biome prevention works in gameplay
- [ ] All features work together without conflicts
- [ ] Performance is acceptable

### Documentation
- [ ] Update README with new features
- [ ] Add semantic topology guide for players
- [ ] Document API for each new class
- [ ] Create examples/tutorials

---

## File Count Summary

**New files**: 16
**Modified files**: 12
**Test files**: 7
**Total changes**: 35 files

## Estimated Lines of Code

- Feature 1: ~400 LOC
- Feature X: ~100 LOC
- Feature 2: ~500 LOC
- Feature 3: ~400 LOC
- Feature 4: ~250 LOC
- Feature 6: ~300 LOC
- Tests: ~600 LOC

**Total**: ~2500 LOC (manageable for 3 weeks)
