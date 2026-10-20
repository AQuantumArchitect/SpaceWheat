"""Adversarial save/load pins.

Playtest 2026-10-14: Reset.bat and Z New still looked like the stuck Ace-only
plant farm. AppData saves/ was already empty. The packed Act-0 scenario
*is* that farm (Fibonacci wallet + Village + StarterForest campaign doors).
Older reset.bat copies also left saves_backup_* beside saves/; Continue
must never scan those folders.

Messy conditions this file is allowed to name:
- leftover saves_backup_* next to saves/
- nested junk inside saves/
- garbled emoji save_slot_0_??_*.tres at user:// root
- Title F / Continue with empty slots
- Z New vs title mash (wipe vs keep)
- ResourceLoader cache of the packed scenario
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _scenario_arrays(text: str, key: str) -> list[str]:
    import re

    m = re.search(key + r"\s*=\s*(?:Array\[String\]\()?\[([^\]]*)\]", text)
    if not m:
        return []
    return re.findall(r'"([^"]+)"', m.group(1))


def test_demos_normal_is_the_packed_new_game() -> None:
    """A wiped user:// still boots this tres. Village + Forest stay on the
    deck because Act-0 wayfinding stands in StarterForest and Superpose
    warms up at Village. Stripping them is a tutorial break, not a save fix.
    """
    text = _read("Scenarios/demos_normal.tres")
    unlocked = _scenario_arrays(text, "unlocked_biomes")
    assert unlocked == ["TheDemos", "Village", "StarterForest"], unlocked
    assert 'active_biome_name = "TheDemos"' in text
    assert '"🌾": 34' in text
    assert '"🧺": 21' in text
    assert '"❄️": 13' in text
    tutorial = _read("Core/Quests/data/tutorial_arc.json")
    assert '"biome": "StarterForest"' in tutorial
    assert "warm up at Village" in tutorial


def test_wipe_play_state_kills_backups_and_nested_dirs() -> None:
    store = _read("Core/GameState/SaveStore.gd")
    wipe = store.split("static func wipe_play_state")[1].split("static func get_save_path")[0]
    assert "saves_backup" in wipe
    assert "save_slot_" in wipe
    assert "autosave_" in wipe
    assert "_wipe_tree" in wipe
    assert "Nested save folders are not a thing we write" not in wipe
    tree = store.split("static func _wipe_tree")[1].split("static func ")[0]
    assert "current_is_dir" in tree
    assert "_wipe_tree(child)" in tree


def test_reset_bat_wipes_backup_folders() -> None:
    deploy = _read("scripts/lib/windows_desktop_deploy.sh")
    bat = deploy.split("reset.bat")[1].split("saves.bat")[0]
    assert "saves_backup*" in bat
    assert rmdir_saves_then_backups(bat)
    assert "save_slot_*" in bat
    assert "autosave_*" in bat


def rmdir_saves_then_backups(bat: str) -> bool:
    saves_at = bat.find(r'rmdir /s /q "%USERDIR%\saves"')
    backup_at = bat.find("saves_backup*")
    return saves_at != -1 and backup_at != -1 and saves_at < backup_at


def test_continue_never_scans_backup_folders() -> None:
    coord = _read("Core/GameState/SaveLoadCoordinator.gd")
    finder = coord.split("func find_best_save_slot")[1].split("\nfunc ")[0]
    assert "saves_backup" not in finder
    assert "SaveStore.save_exists" in finder
    assert "SaveStore.NUM_SAVE_SLOTS" in finder
    store = _read("Core/GameState/SaveStore.gd")
    slot_path = store.split("static func get_save_path")[1].split("static func ")[0]
    assert "SAVE_DIR" in slot_path
    assert "saves_backup" not in slot_path
    auto_path = store.split("static func get_auto_save_path")[1].split("static func ")[0]
    assert "SAVE_DIR" in auto_path
    assert "saves_backup" not in auto_path


def test_packed_new_game_is_act0_until_tutorial_seen() -> None:
    """Playtest 2026-10-14: empty saves/ + title F still milled [0] Druid.
    Packed demos_normal is the default world (Village+Forest, 🌱=3), not a
    Keep slot. Empty flags used to mean 'Act 0 over' (SENTINEL fail-open)
    until Welcome dismissed. That stuffed plant mill onto a locked hat."""
    prog = _read("UI/Core/UIProgression.gd")
    step = prog.split("static func current_tutorial_step")[1].split("static func _act0_live")[0]
    assert 'not _flags().has("tutorial_seen")' in step
    assert "return 0" in step
    assert step.find('not _flags().has("tutorial_seen")') < step.rfind("return 0")
    obj = prog.split("static func objective_text(")[1].split("static func objective_target_key")[0]
    assert "Packed New Game: unsigned mill_wakes is STORY" in obj
    packed = obj.split("Packed New Game: unsigned mill_wakes is STORY")[1]
    assert "if _act0_live():" in packed
    assert "_core_loop_walk_line()" in packed
    assert packed.find("if _act0_live():") < packed.find("return _discover_walk_line()")
    log_boot = _read("scenes/AppRoot.gd")
    assert "request_fresh_restart(false, SaveStore.DEFAULT_SCENARIO_ID)" in log_boot
    start = _read("Core/GameState/SessionLifecycle.gd").split("func start_session")[1].split("\nfunc ")[0]
    assert "find_best_save_slot" not in start


def test_fresh_boot_does_not_pick_a_keep_slot() -> None:
    life = _read("Core/GameState/SessionLifecycle.gd")
    start = life.split("func start_session")[1].split("\nfunc ")[0]
    assert "build_new_session_state" in start
    assert "find_best_save_slot" not in start
    else_arm = start.split("else:")[1]
    assert "build_new_session_state(scenario_id)" in else_arm
    assert "load_game_state" not in else_arm


def test_z_new_wipes_title_f_does_not() -> None:
    menu = _read("UI/Overlays/EscapeMenu.gd")
    start = menu.split("func _start_new_scenario")[1].split("func ")[0]
    assert "request_fresh_restart(true" in start
    title = _read("scenes/AppRoot.gd")
    assert "request_fresh_restart(false, SaveStore.DEFAULT_SCENARIO_ID)" in title
    life = _read("Core/GameState/SessionLifecycle.gd")
    fresh = life.split("func request_fresh_restart")[1].split("\nfunc ")[0]
    assert "SaveStore.wipe_play_state" in fresh
    assert "restart_into(-1)" in fresh


def test_welcome_ghost_pop_does_not_onboard() -> None:
    """Packed Demos + empty saves still looked stuck because welcome opened
    then died next frame. Deferred close_all from session reset raced the
    splash; deactivate then fired tutorial_seen."""
    om = _read("UI/Managers/OverlayManager.gd")
    assert "_close_all_gen" in om
    close_all = om.split("func close_all_overlays")[1].split("func _close_all_overlays_now")[0]
    assert "_close_all_gen += 1" in close_all
    now = om.split("func _close_all_overlays_now")[1].split("func reset")[0]
    assert "gen != _close_all_gen" in now
    open_fn = om.split("func open_overlay(_name: String)")[1].split("func _announce_contract_scope")[0]
    assert "_close_all_gen += 1" in open_fn
    stack = _read("UI/Managers/OverlayStackManager.gd")
    route = stack.split("func route_input")[1].split("func handle_escape")[0]
    assert 'overlay_name")) == "welcome"' in route or 'overlay_name") == "welcome"' in route
    root = _read("scenes/GameRoot.gd")
    welcome = root.split("func _maybe_show_welcome")[1].split("func _show_boot_recap")[0]
    assert "await tree.process_frame" in welcome
    start = root.split("func start(request")[1].split("func _maybe_show_welcome")[0]
    assert "await _maybe_show_welcome" in start


def test_scenario_load_ignores_resource_cache() -> None:
    store = _read("Core/GameState/SaveStore.gd")
    load_sc = store.split("static func load_scenario")[1].split("static func ")[0]
    assert "CACHE_MODE_IGNORE" in load_sc
    assert "duplicate(true)" in load_sc
    load_state = store.split("static func load_state(slot: int)")[1].split("static func ")[0]
    assert "CACHE_MODE_IGNORE" in load_state
