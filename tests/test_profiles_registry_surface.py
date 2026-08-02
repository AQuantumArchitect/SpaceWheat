from conftest import ROOT, read_source as _read


def test_profiles_module_is_single_registry_surface() -> None:
    src = _read("🍄/🎛️/profiles.py")
    assert "def load(" in src
    assert "def list_names(" in src
    assert "def list_all(" in src
    assert "def get_save_path(" in src
    assert "def resolve_save_spec(" in src
    assert "def load_registry(" in src
    assert "def resolve_user_path(" in src
    assert "def to_user_uri(" in src
    assert "def get_profile_name_for_save(" in src
    assert "get_profile = load" not in src
    assert "list_profile_names = list_names" not in src
    assert "get_profile_save = get_save_path" not in src
    assert "resolve_profile_save_spec = resolve_save_spec" not in src


def test_mushroom_callers_use_unified_profiles_module() -> None:
    seed = _read("🍄/🎛️/milk_hunt_seed_save.py")
    batch = _read("🍄/🎛️/milk_hunt_batch.py")
    runner = _read("🍄/🎛️/milk_hunt_runner.py")
    assert "from profiles import load, list_all" in seed
    assert "from profiles import load, get_profile_name_for_save, get_save_path, resolve_save_spec" in batch
    assert "from profiles import get_profile_name_for_save, get_save_path, resolve_save_spec" in runner


def test_old_registry_modules_are_deleted() -> None:
    assert not (ROOT / "🍄" / "🎛️" / "milk_hunt_profiles.py").exists()
    assert not (ROOT / "🍄" / "🎛️" / "profile_save_registry.py").exists()


def test_active_milk_hunt_surface_no_longer_threads_load_alias() -> None:
    args_src = _read("🍄/🎛️/milk_hunt_args.py")
    batch_src = _read("🍄/🎛️/milk_hunt_batch.py")
    summary_src = _read("🍄/🎛️/milk_hunt_summary.py")
    runner_src = _read("🍄/🎛️/milk_hunt_runner.py")
    shell_src = _read("🍄/🎛️/🧭🥛🧪🚜.sh")
    batch_conf = _read("🍄/🎛️/config/milk_hunt_batch.conf")
    visual_conf = _read("🍄/🎛️/config/milk_hunt_visual.conf")
    runner_conf = _read("🍄/🎛️/config/milk_hunt_runner.json")
    graphics_conf = _read("🍄/🎛️/config/milk_hunt_graphics_waits.json")

    assert "--load-alias" not in args_src
    assert "load_alias" not in batch_src
    assert "load_alias" not in summary_src
    assert "--load-alias" not in runner_src
    assert "args.load_alias" not in runner_src
    assert "LOAD_ALIAS" not in shell_src
    assert "LOAD_ALIAS" not in batch_conf
    assert "LOAD_ALIAS" not in visual_conf
    assert '"load_alias"' not in runner_conf
    assert '"load_alias"' not in graphics_conf
