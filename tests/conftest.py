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
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def read_source(rel_path: str) -> str:
    """Read a repo-relative source file as text (shared by surface lint tests)."""
    return (ROOT / rel_path).read_text(encoding="utf-8")


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
