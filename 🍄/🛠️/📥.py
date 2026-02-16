#!/usr/bin/env python3
"""
📥 - Download Required Emoji SVGs from Twemoji

Downloads only the 258 emojis needed for SpaceWheat from the Twemoji repository.
Converts emoji characters to Unicode codepoint filenames.

Usage:
    python3 🍄/🛠️/📥.py [--output-dir Assets/emoji_svg] [--source twemoji|openmoji]
"""

import argparse
import json
import os
import sys
import urllib.request
from pathlib import Path


def emoji_to_codepoints(emoji: str) -> str:
    """Convert emoji to Unicode codepoint hex string (Twemoji format)."""
    # Get codepoints for each character
    codepoints = []
    for char in emoji:
        cp = ord(char)
        # Skip variation selectors in some contexts
        if cp == 0xFE0F:  # VS-16
            codepoints.append(f"{cp:x}")
        else:
            codepoints.append(f"{cp:x}")

    return "-".join(codepoints)


def download_emoji_svg(emoji: str, output_dir: Path, source: str = "twemoji") -> bool:
    """Download a single emoji SVG from the source repository."""
    codepoint = emoji_to_codepoints(emoji)

    if source == "twemoji":
        # Twemoji CDN (official)
        url = f"https://cdn.jsdelivr.net/gh/jdecked/twemoji@latest/assets/svg/{codepoint}.svg"
    elif source == "openmoji":
        # OpenMoji uses different naming
        url = f"https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/color/svg/{codepoint.upper()}.svg"
    else:
        print(f"Unknown source: {source}")
        return False

    output_file = output_dir / f"{codepoint}.svg"

    # Skip if already exists
    if output_file.exists():
        print(f"  ✓ {emoji} ({codepoint}.svg) - already exists")
        return True

    try:
        with urllib.request.urlopen(url) as response:
            svg_content = response.read()
            output_file.write_bytes(svg_content)
            print(f"  ✓ {emoji} ({codepoint}.svg) - downloaded")
            return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print(f"  ✗ {emoji} ({codepoint}.svg) - NOT FOUND (404)")
        else:
            print(f"  ✗ {emoji} ({codepoint}.svg) - HTTP {e.code}")
        return False
    except Exception as e:
        print(f"  ✗ {emoji} ({codepoint}.svg) - Error: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Download SpaceWheat emoji SVGs")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("Assets/emoji_svg"),
        help="Output directory for SVG files"
    )
    parser.add_argument(
        "--source",
        choices=["twemoji", "openmoji"],
        default="twemoji",
        help="SVG source repository"
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("🍄/emoji_manifest.json"),
        help="Path to emoji manifest JSON"
    )
    parser.add_argument(
        "--input-list",
        type=Path,
        help="Path to text file with one emoji per line (alternative to --manifest)"
    )
    args = parser.parse_args()

    # Load emojis from either text list or JSON manifest
    if args.input_list:
        if not args.input_list.exists():
            print(f"Error: Input list not found at {args.input_list}")
            sys.exit(1)

        with open(args.input_list, 'r', encoding='utf-8') as f:
            emojis = [line.strip() for line in f if line.strip()]

        total_count = len(emojis)
    else:
        # Load emoji manifest
        if not args.manifest.exists():
            print(f"Error: Manifest not found at {args.manifest}")
            sys.exit(1)

        with open(args.manifest, 'r', encoding='utf-8') as f:
            manifest = json.load(f)

        emojis = manifest["emojis"]
        total_count = manifest["total_count"]

    print(f"📥 Downloading {total_count} emoji SVGs from {args.source}")
    print(f"   Output: {args.output_dir}")
    print()

    # Create output directory
    args.output_dir.mkdir(parents=True, exist_ok=True)

    # Download each emoji
    success_count = 0
    failed_emojis = []

    for i, emoji in enumerate(emojis, 1):
        print(f"[{i}/{total_count}]", end=" ")

        if download_emoji_svg(emoji, args.output_dir, args.source):
            success_count += 1
        else:
            failed_emojis.append(emoji)

    # Summary
    print()
    print("=" * 60)
    print(f"✅ Downloaded: {success_count}/{total_count}")

    if failed_emojis:
        print(f"❌ Failed: {len(failed_emojis)}")
        print()
        print("Failed emojis:")
        for emoji in failed_emojis:
            codepoint = emoji_to_codepoints(emoji)
            print(f"  - {emoji} ({codepoint})")
        print()
        print("Tip: Try alternate source with --source openmoji")
    else:
        print("🎉 All emojis downloaded successfully!")

    print("=" * 60)

    # Create index file
    index_file = args.output_dir / "emoji_index.json"
    index_data = {
        "source": args.source,
        "total": success_count,
        "emojis": {
            emoji: f"{emoji_to_codepoints(emoji)}.svg"
            for emoji in emojis
            if emoji not in failed_emojis
        }
    }

    with open(index_file, 'w', encoding='utf-8') as f:
        json.dump(index_data, f, ensure_ascii=False, indent=2)

    print(f"📄 Created emoji index: {index_file}")


if __name__ == "__main__":
    main()
