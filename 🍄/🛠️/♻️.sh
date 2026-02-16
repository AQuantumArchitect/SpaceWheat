#!/bin/bash

# ♻️ - Reset & Rebuild C++
# Clean rebuild of godot-cpp bindings + native library (quantum evolution, bubble renderer, etc.)

PROJECT_ROOT="/home/primearchitect/ws/SpaceWheat"

echo "♻️ Reset & Rebuild C++ Native Library"
echo "======================================="
echo ""

# Step 1: Rebuild godot-cpp bindings
echo "📚 Step 1/2: Rebuilding godot-cpp bindings..."
echo "─────────────────────────────────────────────"
cd "$PROJECT_ROOT/godot-cpp"

scons platform=linux target=template_release -j$(nproc)

echo ""
echo "✅ godot-cpp bindings complete!"
echo ""

# Step 2: Rebuild native library
echo "🔧 Step 2/2: Rebuilding native library..."
echo "─────────────────────────────────────────────"
cd "$PROJECT_ROOT/native"

make clean

echo ""
make -j$(nproc)

echo ""
echo "✅ Clean rebuild complete!"
echo ""
echo "📦 Built library:"
ls -lh bin/linux/*.so 2>/dev/null || echo "⚠️  No Linux library found"
echo ""
echo "Run ⚙️🔍.sh from 🍄/ to verify engines loaded."
