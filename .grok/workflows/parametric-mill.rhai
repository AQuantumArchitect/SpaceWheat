let meta = #{
    name: "parametric-mill",
    description: "SpaceWheat parametric mill: leftover-stop, dump, pytest, grind. Cheap seats never fold. Parent synthesizes.",
    when_to_use: "Parametric playtest treadmill. Dump-first, grind gold, packet the wall. Do not hive-wave. Parent folds. Never leftover-stop Windows.",
    phases: [
        #{ title: "Clear", detail: "leftover-stop WSL Godot only" },
        #{ title: "Measure", detail: "dump checkpoint + pytest pins in parallel" },
        #{ title: "Follow", detail: "grind gold when dump is CLEAN with one key" },
        #{ title: "Packet", detail: "structured mill packet for parent fold" },
    ],
};

fn trimmed(s) {
    if type_of(s) == "string" { s.trim(); s } else { "" }
}

fn as_text(v) {
    if v == () { "" }
    else if type_of(v) == "string" { v }
    else { json_encode(v) }
}

fn as_bool(v) {
    v == true
}

fn as_list(v) {
    if type_of(v) == "array" { v } else { [] }
}

let seat_schema = #{
    "type": "object",
    "properties": #{
        "ok": #{ "type": "boolean" },
        "godot_live": #{ "type": "boolean" },
        "note": #{ "type": "string" },
        "error": #{ "type": "string" },
    },
};

let dump_schema = #{
    "type": "object",
    "properties": #{
        "ok": #{ "type": "boolean" },
        "clean": #{ "type": "boolean" },
        "checkpoint": #{ "type": "string" },
        "followable_key": #{ "type": "string" },
        "live_beat": #{ "type": "string" },
        "farm_banner": #{ "type": "string" },
        "mill_seated": #{ "type": "boolean" },
        "village_axes": #{ "type": "array", "items": #{ "type": "string" } },
        "lies": #{ "type": "array", "items": #{ "type": "string" } },
        "flags_fired_n": #{ "type": "integer" },
        "campaign_fired": #{ "type": "integer" },
        "campaign_beats": #{ "type": "integer" },
        "error": #{ "type": "string" },
        "dump_path": #{ "type": "string" },
    },
};

let pins_schema = #{
    "type": "object",
    "properties": #{
        "ok": #{ "type": "boolean" },
        "passed": #{ "type": "integer" },
        "failed": #{ "type": "integer" },
        "summary": #{ "type": "string" },
        "error": #{ "type": "string" },
    },
};

let grind_schema = #{
    "type": "object",
    "properties": #{
        "ok": #{ "type": "boolean" },
        "clean": #{ "type": "boolean" },
        "stop": #{ "type": "string" },
        "lie": #{ "type": "string" },
        "last_gold": #{ "type": "string" },
        "followable": #{ "type": "string" },
        "n_presses": #{ "type": "integer" },
        "presses_head": #{ "type": "string" },
        "new_flags": #{ "type": "array", "items": #{ "type": "string" } },
        "mill_seated": #{ "type": "boolean" },
        "error": #{ "type": "string" },
        "grind_path": #{ "type": "string" },
    },
};

let checkpoint = "literalist_timber_rhythm_wall";
let budget_n = 10;
let repo = "/home/primearchitect/ws/SpaceWheat";
let leftover = "/mnt/c/Users/LUKESP~1/AppData/Local/Temp/sw_leftover_stop.sh";
let skip_grind = false;
let skip_pins = false;
if args != () {
    if args.checkpoint != () { checkpoint = trimmed(as_text(args.checkpoint)); }
    if args.budget != () { budget_n = args.budget; }
    if args.repo != () { repo = trimmed(as_text(args.repo)); }
    if args.leftover != () { leftover = trimmed(as_text(args.leftover)); }
    if args.skip_grind == true { skip_grind = true; }
    if args.skip_pins == true { skip_pins = true; }
}
if checkpoint == "" {
    pause("verification", "Pass args.checkpoint (default literalist_timber_rhythm_wall).");
}

let hive_path = "export PATH=/home/primearchitect/.local/bin:/usr/bin:/bin";
let wsl_pre = "wsl -e bash -lc ";

log("parametric-mill checkpoint=" + checkpoint + " budget=" + budget_n.to_string());

phase("Clear");
let clear_p = "";
clear_p += "You are a SpaceWheat mill seat. Execute leftover-stop for WSL Godot only. ";
clear_p += "Do not leftover-stop or taskkill Windows SpaceWheat.exe. Do not edit game files. ";
clear_p += "Run this PowerShell command with run_terminal_command:\n";
clear_p += wsl_pre + "'" + hive_path + "; bash " + leftover + "'\n";
clear_p += "Then run: wsl -e bash -lc 'pgrep -af rig_listener || true'\n";
clear_p += "A bash -lc line that itself contains godot/rig_listener is not a live Godot. ";
clear_p += "ok=true when leftover-stop printed NO_GODOT or only the checker line remains. ";
clear_p += "godot_live=true only if a real rig_listener Godot process is up.";
let clear_r = agent(clear_p, #{
    label: "clear-godot",
    capability_mode: "execute",
    output_schema: seat_schema,
});
let godot_live = false;
if clear_r != () && clear_r.success && clear_r.output != () {
    godot_live = as_bool(clear_r.output.godot_live);
}
if godot_live {
    log("Godot still live after leftover-stop — packet infra, no second Godot");
}

phase("Measure");
let dump_p = "";
dump_p += "You are a SpaceWheat mill dump seat. One Godot. Do not edit game files. ";
dump_p += "Do not leftover-stop Windows SpaceWheat.exe. Do not launch hive-wave or a persona. ";
dump_p += "Repo: " + repo + "\nCheckpoint: " + checkpoint + "\n";
dump_p += "1. Run leftover-stop first if another WSL Godot might be up:\n";
dump_p += wsl_pre + "'" + hive_path + "; bash " + leftover + "'\n";
dump_p += "2. Dump with a long wait (Godot boot ~2 min). Command:\n";
dump_p += wsl_pre + "'" + hive_path + "; cd " + repo + "; python3 🍄/🧪/hive/dump_checkpoint.py " + checkpoint + "'\n";
dump_p += "Set block_until_ms to 180000.\n";
dump_p += "3. Read " + repo + "/🍄/🧪/hive/waves/dump_latest.json with read_file.\n";
dump_p += "Fill the schema from that JSON only. farm_banner is the joined ActFilament lines. ";
dump_p += "live_beat is mill.live_beat or campaign.live.beat. ";
dump_p += "ok=true when the dump command exited 0. clean=true only if dump.clean is true and lies is empty. ";
dump_p += "If the command fails, ok=false and put stderr in error. Do not guess flags.";

let pins_p = "";
pins_p += "You are a SpaceWheat mill pytest seat. Do not edit game files. Do not boot Godot. ";
pins_p += "Repo: " + repo + "\n";
pins_p += "Run this and wait for it (block_until_ms 60000):\n";
pins_p += wsl_pre + "'" + hive_path + "; cd " + repo + "; python3 -m pytest ";
pins_p += "tests/test_hive_testing_stack.py::test_dump_flags_mill_seated_plant_as_lie ";
pins_p += "tests/test_hive_testing_stack.py::test_grind_follow_is_player_parity_and_raises_cap ";
pins_p += "tests/test_hive_testing_stack.py::test_grind_first_press_picks_advertised_key ";
pins_p += "tests/test_lane_minimalism.py::test_ready_claim_outranks_leftover_arc_accept ";
pins_p += "tests/test_lane_minimalism.py::test_unpayable_fill_does_not_mill_abandon ";
pins_p += "tests/test_narrative_spine_face.py::test_banner_names_the_arc_offer_the_story_waits_on ";
pins_p += "tests/test_hive_testing_stack.py::test_testing_stack_doc_names_four_layers ";
pins_p += "-q --tb=line'\n";
pins_p += "Do not run the whole test_hive_testing_stack file (millwright stash pins fail on campaign HEAD). ";
pins_p += "ok=true only if pytest exit 0. Put the last pytest summary line in summary. failed count from output.";

let measure_jobs = [];
measure_jobs.push(#{
    prompt: dump_p,
    label: "dump",
    capability_mode: "execute",
    output_schema: dump_schema,
});
if skip_pins == false {
    measure_jobs.push(#{
        prompt: pins_p,
        label: "pins",
        capability_mode: "execute",
        output_schema: pins_schema,
    });
}
let measure = parallel(measure_jobs);

let dump_out = #{};
let pins_out = #{};
if measure.len() > 0 && measure[0] != () && measure[0].success && measure[0].output != () {
    dump_out = measure[0].output;
}
if skip_pins == false && measure.len() > 1 && measure[1] != () && measure[1].success && measure[1].output != () {
    pins_out = measure[1].output;
}

let dump_ok = as_bool(dump_out.ok);
let dump_clean = as_bool(dump_out.clean);
let dump_key = trimmed(as_text(dump_out.followable_key));
let dump_beat = trimmed(as_text(dump_out.live_beat));
let dump_gold = trimmed(as_text(dump_out.farm_banner));
let dump_lies = as_list(dump_out.lies);
let pins_ok = true;
if skip_pins == false { pins_ok = as_bool(pins_out.ok); }

log("dump ok=" + as_text(dump_ok) + " clean=" + as_text(dump_clean) + " key=" + dump_key + " beat=" + dump_beat);
log("pins ok=" + as_text(pins_ok));

let dual_bind = false;
let gold_u = dump_gold;
gold_u.make_upper();
if dump_clean && dump_key != "" {
    if gold_u.contains("[C]") && gold_u.contains("[X]") { dual_bind = true; }
    if gold_u.contains("[C]") && gold_u.contains("[5]") { dual_bind = true; }
}

let do_grind = dump_ok && dump_clean && dump_key != "" && skip_grind == false && dual_bind == false && godot_live == false;
if dump_clean == false {
    log("dump DIRTY — skip grind; parent folds");
}
if dual_bind {
    log("dual-bind gold — skip grind; parent decides, do not auto literalist");
}
if pins_ok == false {
    log("pytest pins failed — still grind if dump CLEAN (pins are mill law, parent folds tests)");
}

let grind_out = #{};
let dump2_out = #{};
if do_grind {
    phase("Follow");
    let clear2_p = "";
    clear2_p += "You are a SpaceWheat mill seat. leftover-stop WSL Godot only so grind has one Godot. ";
    clear2_p += "Do not leftover-stop Windows SpaceWheat.exe. Do not edit files. Run:\n";
    clear2_p += wsl_pre + "'" + hive_path + "; bash " + leftover + "'\n";
    clear2_p += "ok=true when NO_GODOT or only the checker line. godot_live=true only for a real rig_listener. ";
    clear2_p += "If leftover-stop prints a real godot line, run leftover-stop again then: wsl -e bash -lc 'pkill -9 -f /home/primearchitect/.local/bin/godot || true'. Dump's Godot leftover is expected; kill it so grind can boot one Godot.";
    let clear2 = agent(clear2_p, #{
        label: "clear-before-grind",
        capability_mode: "execute",
        output_schema: seat_schema,
    });
    let still_live = false;
    if clear2 != () && clear2.success && clear2.output != () {
        still_live = as_bool(clear2.output.godot_live);
    }
    if still_live {
        let kill_p = "";
        kill_p += "Dump leftover Godot. leftover-stop WSL Godot then pkill -9. Do not leftover-stop Windows. Run:\n";
        kill_p += wsl_pre + "'" + hive_path + "; bash " + leftover + "; pkill -9 -f /home/primearchitect/.local/bin/godot || true; sleep 1; pgrep -af godot || echo NO_GODOT'\n";
        kill_p += "ok=true when NO_GODOT. godot_live=true only for a real rig_listener.";
        let kill_r = agent(kill_p, #{
            label: "kill-dump-godot",
            capability_mode: "execute",
            output_schema: seat_schema,
        });
        still_live = false;
        if kill_r != () && kill_r.success && kill_r.output != () {
            still_live = as_bool(kill_r.output.godot_live);
        }
    }
    if still_live == false {
        let grind_p = "";
        grind_p += "You are a SpaceWheat grind_follow seat. No LLM playtest. No add_resource. No inject_icon. ";
        grind_p += "Do not edit game files. Do not leftover-stop Windows. Do not hive-wave. ";
        grind_p += "Repo: " + repo + "\nCheckpoint: " + checkpoint + "\nBudget: " + budget_n.to_string() + "\n";
        grind_p += "Dump gold was: " + dump_gold + "\nFollowable: " + dump_key + "\nLive beat: " + dump_beat + "\n";
        grind_p += "Run with a long wait (80 presses ~5 min). block_until_ms 480000:\n";
        grind_p += wsl_pre + "'" + hive_path + "; cd " + repo + "; python3 🍄/🧪/hive/grind_follow.py --budget ";
        grind_p += budget_n.to_string() + " --bank " + checkpoint + "'\n";
        grind_p += "Then read " + repo + "/🍄/🧪/hive/waves/grind_latest.json with read_file. ";
        grind_p += "Fill the schema from that JSON only. presses_head is the first 16 presses joined by commas. ";
        grind_p += "ok=true when grind_follow exited 0. Do not invent new_flags.";
        let grind_r = agent(grind_p, #{
            label: "grind",
            capability_mode: "execute",
            output_schema: grind_schema,
        });
        if grind_r != () && grind_r.success && grind_r.output != () {
            grind_out = grind_r.output;
        }
        let dump2_p = "";
        dump2_p += "You are a SpaceWheat mill dump seat after grind. leftover-stop WSL Godot first, then dump. ";
        dump2_p += "Do not leftover-stop Windows. Do not edit files. Repo: " + repo + " Checkpoint: " + checkpoint + "\n";
        dump2_p += "1. leftover-stop: " + wsl_pre + "'" + hive_path + "; bash " + leftover + "'\n";
        dump2_p += "2. dump (block_until_ms 180000): " + wsl_pre + "'" + hive_path + "; cd " + repo;
        dump2_p += "; python3 🍄/🧪/hive/dump_checkpoint.py " + checkpoint + "'\n";
        dump2_p += "3. Read " + repo + "/🍄/🧪/hive/waves/dump_latest.json. Fill schema from JSON. ";
        dump2_p += "ok=true on dump exit 0. clean=true only if dump.clean and lies empty.";
        let dump2_r = agent(dump2_p, #{
            label: "dump-after-grind",
            capability_mode: "execute",
            output_schema: dump_schema,
        });
        if dump2_r != () && dump2_r.success && dump2_r.output != () {
            dump2_out = dump2_r.output;
        }
    } else {
        log("skip grind — Godot still live");
    }
} else {
    let clear_m_p = "";
    clear_m_p += "leftover-stop WSL Godot only after measure. Do not leftover-stop Windows. Do not edit files. Run:\n";
    clear_m_p += wsl_pre + "'" + hive_path + "; bash " + leftover + "'\n";
    clear_m_p += "ok=true when NO_GODOT. godot_live=true only for a real rig_listener.";
    agent(clear_m_p, #{
        label: "clear-after-measure",
        capability_mode: "execute",
        output_schema: seat_schema,
    });
}

phase("Packet");
let grind_stop = trimmed(as_text(grind_out.stop));
let grind_lie = trimmed(as_text(grind_out.lie));
let grind_gold = trimmed(as_text(grind_out.last_gold));
let grind_flags = as_list(grind_out.new_flags);
let beat2 = trimmed(as_text(dump2_out.live_beat));
if beat2 == "" { beat2 = dump_beat; }

let next_action = "fold";
if dump_ok == false {
    next_action = "infra";
} else if dump_clean == false || dump_lies.len() > 0 {
    next_action = "fold";
} else if dual_bind {
    next_action = "dual_bind";
} else if do_grind == false && skip_grind {
    next_action = "measure_only";
} else if grind_lie != "" {
    next_action = "fold";
} else if grind_flags.len() > 0 {
    next_action = "banked";
} else if beat2 != "" && dump_beat != "" && beat2 != dump_beat {
    next_action = "beat_moved";
} else if grind_stop == "gold_frozen" || grind_stop == "budget" || grind_stop == "lie" {
    next_action = "fold";
} else if dump_clean && grind_out.ok == true {
    next_action = "grind_again";
}

let parent_job = "Synthesize this mill packet and fold the HUD/grind in the WSL SpaceWheat tree. ";
parent_job += "Do not leftover-stop Windows. Do not hive-wave. Do not mill Abandon or Hearth. ";
parent_job += "Do not cull Woodlot. Ace never Superposes. Never mill TheDemos [T]. ";
parent_job += "READY Claim outranks leftover Arc Accept. Live campaign beat outranks leftover READY rows. ";
parent_job += "After a mill fold: leftover-stop, dump, pytest subset, grind 80 --bank.";

let packet = #{
    next_action: next_action,
    checkpoint: checkpoint,
    budget: budget_n,
    dump_ok: dump_ok,
    dump_clean: dump_clean,
    followable_key: dump_key,
    live_beat: dump_beat,
    live_beat_after: beat2,
    farm_banner: dump_gold,
    mill_seated: as_bool(dump_out.mill_seated),
    lies: dump_lies,
    pins_ok: pins_ok,
    pins_summary: trimmed(as_text(pins_out.summary)),
    grind_ok: as_bool(grind_out.ok),
    grind_stop: grind_stop,
    grind_lie: grind_lie,
    last_gold: grind_gold,
    n_presses: grind_out.n_presses,
    presses_head: trimmed(as_text(grind_out.presses_head)),
    new_flags: grind_flags,
    dual_bind: dual_bind,
    parent_job: parent_job,
};

let report = "";
report += "# parametric-mill packet\n\n";
report += "- next_action: `" + next_action + "`\n";
report += "- checkpoint: `" + checkpoint + "`\n";
report += "- dump: ok=" + as_text(dump_ok) + " clean=" + as_text(dump_clean) + " key=`" + dump_key + "` beat=`" + dump_beat + "`\n";
report += "- gold: " + dump_gold + "\n";
report += "- lies: " + json_encode(dump_lies) + "\n";
report += "- pins_ok: " + as_text(pins_ok) + " " + trimmed(as_text(pins_out.summary)) + "\n";
report += "- grind: stop=`" + grind_stop + "` lie=`" + grind_lie + "` last=`" + grind_gold + "`\n";
report += "- new_flags: " + json_encode(grind_flags) + "\n";
report += "- live_beat_after: `" + beat2 + "`\n";
report += "- dual_bind: " + as_text(dual_bind) + "\n\n";
report += "## Parent fold job\n\n";
report += parent_job + "\n";
let path = write_scratch_file("mill-packet.md", report);
log("packet next_action=" + next_action + " path=" + path);
complete(#{ path: path, packet: packet, summary: "next_action=" + next_action + " beat=" + dump_beat });
