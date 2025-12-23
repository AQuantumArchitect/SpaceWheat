#!/usr/bin/env python3
"""
Repair save files and scenarios to match current GameState format

Current format expectations:
- Grid: 6x1 (6 width, 1 height)
- Each plot must have: position, type, is_planted, has_been_measured, theta_frozen, entangled_with
- No quantum state details (theta, phi, radius, energy) - those regenerate from biome
- No obsolete fields (growth_progress, is_mature)
"""

import re
import sys
from pathlib import Path

class GameStateRepair:
    def __init__(self, file_path):
        self.file_path = Path(file_path)
        self.content = None
        self.plots = []

    def load(self):
        """Load the .tres file"""
        with open(self.file_path, 'r') as f:
            self.content = f.read()
        print(f"  ✓ Loaded {self.file_path.name} ({len(self.content)} bytes)")

    def extract_plots(self):
        """Extract plot array from file content"""
        # Find the plots array
        plots_match = re.search(r'plots = \[(.*?)\](?=\s*\n\s*\w)', self.content, re.DOTALL)
        if not plots_match:
            print("  ❌ Could not find plots array")
            return False

        plots_str = plots_match.group(1)

        # Split by plot dictionaries
        plot_matches = re.findall(r'\{[^}]*\}', plots_str)
        print(f"  Found {len(plot_matches)} plots in file")

        for i, plot_str in enumerate(plot_matches):
            plot_dict = self._parse_dict(plot_str)
            if plot_dict:
                self.plots.append(plot_dict)
            else:
                print(f"    ⚠️  Could not parse plot {i}")

        return True

    def _parse_dict(self, dict_str):
        """Parse a dictionary string into a Python dict"""
        result = {}

        # Extract position
        pos_match = re.search(r'"position":\s*Vector2i\((\d+),\s*(\d+)\)', dict_str)
        if pos_match:
            result['position'] = (int(pos_match.group(1)), int(pos_match.group(2)))

        # Extract type
        type_match = re.search(r'"type":\s*(\d+)', dict_str)
        if type_match:
            result['type'] = int(type_match.group(1))

        # Extract is_planted
        planted_match = re.search(r'"is_planted":\s*(true|false)', dict_str)
        if planted_match:
            result['is_planted'] = planted_match.group(1) == 'true'

        # Extract has_been_measured
        measured_match = re.search(r'"has_been_measured":\s*(true|false)', dict_str)
        if measured_match:
            result['has_been_measured'] = measured_match.group(1) == 'true'

        # Extract entangled_with
        entangled_match = re.search(r'"entangled_with":\s*\[(.*?)\]', dict_str)
        if entangled_match:
            result['entangled_with'] = []

        return result if result else None

    def repair(self):
        """Repair the save file"""
        print("\n  🔧 Repairing file...")

        # Create new plots array with correct format
        # Standard grid: 6x1
        new_plots = []
        for x in range(6):
            for y in range(1):
                # Try to find matching plot in old data
                old_plot = None
                for p in self.plots:
                    if p.get('position') == (x, y):
                        old_plot = p
                        break

                # Create new plot with correct format
                new_plot = {
                    'position': f'Vector2i({x}, {y})',
                    'type': old_plot.get('type', 0) if old_plot else 0,
                    'is_planted': old_plot.get('is_planted', False) if old_plot else False,
                    'has_been_measured': old_plot.get('has_been_measured', False) if old_plot else False,
                    'theta_frozen': False,
                    'entangled_with': []
                }
                new_plots.append(new_plot)

        # Build the new plots array string
        plots_str = "plots = ["
        for plot in new_plots:
            plot_str = "{ "
            plot_str += f'"position": {plot["position"]}, '
            plot_str += f'"type": {plot["type"]}, '
            plot_str += f'"is_planted": {"true" if plot["is_planted"] else "false"}, '
            plot_str += f'"has_been_measured": {"true" if plot["has_been_measured"] else "false"}, '
            plot_str += f'"theta_frozen": false, '
            plot_str += '"entangled_with": [] }'
            plots_str += plot_str + ", "
        plots_str += "]"

        # Replace old plots array with new one
        self.content = re.sub(
            r'plots = \[[^\]]*\]',
            plots_str,
            self.content,
            flags=re.DOTALL
        )

        # Ensure grid dimensions are correct
        self.content = re.sub(r'grid_width = \d+', 'grid_width = 6', self.content)
        self.content = re.sub(r'grid_height = \d+', 'grid_height = 1', self.content)

        # Remove obsolete fields if present (shouldn't be in .tres but just in case)
        print("  ✓ Repaired file structure")
        return True

    def save(self, output_path=None):
        """Save the repaired file"""
        target_path = output_path or self.file_path
        with open(target_path, 'w') as f:
            f.write(self.content)
        print(f"  ✓ Saved repaired file to {target_path.name}")

    def summarize(self):
        """Print summary of changes"""
        print("\n  📊 Repair Summary:")
        print(f"    - Original plots: {len(self.plots)}")
        print(f"    - New grid size: 6x1")
        print(f"    - Removed obsolete fields: theta, phi, growth_progress, is_mature")
        print(f"    - Added missing fields: theta_frozen")

def main():
    print("\n" + "="*70)
    print("🔧 SPACEWHEAT SAVE FILE REPAIR TOOL")
    print("="*70)

    scenario_path = "/home/tehcr33d/ws/SpaceWheat/Scenarios/default.tres"

    print("\n▶ Repairing scenario file...")
    print("-"*70)

    repair = GameStateRepair(scenario_path)
    repair.load()

    if repair.extract_plots():
        if repair.repair():
            repair.summarize()
            repair.save()
            print("\n✅ Scenario file repaired successfully!")
        else:
            print("\n❌ Failed to repair file")
            sys.exit(1)
    else:
        print("\n❌ Failed to extract plots")
        sys.exit(1)

    print("\n" + "="*70)
    print("✅ REPAIR COMPLETE")
    print("="*70 + "\n")

if __name__ == "__main__":
    main()
