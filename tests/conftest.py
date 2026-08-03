"""tests/conftest.py — repo-wide pytest hooks.

Currently carries ONE thing: an opt-in hearth adapter (see d1-10, ring-6
residual) that posts the suite's real pass/fail counts to the shared belief
field. Default OFF — zero behavior change for a normal `pytest tests/` run.

    SEMANTICA_POST=1 pytest tests/

posts a single spacewheat_referee event to project-membrane (eta_tiers.sh
referee tier, 0.92-magnitude) once the session finishes, with value sign
carrying pass/fail (+0.92 clean, -0.92 any failures) and meta = the REAL
counts pytest collected — never a hand-authored claim. If the hearth is
unreachable the adapter prints a warning and does NOT fail the test run;
a dark membrane is not a test failure.
"""
import os
import shutil
import tempfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
RUNNER_ROOT = ROOT / "🍄" / "🎛️"


def read_source(rel_path: str) -> str:
    """Read a repo-relative source file as text (shared by surface lint tests)."""
    return (ROOT / rel_path).read_text(encoding="utf-8")


def _rig_client_class():
    """Lazy import of RigClient from the 🍄/🎛️ runner tree (sys.path side effect
    contained here instead of copy-pasted per test module)."""
    import sys

    if str(RUNNER_ROOT) not in sys.path:
        sys.path.insert(0, str(RUNNER_ROOT))
    from rig_client import RigClient  # noqa: E402

    return RigClient


@pytest.fixture
def rig_boot():
    """Boot a real Godot rig listener and guarantee teardown.

    Replaces the hand-rolled tempdir + start_listener + sentinel-wait +
    finally: terminate/rmtree block that was copy-pasted across 7 rig
    integration tests (slop-patrol 2026-07-29, Tier 6 knot #29).

    Yields a factory:

        rig, proc = rig_boot(prefix="sw_pytest_myname_",
                             scenario_id="new_game_easy", ...)

    All keyword args except ``prefix`` and ``sentinel_timeout_s`` are passed
    straight to ``RigClient.start_listener``. Skips (never fails) when godot
    is not on PATH. Every booted listener is terminated and its XDG tempdir
    removed at test teardown, pass or fail — a leaked listener runs full
    physics forever (real incident: leaked pytest listeners saturating the
    disk until reboot).
    """
    booted = []  # (RigClient class, proc, xdg_root)

    def boot(prefix="sw_pytest_rig_", *, sentinel_timeout_s=60.0, **listener_kwargs):
        if shutil.which("godot") is None:
            pytest.skip("godot not available on PATH")
        RigClient = _rig_client_class()
        xdg_root = Path(tempfile.mkdtemp(prefix=prefix))
        rig = RigClient(xdg=xdg_root, root_from_file=RUNNER_ROOT / "milk_hunt_runner.py")
        rig.clear_rig_files()
        proc = rig.start_listener(**listener_kwargs)
        booted.append((RigClient, proc, xdg_root))
        assert RigClient.wait_for_bridge_sentinel(
            timeout_s=sentinel_timeout_s, xdg=rig.xdg_root
        ), "rig listener not ready"
        return rig, proc

    yield boot

    for RigClient, proc, xdg_root in booted:
        RigClient.terminate_listener(proc, timeout_s=5.0)
        shutil.rmtree(xdg_root, ignore_errors=True)


def pytest_sessionfinish(session, exitstatus):
    if os.environ.get("SEMANTICA_POST") != "1":
        return
    _post_suite_result(session, exitstatus)


def _post_suite_result(session, exitstatus) -> None:
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "🍄" / "🧪"))
    try:
        from semantica_post import post, HearthDark
    except ImportError as exc:
        print(f"[semantica] adapter unavailable: {exc}", file=sys.stderr)
        return

    stats = session.config.pluginmanager.get_plugin("terminalreporter").stats
    passed = len(stats.get("passed", []))
    failed = len(stats.get("failed", [])) + len(stats.get("error", []))
    skipped = len(stats.get("skipped", []))
    value = 0.92 if (exitstatus == 0 and failed == 0) else -0.92
    meta = {"suite": "pytest tests/", "passed": passed, "failed": failed,
            "skipped": skipped, "exitstatus": exitstatus}
    try:
        n = post("spacewheat_referee", value, meta, world="project-membrane")
        print(f"[semantica] spacewheat_referee={value} appended={n} "
              f"passed={passed} failed={failed}")
    except HearthDark as exc:
        print(f"[semantica] hearth dark, suite result NOT posted: {exc}", file=sys.stderr)
