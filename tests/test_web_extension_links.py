"""The web GDExtension must actually link against the engine it ships with.

0.1.0-alpha shipped a browser build that reached the title card and then died
the instant a farm booted:

    Aborted(Assertion failed: undefined symbol '_ZNSt3__213__hash_memoryEPKvm'.
    perhaps a side module was not linked in? ...)

`dlopen` had *succeeded* — the Eigen banner printed at boot — so every check
that only asked "does the extension load?" passed. The failure was a call into
a stub that resolved to nothing, and nothing calls it until you press New Game.

Cause: `libquantummatrix.wasm` was compiled by a different Emscripten than the
Godot web export template. Their libc++ symbol names differ (the template's
carry an ABI tag, `B8nn200100`), so 29 of the extension's 51 libc++ imports had
no provider anywhere in the bundle.

This is a *static* property of the two files. It needs no browser, no export and
no GPU — just the wasm import and export sections. Checking it costs
milliseconds and would have caught the bug the moment the wasm was built.

`scripts/build-all-platforms.sh` pins `SW_EMSDK_VERSION` to keep this from
recurring; this test is the assertion that the pin is doing its job.
"""

from __future__ import annotations

import subprocess
import zipfile
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
EXTENSION = REPO / "native" / "bin" / "web" / "libquantummatrix.wasm"

# The engine side of the link. Godot ships the main module and its own engine
# side module inside the dlink export template.
TEMPLATE_DIRS = [
    Path.home() / ".local" / "share" / "godot" / "export_templates",
    Path.home() / ".steam" / "steam" / "steamapps" / "common" / "Godot Engine" / "templates",
]
TEMPLATE_ZIP_NAME = "web_dlink_release.zip"
TEMPLATE_MEMBERS = ("godot.wasm", "godot.side.wasm")


def _read_uleb(data: bytes, i: int) -> tuple[int, int]:
    result = shift = 0
    while True:
        byte = data[i]
        i += 1
        result |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return result, i
        shift += 7


def _sections(data: bytes):
    if data[:4] != b"\x00asm":
        raise ValueError("not a wasm module")
    i = 8
    while i < len(data):
        section_id = data[i]
        i += 1
        size, i = _read_uleb(data, i)
        yield section_id, data[i : i + size]
        i += size


def _skip_import_descriptor(body: bytes, i: int, kind: int) -> int:
    if kind == 0:  # function: type index
        _, i = _read_uleb(body, i)
    elif kind == 1:  # table: reftype, limits
        i += 1
        flags = body[i]
        i += 1
        _, i = _read_uleb(body, i)
        if flags & 1:
            _, i = _read_uleb(body, i)
    elif kind == 2:  # memory: limits
        flags = body[i]
        i += 1
        _, i = _read_uleb(body, i)
        if flags & 1:
            _, i = _read_uleb(body, i)
    elif kind == 3:  # global: valtype, mutability
        i += 2
    else:
        raise ValueError(f"unknown import kind {kind}")
    return i


def function_imports(data: bytes) -> set[str]:
    """Names this module expects someone else to provide."""
    names: set[str] = set()
    for section_id, body in _sections(data):
        if section_id != 2:
            continue
        count, i = _read_uleb(body, 0)
        for _ in range(count):
            length, i = _read_uleb(body, i)
            i += length  # module name, unused
            length, i = _read_uleb(body, i)
            name = body[i : i + length].decode("utf-8", "replace")
            i += length
            kind = body[i]
            i += 1
            i = _skip_import_descriptor(body, i, kind)
            if kind == 0:
                names.add(name)
    return names


def exports(data: bytes) -> set[str]:
    """Names this module provides."""
    names: set[str] = set()
    for section_id, body in _sections(data):
        if section_id != 7:
            continue
        count, i = _read_uleb(body, 0)
        for _ in range(count):
            length, i = _read_uleb(body, i)
            names.add(body[i : i + length].decode("utf-8", "replace"))
            i += length
            i += 1  # export kind
            _, i = _read_uleb(body, i)
    return names


def _godot_version() -> str | None:
    """The engine that will actually perform the export, e.g. '4.5.stable'."""
    try:
        out = subprocess.run(
            ["godot", "--version"], capture_output=True, text=True, timeout=30
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None
    # "4.5.stable.official.876b29033" -> "4.5.stable"
    parts = out.split(".")
    return ".".join(parts[:3]) if len(parts) >= 3 else None


def _find_template_zip() -> Path | None:
    """The template dir matching the *installed engine*, never merely the newest.

    Several engine versions coexist here (4.5.stable and 4.6.2.stable). Linking
    the extension against the wrong one is the same class of mistake this test
    exists to catch, so match the version exactly and skip rather than guess.
    """
    version = _godot_version()
    if version is None:
        return None
    for root in TEMPLATE_DIRS:
        candidate = root / version / TEMPLATE_ZIP_NAME
        if candidate.is_file():
            return candidate
    return None


# Symbols no wasm module in the bundle exports, because the Emscripten *JS*
# runtime supplies them at instantiation. Both the broken 0.1.0-alpha wasm and
# the repaired one import exactly these and nothing else, which is what makes
# them safe to allow: they are a property of the toolchain, not of our code.
#
# Keep this list tiny and keep the reasons attached. It is the one place a real
# unresolved symbol could hide, so anything added here needs to be shown to come
# from the runtime rather than merely being inconvenient.
RUNTIME_PROVIDED = {
    "__assert_fail",  # libc assert handler, JS-side
    "__cxa_throw",  # Itanium C++ ABI throw, JS-side
}
# clang emits a `_ZTH*` thunk to initialise each thread_local; godot-cpp has two
# (Wrapped::_constructing_*). The dynamic loader wires these up per thread.
RUNTIME_PROVIDED_PREFIXES = ("_ZTH",)


def unresolved_imports(extension: bytes, engine_exports: set[str]) -> list[str]:
    """Imports with no provider anywhere.

    A wasm side module's imports are satisfied from the whole loaded symbol
    table, which includes:
      * the engine main module and Godot's own engine side module,
      * the side module's OWN exports — `-s SIDE_MODULE=1 -s EXPORT_ALL=1`
        routes inline/template instantiations (Eigen, std::vector<Foo>) through
        the GOT even when the module defines them itself,
      * the Emscripten JS runtime, for the handful of names above.

    Checking only against the engine — the first cut of this test — flags ~479
    of the extension's own template instantiations and is useless. Checking all
    three still catches the real defect: the shipped 0.1.0-alpha wasm has
    `_ZNSt3__213__hash_memoryEPKvm` unresolved under this exact rule.
    """
    provided = engine_exports | exports(extension)
    return sorted(
        name
        for name in function_imports(extension) - provided
        if name not in RUNTIME_PROVIDED
        and not name.startswith(RUNTIME_PROVIDED_PREFIXES)
    )


@pytest.fixture(scope="module")
def link_pair() -> tuple[bytes, set[str]]:
    """(extension bytes, every symbol the engine side provides)."""
    if not EXTENSION.is_file():
        pytest.skip(
            f"no web extension at {EXTENSION.relative_to(REPO)} — "
            "build it with scripts/build-all-platforms.sh --web-only"
        )
    template = _find_template_zip()
    if template is None:
        pytest.skip(
            f"no {TEMPLATE_ZIP_NAME} in any known export-template dir — "
            "install Godot's web export templates to check the link"
        )
    provided: set[str] = set()
    with zipfile.ZipFile(template) as zf:
        available = set(zf.namelist())
        for member in TEMPLATE_MEMBERS:
            if member in available:
                provided |= exports(zf.read(member))
    if not provided:
        pytest.skip(f"{template.name} carried none of {TEMPLATE_MEMBERS}")
    return EXTENSION.read_bytes(), provided


def test_every_extension_import_has_a_provider(link_pair):
    """No unresolved function imports. An unresolved one is a live grenade:
    the module loads fine and aborts whenever that code path first runs."""
    extension, engine_exports = link_pair
    unresolved = unresolved_imports(extension, engine_exports)
    assert not unresolved, (
        f"{len(unresolved)} function import(s) in libquantummatrix.wasm have no provider "
        "in the engine, in the extension itself, or in the Emscripten runtime. The "
        "extension will load and then abort the first time one is called.\n"
        "Almost always an Emscripten mismatch: rebuild with the emsdk pinned in "
        "scripts/build-all-platforms.sh (SW_EMSDK_VERSION).\n"
        "First 10 unresolved:\n  " + "\n  ".join(unresolved[:10])
    )


def test_the_symbol_that_broke_the_alpha_is_resolved(link_pair):
    """A named regression guard for the exact abort players hit in 0.1.0-alpha.

    Kept separate from the sweep above so the failure message names the actual
    historical bug rather than a count.
    """
    extension, engine_exports = link_pair
    symbol = "_ZNSt3__213__hash_memoryEPKvm"
    assert symbol not in unresolved_imports(extension, engine_exports), (
        f"{symbol} is imported by the web extension and provided by nothing. "
        "This is the exact undefined symbol that made the 0.1.0-alpha browser build "
        "abort the instant a farm booted."
    )


def test_the_allowlist_stays_a_short_list_of_runtime_symbols():
    """The allowlist is the one place a real unresolved symbol could hide.

    Both the broken and the repaired wasm import exactly these, so the list is a
    toolchain constant. If it needs to grow, that is a signal to re-examine the
    link rather than a routine edit.
    """
    assert len(RUNTIME_PROVIDED) <= 4, RUNTIME_PROVIDED
    assert RUNTIME_PROVIDED_PREFIXES == ("_ZTH",)
