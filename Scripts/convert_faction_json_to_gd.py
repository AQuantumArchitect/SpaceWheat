#!/usr/bin/env python3
"""
Convert faction database from JSON to GDScript format
Reads spacewheat_factions_db_v0_4.json and generates FactionDatabase.gd
"""

import json
import sys
from pathlib import Path

def sanitize_const_name(name: str) -> str:
    """Convert faction name to valid GDScript constant name"""
    # Replace spaces and special chars with underscores
    const_name = name.upper().replace(" ", "_").replace("'", "").replace("-", "_")
    # Remove any other non-alphanumeric chars
    const_name = "".join(c if c.isalnum() or c == "_" else "_" for c in const_name)
    return const_name

def format_bits_array(bits: list) -> str:
    """Format bits array as GDScript array literal"""
    return "[" + ", ".join(str(b) for b in bits) + "]"

def format_signature_array(signature: list) -> str:
    """Format signature emoji array as GDScript array literal"""
    # Escape quotes in emojis (though unlikely needed)
    escaped = ['"{}"'.format(e) for e in signature]
    return "[" + ", ".join(escaped) + "]"

def generate_gdscript(json_data: dict) -> str:
    """Generate complete GDScript file from JSON data"""

    lines = []

    # Header
    lines.append("class_name FactionDatabase")
    lines.append("extends Resource")
    lines.append("")
    lines.append("## Complete database of 32 factions with 12-bit classification patterns")
    lines.append("## Generated from spacewheat_factions_db_v0_4.json")
    lines.append("## Each faction has: name, signature (emoji array), 12-bit pattern, category, description")
    lines.append("")

    # Add axial spine metadata
    lines.append("# " + "=" * 77)
    lines.append("# AXIAL SPINE METADATA")
    lines.append("# " + "=" * 77)
    lines.append("")
    axial_spine = json_data.get("axial_spine", {})
    lines.append(f'const VERSION = "{axial_spine.get("version", "0.4")}"')
    lines.append("")
    lines.append("const AXES = [")
    for axis in axial_spine.get("axes", []):
        lines.append("\t{")
        lines.append(f'\t\t"bit": {axis["bit"]},')
        lines.append(f'\t\t"name": "{axis["name"]}",')
        lines.append(f'\t\t"0": "{axis["0"]}",')
        lines.append(f'\t\t"1": "{axis["1"]}"')
        lines.append("\t},")
    lines.append("]")
    lines.append("")

    # Group factions by category
    factions_by_category = {}
    for faction in json_data.get("factions", []):
        category = faction.get("category", "Uncategorized")
        if category not in factions_by_category:
            factions_by_category[category] = []
        factions_by_category[category].append(faction)

    # Generate faction constants grouped by category
    for category, factions in factions_by_category.items():
        lines.append("# " + "=" * 77)
        lines.append(f"# {category.upper()} ({len(factions)} faction{'s' if len(factions) != 1 else ''})")
        lines.append("# " + "=" * 77)
        lines.append("")

        for faction in factions:
            const_name = sanitize_const_name(faction["name"])
            lines.append(f"const {const_name} = {{")
            lines.append(f'\t"name": "{faction["name"]}",')
            lines.append(f'\t"signature": {format_signature_array(faction["signature"])},')
            lines.append(f'\t"bits": {format_bits_array(faction["bits"])},')
            lines.append(f'\t"category": "{faction["category"]}",')

            # Handle multiline descriptions
            desc = faction.get("description", "")
            if "\n" in desc:
                # Multiline string
                lines.append('\t"description": """')
                lines.append(desc)
                lines.append('"""')
            else:
                # Single line
                lines.append(f'\t"description": "{desc}"')

            lines.append("}")
            lines.append("")

    # Generate ALL_FACTIONS array
    lines.append("# " + "=" * 77)
    lines.append("# ALL FACTIONS ARRAY")
    lines.append("# " + "=" * 77)
    lines.append("")
    lines.append("const ALL_FACTIONS = [")
    for faction in json_data.get("factions", []):
        const_name = sanitize_const_name(faction["name"])
        lines.append(f"\t{const_name},")
    lines.append("]")
    lines.append("")

    # Helper functions
    lines.append("# " + "=" * 77)
    lines.append("# HELPER FUNCTIONS")
    lines.append("# " + "=" * 77)
    lines.append("")
    lines.append("static func get_faction_by_name(name: String) -> Dictionary:")
    lines.append('\t"""Find faction by name (case-insensitive)"""')
    lines.append("\tvar name_lower = name.to_lower()")
    lines.append("\tfor faction in ALL_FACTIONS:")
    lines.append('\t\tif faction["name"].to_lower() == name_lower:')
    lines.append("\t\t\treturn faction")
    lines.append("\treturn {}")
    lines.append("")

    lines.append("static func get_factions_by_category(category: String) -> Array:")
    lines.append('\t"""Get all factions in a category"""')
    lines.append("\tvar result = []")
    lines.append("\tfor faction in ALL_FACTIONS:")
    lines.append('\t\tif faction["category"] == category:')
    lines.append("\t\t\tresult.append(faction)")
    lines.append("\treturn result")
    lines.append("")

    lines.append("static func get_signature_string(faction: Dictionary, max_emojis: int = 3) -> String:")
    lines.append('\t"""Convert signature array to string (first N emojis)"""')
    lines.append('\tvar sig = faction.get("signature", [])')
    lines.append('\treturn "".join(sig.slice(0, max_emojis))')
    lines.append("")

    return "\n".join(lines)

def main():
    # Paths
    project_root = Path(__file__).parent.parent
    json_path = project_root / "llm_inbox" / "spacewheat_factions_db_v0_4.json"
    output_path = project_root / "Core" / "Quests" / "FactionDatabase.gd"

    # Check if JSON exists
    if not json_path.exists():
        print(f"❌ Error: {json_path} not found!", file=sys.stderr)
        return 1

    # Load JSON
    print(f"📖 Reading {json_path}...")
    with open(json_path, 'r', encoding='utf-8') as f:
        json_data = json.load(f)

    faction_count = len(json_data.get("factions", []))
    print(f"✓ Loaded {faction_count} factions")

    # Generate GDScript
    print("🔧 Generating GDScript...")
    gdscript_content = generate_gdscript(json_data)

    # Write output
    print(f"💾 Writing to {output_path}...")
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(gdscript_content)

    print(f"✅ Done! Generated FactionDatabase.gd with {faction_count} factions")
    print(f"⚠️  Note: This uses 'signature' (array) instead of 'emoji' (string)")
    print(f"   You'll need to update code that references faction.emoji")

    return 0

if __name__ == "__main__":
    sys.exit(main())
