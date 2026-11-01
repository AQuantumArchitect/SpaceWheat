let meta = #{
    name: "hive-wave",
    description: "Sequential SpaceWheat hive sensor wave, recap, auto-promote clears. One Godot. Sensors never edit.",
    when_to_use: "Send a hive playtest wave through SpaceWheat. Overlay chapters: literalist only, then recap. tap-lamb is Act-0 mouse only. Dump-first. Sensors never edit.",
    phases: [
        #{ title: "Roster", detail: "per-persona chapter from the promotions ledger" },
        #{ title: "Sensors", detail: "one persona at a time — never parallel Godot" },
        #{ title: "Recap", detail: "one table humans read" },
        #{ title: "Promote", detail: "earned banks advance; no bank, no promotion" },
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

fn persona_stem(p) {
    if p == "lost-lamb" { "lost_lamb" }
    else if p == "tap-lamb" { "tap_lamb" }
    else { p }
}

fn sensor_model(p) {
    "grok-4.5"
}

fn harness_death(line) {
    let t = as_text(line);
    // w363: wall note "STALE in w357" aborted remaining seats. Bare STALE
    // is not this sitting. HARNESS / outcome crash / stale_after_load are.
    t.contains("HARNESS") || t.contains("ok:false") || t.contains(" FAILED") || t.contains("stale_after_load") || t.contains("outcome: crash") || t.contains("outcome:crash") || t.contains("reap_cost_sequence") || t.contains("splash screen") || t.contains("stuck splash") || t.contains("never becomes the farm")
}

fn overlay_heavy(ch) {
    let t = as_text(ch);
    t.contains("timber") || t.contains("woodlot") || t.contains("mill") || t.contains("knot") || t.contains("gear") || t.contains("union") || t.contains("lantern")
}

fn act0_chapter(ch) {
    let t = as_text(ch);
    t == "act0_fresh" || t == "act0" || t.contains("core_loop") || t.contains("wayfinding") || t.contains("mass_explore") || t.contains("superposition") || t.contains("reap_season")
}

fn should_abort_rest(line, last_gold, chapter) {
    if harness_death(line) { true }
    else {
        let t = as_text(line);
        let wall = t.contains("outcome: wall") || t.contains("outcome:wall");
        let cap = t.contains("press_cap");
        let lie = t.contains("HUD lie") || t.contains("BoardTab_U");
        let same = last_gold != "" && t.contains(last_gold) && wall;
        let heavy_wall = overlay_heavy(chapter) && wall;
        cap || lie || same || heavy_wall
    }
}

let chapter = "act0_fresh";
let checkpoint = "";
let stamp = "hive-wave";
let personas = ["literalist", "lost-lamb", "earnest"];
let starts = [];
let dump_note = "";
let include_tap_lamb = false;
let include_earnest = false;
let last_gold = "";
if args != () {
    if args.chapter != () { chapter = args.chapter; }
    if args.checkpoint != () { checkpoint = args.checkpoint; }
    if args.stamp != () { stamp = args.stamp; }
    if args.personas != () { personas = args.personas; }
    if args.starts != () { starts = args.starts; }
    if args.dump_note != () { dump_note = as_text(args.dump_note); }
    if args.last_gold != () { last_gold = as_text(args.last_gold); }
    if args.include_tap_lamb == true { include_tap_lamb = true; }
    if args.include_earnest == true { include_earnest = true; }
    if args.include_tap_lamb == true {
        let already = false;
        for p in personas {
            if p == "tap-lamb" { already = true; }
        }
        if already == false { personas.push("tap-lamb"); }
    }
}

if type_of(personas) != "array" {
    pause("verification", "args.personas must be an array of persona names, e.g. [\"literalist\",\"earnest\"].");
}

const KNOWN = ["masher", "literalist", "earnest", "lost-lamb", "tap-lamb", "runner"];
let kept = [];
let dropped = [];
for p in personas {
    let name = trimmed(p);
    let ok = false;
    for k in KNOWN {
        if name == k { ok = true; }
    }
    if ok { kept.push(name); } else { dropped.push(name); }
}
if dropped.len() > 0 {
    log("dropped unknown personas: " + json_encode(dropped));
}
if kept.len() == 0 {
    pause("verification", "No known personas. Use masher, literalist, earnest, lost-lamb, tap-lamb, runner.");
}
personas = kept;

// TESTING_STACK: tap-lamb is Act-0 mouse only (BoardTab_U overlaps Reap).
// Overlay grind uses one literalist seat unless include_earnest.
let rostered = [];
for p in personas {
    let drop = false;
    if p == "tap-lamb" && include_tap_lamb == false && act0_chapter(chapter) == false {
        log("dropped tap-lamb — overlay chapter, BoardTab_U/Reap overlap");
        drop = true;
    }
    if p == "earnest" && overlay_heavy(chapter) && include_earnest == false {
        log("dropped earnest — overlay grind uses one literalist seat");
        drop = true;
    }
    if drop == false { rostered.push(p); }
}
if rostered.len() == 0 {
    rostered.push("literalist");
}
personas = rostered;
log("roster after testing-stack filter: " + json_encode(personas));

let recap_schema = #{
    "type": "object",
    "required": ["markdown", "rows", "live_door"],
    "properties": #{
        "markdown": #{ "type": "string" },
        "live_door": #{ "type": "string" },
        "rows": #{
            "type": "array",
            "maxItems": 8,
            "items": #{
                "type": "object",
                "required": ["persona", "outcome", "chapter"],
                "properties": #{
                    "persona": #{ "type": "string" },
                    "outcome": #{ "type": "string" },
                    "chapter": #{ "type": "string" },
                    "presses": #{ "type": "string" },
                    "bank": #{ "type": "string" },
                    "note": #{ "type": "string" },
                },
            },
        },
    },
};

let starts_schema = #{
    "type": "object",
    "required": ["starts"],
    "properties": #{
        "starts": #{
            "type": "array",
            "maxItems": 8,
            "items": #{
                "type": "object",
                "required": ["persona", "chapter"],
                "properties": #{
                    "persona": #{ "type": "string" },
                    "chapter": #{ "type": "string" },
                    "checkpoint": #{ "type": "string" },
                    "door": #{ "type": "string" },
                    "band": #{ "type": "string" },
                },
            },
        },
    },
};

phase("Roster");
if type_of(starts) != "array" { starts = []; }
if starts.len() == 0 {
    let names = "";
    let i = 0;
    for p in personas {
        if i > 0 { names += ","; }
        names += p;
        i += 1;
    }
    let roster_prompt = "";
    roster_prompt += "Read the SpaceWheat promotions ledger and return starts for this wave.\n";
    roster_prompt += "Run exactly:\n";
    roster_prompt += "  wsl bash -lc \"cd /home/primearchitect/ws/SpaceWheat && python3 🍄/🧪/hive/promote.py starts --personas " + names + " --json\"\n";
    roster_prompt += "Return that JSON object (starts array of {persona, chapter, checkpoint, door, band}). Do not edit code.\n";
    let roster = agent(roster_prompt, #{
        label: "roster",
        capability_mode: "execute",
        agent_type: "general-purpose",
        output_schema: starts_schema,
    });
    if roster != () && roster.success && roster.output != () && roster.output.starts != () {
        starts = roster.output.starts;
    }
    log("roster fetched");
}

if starts.len() == 0 {
    for p in personas {
        let ck = checkpoint;
        starts.push(#{
            persona: p,
            chapter: chapter,
            checkpoint: ck,
            door: chapter,
            band: "spine",
        });
    }
}

let kept_starts = [];
for s in starts {
    let pn = trimmed(s.persona);
    let keep_s = false;
    for p in personas {
        if pn == p { keep_s = true; }
    }
    if keep_s { kept_starts.push(s); }
}
starts = kept_starts;
if starts.len() == 0 {
    for p in personas {
        starts.push(#{
            persona: p,
            chapter: chapter,
            checkpoint: checkpoint,
            door: chapter,
            band: "spine",
        });
    }
}

log("wave " + stamp + " sequential " + starts.len().to_string() + " seats");

phase("Sensors");
let reports = [];
for s in starts {
    let p = trimmed(s.persona);
    if p == "" { p = "earnest"; }
    let ch = chapter;
    if s.chapter != () { ch = trimmed(s.chapter); }
    if ch == "" { ch = chapter; }
    let ck = "";
    if s.checkpoint != () { ck = trimmed(s.checkpoint); }
    let mouse = p == "tap-lamb";
    let seat_py = "python3 🍄/🧪/player_seat.py";
    if mouse { seat_py = "python3 🍄/🧪/mouse_seat.py"; }
    let seat = "w_" + stamp + "_" + p;
    let stem = persona_stem(p);
    let mdl = sensor_model(p);
    let scout = p == "runner";
    let prompt = "";
    prompt += "You are a SpaceWheat SENSOR playtester. Persona: " + p + ". Seat: " + seat + ". ";
    prompt += "Chapter: " + ch + ". Model " + mdl + ". You never edit code, data, or saves.\n";
    prompt += "BEFORE any input, READ with the Read tool:\n";
    prompt += "  \\\\wsl$\\Ubuntu\\home\\primearchitect\\ws\\SpaceWheat\\🍄\\🧪\\hive\\prompts\\SENSOR.md\n";
    prompt += "  \\\\wsl$\\Ubuntu\\home\\primearchitect\\ws\\SpaceWheat\\🍄\\🧪\\hive\\prompts\\HOST.md\n";
    prompt += "  \\\\wsl$\\Ubuntu\\home\\primearchitect\\ws\\SpaceWheat\\🍄\\🧪\\hive\\prompts\\" + p + ".md\n";
    prompt += "Do not guess the seat CLI. Fetch it.\n";
    prompt += "Host is Grok Build on Windows. Every game command is one wsl bash -lc string. No $ in that string. Use &&, never ;.\n";
    prompt += "Repo: cd /home/primearchitect/ws/SpaceWheat\n";
    prompt += "Seat binary: " + seat_py + "\n";
    if mouse {
        prompt += "This persona is MOUSE ONLY. press is refused. look / click / tap / click_at only.\n";
        prompt += "Headed — one live Godot. Stop any leftover seat first.\n";
        prompt += "First tap on a plot bubble SELECTS. Tap around to move the highlight. A later tap on the already-selected (focused) bubble runs Ace. Do not mash every bubble on first contact.\n";
    } else {
        prompt += "Keyboard player_seat. One live headless Godot. Stop any leftover seat first:\n";
        prompt += "  wsl bash -lc \"cd /home/primearchitect/ws/SpaceWheat && python3 🍄/🧪/player_seat.py stop " + seat + "\"\n";
    }
    if ck != "" {
        prompt += "Start with --fresh --checkpoint " + ck + "\n";
        prompt += "This save was EARNED by clearing the previous chapter. Not a shortcut. Walk the live door yourself.\n";
        prompt += "Lost-lamb / tap-lamb: still look before every input. No intra-session plan. The checkpoint is only where you stand.\n";
    } else {
        prompt += "Start from true zero: --fresh (no --checkpoint). Welcome splash may be up.\n";
    }
    prompt += "start can take up to ~4 minutes. Wait for {\"ok\": true}. Then look before any input.\n";
    if dump_note != "" {
        prompt += "DUMP-FIRST (parent already dumped this checkpoint; look still required; follow this unless look contradicts):\n";
        prompt += dump_note + "\n";
    }
    prompt += "HARNESS DEATH: start ok:false, STALE, empty screen_text AND empty field, welcome/loading splash that never becomes the farm, or reap_cost_sequence spam. Stop immediately. outcome=crash. Stop Godot. Do not mash. Do not try another seat. Parent folds before the next persona.\n";
    prompt += "HUMAN-VS-SWARM (Luke playtest lessons bots missed — treat as laws):\n";
    prompt += "- Mouse: first tap on a bubble SELECTS; later tap on the already-selected bubble is Ace. Do not mash every bubble on first contact.\n";
    prompt += "- Ace never Superposes. Do not Strike unmeasured death-seed (skull-sprout) — that pays skull, not sprout. Even-coin: [U] Forest, [J], [F] if sleeping, [0] Druid, [E] once, [8] Ace, [R] Strike, [Q] if sprout.\n";
    prompt += "- Do not mill empty Arc. If banner names Arc/[X]/[Y] but overlay is empty, WALL that HUD lie. Do not press X hoping.\n";
    prompt += "- Do not mill empty Charge. Charge overlay 'no charge yet' means gold must not name Charge [U]. Do not mill [C]ontracts unless look shows an unsigned board offer.\n";
    prompt += "- Dual-bind keys: farm gold 'biome [U] StarterForest' is the Forest biome TAB (TYUIOP), not Commitments overlay, not Charge, not System pause Z. Keyboard U crosses to Forest. Do not click BoardTab_U (~742,176) — that overlaps TimeBar ReapChip (Reap pauses and opens Self). w370 ClockSpeedRow mute missed Reap. [Y] is Village tab, not Market. Market is [C]ontracts then the Market row. A/D pages a stall overlay, it does not cycle ZXCVBNM when the top overlay has _on_navigate.\n";
    prompt += "- Humans press advertised keys. Bots click named HUD chips. A named BoardTab that shares pixels with a later-tree TimeBar rider is a HUD lie — mill ActionBtn_R or the keyboard key, never the overlapping tab.\n";
    prompt += "- Empty Commitments after Deliver: already on [U] and gold still names [U]Commitments is a HUD lie. Mill leftover [R] Deliver/Claim or ESC. Do not press U again.\n";
    prompt += "- Superpose lesson: after SHIFT [F] mass Explore and SHIFT [R] mass Strike, mill [F] Explore / SHIFT [F] remount before [0] Druid. Fogged plots are not the Superpose canvas. Ace never Superposes. After Superpose, mill Ace then Village warm-up (honest biome key, often [Y]), Strike 🔥 until it lands, Strike again to stack, then [Q] Gather. Do not mill Bell until that Q. A second [E] undoes Superpose.\n";
    prompt += "- A visible hat has a live action bar. Icon is hidden for all of Act 0. Do not mill [5] Icon while the tab is missing. A hat with every chip locked is a HUD lie — wall it.\n";
    prompt += "- Hard cap 20 inputs this sitting. A human will not mill Market thousands of times. After a Deliver, mill [Q] Refresh (1🐇) to change which country the next stall comes from. Shift+E is an unadvertised alias. Repeating Accept-Deliver-[C] without Refresh is a wall. press_cap is a wall, not a prompt to mash. press_cap on a standing grind (Gear-Bench / Union access) is cap-vs-grind: bank, stop, parent runs grind_follow.py.\n";
    prompt += "- TESTING_STACK: dump-first must be CLEAN. Do not mill empty Arc. NEVER mill [H] empty plot while Village H is occupied. NEVER mill Captain cull Woodlot. KEYBOARD [U] not BoardTab_U. Ace never Superposes. Icon mill ⚙ not 🏭. After mill seated, gold mills [C]ontracts then Refresh after a fill.\n";
    prompt += "- Hammer mill: first-learn seats hammer in The Demos; harvest at home then pay 13 to plant Village. [Q] Refresh rerolls stall goods, not the pay emoji. Shift+E is an unadvertised alias. Delivery pays advertised stall only.\n";
    prompt += "- Humans play the Windows Games-folder exe. Source folds are invisible until export. Dump-first catches HUD lies bots mill as printed keys. Follow DUMP-FIRST unless look contradicts.\n";
    prompt += "- Wallet 🦅 outranks gold Spring. If look wallet 🦅 is under 21 and Village has 🦅🐇, mill that plot (usually L). Gold [P] FreshwaterSpring while eagle-short is a HUD lie — wall it. Do not mill Spring to dodge Village Strike.\n";
    prompt += "- ActFilament / gold toast is KEYBOARD-ONLY. Tapping it is a no-op. Mill the named key, biome orb, or QERF chip.\n";
    prompt += "- Do not write the word STALE unless THIS sitting's look is STALE/empty. Mentioning a prior wave's STALE aborts remaining seats (w363 false-positive).\n";
    prompt += "- FRFR is not a loop wall. Gold flipping Strike/Explore while stacking eagle balloons is the mill. Q takes the pile. Wall only if 8-10 presses never name Q and wallet eagles do not move.\n";
    prompt += "- Mill gold Q when gold names Q. [Q] gather eagles cashes the pile. [Q] take rabbits cashes a miss, then mill L again. Do not press the always-on Gather chip while gold still names Strike or Explore.\n";
    prompt += "- w357: mouse tap on overlay chip SelectBtn_3 Contracts hung STALE Godot (empty screen_text). Mill KEYBOARD C for Contracts. If first look after a tap is empty/STALE, WALL immediately (Lane C). Do not mash.\n";
    prompt += "- Buttons only do what they advertise. Player walks doors. Do not mill printed keys that contradict the HUD.\n";
    if scout {
        prompt += "You are the runner on grok-4.5. Play the printed keys. Short plans are allowed. Read screen_text, field, wallet, witness together.\n";
        prompt += "HUNT (file, do not patch): toast vs chip vs banner vs wallet; Arc feeding the next unsigned door; Superpose not H-Gate; Gather not Extract; Contracts/Market not Board; Druid E is hadamard after forest is visible; Ace never Superposes; Operator Bell then Strike; SHIFT [F] mass-explore before Druid; Reap is Ctrl+Shift+Space; Mill plant is 🔨 not Subsistence; grey chips keep their price. A mismatch is a finding even if you can still walk.\n";
        prompt += "Walk as far forward as you honestly can in this sitting. You may clear multiple chapters. Late-game topology is in scope once you walk there.\n";
        prompt += "Do not plant, auto-accept mill, auto-Bell, or wear hats for a skip. Ace never does Druid things. Player walks doors. No gifts.\n";
        prompt += "CURTAIN-PEEK: if stuck (dual-key, mute chrome, chip vs banner, wallet contradict, 3+ dead presses), you MAY Read/Grep GDScript: UIProgression.gd, ToolConfig.gd, AceChipResolvers.gd, ProbeActions.gd, QuantumInstrumentInput.gd, PlayerShell.gd. Name the mechanical why. Still NEVER edit. Do not press a key only source knows unless chrome is mute and the chip/field already names that verb.\n";
        prompt += "If you peek and the world is deadlocked, wall with a second line: DIAGNOSIS: path:line mechanical why. Still a wall — do not patch. If you missed an honest printed verb, resume play.\n";
        prompt += "After each chapter you CLEAR, bank as " + stem + "_CHAPTER_clear, then KEEP WALKING the next live door in the same seat.\n";
        prompt += "Stop only on wall (~8-10 dead presses on the CURRENT door), crash, or beating the game. Press budget 20 this sitting.\n";
        prompt += "At the end, bank as " + stem + "_FURTHEST_clear or " + stem + "_FURTHEST_wall, then stop.\n";
    } else {
        prompt += "Clear this chapter's live door. Do not plant, accept, Bell, or wear hats for a skip — walk the printed keys.\n";
        prompt += "If you CLEAR: bank as " + stem + "_" + ch + "_clear then stop. Skip hive.py wall on a clean clear.\n";
        prompt += "If you WALL: file the wall, bank as " + stem + "_" + ch + "_wall if the seat is worth resuming, then stop.\n";
    }
    prompt += "Walls via --file, never on the command line:\n";
    prompt += "  wsl bash -lc \"printf '%s\\n' 'PERSONA: tried ...; saw ...; expected ...' > /tmp/sw_wall_" + seat + ".txt\"\n";
    prompt += "  wsl bash -lc \"cd /home/primearchitect/ws/SpaceWheat && python3 🍄/🧪/hive/hive.py wall " + ch + " --file /tmp/sw_wall_" + seat + ".txt\"\n";
    prompt += "Bank then stop so the next persona can boot. Laws: sensor never holds the hammer; ~8-10 dead inputs = wall and stop. Hard cap 20 inputs. press_cap = wall.\n";
    prompt += "End with the 8-line report in SENSOR.md (persona / seat / presses / outcome / last screen_text / hat / wall / bank).\n";
    prompt += "outcome must be one of: clear | wall | playing | plateau | crash | failed.\n";
    prompt += "playing = you reached open customization (village identity / the island stops asking) and are exploring, not stuck.\n";
    let r = agent(prompt, #{
        label: "sensor:" + p,
        capability_mode: "execute",
        agent_type: "general-purpose",
    });
    let line = p + " FAILED";
    if r != () && r.success {
        line = as_text(r.output);
        if trimmed(line) == "" { line = p + " empty report"; }
    }
    reports.push(#{ persona: p, chapter: ch, checkpoint: ck, report: line });
    log("finished " + p);
    if should_abort_rest(line, last_gold, ch) {
        log("abort remaining seats this wave (harness / press_cap / HUD lie / overlay-heavy wall / same gold); fold before anyone else boots");
        break;
    }
}

phase("Recap");
let recap_prompt = "";
recap_prompt += "Write a SpaceWheat hive wave recap. Humans read this. Do not invent walls.\n";
recap_prompt += "Stamp: " + stamp + ".\n";
recap_prompt += "Laws: no back doors; Ace never does Druid things; player walks doors; no promotion without a banked save.\n";
recap_prompt += "Return JSON with: markdown (a table Persona | Presses | Outcome | Note, then one paragraph naming the live door), live_door (string), and rows array.\n";
recap_prompt += "Each row: persona, outcome (clear|wall|playing|plateau|crash|failed), chapter (the chapter they were sent to, from the reports JSON), presses, bank (the bank name they reported, or empty), note.\n";
recap_prompt += "If a report is FAILED or empty, outcome=failed. Do not mark clear unless the sensor said they cleared the live door.\n";
recap_prompt += "Measure SPINE not wave count: name mill seated (Village ⚙/🏭), last gold, press_cap vs grind, and whether FLAG/standing moved vs the previous stamp. A wave that reprints last gold with no FLAG/standing change is a process failure, not a finding. tap-lamb BoardTab_U is mouse chrome, not a timber_rhythm wall. After Deliver gold must mill [Q] Refresh, not leftover Accept.\n";
recap_prompt += "Reports JSON:\n";
recap_prompt += json_encode(reports);
let recap = agent(recap_prompt, #{
    label: "recap",
    capability_mode: "read-only",
    agent_type: "general-purpose",
    output_schema: recap_schema,
});
let body = "";
let rows = [];
let live_door = "";
if recap != () && recap.success && recap.output != () {
    if recap.output.markdown != () { body = as_text(recap.output.markdown); }
    if recap.output.live_door != () { live_door = as_text(recap.output.live_door); }
    if recap.output.rows != () { rows = recap.output.rows; }
}
if trimmed(body) == "" {
    body = "# Wave " + stamp + "\n\nRecap agent failed. Raw reports:\n\n" + json_encode(reports) + "\n";
}

phase("Promote");
let apply_rows = [];
if type_of(rows) == "array" && rows.len() > 0 {
    for row in rows {
        apply_rows.push(row);
    }
} else {
    for r in reports {
        apply_rows.push(#{
            persona: r.persona,
            chapter: r.chapter,
            outcome: "failed",
            bank: "",
            note: "recap missing row",
        });
    }
}
let inbox = #{
    stamp: stamp,
    markdown: body,
    rows: apply_rows,
};
let promote_prompt = "";
promote_prompt += "Apply SpaceWheat hive auto-promotion. Sensors never edit; you only run promote.py apply.\n";
promote_prompt += "1. Write this JSON with the Write tool to:\n";
promote_prompt += "   \\\\wsl$\\Ubuntu\\home\\primearchitect\\ws\\SpaceWheat\\🍄\\🧪\\hive\\promotions_inbox.json\n";
promote_prompt += json_encode(inbox);
promote_prompt += "\n2. Then run:\n";
promote_prompt += "   wsl bash -lc \"cd /home/primearchitect/ws/SpaceWheat && python3 🍄/🧪/hive/promote.py apply --file 🍄/🧪/hive/promotions_inbox.json\"\n";
promote_prompt += "3. Write the recap markdown (inbox.markdown) with the Write tool to:\n";
promote_prompt += "   \\\\wsl$\\Ubuntu\\home\\primearchitect\\ws\\SpaceWheat\\🍄\\🧪\\hive\\waves\\" + stamp + ".md\n";
promote_prompt += "4. Return the command's JSON stdout. Do not edit game code. Do not invent banks.\n";
promote_prompt += "Promotion law: a clear without a real 🍄/🧪/checkpoints/<bank>.tres does not advance. Do not promote wall banks. village_path_watched starts stay on village_path_watched (promote overlay maps commons — ALWAYS override).\n";
let promo = agent(promote_prompt, #{
    label: "promote",
    capability_mode: "execute",
    agent_type: "general-purpose",
});
let promo_text = "";
if promo != () && promo.success {
    promo_text = as_text(promo.output);
}
if trimmed(promo_text) != "" {
    body += "\n\n## Auto-promote\n\n```\n" + promo_text + "\n```\n";
}

let path = write_scratch_file("wave.md", body);
complete(#{
    path: path,
    stamp: stamp,
    chapter: chapter,
    personas: personas,
    live_door: live_door,
    report: body,
    promote: promo_text,
});
