# Emoji SVG Assets

This directory contains SVG files for all resource emojis used in SpaceWheat.

**Source**: Generated from `config/emoji_registry.json` (31 emojis)

## Categories

- **Agriculture**: wheat, sprout, detritus, herb, tree
- **Labor**: labor, gear
- **Cosmic**: energy, galaxy, sun, moon, sparkle
- **Economic**: bread, midwife, tomato, gold, credit
- **Elemental**: cold, fire, wind, water, desert
- **Biological**: eagle, mushroom, rabbit, wolf, deer, bull, bear, microbe
- **Political**: crown

## Usage

These SVG files use Unicode emoji rendered as text with system emoji fonts. They're designed for:
- Documentation generation
- Web dashboards
- Automated visualizations
- Cross-platform emoji display

Each file is named by the emoji's canonical name (e.g., `wheat.svg` for 🌾).

## Regeneration

To regenerate these files:

```bash
python3 << 'PYEOF'
from milk_hunt_emoji_registry import all_emojis, emoji_name
from pathlib import Path

SVG_TEMPLATE = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <text x="50" y="50" font-size="72" text-anchor="middle" dominant-baseline="central" font-family="Noto Color Emoji, Apple Color Emoji, Segoe UI Emoji, sans-serif">{emoji}</text>
</svg>'''

output_dir = Path("config/emoji_svg")
for emoji in all_emojis():
    name = emoji_name(emoji)
    svg_content = SVG_TEMPLATE.format(emoji=emoji)
    (output_dir / f"{name}.svg").write_text(svg_content, encoding='utf-8')
PYEOF
```
