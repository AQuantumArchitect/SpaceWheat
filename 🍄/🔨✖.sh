#!/bin/bash

# 🔨🔧 - Rebuild Native Library
# Recompiles C++ extensions (quantum evolution, bubble renderer, etc.)

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../native" && pwd)"

echo "🔨 Rebuilding Native Library"
echo "============================="
echo "This will recompile all C++ engines..."
echo ""

make -j"$(nproc)"

echo ""
echo "✅ Build complete! Run ⚙️🔍.sh to verify engines loaded."
