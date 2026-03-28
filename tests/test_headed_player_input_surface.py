from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def _read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_rig_listener_exposes_player_input_backend_and_key_commands() -> None:
    src = _read("Tests/rig_listener.gd")
    assert 'execution_backend?: "direct"|"player_input"|"auto"' in src
    assert '"press_key":' in src
    assert '"key_sequence":' in src
    assert "func _resolve_policy_execution_backend(" in src
    assert "func _press_key(" in src
    assert "func _execute_policy_action_via_input(" in src
    assert 'execution_backend == "player_input"' in src
    assert 'if not _is_headless:' in src
    assert 'return "player_input"' in src


def test_player_input_backend_does_not_hide_direct_fallbacks() -> None:
    src = _read("UI/Core/PlayerInputMacroRunner.gd")
    assert "not_supported_by_player_input" in src
    assert "_direct_fallback" not in src


def test_runner_batch_and_launcher_thread_display_backend_flags() -> None:
    runner = _read("🍄/🎛️/milk_hunt_runner.py")
    batch = _read("🍄/🎛️/milk_hunt_batch.py")
    client = _read("🍄/🎛️/rig_client.py")
    launcher = _read("🍄/🎛️/🟢.sh")
    assert "--display-mode" in runner
    assert "--policy-execution-backend" in runner
    assert "execution_backend=policy_execution_backend" in runner
    assert '--display-mode", str(display_mode)' in batch
    assert '--policy-execution-backend", str(policy_execution_backend)' in batch
    assert 'env["RIG_DISPLAY_MODE"] = str(display_mode or "headless")' in client
    assert "def clear_rig_files(self, preserve_live_sentinel: bool = True) -> None:" in client
    assert "if not preserve_live_sentinel or not self._bridge_sentinel_is_ready(self.xdg_root):" in client
    assert 'if [ "$RIG_DISPLAY_MODE" = "headed" ]; then' in launcher
    assert "exec godot --audio-driver" in launcher


def test_derby_and_seed_save_accept_headed_player_input_flags() -> None:
    derby = _read("🍄/🎛️/derby.py")
    wrapper = _read("🍄/🎛️/derby_character_derby.py")
    seed = _read("🍄/🎛️/milk_hunt_seed_save.py")
    assert "--display-mode" in derby
    assert "--policy-execution-backend" in derby
    assert 'display_mode=str(args.display_mode)' in derby
    assert 'policy_execution_backend=str(args.policy_execution_backend)' in derby
    assert "--display-mode" in wrapper
    assert "--policy-execution-backend" in wrapper
    assert "--display-mode" in seed
    assert "--ready-timeout" in seed
    assert 'display_mode=str(args.display_mode or "headless")' in seed
    assert "if proc is not None and not args.reuse_listener:" in seed


def test_obsolete_dev_runner_forks_are_deleted() -> None:
    assert not (ROOT / "🍄" / "🎛️" / "dev" / "milk_hunt_runner_graphics_waits.py").exists()
    assert not (ROOT / "🍄" / "🎛️" / "dev" / "milk_hunt_runner_quantum_waits.py").exists()
