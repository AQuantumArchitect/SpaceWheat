# SpaceWheat - Quantum Farm Game

**Version:** 0.1.0
**Platform:** Linux (x86_64)
**Engine:** Godot 4.5

---

## 🎮 About SpaceWheat

SpaceWheat is a quantum farming simulation built on a real density-matrix engine. You start in the enclave — a closed quantum world where evolution is exactly unitary, nothing decays, and your measurements are the only irreversible acts. Superpose, entangle, and collapse your way across biomes; every harvest is a Born sample paid in surprisal. Past the story's edge lies the wet country: open quantum systems where the world itself leaks, watching is the only way to keep, and the reap pays kT·ΔS from the season's entropy.

---

## 🚀 Quick Start

### Linux (Pre-built Binary)

```bash
# Extract and run
tar xzf spacewheat-linux-v0.1.0.tar.gz
cd SpaceWheat
./launch.sh
```

### Building from Source (Recommended)

For the best performance with native C++ quantum simulation:

1. **Clone the repository:**
   ```bash
   git clone --recurse-submodules https://github.com/AQuantumArchitect/SpaceWheat.git
   cd SpaceWheat
   ```

2. **Run the setup script:**
   ```bash
   ./scripts/setup.sh
   ```

3. **Launch the game:**
   ```bash
   godot --path . project.godot
   ```

For detailed instructions, see [BUILDING.md](https://github.com/AQuantumArchitect/SpaceWheat/blob/main/BUILDING.md)

---

## 📦 What's Included

### Linux Release
- `SpaceWheat.x86_64` - Game executable (374 MB)
- `libquantummatrix.*.so` - Native C++ quantum simulation (1.7 MB)
- `launch.sh` - Convenient launcher script
- `README.md` - This file

### Web Release (experimental only)
- Web export exists as an exploratory path, not the primary shipping lane.
- Current repo status is documented in `docs/release/ITCH_STATUS.md` and `docs/EXPORT_HEALTH.md`.

---

## 🔧 System Requirements

### Minimum
- **OS:** Linux, Windows 10+, macOS 10.13+
- **CPU:** Dual-core 2.0 GHz
- **RAM:** 2 GB
- **GPU:** OpenGL 3.3 / Vulkan support
- **Storage:** 500 MB

### Recommended
- **OS:** Linux or Windows
- **CPU:** Quad-core 2.5 GHz
- **RAM:** 4 GB
- **GPU:** Dedicated GPU with Vulkan support
- **Storage:** 1 GB

**Note:** Native C++ extension provides 10-100× better performance than the pure GDScript path.

---

## 🎯 Performance Modes

### Native C++ Mode (desktop shipping path)
- ✅ **Best performance:** native desktop runtime
- ✅ **Fast simulation:** real-time quantum evolution
- ✅ **Recommended for:** Linux and Windows desktop builds

### Pure GDScript Mode
- ⚠️ matrix ops and gates fall back to GDScript; **continuous biome evolution
  does not run without the native extension** (biomes stall rather than evolve)
- ⚠️ useful for debugging and headless physics tests, not for playing
- ℹ️ shipped desktop builds always include the native library

---

## 🛠️ Building C++ Extension

For maximum performance on any platform:

### Linux
```bash
# Install prerequisites
sudo apt-get install build-essential git python3 python3-pip scons

# Clone and build
git clone --recurse-submodules https://github.com/AQuantumArchitect/SpaceWheat.git
cd SpaceWheat
./scripts/setup.sh
```

### Windows
Requires Visual Studio 2019+ or MinGW-w64. See [BUILDING.md](https://github.com/AQuantumArchitect/SpaceWheat/blob/main/BUILDING.md) for detailed instructions.

### macOS
```bash
# Install prerequisites
brew install python scons
xcode-select --install

# Clone and build
git clone --recurse-submodules https://github.com/AQuantumArchitect/SpaceWheat.git
cd SpaceWheat
./scripts/setup.sh
```

---

## 🐛 Troubleshooting

### Game won't start
- **Linux:** Ensure OpenGL 3.3+ or Vulkan drivers installed
- **WSL2:** Set up WSLg for graphics support
- **Check logs:** Look in `~/.local/share/godot/app_userdata/SpaceWheat/logs/`

### Performance issues
- **Check mode:** Look for "GDExtension loaded: QuantumMatrix" in logs
- **If GDScript mode:** Build the native extension (see BUILDING.md) — biome evolution requires it
- **Lower settings:** Reduce quantum node count in game options

### "libGLEW.so.2.1: cannot open shared object file"
```bash
# Debian/Ubuntu
sudo apt-get install libglew2.1

# Fedora
sudo dnf install glew

# Arch
sudo pacman -S glew
```

### WSL2 Graphics
```bash
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
export DISPLAY=:0
./SpaceWheat.x86_64
```

---

## 🤝 Getting Help

### With AI Assistants (Claude, ChatGPT, etc.)

SpaceWheat is designed to be LLM-friendly for building and troubleshooting:

1. **Share your platform:** "I'm on Ubuntu 22.04 / Windows 11 / macOS 14"
2. **Share the error:** Copy the full error message
3. **Reference the docs:** "Check BUILDING.md in the SpaceWheat repo"

Example prompts:
- *"Help me build SpaceWheat on Windows"*
- *"I'm getting libGLEW.so.2.1 error on Ubuntu"*
- *"How do I check if the native extension is loading?"*

### Community
- **GitHub Issues:** https://github.com/AQuantumArchitect/SpaceWheat/issues
- **Discussions:** https://github.com/AQuantumArchitect/SpaceWheat/discussions
- **Discord:** (Coming soon)

---

## 📚 Documentation

- **BUILDING.md** - Comprehensive build guide for all platforms
- **README.md** - Repository overview and getting started
- **docs/** - Architecture, design docs, and technical details

---

## 🎮 Gameplay Tips

1. **Start with the tutorial** - It teaches one mechanic per step; the progress bar is the teacher
2. **Measure carefully** - Collapse is the game's only irreversible act, and rare outcomes pay more
3. **Use entanglement** - Weave qubits with Bell/CNOT gates, then watch a measurement snap both
4. **Press E on everything** - E is inspect: quest offers reveal faction resonance, graph views explain themselves
5. **Farm Berry loops** - Steer a tracked qubit in a closed circle; when it ripens, incorporate the axis
6. **Explore biomes** - Each biome has unique quantum properties

---

## 📝 License

All rights reserved. Contact for licensing inquiries.

---

## 🌟 Feedback

Bug reports and playtest notes are welcome via GitHub Issues.

**Especially useful:**
- Windows export smoke reports
- macOS build attempts
- Web export findings
- Documentation gaps
- Balance/feel notes from real sessions

---

## 🔗 Links

- **Repository:** https://github.com/AQuantumArchitect/SpaceWheat
- **Releases:** https://github.com/AQuantumArchitect/SpaceWheat/releases
- **itch.io:** (Coming soon)
- **Website:** (Coming soon)

---

## 📅 Release Notes

### v0.1.0 (Current)
- ✅ Core quantum farming mechanics
- ✅ Multiple biomes with unique properties
- ✅ Quest system
- ✅ Linux native C++ extension
- ✅ Windows desktop native DLL path
- ⚠️ Web remains experimental
- 🚧 Still in alpha - expect bugs!

---

**Built with ❤️ using Godot Engine 4.5**

For the best experience, build from source with native C++ support!

See BUILDING.md for detailed instructions.
