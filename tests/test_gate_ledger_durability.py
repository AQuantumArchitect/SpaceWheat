import time


def test_gate_counters_survive_save_load(rig_boot) -> None:
    # THE stall that shipped (2026-08-17 playtest): quest gate progress lived
    # in a session-scoped 64-row ring that was never saved — a reap done
    # before its quest existed was forgotten by later play or by any load,
    # and reap is once-affordable early, so the run bricked. The durable
    # gate ledger (QuestStateProjectionService.gate_counters, persisted
    # through QuestManager.to_save_dict like lesson_receipts) kills both
    # stall modes. Unit semantics are pinned in tests/gate_ledger_smoke.gd;
    # THIS test pins the integration: a real gate, through the real save
    # serializer, across a real load_and_apply, still counted.
    rig, _proc = rig_boot(
        prefix="sw_pytest_gate_ledger_",
        load_slot=None,
        scenario_id="demos_normal",
        allow_resource_injection=True,
        listener_stdout="null",
        rig_log_profile="quiet",
        extra_env={"RIG_QUEUE_POLL_MS": "80"},
    )

    turn = [1]

    def step(action, **kw):
        turn[0] += 1
        return rig.run_turn(turn[0], action, timeout_s=60.0, **kw)

    def press(key, frames=4, **kw):
        step("press_key", key=key, settle_frames=frames, **kw)

    def measure_count():
        row = step("quest_projection")
        assert row.get("ok", False), row
        counters = row.get("gate_counters", {}) or {}
        return sum(int(v) for k, v in counters.items() if "measure" in str(k).lower())

    # One real strike (Ace: explore, then measure) — the recorded gate.
    press("8")
    press("G")
    press("F", frames=8)   # explore
    press("R", frames=10)  # strike → records "measure"
    deadline = time.time() + 10.0
    while time.time() < deadline and measure_count() < 1:
        time.sleep(0.2)
    assert measure_count() >= 1, "strike never reached the gate ledger"

    # Through the real serializer and back.
    saved = step("save_game", slot=0)
    assert saved.get("ok", False) and saved.get("saved", False), saved
    loaded = step("load_game", slot=0)
    assert loaded.get("ok", False) and loaded.get("loaded", False), loaded

    # The counted gate survived the load — the old ring came back empty here.
    deadline = time.time() + 10.0
    post = 0
    while time.time() < deadline:
        post = measure_count()
        if post >= 1:
            break
        time.sleep(0.2)
    assert post >= 1, (
        "gate ledger lost the measure across save/load — the load-wipe "
        "stall is back"
    )
