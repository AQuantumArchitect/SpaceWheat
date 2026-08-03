def test_action_cost_surface_parity(rig_boot) -> None:
    """Validate rig-exposed action costs match live balance snapshot costs."""
    rig, _proc = rig_boot(
        prefix="sw_pytest_rig_",
        load_slot=None,
        scenario_id="new_game_easy",
        allow_resource_injection=False,
        listener_stdout="null",
        rig_log_profile="quiet",
        extra_env={"RIG_QUEUE_POLL_MS": "80"},
    )

    turn = 1
    balance = rig.run_turn(turn, "balance_snapshot", timeout_s=120.0)
    assert balance.get("ok", False), balance
    action_costs = (
        balance.get("balance", {}).get("action_costs", {})
        if isinstance(balance.get("balance", {}), dict)
        else {}
    )

    checks = [
        ("quest_reroll", {}, True),
        ("inject_icon", {"south_emoji": "👥"}, False),  # dynamic cost depends on context
    ]
    for action_name, context, compare_balance_snapshot in checks:
        turn += 1
        cost_row = rig.run_turn(
            turn,
            "action_cost",
            timeout_s=30.0,
            name=action_name,
            context=context,
        )
        assert cost_row.get("ok", False), cost_row
        cost = cost_row.get("cost", {})
        assert isinstance(cost, dict), cost_row

        if compare_balance_snapshot:
            assert cost == action_costs.get(action_name, {}), {
                "action": action_name,
                "cost_row": cost,
                "balance_snapshot": action_costs.get(action_name, {}),
            }

        turn += 1
        preflight_row = rig.run_turn(
            turn,
            "action_preflight",
            timeout_s=30.0,
            name=action_name,
            context=context,
        )
        assert preflight_row.get("ok", False), preflight_row
        preflight = preflight_row.get("preflight", {})
        assert isinstance(preflight, dict), preflight_row
        assert preflight.get("cost", {}) == cost
