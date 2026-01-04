#!/usr/bin/env python3
"""
Convert spacewheat_faction_lexicon_v2.1.json to FactionDatabaseV2.gd

This script converts the rich v2.1 faction lexicon (with motto, description, domain, ring)
into a GDScript format for use in SpaceWheat.

New fields in v2.1:
- motto: Short tagline for the faction
- description: Rich flavor text explaining the faction
- domain: Category (Commerce, Civic, Infrastructure, Science, Military, Criminal, Horror, Mystic)
- ring: Position in hierarchy (center, first, second, third, outer)
"""

import json
import sys
from pathlib import Path


def escape_gdscript_string(s: str) -> str:
    """Escape a string for GDScript"""
    if s is None:
        return '""'
    # Escape backslashes first, then quotes
    s = s.replace('\\', '\\\\')
    s = s.replace('"', '\\"')
    # Escape newlines
    s = s.replace('\n', '\\n')
    return f'"{s}"'


def format_emoji_array(emojis: list) -> str:
    """Format an emoji array for GDScript"""
    if not emojis:
        return "[]"
    emoji_strs = [f'"{emoji}"' for emoji in emojis]
    return f"[{', '.join(emoji_strs)}]"


def format_bits_array(bits: list) -> str:
    """Format a bits array for GDScript"""
    if not bits:
        return "[]"
    return f"[{', '.join(str(b) for b in bits)}]"


def convert_json_to_gdscript(json_path: Path, output_path: Path):
    """Convert faction lexicon JSON to GDScript"""

    # Load JSON
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Start building GDScript file
    gd_lines = []

    # Header
    gd_lines.append("class_name FactionDatabaseV2")
    gd_lines.append("extends RefCounted")
    gd_lines.append("")
    gd_lines.append("## Faction Database v2.1")
    gd_lines.append("## Generated from spacewheat_faction_lexicon_v2.1.json")
    gd_lines.append(f"## Contains {len(data['factions'])} factions with rich flavor text, mottos, and lore")
    gd_lines.append("")

    # Meta information
    meta = data.get('meta', {})
    gd_lines.append("## Meta Information")
    gd_lines.append(f"const VERSION = {escape_gdscript_string(data.get('version', 'v2.1'))}")
    gd_lines.append(f"const TITLE = {escape_gdscript_string(data.get('title', 'SpaceWheat Faction Lexicon'))}")
    gd_lines.append("")
    gd_lines.append("const META = {")
    gd_lines.append(f"	\"design_philosophy\": {escape_gdscript_string(meta.get('design_philosophy', ''))},")
    gd_lines.append(f"	\"player_start\": {escape_gdscript_string(meta.get('player_start', ''))},")
    gd_lines.append(f"	\"shadow_path\": {escape_gdscript_string(meta.get('shadow_path', ''))},")
    gd_lines.append(f"	\"quantum_awareness\": {escape_gdscript_string(meta.get('quantum_awareness', ''))},")
    gd_lines.append(f"	\"patch_notes\": {escape_gdscript_string(meta.get('patch_notes', ''))}")
    gd_lines.append("}")
    gd_lines.append("")

    # Axial spine
    axial = data.get('axial_spine', {})
    gd_lines.append("## Axial Spine (Bit Encoding)")
    gd_lines.append("const AXIAL_SPINE = {")
    gd_lines.append(f"	\"version\": {escape_gdscript_string(axial.get('version', '1.4'))},")
    gd_lines.append("	\"axes\": [")
    for axis in axial.get('axes', []):
        gd_lines.append("		{")
        gd_lines.append(f"			\"bit\": {axis.get('bit', 0)},")
        gd_lines.append(f"			\"name\": {escape_gdscript_string(axis.get('name', ''))},")
        gd_lines.append(f"			\"0\": {escape_gdscript_string(axis.get('0', ''))},")
        gd_lines.append(f"			\"1\": {escape_gdscript_string(axis.get('1', ''))}")
        gd_lines.append("		},")
    gd_lines.append("	]")
    gd_lines.append("}")
    gd_lines.append("")

    # Faction count and rings
    rings = set()
    domains = set()
    for faction in data['factions']:
        rings.add(faction.get('ring', 'unknown'))
        domains.add(faction.get('domain', 'unknown'))

    gd_lines.append("## Statistics")
    gd_lines.append(f"const TOTAL_FACTIONS = {len(data['factions'])}")
    gd_lines.append(f"const RINGS = {sorted(list(rings))}")
    gd_lines.append(f"const DOMAINS = {sorted(list(domains))}")
    gd_lines.append("")

    # All factions array
    gd_lines.append("## All Factions")
    gd_lines.append("const ALL_FACTIONS = [")

    for i, faction in enumerate(data['factions']):
        gd_lines.append("	{")
        gd_lines.append(f"		\"name\": {escape_gdscript_string(faction.get('name', 'Unknown'))},")
        gd_lines.append(f"		\"domain\": {escape_gdscript_string(faction.get('domain', 'Unknown'))},")
        gd_lines.append(f"		\"ring\": {escape_gdscript_string(faction.get('ring', 'unknown'))},")
        gd_lines.append(f"		\"bits\": {format_bits_array(faction.get('bits', []))},")
        gd_lines.append(f"		\"sig\": {format_emoji_array(faction.get('sig', []))},")

        # Motto (can be null)
        motto = faction.get('motto')
        if motto is None:
            gd_lines.append(f"		\"motto\": null,")
        else:
            gd_lines.append(f"		\"motto\": {escape_gdscript_string(motto)},")

        gd_lines.append(f"		\"description\": {escape_gdscript_string(faction.get('description', ''))}")

        # Close faction dict (last one has no comma)
        if i < len(data['factions']) - 1:
            gd_lines.append("	},")
        else:
            gd_lines.append("	}")

    gd_lines.append("]")
    gd_lines.append("")

    # Helper functions
    gd_lines.append("")
    gd_lines.append("## Helper Functions")
    gd_lines.append("")
    gd_lines.append("static func get_faction_by_name(name: String) -> Dictionary:")
    gd_lines.append("	\"\"\"Get faction by name\"\"\"")
    gd_lines.append("	for faction in ALL_FACTIONS:")
    gd_lines.append("		if faction.name == name:")
    gd_lines.append("			return faction")
    gd_lines.append("	return {}")
    gd_lines.append("")
    gd_lines.append("static func get_factions_by_ring(ring: String) -> Array:")
    gd_lines.append("	\"\"\"Get all factions in a specific ring\"\"\"")
    gd_lines.append("	var result = []")
    gd_lines.append("	for faction in ALL_FACTIONS:")
    gd_lines.append("		if faction.ring == ring:")
    gd_lines.append("			result.append(faction)")
    gd_lines.append("	return result")
    gd_lines.append("")
    gd_lines.append("static func get_factions_by_domain(domain: String) -> Array:")
    gd_lines.append("	\"\"\"Get all factions in a specific domain\"\"\"")
    gd_lines.append("	var result = []")
    gd_lines.append("	for faction in ALL_FACTIONS:")
    gd_lines.append("		if faction.domain == domain:")
    gd_lines.append("			result.append(faction)")
    gd_lines.append("	return result")
    gd_lines.append("")
    gd_lines.append("static func get_faction_emoji(faction: Dictionary) -> String:")
    gd_lines.append("	\"\"\"Get first emoji from faction signature as display emoji\"\"\"")
    gd_lines.append("	if faction.has(\"sig\") and faction.sig.size() > 0:")
    gd_lines.append("		return faction.sig[0]")
    gd_lines.append("	return \"❓\"")
    gd_lines.append("")
    gd_lines.append("static func get_faction_signature_string(faction: Dictionary) -> String:")
    gd_lines.append("	\"\"\"Get faction signature as emoji string\"\"\"")
    gd_lines.append("	if faction.has(\"sig\"):")
    gd_lines.append("		return \"\".join(faction.sig)")
    gd_lines.append("	return \"\"")
    gd_lines.append("")

    # Write to file
    output_content = "\n".join(gd_lines)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(output_content)

    print(f"✅ Converted {len(data['factions'])} factions from {json_path} to {output_path}")
    print(f"   Rings: {', '.join(sorted(rings))}")
    print(f"   Domains: {', '.join(sorted(domains))}")
    print(f"   Output size: {len(output_content)} characters, {len(gd_lines)} lines")


if __name__ == "__main__":
    # Get paths
    script_dir = Path(__file__).parent
    json_path = script_dir / "llm_inbox" / "spacewheat_faction_lexicon_v2.1.json"
    output_path = script_dir / "Core" / "Quests" / "FactionDatabaseV2.gd"

    # Check if input exists
    if not json_path.exists():
        print(f"❌ Error: Input file not found: {json_path}")
        sys.exit(1)

    # Convert
    try:
        convert_json_to_gdscript(json_path, output_path)
    except Exception as e:
        print(f"❌ Error during conversion: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
