# SpaceWheat Emoji Sources

## Quick Reference

**Total Required**: 258 unique emojis  
**Budget**: 350 max (we're at 74% capacity)  
**File Size**: ~0.5-1.3 MB for all SVGs

---

## Breakdown by Source

### Biomes (163 unique)
- Environment/terrain emojis
- Structural elements
- Atmospheric/weather
- Extracted from: `Core/Biomes/data/biomes_merged.json`

### Factions (207 total, overlaps with biomes)
- 197 icons built from 89 factions
- Hamiltonian/Lindblad coupling emojis
- Faction signatures and decay targets
- Extracted from: `Core/Factions/data/factions_merged.json`

### Quest System (26)
- Verbs: 🌾📦🛡️💥🏗️🔧🤝🔍🔐👁️🔮✨🔄🌌⚡🍽️⛏️🎁
- Urgency: 🕰️⏰🌙⚡
- Quantities: 1️⃣2️⃣3️⃣🖐️📦🌾🌾
- Extracted from: `Core/Quests/QuestVocabulary.gd`

### Economy/Resources (25)
- Core resources: 🌱💀🍞❄️🔥💧👥💰💳
- Plants/food: 🌾🍄🌲🌿🍂🌻
- Animals: 🐺🐻🐂🦅🦌🐇
- Elements: 💨☀️🌙⚡
- Extracted from: `Core/GameMechanics/EconomyConstants.gd`

### UI/System (17)
- Status: ✅❌⚠️ℹ️🔔
- Controls: ▶️⏸️⏹️🔄↩️
- Navigation: ⬅️➡️⬆️⬇️
- Metrics: 📊📈📉
- Used across UI components

### 🍄 Dev Tools (29)
- Test/debug script filenames
- Rig/automation tools
- Performance profilers
- Milk hunt runners

---

## Special Handling Required

### Multi-Character Sequences (3)
1. `🌾🌾` - Double wheat (quest quantity)
2. `👨‍💻` - Man technologist (ZWJ: U+1F468 + U+200D + U+1F4BB)
3. `🏋️‍♀️` - Woman lifting (ZWJ: U+1F3CB + U+FE0F + U+200D + U+2640 + U+FE0F)

### Variation Selector Pairs (10 duplicates)
Format: Base emoji with/without U+FE0F (VS-16)
```
☀/☀️  ❄/❄️  ⚙/⚙️  🏚/🏚️  🏛/🏛️
🕰/🕰️  👁/👁️  🛠/🛠️  🛡/🛡️  🗺/🗺️
```
**Decision**: Keep both variants, normalize to VS-16 (with ️) in atlas

---

## Coverage Verification

Tested against:
- ✅ EmojiRegistry.gd (biomes + factions)
- ✅ QuestVocabulary.gd (quest atoms)
- ✅ PlayerVocabulary.gd (learned pairs)
- ✅ IconRegistry.gd (197 icons)
- ✅ 🍄 folder filenames

---

## Files Created

1. **🍄/EMOJI_MANIFEST.md** - This comprehensive guide
2. **🍄/emoji_list.txt** - Simple newline-separated list (258 lines)
3. **🍄/emoji_manifest.json** - Structured metadata + emoji array
4. **🍄/🛠️/📥.py** - Download script for Twemoji/OpenMoji SVGs

---

## Usage

### Download All Required SVGs
```bash
# From Twemoji (recommended)
python3 🍄/🛠️/📥.py --output-dir Assets/emoji_svg --source twemoji

# Or from OpenMoji
python3 🍄/🛠️/📥.py --output-dir Assets/emoji_svg --source openmoji
```

### Verify Coverage
```bash
# Check emoji count
wc -l 🍄/emoji_list.txt
# Should output: 258

# View JSON metadata
cat 🍄/emoji_manifest.json
```

---

## Repository Comparison

| Feature | Twemoji | OpenMoji |
|---------|---------|----------|
| Total emojis | 3,245+ | 4,000+ |
| Our coverage | 100% ✅ | 100% ✅ |
| License | CC-BY 4.0 / MIT | CC-BY-SA 4.0 |
| Style | Twitter style | Flat/minimalist |
| File size | 2-5 KB/emoji | 3-6 KB/emoji |
| Commercial use | ✅ Yes | ✅ Yes |
| Modification | ✅ Allowed | ✅ Allowed |
| Share-alike | ❌ No | ⚠️ Yes (derivatives) |

**Recommendation**: **Twemoji** for maximum license flexibility

---

## Next Steps

1. Run download script: `python3 🍄/🛠️/📥.py`
2. Verify all 258 SVGs downloaded
3. Add to git: `git add Assets/emoji_svg/`
4. Update atlas builder to use local SVGs
5. Test in-game rendering

---

## Maintenance

When adding new emojis:
1. Add to appropriate source (biomes_merged.json, factions_merged.json, etc.)
2. Re-run extraction: `godot --headless --script /tmp/extract_all_emojis.gd`
3. Update this manifest
4. Re-run download script to fetch new SVGs

Maximum budget: **350 emojis** (92 slots remaining)
