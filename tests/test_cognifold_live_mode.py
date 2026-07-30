from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
TRACE_VIEW = PROJECT_ROOT / "Core" / "Visualization" / "CognifoldTraceView.gd"


def _src() -> str:
    return TRACE_VIEW.read_text(encoding="utf-8")


def test_live_url_takes_precedence_and_defers_field_build() -> None:
    """SW_COGNIFOLD_URL wins over the file/dir modes, and the field must be built lazily
    off the FIRST successful response (register count is unknowable before that)."""
    src = _src()
    ready = src.split("func _ready")[1].split("\nfunc ")[0]
    assert 'OS.get_environment("SW_COGNIFOLD_URL")' in ready
    # live mode returns before any trace-file loading happens (compare against the env
    # READ, not the precedence comment, which also names the var)
    assert ready.index("_start_live_poll()") < ready.index(
        'OS.get_environment("SW_COGNIFOLD_TRACE_DIR")')
    resp = src.split("func _on_live_response")[1].split("\nfunc ")[0]
    assert "_build_field()" in resp


def test_live_poll_is_single_flight_and_authenticated() -> None:
    """One request in flight at a time (a slow daemon must not stack requests), and the
    X-API-Key header rides along when UMWELTD_API_KEY is set."""
    src = _src()
    poll = src.split("func _poll_live")[1].split("\nfunc ")[0]
    assert "if _live_pending" in poll
    assert 'OS.get_environment("UMWELTD_API_KEY")' in poll
    assert '"X-API-Key: "' in poll


def test_live_tween_holds_instead_of_wrapping() -> None:
    """Live mode glides to the latest response and HOLDS (minf clamp) — a quiet world is
    legitimately still. Only the filmstrip mode wraps modulo its frame ring."""
    src = _src()
    proc = src.split("func _process")[1].split("\nfunc ")[0]
    live_branch = proc.split('_live_url != ""')[1].split("_frames.size()")[0]
    assert "minf(1.0" in live_branch


def test_live_topology_change_respawns_field() -> None:
    """If the world regrew (register count changed), the tween would mis-pair indices —
    the handler must reload flat and reconnect the renderer instead."""
    src = _src()
    resp = src.split("func _on_live_response")[1].split("\nfunc ")[0]
    assert "get_num_qubits()" in resp
    assert "_field.connect_to_farm(_farm)" in resp
