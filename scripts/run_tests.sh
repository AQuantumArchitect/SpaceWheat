#!/bin/bash
# Quick test runner for SpaceWheat quantum substrate

echo "======================================="
echo "SpaceWheat Quantum Substrate Test"
echo "======================================="
echo ""

# Find Godot executable
GODOT=""
if command -v godot4 &> /dev/null; then
    GODOT="godot4"
elif command -v godot &> /dev/null; then
    GODOT="godot"
else
    echo "❌ Godot not found in PATH"
    echo "Please install Godot 4.3+ or add it to PATH"
    echo ""
    echo "Alternatives:"
    echo "  1. Open project in Godot Editor"
    echo "  2. Run scene: scenes/test_quantum_substrate.tscn"
    exit 1
fi

echo "✓ Found Godot: $GODOT"
echo ""

# Check Godot version
VERSION=$($GODOT --version 2>&1 | head -1)
echo "Godot version: $VERSION"
echo ""

# Run tests
echo "Running quantum substrate tests..."
echo "-----------------------------------"
$GODOT --headless --path . scenes/test_quantum_substrate.tscn 2>&1

echo ""
echo "======================================="
echo "Tests complete!"
echo "======================================="
echo ""
echo "To see visual debugger:"
echo "  $GODOT --path . scenes/quantum_network_visualizer.tscn"
