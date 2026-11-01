#!/usr/bin/env python3
"""Pack SpaceWheat as a small headless player bundle.

A headless run needs no pictures and no music: the rig (🍄/🎛️/rig_listener.gd)
drives the game through its own input events and reads the guide's banner, and
the follower (🍄/🧪/banner_follow.py) presses only the keys that banner names.
So the bundle is the tracked source minus Assets/Audio and Assets/Biomes (the
two ~530 MB trees), docs, tests, releases, web and the non-Linux native
libraries, plus (optionally) the Godot binary and a warm import cache.

    python3 tools/headless_bundle.py                      # source only  -> dist/spacewheat-headless.tar.gz
    python3 tools/headless_bundle.py --godot /usr/local/bin/godot
    python3 tools/headless_bundle.py --out /tmp/sw.tar.gz --no-import-cache

On the host (needs only glibc; the Godot binary does not link X11 or audio):

    tar -xzf spacewheat-headless.tar.gz && cd spacewheat-headless
    ./godot --headless --path . --import          # once, ~45 s, unless the cache shipped
    python3 "🍄/🧪/banner_follow.py" fresh --journey 25 --until island_free

The bundle is a player, not a release: nothing here is exported or signed.
"""
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAME = "spacewheat-headless"

# Tracked paths a headless player never reads.
DROP = re.compile(
    r"^(Assets/(Audio|Biomes)/|Assets/spacewheat_titlecard|docs/|tests/|releases/|web/"
    r"|native/(src|include|lib|windows)/|native/bin/(web|windows)/|\.github/)"
)


def tracked() -> list[str]:
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, check=True,
                         capture_output=True).stdout.decode("utf-8")
    return [p for p in out.split("\0") if p and not DROP.match(p)]


def build(out: Path, godot: Path | None, import_cache: bool) -> Path:
    with tempfile.TemporaryDirectory() as td:
        stage = Path(td) / NAME
        stage.mkdir()
        for rel in tracked():
            src = ROOT / rel
            if not src.is_file():
                continue
            dst = stage / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
        if godot is not None:
            shutil.copy2(godot, stage / "godot")
            (stage / "godot").chmod(0o755)
        if import_cache:
            if godot is None:
                sys.exit("--import-cache needs --godot (the cache is made by that binary)")
            subprocess.run([str(stage / "godot"), "--headless", "--path", str(stage), "--import"],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        out.parent.mkdir(parents=True, exist_ok=True)
        with tarfile.open(out, "w:gz", compresslevel=9) as tar:
            tar.add(stage, arcname=NAME)
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot", type=Path, help="Godot 4.5 Linux binary to ship as ./godot")
    ap.add_argument("--out", type=Path, default=ROOT / "dist" / f"{NAME}.tar.gz")
    ap.add_argument("--no-import-cache", action="store_true",
                    help="skip the warm import (first run on the host imports in ~45 s)")
    args = ap.parse_args(argv)
    out = build(args.out, args.godot, import_cache=args.godot is not None and not args.no_import_cache)
    print(f"{out}  {out.stat().st_size / 1e6:.1f} MB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
