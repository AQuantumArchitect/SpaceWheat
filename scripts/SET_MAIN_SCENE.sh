#!/bin/bash

## Quick script to set the main scene in project.godot
## Usage: ./SET_MAIN_SCENE.sh res://scenes/MyNewScene.tscn

if [ -z "$1" ]; then
	echo ""
	echo "=========================================="
	echo "🎬 Godot Main Scene Setter"
	echo "=========================================="
	echo ""
	echo "Usage: ./SET_MAIN_SCENE.sh <scene_path>"
	echo ""
	echo "Example:"
	echo "  ./SET_MAIN_SCENE.sh res://scenes/MainLayout.tscn"
	echo ""
	echo "Current main scene:"
	grep "run/main_scene" project.godot
	echo ""
	exit 1
fi

SCENE_PATH="$1"
PROJECT_FILE="/home/tehcr33d/ws/SpaceWheat/project.godot"

if [ ! -f "$PROJECT_FILE" ]; then
	echo "❌ project.godot not found"
	exit 1
fi

# Backup the file
cp "$PROJECT_FILE" "${PROJECT_FILE}.backup"
echo "✓ Backup created: ${PROJECT_FILE}.backup"

# Update the main_scene setting
sed -i "s|run/main_scene=\".*\"|run/main_scene=\"$SCENE_PATH\"|" "$PROJECT_FILE"

echo "✓ Updated main_scene to: $SCENE_PATH"
echo ""
echo "New setting:"
grep "run/main_scene" "$PROJECT_FILE"
echo ""
echo "To launch: godot"
