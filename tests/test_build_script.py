import re
from pathlib import Path


def test_linux_preset_checks_native_library_and_export_outputs():
    script = (Path(__file__).resolve().parents[1] / "tools/build.ps1").read_text(encoding="utf-8")
    validate_set = re.search(r"\[ValidateSet\(([^)]*)\)\]", script)
    assert validate_set and "'linux'" in validate_set[1]

    presets = re.search(r"(?ms)^\$Presets\s*=\s*@\{(.*?)^\}", script)
    assert presets
    linux = re.search(r"(?s)'linux'\s*=\s*@\{([^}]+)\}", presets[1])
    assert linux

    library = "libquantummatrix.linux.template_release.x86_64.so"
    assert "Name='Linux Desktop'" in linux[1]
    assert "File='SpaceWheat.x86_64'" in linux[1]
    assert "DefaultOut='build/release/linux'" in linux[1]
    assert f"Native=@('native/bin/linux/{library}')" in linux[1]
    assert f"Check=@('SpaceWheat.x86_64', '{library}')" in linux[1]
