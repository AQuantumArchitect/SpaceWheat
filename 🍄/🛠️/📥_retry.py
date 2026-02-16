#!/usr/bin/env python3
"""
Retry failed emoji downloads by stripping variation selectors and trying alternate filenames.
"""

import urllib.request
from pathlib import Path
import sys

failed_list = [
    ("0️⃣", "30-fe0f-20e3", "30-20e3"),
    ("1️⃣", "31-fe0f-20e3", "31-20e3"),
    ("2️⃣", "32-fe0f-20e3", "32-20e3"),
    ("3️⃣", "33-fe0f-20e3", "33-20e3"),
    ("4️⃣", "34-fe0f-20e3", "34-20e3"),
    ("5️⃣", "35-fe0f-20e3", "35-20e3"),
    ("6️⃣", "36-fe0f-20e3", "36-20e3"),
    ("7️⃣", "37-fe0f-20e3", "37-20e3"),
    ("8️⃣", "38-fe0f-20e3", "38-20e3"),
    ("9️⃣", "39-fe0f-20e3", "39-20e3"),
    ("‼️", "203c-fe0f", "203c"),
    ("⁉️", "2049-fe0f", "2049"),
    ("ℹ️", "2139-fe0f", "2139"),
    ("↔️", "2194-fe0f", "2194"),
    ("↕️", "2195-fe0f", "2195"),
    ("↖️", "2196-fe0f", "2196"),
    ("↗️", "2197-fe0f", "2197"),
    ("↘️", "2198-fe0f", "2198"),
    ("↙️", "2199-fe0f", "2199"),
    ("↩️", "21a9-fe0f", "21a9"),
    ("⌨️", "2328-fe0f", "2328"),
    ("⏱️", "23f1-fe0f", "23f1"),
    ("⏸️", "23f8-fe0f", "23f8"),
    ("⏹️", "23f9-fe0f", "23f9"),
    ("▪️", "25aa-fe0f", "25aa"),
    ("▫️", "25ab-fe0f", "25ab"),
    ("▶️", "25b6-fe0f", "25b6"),
    ("◻️", "25fb-fe0f", "25fb"),
    ("◼️", "25fc-fe0f", "25fc"),
    ("☁️", "2601-fe0f", "2601"),
    ("☃️", "2603-fe0f", "2603"),
    ("☄️", "2604-fe0f", "2604"),
    ("☢️", "2622-fe0f", "2622"),
    ("☣️", "2623-fe0f", "2623"),
    ("☪️", "262a-fe0f", "262a"),
    ("☮️", "262e-fe0f", "262e"),
    ("☯️", "262f-fe0f", "262f"),
    ("♠️", "2660-fe0f", "2660"),
    ("♣️", "2663-fe0f", "2663"),
    ("♥️", "2665-fe0f", "2665"),
    ("♦️", "2666-fe0f", "2666"),
    ("♻️", "267b-fe0f", "267b"),
    ("♾️", "267e-fe0f", "267e"),
    ("⚒️", "2692-fe0f", "2692"),
    ("⚕️", "2695-fe0f", "2695"),
    ("⚖️", "2696-fe0f", "2696"),
    ("⚗️", "2697-fe0f", "2697"),
    ("⚙️", "2699-fe0f", "2699"),
    ("⚛️", "269b-fe0f", "269b"),
    ("⚜️", "269c-fe0f", "269c"),
    ("⚠️", "26a0-fe0f", "26a0"),
    ("⚰️", "26b0-fe0f", "26b0"),
    ("⚱️", "26b1-fe0f", "26b1"),
    ("⛈️", "26c8-fe0f", "26c8"),
    ("⛏️", "26cf-fe0f", "26cf"),
    ("⛩️", "26e9-fe0f", "26e9"),
    ("⛰️", "26f0-fe0f", "26f0"),
    ("✍️", "270d-fe0f", "270d"),
    ("✏️", "270f-fe0f", "270f"),
    ("✝️", "271d-fe0f", "271d"),
    ("❄️", "2744-fe0f", "2744"),
    ("➡️", "27a1-fe0f", "27a1"),
    ("⬅️", "2b05-fe0f", "2b05"),
    ("⬆️", "2b06-fe0f", "2b06"),
    ("⬇️", "2b07-fe0f", "2b07"),
    ("〰️", "3030-fe0f", "3030"),
    ("🌨️", "1f328-fe0f", "1f328"),
    ("🌩️", "1f329-fe0f", "1f329"),
    ("🌪️", "1f32a-fe0f", "1f32a"),
    ("🍽️", "1f37d-fe0f", "1f37d"),
    ("🎖️", "1f396-fe0f", "1f396"),
    ("🎚️", "1f39a-fe0f", "1f39a"),
    ("🎛️", "1f39b-fe0f", "1f39b"),
    ("🏔️", "1f3d4-fe0f", "1f3d4"),
    ("🏕️", "1f3d5-fe0f", "1f3d5"),
    ("🏗️", "1f3d7-fe0f", "1f3d7"),
    ("🏚️", "1f3da-fe0f", "1f3da"),
    ("🏛️", "1f3db-fe0f", "1f3db"),
    ("🏜️", "1f3dc-fe0f", "1f3dc"),
    ("🏝️", "1f3dd-fe0f", "1f3dd"),
    ("🏞️", "1f3de-fe0f", "1f3de"),
    ("🏳️", "1f3f3-fe0f", "1f3f3"),
    ("🏵️", "1f3f5-fe0f", "1f3f5"),
    ("🏷️", "1f3f7-fe0f", "1f3f7"),
    ("👁️", "1f441-fe0f", "1f441"),
    ("🕉️", "1f549-fe0f", "1f549"),
    ("🕊️", "1f54a-fe0f", "1f54a"),
    ("🕯️", "1f56f-fe0f", "1f56f"),
    ("🕰️", "1f570-fe0f", "1f570"),
    ("🕴️", "1f574-fe0f", "1f574"),
    ("🕵️", "1f575-fe0f", "1f575"),
    ("🕷️", "1f577-fe0f", "1f577"),
    ("🕸️", "1f578-fe0f", "1f578"),
    ("🕹️", "1f579-fe0f", "1f579"),
    ("🖊️", "1f58a-fe0f", "1f58a"),
    ("🖐️", "1f590-fe0f", "1f590"),
    ("🖱️", "1f5b1-fe0f", "1f5b1"),
    ("🖼️", "1f5bc-fe0f", "1f5bc"),
    ("🗜️", "1f5dc-fe0f", "1f5dc"),
    ("🗝️", "1f5dd-fe0f", "1f5dd"),
    ("🗳️", "1f5f3-fe0f", "1f5f3"),
    ("🗺️", "1f5fa-fe0f", "1f5fa"),
    ("🛠️", "1f6e0-fe0f", "1f6e0"),
    ("🛡️", "1f6e1-fe0f", "1f6e1"),
]

output_dir = Path("Assets/emoji_svg")
success = 0
still_failed = []

print(f"🔄 Retrying {len(failed_list)} failed emojis without variation selectors...")
print()

for emoji, orig_code, alt_code in failed_list:
    url = f"https://cdn.jsdelivr.net/gh/jdecked/twemoji@latest/assets/svg/{alt_code}.svg"
    output_file = output_dir / f"{orig_code}.svg"  # Keep original filename

    try:
        with urllib.request.urlopen(url) as response:
            svg_content = response.read()
            output_file.write_bytes(svg_content)
            print(f"  ✓ {emoji} - downloaded as {orig_code}.svg")
            success += 1
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print(f"  ✗ {emoji} - still 404 (tried {alt_code}.svg)")
            still_failed.append((emoji, alt_code))
        else:
            print(f"  ✗ {emoji} - HTTP {e.code}")
            still_failed.append((emoji, alt_code))
    except Exception as e:
        print(f"  ✗ {emoji} - Error: {e}")
        still_failed.append((emoji, alt_code))

print()
print("="*60)
print(f"✅ Recovered: {success}/{len(failed_list)}")

if still_failed:
    print(f"❌ Still failed: {len(still_failed)}")
    print()
    print("Emojis that truly don't exist in Twemoji:")
    for emoji, code in still_failed:
        print(f"  - {emoji} ({code})")
else:
    print("🎉 All failed emojis recovered!")

print("="*60)
