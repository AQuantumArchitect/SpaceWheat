#!/bin/bash
# Quick UI test runner

echo "🎮 Testing Quantum Farm UI..."
echo ""
echo "This will open the farm view for 10 seconds"
echo "You should see:"
echo "  - 5x5 grid of farm plots"
echo "  - Top bar with credits (💰 100) and wheat (🌾 0)"
echo "  - Action buttons at bottom"
echo "  - Info panel showing plot status"
echo ""
echo "Try clicking plots and buttons!"
echo ""

# Run with timeout (--path points to project root)
timeout 30 godot --path .. scenes/FarmView.tscn 2>&1 &

PID=$!
sleep 2

if ps -p $PID > /dev/null; then
    echo "✅ UI is running!"
    echo "Press Ctrl+C or close window to exit"
    wait $PID
else
    echo "❌ UI failed to start"
    exit 1
fi
