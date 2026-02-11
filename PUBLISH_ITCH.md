# Publishing SpaceWheat to itch.io

This guide walks you through publishing SpaceWheat to itch.io for both Linux and Web platforms.

---

## Prerequisites

1. **itch.io account** - Create at https://itch.io/register
2. **Release builds** - Already prepared:
   - Linux: `releases/linux/spacewheat-linux-v0.1.0.tar.gz` (331 MB)
   - Web: `releases/web/spacewheat-web-v0.1.0.tar.gz` (314 MB)

---

## Step 1: Create New Project on itch.io

1. Go to https://itch.io/game/new
2. Fill in project details:

### Basic Information
- **Title:** SpaceWheat - Quantum Farm
- **Project URL:** spacewheat (or your preferred name)
- **Short description:** "Cultivate quantum crops across biomes. Manage entanglement, decoherence, and quantum states in this unique farming simulation."
- **Classification:** Game
- **Kind of project:** HTML / Downloadable

### Pricing
- **Pricing:** Free or Pay-what-you-want (recommended for alpha)
- **Minimum price:** $0 (if pay-what-you-want)

### Uploads

#### For Linux Build
1. Click "Upload files"
2. Select: `releases/linux/spacewheat-linux-v0.1.0.tar.gz`
3. **This file will be:** Downloadable
4. **Kind of file:** Linux
5. **Display name:** SpaceWheat Linux (v0.1.0)
6. **Architecture:** 64-bit only

#### For Web Build
1. Click "Upload files"
2. Select: `releases/web/spacewheat-web-v0.1.0.tar.gz`
3. **This file will be:** Playable in browser
4. **Extract and play:** ✅ Checked
5. **Index file:** SpaceWheat/SpaceWheat.html
6. **Display name:** SpaceWheat Web (v0.1.0)
7. **Embed options:**
   - Width: 1920
   - Height: 1080
   - Orientation: Landscape
   - Mobile friendly: ✅ Checked

**Note:** Web version uses GDScript fallback (slower). Linux version has native C++ extension (60 FPS).

### Details

#### Genre & Tags
- **Genre:** Simulation, Strategy
- **Tags:**
  - quantum
  - farming
  - simulation
  - puzzle
  - science
  - godot
  - indie
  - casual
  - strategy
  - experimental

#### Release Status
- **Release status:** In development
- **Development stage:** Alpha

#### Description (Markdown)

```markdown
# SpaceWheat - Quantum Farm

**Cultivate quantum crops using real quantum mechanics principles!**

## 🎮 About

SpaceWheat is a unique farming simulation where you manage quantum states, entanglement, and decoherence to maximize your harvest. Each biome has different quantum properties that affect how your crops grow.

## ✨ Features

- 🌾 **Quantum Farming** - Real quantum mechanics simulation
- 🌍 **Multiple Biomes** - Each with unique quantum properties
- 🔗 **Entanglement System** - Link plots for coordinated effects
- 📊 **Decoherence Management** - Keep quantum states stable
- 🎯 **Quest System** - Learn and master quantum farming

## 🚀 Performance Notes

### Linux Build (Recommended)
- ✅ **Native C++ extension** - 60 FPS, 100+ quantum nodes
- ✅ **Best performance** - Real-time quantum evolution
- **Requirements:** Linux x86_64, OpenGL 3.3+

### Web Build
- ⚠️ **GDScript fallback** - 6-30 FPS, ~20 quantum nodes
- ⚠️ **Playable but slower** - No native compilation
- **Works in:** Chrome, Firefox, Safari, Edge (modern versions)

## 🛠️ Building from Source

Want better performance? Build the native C++ extension yourself!

See [BUILDING.md](https://github.com/AQuantumArchitect/SpaceWheat/blob/main/BUILDING.md) for detailed instructions. Works on Linux, Windows, and macOS.

**Quick start (Linux):**
```bash
git clone --recurse-submodules https://github.com/AQuantumArchitect/SpaceWheat.git
cd SpaceWheat
./scripts/setup.sh
```

## 🐛 Known Issues (Alpha)

- Web version performance is limited (GDScript fallback)
- Some UI elements need polish
- Balance is still being tuned
- Save/load may have edge cases

## 🤝 Feedback

This is an **alpha release** - your feedback is invaluable!

- **GitHub:** https://github.com/AQuantumArchitect/SpaceWheat/issues
- **itch.io comments:** Use the comments below!
- **Discord:** (Coming soon)

## 📚 More Info

- **Repository:** https://github.com/AQuantumArchitect/SpaceWheat
- **Build Guide:** [BUILDING.md](https://github.com/AQuantumArchitect/SpaceWheat/blob/main/BUILDING.md)
- **License:** Open Source (see LICENSE)

---

**Built with ❤️ using Godot Engine 4.5**
```

#### Screenshots (Add later)
Take screenshots of:
1. Main farm view with quantum bubbles
2. Biome selection screen
3. Quest board
4. Quantum measurement effect
5. Entanglement visualization

#### Cover Image (Add later)
Recommended size: 630 x 500 pixels

---

## Step 2: Configure Advanced Settings

### Metadata
- **Engine:** Godot
- **Made with:** Godot 4.5
- **Average session:** 15-30 minutes
- **Languages:** English
- **Inputs:** Keyboard, Mouse
- **Multiplayer:** Singleplayer

### Access
- **Visibility:** Public (or Restricted for early testing)
- **Comments:** Enabled
- **Ratings:** Enabled

### Community
- **Enable Devlog:** ✅ (Post development updates)
- **Enable Discussion:** ✅ (For feedback and questions)

---

## Step 3: Save and Publish

1. Click **Save & view page** (saves as draft)
2. Review your page
3. Click **Edit game** if changes needed
4. When ready: **Publish**

---

## Step 4: After Publishing

### Announce
- Post on your social media
- Share in game dev communities
- Post devlog on itch.io

### Monitor
- Check itch.io analytics
- Read comments and respond
- Track downloads vs. web plays

### Update
When you have updates:
1. Build new version
2. Upload with version number in filename
3. Post devlog announcing changes
4. Consider marking old versions as "archived"

---

## Using Butler (Optional - For Easy Updates)

Butler is itch.io's command-line upload tool.

### Install Butler
```bash
# Linux
curl -L -o butler.zip https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default
unzip butler.zip
chmod +x butler
sudo mv butler /usr/local/bin/

# Authenticate
butler login
```

### Upload with Butler
```bash
# Linux build
butler push releases/linux/spacewheat-linux-v0.1.0.tar.gz yourname/spacewheat:linux-x64

# Web build
butler push releases/web/spacewheat-web-v0.1.0.tar.gz yourname/spacewheat:web
```

Replace `yourname/spacewheat` with your actual itch.io username and project URL.

---

## Versioning Strategy

### Version Numbers
- **Format:** vMAJOR.MINOR.PATCH (e.g., v0.1.0, v0.2.1)
- **Alpha:** v0.x.x
- **Beta:** v0.9.x
- **Release:** v1.0.0+

### Changelog in Devlogs
When uploading new versions, post a devlog with:
```markdown
## v0.2.0 - 2026-02-15

### Added
- New biome: Quantum Crystals
- Tutorial system
- Save/load improvements

### Fixed
- Measurement timing issues
- UI scaling on 4K displays
- Memory leak in quantum evolution

### Changed
- Rebalanced decoherence rates
- Improved entanglement visuals
```

---

## File Size Optimization (Future)

If file sizes become an issue:

### For Linux
```bash
# Strip debug symbols (reduces by ~30%)
strip releases/linux/SpaceWheat/SpaceWheat.x86_64
strip releases/linux/SpaceWheat/*.so

# Repackage
tar czf releases/linux/spacewheat-linux-v0.1.0.tar.gz SpaceWheat/
```

### For Web
```bash
# Already optimized by Godot export
# Consider enabling compression in export_presets.cfg:
# - vram_texture_compression/for_desktop=true
# - progressive_web_app/enabled=true
```

---

## Marketing Description (For itch.io and Press)

### Short Pitch (1 sentence)
"SpaceWheat is a quantum farming simulation where you cultivate crops using real quantum mechanics - manage entanglement, decoherence, and measurement collapse across unique biomes."

### Medium Description (1 paragraph)
"In SpaceWheat, quantum mechanics meets farming simulation. Grow quantum wheat, tomatoes, and exotic crops across diverse biomes, each with unique quantum properties. Master entanglement to link plots, manage decoherence to keep states stable, and time your measurements perfectly to maximize harvest. Built with real quantum physics principles and powered by a native C++ quantum simulation engine for smooth 60 FPS gameplay."

### Long Description (Press kit)
"SpaceWheat reimagines farming simulation through the lens of quantum mechanics. Players cultivate quantum crops where superposition, entanglement, and measurement collapse aren't just mechanics—they're the core gameplay. Each biome presents unique quantum environments: the Starter Forest with gentle coherence times, the Volcanic Worlds with high-energy states, or the Biotic Flux with living quantum systems.

The game features a complete quantum computer simulation under the hood, handling real density matrices and quantum evolution. While approachable for casual players, it offers genuine depth for those interested in quantum computing concepts. The native C++ extension provides smooth 60 FPS even with dozens of entangled quantum nodes evolving in real-time.

Built in Godot 4.5, SpaceWheat is open source and designed for easy modification and learning. Whether you want to understand quantum mechanics through play or just enjoy a unique farming experience, SpaceWheat offers something genuinely different."

---

## Press Kit (Create Later)

### Include:
1. **Logo** (various sizes)
2. **Screenshots** (high-res, 1920x1080)
3. **GIFs** (gameplay highlights)
4. **Trailer** (optional, 30-60 seconds)
5. **Fact Sheet:**
   - Developer name
   - Release date
   - Platforms
   - Engine (Godot 4.5)
   - Price (Free/Pay-what-you-want)
   - Links (itch.io, GitHub, etc.)
6. **Contact** (email, Discord, etc.)

---

## License Note

Make sure to include license information:
- SpaceWheat itself (your license)
- Godot Engine (MIT)
- godot-cpp (MIT)
- Any assets used (check licenses)

---

## Success Metrics

Track these after publishing:
- **Downloads:** Linux vs. Web
- **Play sessions:** Web build analytics
- **Comments:** Feedback and suggestions
- **Ratings:** Overall reception
- **External traffic:** GitHub stars, Discord joins

---

## Next Steps After First Release

1. **Gather Feedback** - Read all comments
2. **Fix Critical Bugs** - Priority issues first
3. **Performance Improvements** - Optimize slow areas
4. **Windows Build** - Once you have bigger machine
5. **macOS Build** - If you have access to Mac
6. **Content Updates** - New biomes, crops, mechanics
7. **Polish** - UI/UX improvements, tutorial, etc.

---

**Good luck with your launch! 🚀**

For questions, see GitHub issues or post on your itch.io discussion board.
