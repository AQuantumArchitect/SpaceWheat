# 🧬 Biome Stress Test

Tests buffer invalidation + biome creation/destruction to verify:
- ✅ No memory leaks
- ✅ No crashes
- ✅ Proper cleanup of threads and C++ resources
- ✅ System stability under biome toggle stress

## Usage

```bash
# Run standard test
bash 🍄/🧪/🧬.sh

# Run with verbose output
bash 🍄/🧪/🧬.sh --verbose
```

## Test Sequence

1. **Stabilize** (3s) - Let 6 biomes reach steady state
2. **Invalidate biome 0** (2.5s) - Clear buffer, test recovery
3. **Toggle biome 1 OFF** (1s) - Destroy biome, test cleanup
4. **Toggle biome 1 ON** (2.5s) - Recreate biome, test initialization
5. **Invalidate biome 3** (2.5s) - Clear buffer again
6. **Toggle biome 2 OFF** (1s) - Destroy another biome
7. **Toggle biome 2 ON** (2.5s) - Recreate, verify stability
8. **Complete** (1s) - Collect final metrics

## What It Tests

### Buffer Invalidation
- Clears a biome's buffer to depth=0
- Should trigger escalation (fib_index increases)
- System should recover with larger batch sizes

### Biome Toggle
- **OFF**: Calls `boot_manager.unregister_biome()`
  - Removes from batcher
  - Cleans up quantum computer
  - Removes visualization nodes
- **ON**: Calls `boot_manager.build_single_biome()`
  - Creates new quantum computer
  - Registers with batcher
  - Adds visualization nodes

### Cleanup Verification
- All threads finish before exit
- No C++ object leaks
- No mutex/thread leaks
- Proper GDExtension cleanup

## Expected Results

✅ **No errors or memory leaks**
✅ **Clean exit** 
⚠️ **Escalation count: varies** (depends on timing)

## Implementation

- **Test Controller**: `Tests/StressTestController.gd`
- **Bash Wrapper**: `🍄/🧪/🧬.sh`
- **Cleanup Logic**: `Core/Environment/BiomeEvolutionBatcher.gd:_notification()`

## Fixes Applied

### 1. Cleanup Error Fix
**Before**: `SCRIPT ERROR: Attempt to call function '_cleanup_lookahead_engine' in base 'null instance'`

**After**: Cleanup logic moved directly into `_notification()` handler

### 2. Memory Leak Fix  
**Before**: `Leaked instance: Mutex` (threads not cleaned up)

**After**: All threads waited for before freeing

### 3. RefCounted Free Error
**Before**: `ERROR: Can't free a RefCounted object`

**After**: GDExtension objects nulled, not freed (auto-cleanup)

## All Fixes Apply to Main Game

There is only one `BiomeEvolutionBatcher.gd` file:
- `Core/Environment/BiomeEvolutionBatcher.gd`

Both VisualBubbleTest and main game use the same file, so all fixes automatically apply to production.
