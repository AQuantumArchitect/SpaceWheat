#!/usr/bin/env python3
"""The opening, played honestly: Act 0's six lessons and Act 1's first beats.

PLAYER PARITY: RIG_UNLOCK_ALL=0 (locked hats/menus redirect), resource
injection OFF, no fire_flag / grant_standing / time_skip / accept_quest /
complete_or_claim. Every accept, claim, delivery and mechanic is a KEY PRESS;
waiting is real time passing (frames settling, or a short sleep). Reads
(story_flags, story_offers, active_quests, resource_snapshot, overlay_text,
biome_slots, board_state) are orientation only — what a sighted player reads
off the screen.

Stages, in order (the drive stops at the first that does not happen, and says
why):
  act0:<step>         the six tutorial steps advance (core_loop … reap_season)
  first_harvest       fired from the capstone reap
  arc_handover        offered on the Arc tab, then accepted there (handshake:
                      Accept IS the beat)
  village_stirs       offered (its door rule: arc_handover claimed)
  village_stirs:accepted   accepted on the Arc tab
  millwright:+N       kept Millwright deliveries via the Village board's market
  village_stirs:ready  access ≥ 0.06 — the teaching's bar fills
  village_stirs:claimed claimed on Commitments (teaches 💨/🔨)
  first_breath … new_voices   the Icon hat: berry ritual, then plant a known word
  woodlot_door + spring_door  Captain [7] R (Add Biome) until both biomes stand
  woodlot_contact, lumber_flows   kept Millwright deliveries (standing ladder)
  spring_contact, spring_connects kept Hearth Keepers deliveries
  forest_evolving     the forest's third berry; ends at forest_listener offered
Gathering spends 🧺; when the baskets run dry the drive keeps the Hearth
Keepers' standing 👥→🧺 Village trade (the spec's rescue), as a player would.

    python3 🍄/🧪/honest_opening.py            # boots its own lane, prints JSON
Library use (tests/test_honest_opening.py): drive(rig) -> report dict.
"""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

_RUNNER_ROOT = Path(__file__).resolve().parents[1] / "\U0001F39B️"  # 🍄/🎛️
SEL_KEYS = ["g", "h", "j", "k", "l", ";"]
ACT0 = ["core_loop", "contracts", "wayfinding", "superposition", "entanglement", "reap_season"]

# Verbs this drive is allowed to send. Everything else would be a seam a
# player does not have.
READ_VERBS = {"story_flags", "story_offers", "active_quests", "resource_snapshot",
              "overlay_text", "biome_slots", "board_state", "instrument_state",
              "confirm_state", "ui_unlocks", "berry_state", "plot_glance"}
INPUT_VERBS = {"press_key"}


class HonestDrive:
    def __init__(self, rig, log=print):
        self.rig = rig
        self.n = 0
        self.log = log
        self.report = {"reached": [], "stopped_at": None, "why": None, "notes": [],
                       "deliveries": 0}

    # ---- the only two doors into the game -------------------------------
    def t(self, action, timeout=60, **kw):
        assert action in READ_VERBS | INPUT_VERBS, "honest drive refused verb %s" % action
        self.n += 1
        return self.rig.run_turn(self.n, action, timeout_s=timeout, **kw)

    def press(self, k, settle=8, shift=False):
        return self.t("press_key", key=k, shift=shift, settle_frames=settle)

    def wait(self, seconds=1.0):
        # Real time passing — the game runs on while nobody touches it.
        time.sleep(seconds)

    # ---- reads -----------------------------------------------------------
    def offers(self):
        return self.t("story_offers").get("story_offers", []) or []

    def actives(self):
        return self.t("active_quests", full=True).get("quests", []) or []

    def flags(self):
        return self.t("story_flags").get("flags_fired", {}) or {}

    def wallet(self):
        r = self.t("resource_snapshot").get("resources", {})
        return (r.get("resources", r) or {})

    def lines(self):
        return [str(x.get("text", "")).strip() for x in (self.t("overlay_text").get("lines", []) or [])]

    def biome_key(self, name):
        for s in self.t("biome_slots").get("slots", []):
            if s.get("biome") == name:
                return str(s.get("key")).lower()
        return ""

    def reached(self, stage):
        self.log("  ✓ %s" % stage)
        self.report["reached"].append(stage)

    def stop(self, stage, why):
        self.log("  ✗ stopped at %s: %s" % (stage, why))
        self.report["stopped_at"] = stage
        self.report["why"] = why
        return self.report

    def step_live(self, teach):
        for q in self.offers():
            if str(q.get("tutorial_teaches", "")) == teach:
                return "offer", q
        for q in self.actives():
            if str(q.get("tutorial_teaches", "")) == teach:
                return "active", q
        return "", {}

    def past(self, teach):
        idx = ACT0.index(teach)
        live = {str(q.get("tutorial_teaches", "")) for q in self.offers() + self.actives()}
        if any(later in live for later in ACT0[idx + 1:]):
            return True
        return not any(s in live for s in ACT0) and "first_harvest" in self.flags()

    # ---- UI rows ---------------------------------------------------------
    def row_key_for(self, snippet):
        """Row key ([G]/[H]/…) whose rendered text contains snippet."""
        cur = None
        for s in self.lines():
            m = re.match(r"^\[([A-Z;])\]$", s)
            if m:
                cur = m.group(1)
                continue
            if cur and snippet in s:
                return cur
        return None

    def screen_rows(self):
        """{row key: [text lines under it]} for the rows on screen now."""
        rows, cur = {}, None
        for s in self.lines():
            m = re.match(r"^\[([A-Z;])\]$", s)
            if m:
                cur = m.group(1)
                rows.setdefault(cur, [])
                continue
            if cur is not None and s:
                rows[cur].append(s)
        return rows

    def accept_on_arc(self, snippet):
        self.press("x", settle=6)
        self.press("i", settle=6)
        row = self.row_key_for(snippet)
        if row is None:
            self.press("escape", settle=6)
            return False
        self.press(row.lower(), settle=6)
        self.press("r", settle=12)
        self.press("escape", settle=6)
        return True

    def commit_row(self, qid):
        rows = [q for q in self.actives()]
        # The Commitments tab lists commitment_quests (verb-lesson steps excluded).
        rows = [q for q in rows if not (str(q.get("category", "")) == "TUTORIAL"
                                        and q.get("state_predicates"))]
        for i, q in enumerate(rows):
            if int(q.get("id", -1)) == int(qid):
                return i
        return -1

    def claim_on_commitments(self, qid):
        idx = self.commit_row(qid)
        if idx < 0 or idx >= len(SEL_KEYS):
            return False
        self.press("c", settle=6)
        self.press("u", settle=6)
        self.press(SEL_KEYS[idx], settle=6)
        self.press("r", settle=12)
        self.press("escape", settle=6)
        return True

    # ---- verbs -------------------------------------------------------------
    def strike_gather(self, biome_key, plot):
        self.press(biome_key, settle=6)
        self.press("8", settle=4)
        self.press(plot, settle=4)
        self.press("f", settle=8)
        self.press("r", settle=10)
        self.press("q", settle=8)

    def gather(self, resource, quantity, biome_names=("TheDemos", "Village"), rounds=24):
        for rnd in range(rounds):
            w = self.wallet()
            if float(w.get(resource, 0)) >= quantity:
                return True
            # Gathering spends 🧺. An empty basket is never a dead end: the
            # Hearth Keepers' standing Village trade (👥 → 🧺) is the rescue.
            if float(w.get("🧺", 0)) < 2 and not getattr(self, "_rescuing", False):
                self._rescuing = True
                try:
                    why = self.millwright_delivery("Hearth Keepers", pays="🧺")
                finally:
                    self._rescuing = False
                if why:
                    self.report["notes"].append("basket rescue failed: " + why)
                    return False
                self.report["notes"].append("basket rescue: Hearth Keepers 👥→🧺 trade kept")
            for b in biome_names:
                k = self.biome_key(b)
                if k:
                    self.strike_gather(k, SEL_KEYS[rnd % 6])
        return float(self.wallet().get(resource, 0)) >= quantity

    # ---- act 0 ------------------------------------------------------------
    def run_auto(self, teach, drive, rounds=12):
        where, _q = self.step_live(teach)
        if where == "":
            return self.past(teach)
        for rnd in range(rounds):
            drive(rnd)
            if self.step_live(teach)[0] == "":
                return True
        return False

    def act0(self):
        dk, fk = self.biome_key("TheDemos"), self.biome_key("StarterForest")

        def d0(_r):
            self.strike_gather(dk, "g")
        if not self.run_auto("core_loop", d0):
            return "core_loop never advanced"
        self.reached("act0:core_loop")

        where, q = self.step_live("contracts")
        if where != "active":
            return "contracts step not auto-accepted (%s)" % where
        for rnd in range(12):
            if float(self.wallet().get("🌾", 0)) < 2:
                self.strike_gather(dk, SEL_KEYS[rnd % 6])
            else:
                self.claim_on_commitments(int(q.get("id", -1)))
            if self.step_live("contracts")[0] == "":
                break
        else:
            return "contracts never delivered on Commitments"
        self.reached("act0:contracts")

        if not self.run_auto("wayfinding", lambda _r: self.press(fk, settle=10)):
            return "wayfinding never advanced"
        self.reached("act0:wayfinding")

        def d3(rnd):
            self.press(fk, settle=8)
            self.press("0", settle=4)
            self.press(SEL_KEYS[rnd % 6], settle=4)
            self.press("e", settle=8)
        if not self.run_auto("superposition", d3):
            return "superposition never advanced"
        self.reached("act0:superposition")
        if "loom_opens" not in self.flags():
            return "loom_opens did not fire — Operator hat stays locked"

        def d4(_r):
            self.press(fk, settle=8)
            self.press("9", settle=4)
            if self.t("instrument_state").get("checked_plots"):
                self.t("press_key", keycode=39, settle_frames=6)  # ' = bulk clear
            self.press("g", settle=6, shift=True)
            self.press("h", settle=6, shift=True)
            self.press("r", settle=10)
            self.press("q", settle=12)
            self.wait(1.0)
        if not self.run_auto("entanglement", d4, rounds=8):
            return "entanglement never advanced"
        self.reached("act0:entanglement")

        def d5(rnd):
            self.press(dk, settle=8)
            self.press("8", settle=4)
            self.press(SEL_KEYS[rnd % 6], settle=4)
            self.press("f", settle=8)
            self.press("f", settle=12, shift=True)
        if not self.run_auto("reap_season", d5):
            return "reap_season never advanced (wallet %s)" % json.dumps(self.wallet(), ensure_ascii=False)
        self.reached("act0:reap_season")
        return None

    # ---- act 1 ------------------------------------------------------------
    def wait_flag(self, fid, tries=10):
        for _ in range(tries):
            if fid in self.flags():
                return True
            self.wait(0.5)
        return fid in self.flags()

    def offer_for(self, fid):
        for q in self.offers():
            if str(q.get("source_flag", "")) == fid:
                return q
        return {}

    def active_for(self, fid):
        for q in self.actives():
            if str(q.get("source_flag", "")) == fid:
                return q
        return {}

    def snippet(self, q):
        name = str(q.get("display_name", "") or q.get("title", "") or "").strip()
        body = str(q.get("body", "")).strip()
        return name or body[:24]

    def accept_beat(self, fid):
        """Accept fid's offer on the Arc tab: select the row titled with the
        beat's name, press R. If R signs a DIFFERENT offer than the row shown
        (seen: the Arc cursor can sit on another row than the one drawn as
        open), note it as a finding and try again — that offer is on the road
        too, so the drive keeps going the way a player would."""
        for _attempt in range(4):
            q = self.offer_for(fid)
            if not q:
                return True
            before = {str(o.get("source_flag", "")) for o in self.offers()}
            body = str(q.get("body", ""))
            # The Arc row title is the beat's name — the body's lead before " — ".
            title = body.split(" — ")[0].strip() or self.snippet(q)
            self.accept_on_arc(title)
            after = {str(o.get("source_flag", "")) for o in self.offers()}
            if fid not in after:
                return True
            other = sorted(before - after)
            if other:
                self.report["notes"].append(
                    "Arc R on the row titled %r signed %s instead" % (title, ", ".join(other)))
        return not self.offer_for(fid)

    def millwright_delivery(self, faction="Millwright's Union", pays=None):
        """One kept contract for `faction` from the Village board's market
        (optionally one whose payout line names `pays`)."""
        vk = self.biome_key("Village")
        self.press(vk, settle=10)
        self.press("c", settle=8)
        self.press("y", settle=8)  # Market tab
        pick = None
        seen = []
        for rnd in range(10):
            have = self.wallet()
            best = None
            for key, row in self.screen_rows().items():
                if key not in "GHJKL;" or not row or row[0] != faction:
                    continue
                m = re.match(r"^(\S+) × (\d+)$", row[1] if len(row) > 1 else "")
                if not m:
                    continue
                res, qty = m.group(1), int(m.group(2))
                if pays and not any(pays in ln for ln in row[2:3]):
                    continue
                seen.append("%s×%d" % (res, qty))
                short = qty - float(have.get(res, 0))
                if res == "🧺" and pays == "🧺":
                    continue
                if best is None or short < best[0]:
                    best = (short, key, {"resource": res, "quantity": qty})
            # A contract the wallet already covers, or one a few strikes away.
            if best is not None and best[0] <= 6:
                pick = (SEL_KEYS.index(best[1].lower()), best[2])
                break
            self.press("e", settle=8)  # refresh the market
        if not pick:
            self.press("escape", settle=6)
            return "no affordable %s offer on the Village board in 10 refreshes (saw %s)" % (
                faction, ", ".join(seen[-8:]) or "none")
        i, o = pick
        before = {int(a.get("id", -1)) for a in self.actives()}
        self.press(SEL_KEYS[i], settle=6)
        self.press("r", settle=10)  # accept
        self.press("escape", settle=6)
        new = [a for a in self.actives() if int(a.get("id", -1)) not in before]
        if not new:
            return "accepting the %s offer added no commitment" % faction
        q = new[0]
        res, qty = str(q.get("resource", "")), float(q.get("quantity", 1) or 1)
        if res and not self.gather(res, qty):
            return "could not gather %s×%d honestly (wallet %s)" % (
                res, qty, json.dumps(self.wallet(), ensure_ascii=False))
        if not self.claim_on_commitments(int(q.get("id", -1))):
            return "commitment row not selectable"
        if any(int(a.get("id", -1)) == int(q.get("id", -2)) for a in self.actives()):
            return "delivery did not settle (%s×%d)" % (res, qty)
        self.report["deliveries"] += 1
        return None

    def act1(self, deliveries=4):
        if not self.wait_flag("first_harvest"):
            return self.stop("first_harvest", "did not fire after the capstone reap")
        self.reached("first_harvest")
        if not self.wait_flag("arc_handover"):
            return self.stop("arc_handover", "did not fire (first_harvest ∧ loom_opens)")
        if not self.offer_for("arc_handover"):
            return self.stop("arc_handover", "fired but no offer on the Arc tab")
        self.reached("arc_handover:offered")
        if not self.accept_beat("arc_handover"):
            return self.stop("arc_handover:accepted", "Arc tab row not found / R did not accept")
        self.reached("arc_handover:accepted")
        if not self.wait_flag("village_stirs"):
            return self.stop("village_stirs", "did not open after the handover was accepted")
        if not (self.offer_for("village_stirs") or self.active_for("village_stirs")):
            return self.stop("village_stirs", "fired but not offered")
        self.reached("village_stirs:offered")
        if not self.accept_beat("village_stirs"):
            return self.stop("village_stirs:accepted", "Arc tab row not found / R did not accept")
        self.reached("village_stirs:accepted")
        for _ in range(deliveries):
            q = self.active_for("village_stirs")
            if q.get("status") == "ready":
                break
            why = self.millwright_delivery()
            if why:
                return self.stop("millwright:+%d" % (self.report["deliveries"] + 1), why)
            self.reached("millwright:+%d" % self.report["deliveries"])
            self.wait(0.5)
        q = self.active_for("village_stirs")
        if q.get("status") != "ready":
            return self.stop("village_stirs:ready", "bar not full after %d deliveries (progress %.2f)"
                             % (self.report["deliveries"], float(q.get("progress", 0) or 0)))
        self.reached("village_stirs:ready")
        if not self.claim_on_commitments(int(q.get("id", -1))) or self.active_for("village_stirs"):
            return self.stop("village_stirs:claimed", "claim on Commitments did not land")
        self.reached("village_stirs:claimed")
        if not self.wait_flag("first_breath"):
            return self.stop("first_breath", "did not open after the mill teaching was claimed")
        self.reached("first_breath:offered")
        return None

    # ---- act 1 (the first taste) and act 2's doors -------------------------
    def berry_ritual(self, biome, target, rounds=14):
        """Icon hat: F tracks each plot, the clock runs fast, R incorporates
        every ripe loop — until the biome has consumed `target` berries."""
        self.press(self.biome_key(biome), settle=10)
        self.press("5", settle=6)
        for _ in range(5):
            self.press("=", settle=4)  # clock to max
        for _ in range(rounds):
            bs = self.t("berry_state", biome=biome)
            if int(bs.get("consumed_count", 0)) >= target:
                return True
            for i, q in enumerate((bs.get("qubits", []) or [])[:6]):
                if q.get("ripe"):
                    self.press(SEL_KEYS[i], settle=4)
                    self.press("r", settle=8)
                elif not q.get("tracked"):
                    self.press(SEL_KEYS[i], settle=4)
                    self.press("f", settle=4)
            self.wait(3.0)
        return int(self.t("berry_state", biome=biome).get("consumed_count", 0)) >= target

    def done(self, fid):
        """Fired, and its door no longer open (claimed — nothing left on the board)."""
        return fid in self.flags() and not self.offer_for(fid) and not self.active_for(fid)

    def take_beat(self, fid, work, label=None):
        label = label or fid
        if not self.wait_flag(fid):
            return self.stop(label, "never opened")
        if self.offer_for(fid) and not self.accept_beat(fid):
            return self.stop(label + ":accepted", "Arc tab row not found / R did not accept")
        why = work() if work else None
        if why:
            return self.stop(label, why)
        for _ in range(6):
            q = self.active_for(fid)
            if not q:
                break
            if q.get("status") == "ready":
                self.claim_on_commitments(int(q.get("id", -1)))
            self.wait(0.5)
        if not self.done(fid):
            q = self.active_for(fid)
            return self.stop(label + ":claimed", "still open (status %s, progress %.2f)" % (
                q.get("status"), float(q.get("progress", 0) or 0)))
        self.reached(label + ":claimed")
        return None

    def inject_known_word(self):
        if not self.gather("🌱", 5, biome_names=("StarterForest",)):
            return "could not gather 🌱×5 for the inject"
        vk = self.biome_key("Village")
        self.press(vk, settle=10)
        self.press("5", settle=6)
        empty = [p["key"] for p in self.t("plot_glance").get("plots", [])
                 if p.get("biome") == "Village" and p.get("empty")]
        if not empty:
            return "no empty Village plot to plant a word in"
        self.press(empty[0].lower(), settle=6)
        self.press("r", settle=10)   # Add Icon → word picker
        self.press("e", settle=12)   # 🌾/👥 — the word every Demos player knows
        return None

    def chart_story_biomes(self, wanted, tries=5):
        """Captain [7] R (Add Biome) — the discovery draw leans on open doors."""
        for _ in range(tries):
            have = {s.get("biome") for s in self.t("biome_slots").get("slots", [])}
            if all(b in have for b in wanted):
                return None
            if not self.gather("🦅", 22, biome_names=("StarterForest",), rounds=30):
                return "could not gather 🦅×21 to chart (wallet %s)" % json.dumps(self.wallet(), ensure_ascii=False)
            self.press("7", settle=6)
            self.press("r", settle=30)
        have = {s.get("biome") for s in self.t("biome_slots").get("slots", [])}
        missing = [b for b in wanted if b not in have]
        return ("still missing %s after %d draws" % (missing, tries)) if missing else None

    def act2_doors(self):
        if self.take_beat("first_breath", lambda: None if self.berry_ritual("StarterForest", 1)
                          else "no berry ripened in StarterForest"):
            return self.report
        if self.take_beat("spiral_breaks", lambda: None if self.berry_ritual("StarterForest", 2)
                          else "second berry never ripened"):
            return self.report
        if self.take_beat("new_voices", self.inject_known_word):
            return self.report
        # Both doors open together; accept both, then chart until both biomes stand.
        for fid in ("woodlot_door", "spring_door"):
            if not self.wait_flag(fid):
                return self.stop(fid, "never opened after new_voices")
            if self.offer_for(fid) and not self.accept_beat(fid):
                return self.stop(fid + ":accepted", "Arc tab row not found")
        why = self.chart_story_biomes(["Woodlot", "FreshwaterSpring"])
        if why:
            return self.stop("woodlot_door+spring_door", why)
        for fid in ("woodlot_door", "spring_door"):
            if self.take_beat(fid, None):
                return self.report
        for fid in ("woodlot_contact", "spring_contact"):
            if not self.wait_flag(fid):
                return self.stop(fid, "never opened after its door")
            self.reached(fid + ":offered")
        # The standing ladder: each gate is a few kept deliveries on the Village board.
        def deliveries(fid, faction, cap=5):
            def work():
                for _ in range(cap):
                    q = self.active_for(fid)
                    if not q or q.get("status") == "ready":
                        return None
                    why = self.millwright_delivery(faction)
                    if why:
                        return why
                    self.reached("%s:+%d" % ("millwright" if faction.startswith("Mill") else "hearth",
                                             self.report["deliveries"]))
                    self.wait(0.5)
                return None
            return work
        if self.take_beat("woodlot_contact", deliveries("woodlot_contact", "Millwright's Union")):
            return self.report
        for fid in ("lumber_flows",):
            if not self.wait_flag(fid):
                return self.stop(fid, "never opened after woodlot_contact")
            self.reached(fid + ":offered")
        if self.take_beat("lumber_flows", deliveries("lumber_flows", "Millwright's Union")):
            return self.report
        if not self.wait_flag("woodlot_wakes"):
            return self.stop("woodlot_wakes", "never opened after lumber_flows")
        self.reached("woodlot_wakes:offered")
        if self.take_beat("spring_contact", deliveries("spring_contact", "Hearth Keepers")):
            return self.report
        if not self.wait_flag("spring_connects"):
            return self.stop("spring_connects", "never opened after spring_contact")
        self.reached("spring_connects:offered")
        # spring_connects: Hearth Keepers trust 0.65, teaches 💧/🌊.
        if self.take_beat("spring_connects", deliveries("spring_connects", "Hearth Keepers", cap=8)):
            return self.report
        # Act 3 opens on lumber_flows ∧ spring_connects: the forest chapter.
        if not self.wait_flag("forest_evolving"):
            return self.stop("forest_evolving", "never opened after lumber_flows and spring_connects")
        self.reached("forest_evolving:offered")
        if self.take_beat("forest_evolving", lambda: None if self.berry_ritual("StarterForest", 3)
                          else "third forest berry never ripened"):
            return self.report
        if not self.wait_flag("forest_listener"):
            return self.stop("forest_listener", "never opened after forest_evolving")
        self.reached("forest_listener:offered")
        return self.report

    def drive(self, through="act2"):
        why = self.act0()
        if why:
            stage = next((s for s in ACT0 if "act0:" + s not in self.report["reached"]), "act0")
            return self.stop("act0:" + stage, why)
        stopped = self.act1()
        if stopped is not None or through == "act1":
            return self.report
        return self.act2_doors()


def drive(rig, log=print, through="act2") -> dict:
    return HonestDrive(rig, log=log).drive(through=through)


def main() -> int:
    sys.path.insert(0, str(_RUNNER_ROOT))
    from rig_client import RigClient  # noqa: E402
    c = RigClient(root_from_file=_RUNNER_ROOT / "milk_hunt_runner.py")
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            allow_resource_injection=False,
                            extra_env={"RIG_UNLOCK_ALL": "0"})
    try:
        c.wait_for_ready(proc, timeout_s=240)
        rep = drive(c)
        print(json.dumps(rep, ensure_ascii=False, indent=1))
        return 0 if rep.get("stopped_at") is None else 1
    finally:
        c.terminate_listener(proc)


if __name__ == "__main__":
    sys.exit(main())
