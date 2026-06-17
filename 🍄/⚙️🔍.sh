#!/bin/bash

# ⚙️🔍 - Native Engine Status Check
# Quick diagnostic for GPU batching and C++ acceleration

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # repo root (script lives in the mushroom dir)

echo "⚙️ Native Engine Status Check"
echo "=============================="
echo "Checking which engines are loaded..."
echo ""

godot BubbleStressTest.tscn   # the stress scene was renamed/moved to the repo root
