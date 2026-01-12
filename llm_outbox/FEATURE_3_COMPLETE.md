# Feature 3: Sparks System - COMPLETE ✅

**Date**: 2026-01-09
**Status**: Core mechanics implemented and tested
**Test Results**: 20/20 passing (100%)

---

## Overview

Feature 3 implements the "Sparks" mechanic - a system for extracting quantum potential (imaginary/coherence energy) and converting it into real observable energy. This creates a strategic tradeoff between quantum flexibility and immediate gains.

## What Was Implemented

### 1. Energy Split Calculation

**Modified**: `Core/QuantumSubstrate/ComplexMatrix.gd` (+42 lines)

Added `compute_energy_split()` method that separates:
- **Real Energy**: Sum of diagonal elements (observable populations)
- **Imaginary Energy**: Sum of |off-diagonal| elements (quantum coherence)

```gdscript
func compute_energy_split() -> Dictionary:
    """Returns: {real, imaginary, total, coherence_ratio}"""
```

Physics interpretation:
- Real = classical probabilities (what you can observe)
- Imaginary = quantum superposition potential (what you could become)
- Coherence ratio = imaginary/total (flexibility measure)

### 2. SparkConverter Class

**Created**: `Core/QuantumSubstrate/SparkConverter.gd` (245 lines)

Core extraction logic:
```gdscript
static func extract_spark(quantum_computer, target_emoji, fraction) -> Dictionary:
    """Convert coherence energy into population energy

    Returns:
        {success, extracted_amount, new_population, coherence_lost, message}
    """
```

**Mechanics**:
1. Extract fraction `f` of imaginary energy
2. Apply dephasing: decay all off-diagonals by `exp(-f * DECOHERENCE_RATE)`
3. Inject population into target emoji basis states
4. Renormalize to maintain Tr(ρ) = 1

**Constants**:
- `EXTRACTION_EFFICIENCY = 0.8` (80% of coherence converts to population)
- `DECOHERENCE_RATE = 2.0` (how much coherence is lost)
- `MIN_COHERENCE_THRESHOLD = 0.01` (minimum to extract)

**Helper functions**:
- `get_energy_status(qc)` - Inspect energy split without modification
- `get_regime_description(regime)` - Human-readable regime descriptions
- `get_regime_color(regime)` - Color coding for visualization

**Regimes**:
- `high_coherence` (ratio > 0.4): ⚡ High quantum potential
- `balanced` (0.1 < ratio < 0.4): ⚖️ Moderate extraction possible
- `mostly_classical` (ratio < 0.1): 📊 Limited extraction

### 3. QuantumEnergyMeter UI Panel

**Created**: `UI/Panels/QuantumEnergyMeter.gd` (190 lines)

Visual display panel showing:
- Real energy bar (📊 orange)
- Imaginary energy bar (✨ cyan)
- Current regime indicator
- Extractable energy amount
- Biome-aware title

Features:
- Updates every 0.5 seconds
- Works with multi-biome or single-biome farm structures
- Styled progress bars with rounded corners
- Tooltip with detailed explanation

### 4. Test Suite

**Created**: `Tests/test_spark_extraction.gd` (175 lines)

**Test Results**: 20/20 passing

| Test Category | Count | Status |
|--------------|-------|--------|
| Energy split - pure state | 4 | ✅ PASS |
| Energy split - mixed state | 3 | ✅ PASS |
| Energy split - coherent state | 4 | ✅ PASS |
| Spark extraction - basic | 5 | ✅ PASS |
| Spark extraction - insufficient | 1 | ✅ PASS |
| Spark extraction - invalid target | 1 | ✅ PASS |
| Energy status reporting | 2 | ✅ PASS |

---

## Test Output Highlights

### Energy Split Tests

```
TEST: Energy Split - Coherent Superposition |+⟩
  ✓ Real energy should be 1.0
  ✓ Imaginary energy should be 1.0 (max coherence)
  ✓ Total should be 2.0
  ✓ Coherence ratio should be 0.5
    Energy split: real=1.00, imaginary=1.00, ratio=0.50
```

### Spark Extraction Tests

```
TEST: Spark Extraction - Basic
    Before: real=1.000, imaginary=0.447
  ✓ Extraction should succeed
  ✓ Should extract some energy
  ✓ Should lose some coherence
  ✓ Target population should increase or stay same
  ✓ Imaginary energy should decrease
    After: real=1.000, imaginary=0.140
    Extracted: 0.179, Coherence lost: 0.307
```

### Error Handling

```
TEST: Spark Extraction - Insufficient Coherence
  ✓ Extraction should fail with no coherence
    Message: Insufficient quantum potential to extract (coherence = 0.000)

TEST: Spark Extraction - Invalid Target Emoji
  ✓ Extraction should fail with invalid target
    Message: Target emoji '🔥' not registered in this biome
```

---

## Files Created/Modified

| File | Type | Lines |
|------|------|-------|
| `Core/QuantumSubstrate/ComplexMatrix.gd` | Modified | +42 |
| `Core/QuantumSubstrate/SparkConverter.gd` | Created | 245 |
| `UI/Panels/QuantumEnergyMeter.gd` | Created | 190 |
| `Tests/test_spark_extraction.gd` | Created | 175 |

**Total**: 652 lines added across 4 files (3 new, 1 modified)

---

## Gameplay Integration

### Current Status

The core mechanics are complete and tested. To use in gameplay:

```gdscript
# Get current energy status
var status = SparkConverter.get_energy_status(biome.quantum_computer)
print("Extractable: %.2f" % status.extractable)

# Extract spark targeting a specific emoji
var result = SparkConverter.extract_spark(
    biome.quantum_computer,
    "🌾",  # Target emoji to boost
    0.2    # Extract 20% of imaginary energy
)

if result.success:
    print("Extracted %.3f → %s now at %.2f" % [
        result.extracted_amount,
        "🌾",
        result.new_population
    ])
```

### Tool 4 Integration (Optional Enhancement)

To add spark extraction to Tool 4 (Biome Control), add a submenu action:
```gdscript
"energy_tap": {
    "name": "Energy Tap",
    "emoji": "⚡",
    "actions": {
        "Q": {"action": "spark_extract", "label": "Extract Quantum Potential"},
        "E": {"action": "spark_inspect", "label": "Inspect Energy Split"},
        "R": {"action": "cancel_submenu", "label": "Cancel"}
    }
}
```

---

## Physics Notes

### Why "Imaginary" Energy?

In quantum mechanics, off-diagonal elements of density matrices are complex numbers representing coherence (superposition). While the imaginary part (im) of individual elements is phase information, the *magnitude* of these off-diagonals represents "quantum potential" - the ability of the system to interfere and exist in superposition.

Converting this to population is analogous to:
- **Measurement collapse**: Observing the system collapses superposition
- **Decoherence**: Environmental interaction destroys quantum coherence
- **Energy extraction**: In some quantum thermodynamics, coherence can do work

### Trace Preservation

The extraction always maintains Tr(ρ) = 1:
1. Dephasing preserves trace (only modifies off-diagonals)
2. Population injection is followed by renormalization
3. Total probability always sums to 1.0

---

## Strategic Implications

### High Coherence State
- **Pro**: Maximum extractable energy, flexible future options
- **Con**: Unpredictable dynamics, meanings can drift

### Low Coherence State
- **Pro**: Stable, predictable behavior
- **Con**: Limited extraction possible, "crystallized"

### The Tradeoff
Players must decide:
- Extract now for immediate gain (reduce flexibility)
- Preserve coherence for future options (delay gratification)

This creates emergent gameplay around resource timing and quantum state management.

---

## Conclusion

**Feature 3 is complete** ✅

The Sparks system provides:
1. A clear metric for quantum potential (coherence ratio)
2. A conversion mechanic (extraction)
3. Meaningful tradeoffs (flexibility vs immediate gain)
4. Visual feedback (UI panel)
5. Comprehensive testing (100% pass rate)

**User Request**: "continue to phase 3" ✅

---

*Generated by Claude Code - 2026-01-09*
