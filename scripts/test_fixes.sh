#!/bin/bash

echo "============================================================"
echo "🧪 TESTING FIXES: String Formatting & Save/Load"
echo "============================================================"
echo ""
echo "This script will:"
echo "1. Plant wheat"
echo "2. Sell wheat (test string formatting fix)"
echo "3. Save game to slot 0"
echo "4. Modify state"
echo "5. Load game from slot 0"
echo "6. Verify state restored"
echo ""
echo "Watch for:"
echo "  ❌ 'String formatting error: a number is required'"
echo "  ❌ 'Invalid assignment of property or key plots'"
echo ""
echo "If you see either error, the fix failed!"
echo ""
echo "Press Enter to start test..."
read

# Run automated playtest
godot --path . --script test_automated_wheat_sale_and_save.gd

echo ""
echo "============================================================"
echo "Test complete! Check output above for errors."
echo "============================================================"
