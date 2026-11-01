# Failing tests — 2026-10-20 (full pytest run, builder brief)

Source: `python3 -m pytest tests -q` on the dirty tree at fa37bec7 → **83 failed, 630 passed** (22 min).
Fold after the next hive wave. Each failure is either stale source (the spec is right, code is behind)
or a stale spec (code moved on). Decide per test; do not weaken a test to pass it (law 4).

Known example already diagnosed: `test_arc_grammar_and_knot_honesty.py::test_contracts_name_arc_y_not_guide_i`
— QuestBoard still said "open the Arc [X→I]"; folded 2026-10-20 to `SurfaceRooms.walk_open_offers("X")`.
Others in that file expect `Tab.ARC` on X, `[F] Fast-Fwd` in `_berry_walk_line`, `QuestManager.is_market_hold`, etc.
that are not in the tree.

Tracked-test failures (check first, these may be real regressions): 
`test_top_strip_geometry`, `test_campaign_fixtures`, `test_build_identity` (build_identity may just be the `-dirty` stamp).

## Counts by file
- tests/test_harvest_balloons.py — 13
- tests/test_arc_grammar_and_knot_honesty.py — 10
- tests/test_mill_plant_honesty.py — 9
- tests/test_spine_recipe.py — 8
- tests/test_hive_testing_stack.py — 8
- tests/test_discover_biome_confirm.py — 8
- tests/test_save_load_adversarial.py — 7
- tests/test_verb_grammar.py — 5
- tests/test_druid_chip_costs.py — 5
- tests/test_surface_rooms.py — 4
- tests/test_plant_shows_and_opens_board.py — 3
- tests/test_top_strip_geometry.py — 1
- tests/test_campaign_fixtures.py — 1
- tests/test_build_identity.py — 1

## All failing node ids
- tests/test_arc_grammar_and_knot_honesty.py::test_contracts_name_arc_y_not_guide_i
- tests/test_arc_grammar_and_knot_honesty.py::test_keyboard_x_lands_arc
- tests/test_arc_grammar_and_knot_honesty.py::test_ace_f_fast_fwd_when_berry_tracked
- tests/test_arc_grammar_and_knot_honesty.py::test_loops_linked_needs_closed_lifts
- tests/test_arc_grammar_and_knot_honesty.py::test_unsigned_arc_now_prefers_later_act
- tests/test_arc_grammar_and_knot_honesty.py::test_knot_save_reoffers_when_lifts_still_open
- tests/test_arc_grammar_and_knot_honesty.py::test_hint_toast_stays_on_screen
- tests/test_arc_grammar_and_knot_honesty.py::test_accepted_arc_is_now_not_open
- tests/test_arc_grammar_and_knot_honesty.py::test_knot_accept_is_not_a_handshake
- tests/test_arc_grammar_and_knot_honesty.py::test_reap_cost_quiet_before_economy
- tests/test_build_identity.py::test_stamp_is_not_tracked_by_git
- tests/test_campaign_fixtures.py::test_start_at_beat_opens_the_beat[forest_evolving]
- tests/test_discover_biome_confirm.py::test_add_biome_opens_a_pick_submenu
- tests/test_discover_biome_confirm.py::test_peek_freezes_the_named_land_until_confirm
- tests/test_discover_biome_confirm.py::test_pressured_story_land_enters_a_pool_that_omitted_it
- tests/test_discover_biome_confirm.py::test_woodlot_off_rail_mills_captain_add_biome
- tests/test_discover_biome_confirm.py::test_woodlot_door_names_timber_country_and_completes_on_load
- tests/test_discover_biome_confirm.py::test_banner_and_chip_name_the_fish
- tests/test_discover_biome_confirm.py::test_n_network_shows_fog_links_to_unexplored
- tests/test_discover_biome_confirm.py::test_claim_biome_is_the_plant_price
- tests/test_druid_chip_costs.py::test_druid_verbs_are_priced_on_the_charging_board
- tests/test_druid_chip_costs.py::test_disabled_chips_keep_their_price_badge
- tests/test_druid_chip_costs.py::test_multi_druid_batch_charges_the_board
- tests/test_druid_chip_costs.py::test_multi_superpose_records_hadamard
- tests/test_druid_chip_costs.py::test_multi_e_superpose_batches_and_applies_now
- tests/test_harvest_balloons.py::test_gather_refuses_unstruck_plots
- tests/test_harvest_balloons.py::test_strike_hangs_a_harvest_balloon
- tests/test_harvest_balloons.py::test_strike_sleeps_plot_frfr_stacks_q_takes_pile
- tests/test_harvest_balloons.py::test_operator_bell_leaves_a_visible_mark
- tests/test_harvest_balloons.py::test_bell_partner_stamp_uses_biome_row_not_demos
- tests/test_harvest_balloons.py::test_bell_lesson_is_weave_then_strike_one
- tests/test_harvest_balloons.py::test_bell_collapse_counts_weave_partners
- tests/test_harvest_balloons.py::test_bell_2q_writes_entanglement_graph
- tests/test_harvest_balloons.py::test_entanglement_walk_stays_on_ace_after_weave
- tests/test_harvest_balloons.py::test_reap_mills_explore_every_qubit_then_harvests_all_bound
- tests/test_harvest_balloons.py::test_gather_cashes_focused_plot_only
- tests/test_harvest_balloons.py::test_gather_flier_splits_credits_by_emoji
- tests/test_harvest_balloons.py::test_gather_does_not_collapse_or_blank
- tests/test_hive_testing_stack.py::test_sensor_laws_advertise_q_refresh_and_act0_tap_lamb
- tests/test_hive_testing_stack.py::test_market_body_does_not_name_arc_while_mill_seated
- tests/test_hive_testing_stack.py::test_millwright_seated_outranks_empty_arc
- tests/test_hive_testing_stack.py::test_mill_wakes_is_not_plant_ask_once_mill_seated
- tests/test_hive_testing_stack.py::test_millwright_outranks_leftover_plant_ask_when_seated
- tests/test_hive_testing_stack.py::test_refresh_shortfall_mills_rabbit_plot
- tests/test_hive_testing_stack.py::test_gear_bench_does_not_accept_pack_lords
- tests/test_hive_testing_stack.py::test_refresh_after_deliver_beats_leftover_accept_in_room_cue
- tests/test_mill_plant_honesty.py::test_new_voices_requires_mill_hammer_in_village
- tests/test_mill_plant_honesty.py::test_picker_pins_quest_atom_to_q
- tests/test_mill_plant_honesty.py::test_icon_q_trim_disabled_when_wolf_short
- tests/test_mill_plant_honesty.py::test_walk_names_hammer_cost_before_q_plant
- tests/test_mill_plant_honesty.py::test_hammer_need_mills_icon_not_captain
- tests/test_mill_plant_honesty.py::test_unsigned_new_voices_beats_cull_walk
- tests/test_mill_plant_honesty.py::test_intro_voice_treats_mill_union_as_plant
- tests/test_mill_plant_honesty.py::test_first_learn_seats_the_word_in_demos
- tests/test_mill_plant_honesty.py::test_market_delivery_does_not_pay_unadvertised_born_pole
- tests/test_plant_shows_and_opens_board.py::test_field3d_rebuilds_when_qubit_count_grows
- tests/test_plant_shows_and_opens_board.py::test_force_graph_seeds_when_registers_outrun_bubbles
- tests/test_plant_shows_and_opens_board.py::test_planted_word_opens_that_faction_board
- tests/test_save_load_adversarial.py::test_demos_normal_is_the_packed_new_game
- tests/test_save_load_adversarial.py::test_wipe_play_state_kills_backups_and_nested_dirs
- tests/test_save_load_adversarial.py::test_reset_bat_wipes_backup_folders
- tests/test_save_load_adversarial.py::test_packed_new_game_is_act0_until_tutorial_seen
- tests/test_save_load_adversarial.py::test_z_new_wipes_title_f_does_not
- tests/test_save_load_adversarial.py::test_welcome_ghost_pop_does_not_onboard
- tests/test_save_load_adversarial.py::test_scenario_load_ignores_resource_cache
- tests/test_spine_recipe.py::test_targets_parse_matches_gloss_kinds
- tests/test_spine_recipe.py::test_tutorial_clocks_are_authored
- tests/test_spine_recipe.py::test_village_to_mill_kinds
- tests/test_spine_recipe.py::test_hint_keys_subset_of_recipe
- tests/test_spine_recipe.py::test_live_recipe_pair_missing_outranks_children
- tests/test_spine_recipe.py::test_gold_off_spine_catches_icon_on_granary
- tests/test_spine_recipe.py::test_mermaid_names_the_village_band
- tests/test_spine_recipe.py::test_quest_schema_and_manager_read_authored_clocks
- tests/test_surface_rooms.py::test_c_and_x_tabs_read_surface_rooms
- tests/test_surface_rooms.py::test_commitments_are_market_holds_charge_is_story
- tests/test_surface_rooms.py::test_walk_cues_and_dock_share_one_table
- tests/test_surface_rooms.py::test_overlay_manager_xy_is_arc_xu_is_charge_xi_is_guide
- tests/test_top_strip_geometry.py::test_every_row_receives_the_layout_manager
- tests/test_verb_grammar.py::test_ace_q_shift_is_mass_gather_not_reap
- tests/test_verb_grammar.py::test_multi_click_arms_batch_and_toasts_shift_f
- tests/test_verb_grammar.py::test_qerf_swaps_instead_of_cramming
- tests/test_verb_grammar.py::test_reap_is_the_season_button
- tests/test_verb_grammar.py::test_unlock_keys_match_the_grammar
