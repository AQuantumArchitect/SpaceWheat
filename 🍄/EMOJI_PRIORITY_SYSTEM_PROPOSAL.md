# Emoji Priority System Implementation Proposal

**Date**: 2026-02-15
**Goal**: Implement 3-tier emoji rendering with proper fallback chain

---

## 🎯 REQUIRED PRIORITY ORDER

```
Priority 1: Hand-Crafted SVGs    (highest quality, ~29 emojis)
    ↓ (if not found)
Priority 2: Downloaded Emoji SVGs (Twemoji, 490 emojis)
    ↓ (if not found)
Priority 3: Text Fallback         (system font) + ⚠️ WARNING
```

---

## 📊 CURRENT STATE ANALYSIS

### ✅ What's Already Working

**Hand-Crafted SVGs (Priority 1)**:
- Location: `Assets/UI/Resources/`, `Assets/UI/Tools/`, etc.
- Registry: `VisualAssetRegistry.gd` with `_emoji_to_svg` mapping
- Coverage: 29 custom emojis (🌾 💨 🪵 ⚡ 🔥 💧 etc.)
- Integration: Used by `EmojiAtlasBatcher._render_emoji_to_image()`

**Text Fallback (Priority 3)**:
- Method: `EmojiAtlasBatcher._render_emoji_to_viewport_text()`
- Renders emoji to SubViewport using system font
- Works but lacks quality and warning system

### ❌ What's Missing

**Downloaded Emoji SVGs (Priority 2)**:
- Location: `Assets/emoji_svg/` (490 SVG files)
- Index: `Assets/emoji_svg/emoji_index.json`
- **Problem**: Not registered in VisualAssetRegistry
- **Problem**: Never loaded or used at runtime
- **Problem**: No codepoint → filename conversion

**Warning System**:
- No logging when text fallback is used
- No developer feedback for missing emojis
- No metrics on coverage gaps

---

## 🔧 IMPLEMENTATION PLAN

### Phase 1: Extend VisualAssetRegistry (New: TieredEmojiRegistry)

**File**: `Core/Visualization/TieredEmojiRegistry.gd` (NEW)

```gdscript
class_name TieredEmojiRegistry
extends RefCounted

## Three-tier emoji texture provider with priority fallback

enum EmojiSource {
    HAND_CRAFTED,    # Priority 1: Custom SVGs from Assets/UI/
    TWEMOJI,         # Priority 2: Downloaded SVGs from Assets/emoji_svg/
    TEXT_FALLBACK    # Priority 3: System font rendering
}

# Caches
var _custom_cache: Dictionary = {}      # emoji → Texture2D
var _twemoji_cache: Dictionary = {}     # emoji → Texture2D
var _twemoji_index: Dictionary = {}     # emoji → codepoint filename

# Mappings (same as current VisualAssetRegistry)
var _custom_mappings: Dictionary = {}   # emoji → res:// path

# Statistics
var _source_stats: Dictionary = {
    EmojiSource.HAND_CRAFTED: 0,
    EmojiSource.TWEMOJI: 0,
    EmojiSource.TEXT_FALLBACK: 0
}

func _init():
    _load_custom_mappings()
    _load_twemoji_index()

## PRIORITY 1: Hand-Crafted SVGs
func _load_custom_mappings():
    # Same as current VisualAssetRegistry._load_asset_mappings()
    # Resources
    _register_custom("💨", "res://Assets/UI/Resources/Flour.svg")
    _register_custom("🌾", "res://Assets/UI/Resources/Wheat.svg")
    _register_custom("🪵", "res://Assets/UI/Resources/Lumber.svg")
    _register_custom("⚡", "res://Assets/UI/Resources/Power.svg")
    # ... (all 29 existing mappings)

## PRIORITY 2: Twemoji SVG Index
func _load_twemoji_index():
    var index_path = "res://Assets/emoji_svg/emoji_index.json"
    if not FileAccess.file_exists(index_path):
        push_warning("Twemoji index not found: %s" % index_path)
        return

    var file = FileAccess.open(index_path, FileAccess.READ)
    var json_text = file.get_as_text()
    file.close()

    var json = JSON.new()
    var parse_result = json.parse(json_text)
    if parse_result != OK:
        push_error("Failed to parse twemoji index")
        return

    var data = json.get_data()
    _twemoji_index = data.get("emojis", {})

    print("TieredEmojiRegistry: Loaded %d twemoji mappings" % _twemoji_index.size())

## MAIN API: Get texture with 3-tier fallback
func get_texture(emoji: String) -> Texture2D:
    # Normalize emoji (handle variation selectors)
    var normalized = _normalize_emoji(emoji)

    # Priority 1: Hand-crafted SVG
    if _custom_mappings.has(normalized):
        if _custom_cache.has(normalized):
            return _custom_cache[normalized]

        var path = _custom_mappings[normalized]
        if ResourceLoader.exists(path):
            var texture = load(path) as Texture2D
            _custom_cache[normalized] = texture
            _source_stats[EmojiSource.HAND_CRAFTED] += 1
            return texture

    # Priority 2: Twemoji SVG
    if _twemoji_index.has(normalized):
        if _twemoji_cache.has(normalized):
            return _twemoji_cache[normalized]

        var filename = _twemoji_index[normalized]
        var path = "res://Assets/emoji_svg/" + filename

        if ResourceLoader.exists(path):
            var texture = load(path) as Texture2D
            _twemoji_cache[normalized] = texture
            _source_stats[EmojiSource.TWEMOJI] += 1
            return texture
        else:
            push_warning("Twemoji SVG missing: %s (expected: %s)" % [emoji, path])

    # Priority 3: Will use text fallback (null return)
    _source_stats[EmojiSource.TEXT_FALLBACK] += 1
    push_warning("⚠️ EMOJI TEXT FALLBACK: '%s' not found in custom or twemoji" % emoji)
    return null

## Check if emoji has ANY source (no text fallback needed)
func has_texture(emoji: String) -> bool:
    var normalized = _normalize_emoji(emoji)
    return _custom_mappings.has(normalized) or _twemoji_index.has(normalized)

## Get source tier for debugging
func get_source(emoji: String) -> EmojiSource:
    var normalized = _normalize_emoji(emoji)
    if _custom_mappings.has(normalized):
        return EmojiSource.HAND_CRAFTED
    if _twemoji_index.has(normalized):
        return EmojiSource.TWEMOJI
    return EmojiSource.TEXT_FALLBACK

## Emoji normalization (handle variation selectors, ZWJ, etc.)
func _normalize_emoji(emoji: String) -> String:
    # Remove variation selector 16 (FE0F) - visual representation hint
    var normalized = emoji.replace(String.chr(0xFE0F), "")
    # Remove variation selector 15 (FE0E) - text representation hint
    normalized = normalized.replace(String.chr(0xFE0E), "")
    return normalized

## Helper for codepoint conversion
func _emoji_to_codepoint(emoji: String) -> String:
    var codepoints = []
    for i in range(emoji.length()):
        var code = emoji.unicode_at(i)
        codepoints.append("%x" % code)
    return "-".join(codepoints)

## Statistics for debugging
func print_statistics():
    print("=== TieredEmojiRegistry Statistics ===")
    print("  Hand-Crafted: %d uses" % _source_stats[EmojiSource.HAND_CRAFTED])
    print("  Twemoji:      %d uses" % _source_stats[EmojiSource.TWEMOJI])
    print("  Text Fallback: %d uses ⚠️" % _source_stats[EmojiSource.TEXT_FALLBACK])
    print("  Custom cache: %d loaded" % _custom_cache.size())
    print("  Twemoji cache: %d loaded" % _twemoji_cache.size())
    print("=====================================")

func _register_custom(emoji: String, path: String):
    _custom_mappings[emoji] = path
```

---

### Phase 2: Modify EmojiAtlasBatcher Integration

**File**: `Core/Visualization/EmojiAtlasBatcher.gd` (MODIFY)

**Changes**:

```gdscript
# Replace _visual_asset_registry reference
var _tiered_emoji_registry: TieredEmojiRegistry = null

func _init():
    # ... existing code ...
    _tiered_emoji_registry = TieredEmojiRegistry.new()

# MODIFY: _render_emoji_to_image()
func _render_emoji_to_image(emoji: String) -> Image:
    # Try tiered registry (Priority 1 & 2)
    if _tiered_emoji_registry:
        var tex = _tiered_emoji_registry.get_texture(emoji)
        if tex:
            var img = tex.get_image()
            if img:
                return img
            else:
                push_warning("Texture for '%s' has no image data" % emoji)

    # Priority 3: Text fallback (existing code)
    return _render_emoji_to_viewport_text(emoji)

# ADD: Warning aggregation for batch reporting
var _fallback_warnings: Dictionary = {}  # emoji → count

func _render_emoji_to_viewport_text(emoji: String) -> Image:
    # Log fallback usage
    if not _fallback_warnings.has(emoji):
        _fallback_warnings[emoji] = 0
    _fallback_warnings[emoji] += 1

    # ... existing SubViewport rendering code ...
    return img

# ADD: Print fallback report after atlas build
func build_atlas_async(emoji_list: Array) -> void:
    # ... existing atlas building code ...

    # After build complete:
    if _fallback_warnings.size() > 0:
        print("⚠️ EMOJI TEXT FALLBACK REPORT:")
        for emoji in _fallback_warnings.keys():
            print("  '%s' rendered as text (%d times)" % [emoji, _fallback_warnings[emoji]])
        print("  Consider adding these to Assets/emoji_svg/ or Assets/UI/")

    # Print registry stats
    if _tiered_emoji_registry:
        _tiered_emoji_registry.print_statistics()
```

---

### Phase 3: Update EmojiDisplay UI Component

**File**: `UI/Core/EmojiDisplay.gd` (MODIFY)

```gdscript
var _tiered_emoji_registry: TieredEmojiRegistry = null

func _ready():
    _tiered_emoji_registry = TieredEmojiRegistry.new()

func _update_display():
    if emoji.is_empty():
        return

    # Try tiered registry
    var texture = _tiered_emoji_registry.get_texture(emoji)

    if texture:
        # Show as texture (Priority 1 or 2)
        texture_rect.texture = texture
        texture_rect.visible = true
        label.visible = false
    else:
        # Text fallback (Priority 3)
        label.text = emoji
        label.visible = true
        texture_rect.visible = false

        # Warning (only once per emoji)
        if not _has_warned:
            push_warning("⚠️ EmojiDisplay: Using text fallback for '%s'" % emoji)
            _has_warned = true

var _has_warned: bool = false
```

---

### Phase 4: Cache Invalidation

**File**: `Core/Visualization/EmojiAtlasCache.gd` (MODIFY)

```gdscript
func _compute_cache_hash() -> String:
    # Existing: Hash biome/faction emoji lists
    var emoji_hash = _hash_emoji_list(_emoji_list)

    # NEW: Include twemoji index version
    var twemoji_index_path = "res://Assets/emoji_svg/emoji_index.json"
    var twemoji_hash = ""
    if FileAccess.file_exists(twemoji_index_path):
        var file = FileAccess.open(twemoji_index_path, FileAccess.READ)
        twemoji_hash = file.get_md5(twemoji_index_path)
        file.close()

    # NEW: Include custom SVG mappings version
    var custom_hash = str(TieredEmojiRegistry._custom_mappings.hash())

    # Combined hash
    var combined = emoji_hash + "|" + twemoji_hash + "|" + custom_hash
    return combined.md5_text()
```

**Effect**: Atlas rebuilds when:
- Biome/faction emojis change (existing)
- Twemoji index updates (new)
- Custom SVG mappings change (new)

---

### Phase 5: Singleton/Autoload Setup

**File**: `project.godot` (MODIFY)

Add autoload for global access:

```ini
[autoload]
TieredEmojiRegistry="*res://Core/Visualization/TieredEmojiRegistry.gd"
```

**Usage from anywhere**:
```gdscript
var texture = TieredEmojiRegistry.get_texture("🌾")
```

---

## 📋 IMPLEMENTATION CHECKLIST

### Step 1: Create TieredEmojiRegistry
- [ ] Create `Core/Visualization/TieredEmojiRegistry.gd`
- [ ] Copy custom mappings from VisualAssetRegistry
- [ ] Implement twemoji index loading
- [ ] Implement 3-tier get_texture() with fallback
- [ ] Add warning logging for text fallbacks
- [ ] Add statistics tracking

### Step 2: Integrate with EmojiAtlasBatcher
- [ ] Replace `_visual_asset_registry` with `_tiered_emoji_registry`
- [ ] Modify `_render_emoji_to_image()` to use tiered system
- [ ] Add fallback warning aggregation
- [ ] Print fallback report after atlas build
- [ ] Print registry statistics

### Step 3: Update EmojiDisplay
- [ ] Replace registry reference
- [ ] Add warning for text fallbacks in UI
- [ ] Test with various emoji sources

### Step 4: Update Cache System
- [ ] Modify `_compute_cache_hash()` to include twemoji/custom versions
- [ ] Test cache invalidation on emoji changes
- [ ] Verify atlas rebuilds correctly

### Step 5: Add Autoload
- [ ] Add TieredEmojiRegistry to project.godot autoloads
- [ ] Test global access from various nodes
- [ ] Verify singleton behavior

### Step 6: Testing & Validation
- [ ] Test with hand-crafted emoji (🌾 should use custom SVG)
- [ ] Test with twemoji emoji (🕸️ should use downloaded SVG)
- [ ] Test with missing emoji (should warn and use text)
- [ ] Check atlas build performance (should stay ~700ms)
- [ ] Verify cache hit rate after first boot
- [ ] Test UI emoji display components
- [ ] Review console output for warnings

---

## 🎯 EXPECTED OUTCOMES

### Performance
- **No change**: Atlas building still fast (~700ms first boot, ~70ms cached)
- **Benefit**: 490 twemoji SVGs now available vs text rendering
- **Quality**: Higher visual consistency across all emojis

### Coverage Improvements

**Before** (current):
- Hand-crafted: 29 emojis (custom quality)
- Text fallback: 229 emojis (inconsistent, low quality)

**After** (proposed):
- Hand-crafted: 29 emojis (highest quality)
- Twemoji: ~450 emojis (consistent, high quality)
- Text fallback: ~21 emojis (with warnings!)

**Coverage increase**: 11% → 89% with high-quality SVGs ✨

### Developer Experience

**Console Output**:
```
TieredEmojiRegistry: Loaded 490 twemoji mappings
Building emoji atlas for 258 unique emojis...
  ✓ Atlas built in 687ms

⚠️ EMOJI TEXT FALLBACK REPORT:
  '≈' rendered as text (12 times)
  '≠' rendered as text (8 times)
  '▁' rendered as text (4 times)
  Consider adding these to Assets/emoji_svg/ or Assets/UI/

=== TieredEmojiRegistry Statistics ===
  Hand-Crafted: 29 uses
  Twemoji:      227 uses
  Text Fallback: 2 uses ⚠️
=====================================
```

---

## 🚧 EDGE CASES & SOLUTIONS

### Edge Case 1: Emoji Variation Selectors

**Problem**: `☀` (U+2600) vs `☀️` (U+2600 U+FE0F) are same visual

**Solution**: `_normalize_emoji()` strips variation selectors before lookup
```gdscript
func _normalize_emoji(emoji: String) -> String:
    return emoji.replace(String.chr(0xFE0F), "")
```

### Edge Case 2: Multi-Codepoint Emojis

**Problem**: `👨‍💻` (man + ZWJ + computer) is sequence, not single emoji

**Solution**: Twemoji index uses full sequence as key
```json
{
  "👨‍💻": "1f468-200d-1f4bb.svg"
}
```

### Edge Case 3: Missing Twemoji Index

**Problem**: `emoji_index.json` not bundled or corrupted

**Solution**: Graceful degradation to hand-crafted + text
```gdscript
if not FileAccess.file_exists(index_path):
    push_warning("Twemoji index not found, using hand-crafted + text only")
    return  # Skip twemoji loading
```

### Edge Case 4: SVG Load Failure

**Problem**: SVG file exists in index but fails to load

**Solution**: Catch and fall through to next priority
```gdscript
if ResourceLoader.exists(path):
    var texture = load(path) as Texture2D
    if texture:  # Verify load succeeded
        return texture
    else:
        push_warning("Failed to load: %s" % path)
# Falls through to text fallback
```

---

## 📊 MIGRATION STRATEGY

### Backward Compatibility

**VisualAssetRegistry** → Keep for now (deprecated)
- Mark as deprecated in comments
- Redirect calls to TieredEmojiRegistry
- Remove in future release after testing

**EmojiDisplay** → Update incrementally
- Add feature flag: `use_tiered_registry` (default: false)
- Gradual rollout across UI components
- Full migration after validation

### Rollout Plan

**Phase 1** (Testing):
- Enable TieredEmojiRegistry only in EmojiAtlasBatcher
- Monitor console warnings
- Verify visual quality

**Phase 2** (UI Integration):
- Enable in EmojiDisplay components
- Update faction/biome UI
- Test user-facing emoji displays

**Phase 3** (Cleanup):
- Deprecate VisualAssetRegistry
- Remove old code paths
- Update documentation

---

## 💾 FILE CHANGES SUMMARY

| File | Change Type | Description |
|------|-------------|-------------|
| `Core/Visualization/TieredEmojiRegistry.gd` | **NEW** | 3-tier emoji texture provider |
| `Core/Visualization/EmojiAtlasBatcher.gd` | **MODIFY** | Use TieredEmojiRegistry |
| `Core/Visualization/EmojiAtlasCache.gd` | **MODIFY** | Include twemoji in cache hash |
| `UI/Core/EmojiDisplay.gd` | **MODIFY** | Use TieredEmojiRegistry |
| `project.godot` | **MODIFY** | Add TieredEmojiRegistry autoload |
| `Core/QuantumSubstrate/VisualAssetRegistry.gd` | **DEPRECATE** | Mark as legacy |

---

## 🎉 SUCCESS CRITERIA

✅ **Functional**:
- [ ] Hand-crafted SVGs load as Priority 1
- [ ] Twemoji SVGs load as Priority 2
- [ ] Text fallback works as Priority 3
- [ ] Warnings logged for all text fallbacks

✅ **Performance**:
- [ ] Atlas build time ≤ 750ms (within 10% of current)
- [ ] Cache hit rate ≥ 90% on subsequent boots
- [ ] No memory leaks from texture caching

✅ **Quality**:
- [ ] Visual consistency across emoji types
- [ ] No rendering artifacts
- [ ] All 490 twemoji load correctly

✅ **Developer Experience**:
- [ ] Clear console output showing source breakdown
- [ ] Warning system catches missing emojis
- [ ] Statistics help optimize coverage

---

**Status**: Ready for implementation 🚀
**Estimated Time**: 4-6 hours (including testing)
**Risk Level**: Low (backward compatible, gradual rollout)
