# LAB_TRUE Mode Non-Compliance Issue

**Date**: 2026-01-03
**Severity**: MEDIUM (Physics Accuracy)
**Status**: Implementation does not match LAB_TRUE specification

---

## Summary

The `partial_collapse()` function does **not** perform full projective collapse even when strength=1.0 (LAB_TRUE mode). Instead, it performs a probability-boosting operation that gives ~67% probability to the measured outcome instead of 100%.

---

## Expected Behavior (LAB_TRUE Mode)

According to the Quantum Mechanics Manifest:
- **LAB_TRUE**: Full quantum rigor with Born rule projective measurement
- Collapse strength = 1.0
- After measurement of outcome `e`, the density matrix should be:
  - ρ = |e⟩⟨e| (pure state in outcome)
  - P(e) = 1.0
  - P(all others) = 0.0
  - All coherences destroyed: ρ[i,j] = 0 for i≠j

---

## Actual Behavior

### Current Implementation

**File**: `Core/QuantumSubstrate/QuantumBath.gd:520`

```gdscript
func partial_collapse(emoji: String, strength: float) -> void:
    var current = mat.get_element(idx, idx).re
    mat.set_element(idx, idx, Complex.new(current * (1.0 + strength), 0.0))

    # Dampen off-diagonals
    for i in range(_density_matrix.dimension()):
        for j in range(_density_matrix.dimension()):
            if i != j:
                var off_diag = mat.get_element(i, j)
                mat.set_element(i, j, off_diag.scale(1.0 - strength * 0.5))

    _density_matrix._enforce_trace_one()
```

### What This Does

With strength=1.0:
1. P(measured) ← P(measured) × 2.0
2. P(others) ← unchanged
3. Renormalize to Tr(ρ)=1

### Test Results

Starting state: P(north)=0.5, P(south)=0.5
After measuring north with strength=1.0:
- **Expected**: P(north)=1.0, P(south)=0.0
- **Actual**: P(north)=0.667, P(south)=0.333

---

## Mathematical Analysis

### Case 1: Strength = 1.0 (LAB_TRUE)

Starting: P(A)=0.5, P(B)=0.5

Current implementation:
1. P'(A) = 0.5 × (1.0 + 1.0) = 1.0
2. P'(B) = 0.5 (unchanged)
3. Total = 1.5
4. Renormalize: P(A) = 1.0/1.5 = **0.667**, P(B) = 0.5/1.5 = **0.333**

Correct projective collapse:
1. P'(A) = 1.0
2. P'(B) = 0.0
3. No renormalization needed

### Case 2: Strength = 0.5 (KID_LIGHT)

Starting: P(A)=0.5, P(B)=0.5

Current implementation:
1. P'(A) = 0.5 × (1.0 + 0.5) = 0.75
2. P'(B) = 0.5
3. Total = 1.25
4. Renormalize: P(A) = **0.6**, P(B) = **0.4**

This seems reasonable for "partial collapse" - gently increases measured outcome probability.

---

## Root Cause

The formula `P_new = P_old × (1.0 + strength)` is a **continuous interpolation** that works well for partial collapse (strength < 1.0), but doesn't converge to true projective measurement at strength=1.0.

For true projective collapse, the formula should be discontinuous at strength=1.0:
- strength < 1.0: Use partial boosting
- strength = 1.0: Set P(outcome)=1.0, P(others)=0.0

---

## Recommended Fix

### Option A: True Projective Collapse at strength=1.0

```gdscript
func partial_collapse(emoji: String, strength: float) -> void:
    var idx = _density_matrix.emoji_to_index.get(emoji, -1)
    if idx < 0:
        return

    var mat = _density_matrix.get_matrix()
    var dim = _density_matrix.dimension()

    if abs(strength - 1.0) < 0.01:  # Full projective collapse
        # Zero everything
        for i in range(dim):
            for j in range(dim):
                mat.set_element(i, j, Complex.zero())

        # Set outcome to 1.0
        mat.set_element(idx, idx, Complex.one())

    else:  # Partial collapse (original implementation)
        var current = mat.get_element(idx, idx).re
        mat.set_element(idx, idx, Complex.new(current * (1.0 + strength), 0.0))

        # Dampen off-diagonals
        for i in range(dim):
            for j in range(dim):
                if i != j:
                    var off_diag = mat.get_element(i, j)
                    mat.set_element(i, j, off_diag.scale(1.0 - strength * 0.5))

        _density_matrix._enforce_trace_one()

    _density_matrix.set_matrix(mat)
```

### Option B: Different Formula for strength Interpolation

Use a formula that naturally converges to projection:

```gdscript
# Lüders rule interpolation
# strength=0: no change
# strength=1: full projection

var p_outcome = mat.get_element(idx, idx).re

# Mix of original state and projected state
for i in range(dim):
    for j in range(dim):
        var original = mat.get_element(i, j)
        var projected = Complex.zero()
        if i == idx and j == idx:
            projected = Complex.one()

        # Linear interpolation
        var mixed = original.scale(1.0 - strength).add(projected.scale(strength))
        mat.set_element(i, j, mixed)
```

---

## Impact Assessment

### Current State Impact

**Low-Medium Impact on Gameplay**:
- KID_LIGHT mode (default): Works as intended (partial collapse)
- LAB_TRUE mode: Not scientifically accurate, but still functional
- Players may not notice the difference in casual play
- Scientists/educators may notice non-projective behavior

**Physics Accuracy**: ❌ NOT COMPLIANT
- LAB_TRUE does not implement Born rule projective measurement
- Manifest Section 1.4 not satisfied for LAB_TRUE mode

### After Fix Impact

**Benefits**:
- ✅ LAB_TRUE mode becomes scientifically rigorous
- ✅ Manifest compliance achieved
- ✅ Educational value increased

**Risks**:
- LAB_TRUE mode becomes "harsher" (full collapse vs partial)
- May affect game balance if players use LAB_TRUE mode
- Existing saves/playthroughs in LAB_TRUE may behave differently

---

## Test Results

### LAB_TRUE Mode Tests (Current Implementation)

```
✓ Collapse strength = 1.0 (configuration correct)
✓ POSTSELECT_COSTED works (cost formula correct)
✗ Full collapse after measurement (got 0.667, expected 1.0)
✗ No coherence preservation (got 0.667, expected 0.9+)
```

**Score**: 2/4 LAB_TRUE-specific tests failed

### Phase 1-2 Tests (Mode-Independent)

All pass regardless of mode ✅

---

## Recommendation

### Short Term (Current Release)

**Document the limitation**:
- Add comment to `partial_collapse()` explaining current behavior
- Note in manifest that LAB_TRUE uses "strong partial collapse" not "full projection"
- Update QuantumRigorConfig documentation

### Medium Term (Next Version)

**Implement Option A (True Projective Collapse)**:
- Add special case for strength=1.0
- Thoroughly test game balance impact
- Consider making it toggleable (e.g., "LAB_TRUE_STRICT" mode)

### Long Term (Research Mode)

**Implement proper quantum measurement**:
- Use Lüders rule for proper POVM measurements
- Support multi-outcome measurements (not just binary)
- Add measurement backaction options (e.g., weak measurement)

---

## Priority

**Medium Priority**:
- Not blocking gameplay (KID_LIGHT works fine)
- Not breaking (LAB_TRUE functional, just not rigorous)
- Important for educational/scientific credibility
- Can be fixed incrementally

---

## Related Files

- `Core/QuantumSubstrate/QuantumBath.gd:513` - partial_collapse()
- `Core/QuantumSubstrate/QuantumBath.gd:613` - measure_axis_costed()
- `Core/GameState/QuantumRigorConfig.gd` - Mode configuration
- `llm_inbox/space_wheat_quantum↔classical_interface_manifest_gozintas_gozoutas.md` - Manifest spec

---

## Conclusion

The current implementation trades off physics rigor for smooth gameplay interpolation. This is a **reasonable design choice** for a game, but should be documented as "strong partial collapse" rather than "full projective measurement."

If true LAB_TRUE rigor is desired (for educational purposes), Option A fix should be implemented with appropriate game balance testing.

**Current Status**: ⚠️ Functional but not rigorous in LAB_TRUE mode
**Recommended Action**: Document limitation, implement fix in next version
