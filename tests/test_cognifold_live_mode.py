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


# ---- the dark banner: a dead daemon must not look like a calm world ------------------

def test_every_failed_poll_path_says_so_on_screen() -> None:
    """A belief field renders a quiet world and a dead daemon IDENTICALLY — both are a
    still picture. Every early-return in the response handler must therefore set the
    banner, not just push_warning to a stderr nobody is watching."""
    src = _src()
    resp = src.split("func _on_live_response")[1].split("\nfunc ")[0]
    bail_blocks = [b for b in resp.split("\t\treturn") if "push_warning" in b]
    assert bail_blocks, "expected failure branches in the live response handler"
    for block in bail_blocks:
        assert "_set_dark(" in block, f"a failure path renders nothing on screen:\n{block}"


def test_success_clears_the_banner() -> None:
    """Once a good frame lands, stillness is honest again — the banner must come down,
    or it would itself become the lie."""
    resp = _src().split("func _on_live_response")[1].split("\nfunc ")[0]
    assert '_set_dark("")' in resp
    assert "_last_ok_ms = Time.get_ticks_msec()" in resp


def test_banner_distinguishes_never_arrived_from_gone_stale() -> None:
    """'No frame ever arrived' (the field is EMPTY) and 'the daemon died' (the field is
    FROZEN at a real past state) are different claims about what you're looking at."""
    txt = _src().split("func _dark_text")[1].split("\nfunc ")[0]
    assert "_last_ok_ms == 0" in txt, "must special-case the never-arrived state"
    assert "DARK" in txt and "STALE" in txt
    assert "_live_fails" in txt, "a stale banner should say how many polls have failed"
