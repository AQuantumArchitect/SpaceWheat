"""One Windows layout (2026-10-18): C:\\Games\\SpaceWheat holds the play folder,
releases\\vX.Y.Z archives (newest 3) and profiling-kit\\ — all derived in
scripts/lib/windows_desktop_deploy.sh. Before this, three folders held the same
exe (an emoji play folder, a "staging" copy, a plain-ASCII copy no script
wrote) and a 2.6 GB SpaceWheat-Releases of hand-copied archives.

  * no script or tool spells a C:\\Games path outside the one lib file
  * deploying never wipes the root (releases/ and profiling-kit/ live there)
  * deploy writes the launcher set + VERSION.txt
  * the archive keeps exactly the newest SW_WINDOWS_KEEP_RELEASES versions
"""
import os
import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "scripts" / "lib" / "windows_desktop_deploy.sh"
RETIRED = ("/mnt/c/Games", "🌾🚀🌌", "SpaceWheat-Releases", "SpaceWheat Builds", "sw_windows_stage_root")


def test_no_windows_path_outside_the_lib():
    offenders = []
    for base in ("scripts", "tools", "🍄/🎛️"):
        for p in (ROOT / base).rglob("*"):
            if not p.is_file() or p.suffix not in (".sh", ".py", ".gd", ".bat", ".ps1", ".md", ".mjs"):
                continue
            if p == LIB:
                continue
            text = p.read_text(encoding="utf-8", errors="ignore")
            for needle in RETIRED:
                if needle in text:
                    offenders.append(f"{p.relative_to(ROOT)}: {needle}")
    assert not offenders, "Windows paths belong in scripts/lib/windows_desktop_deploy.sh only:\n  " + "\n  ".join(offenders)


def _bash(script: str, env: dict) -> subprocess.CompletedProcess:
    return subprocess.run(["bash", "-c", f'set -e; source "{LIB}"; {script}'],
                          env={**os.environ, **env}, capture_output=True, text=True)


def test_deploy_keeps_releases_and_writes_the_launcher_set(tmp_path):
    games = tmp_path / "Games"
    root = games / "SpaceWheat"
    (root / "releases" / "v0.0.1").mkdir(parents=True)
    (root / "releases" / "v0.0.1" / "keep.txt").write_text("x")
    src = tmp_path / "export"
    src.mkdir()
    (src / "SpaceWheat.exe").write_bytes(b"exe")
    (src / "libquantummatrix.windows.template_release.x86_64.dll").write_bytes(b"dll")
    env = {"WINDOWS_ROOT": str(root), "SW_DEPLOY_VERSION_LINE": "v9.9.9 · abc1234 · 2026-10-18"}
    r = _bash(f'sw_windows_can_use_cmd() {{ return 1; }}; sw_windows_deploy_tree "{src}" "$(sw_windows_player_root)" 1', env)
    assert r.returncode == 0, r.stderr
    for f in ("SpaceWheat.exe", "libquantummatrix.windows.template_release.x86_64.dll",
              "launch.bat", "reset.bat", "saves.bat", "README.txt", "VERSION.txt"):
        assert (root / f).exists(), f
    assert (root / "releases" / "v0.0.1" / "keep.txt").exists(), "deploy wiped the archive"
    assert "v9.9.9" in (root / "VERSION.txt").read_text()


def test_archive_keeps_the_newest_three(tmp_path):
    root = tmp_path / "Games" / "SpaceWheat"
    root.mkdir(parents=True)
    pkgs = tmp_path / "packages"
    pkgs.mkdir()
    for i, v in enumerate(("0.1.1-alpha", "0.1.2-alpha", "0.1.3-alpha", "0.1.4-alpha")):
        (pkgs / f"spacewheat-windows-{v}-abc1234.zip").write_bytes(v.encode())
        r = _bash(f'sw_windows_archive_release "{v}" "{pkgs}"', {"WINDOWS_ROOT": str(root)})
        assert r.returncode == 0, r.stderr
        time.sleep(1.1)  # mtime ordering
    kept = sorted(p.name for p in (root / "releases").iterdir())
    assert kept == ["v0.1.2-alpha", "v0.1.3-alpha", "v0.1.4-alpha"], kept
    sha = (root / "releases" / "v0.1.4-alpha" / "SHA256").read_text()
    assert re.search(r"[0-9a-f]{64}  spacewheat-windows-0\.1\.4-alpha", sha)
