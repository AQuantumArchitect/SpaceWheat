# Dev journal

These are dated records of individual sessions, audits and investigations, kept
because the reasoning matters even after the code moves on. They are not live
documentation: flag counts, file paths and act maps in them are as of the date
in the filename. For how things work now, read [GAME_CODEX](../GAME_CODEX.md)
and [CAMPAIGN](../CAMPAIGN.md).

Most of these were written by the agents that did the work, at the end of the
session, as a handoff to the next one.

| Date | Record | What happened |
|---|---|---|
| 2026-07-05 | [Polish day](2026-07-05_POLISH_DAY.md) | One autonomous session: merged two dev streams (95 + 33 commits), tested, played, published. |
| 2026-07-05 | [Deadwood census](2026-07-05_DEADWOOD.md) | Inventory of dead code. The verified cull ran the next night (722 lines across 8 files). |
| 2026-07-06 | [Night purge](2026-07-06_NIGHT_PURGE.md) | Cut the GDScript physics fallback; the game now requires the native engine. |
| 2026-07-11 | [Doc rot audit](2026-07-11_DOC_ROT.md) | Fresh-eyes pass over ~90 docs before the itch.io soft launch. |
| 2026-07-29 | [Slop patrol](2026-07-29_SLOP_PATROL.md) | Six parallel agents hunting duplicated code; four findings were live bugs. |
| 2026-08-04 | [Campaign state](2026-08-04_CAMPAIGN_STATE.md) | Snapshot of the whole campaign as a briefing for a rewrite push. |
| 2026-08-10 | [Playtest sweep](2026-08-10_PLAYTEST_SWEEP.md) | Persona bots (literalist, lost lamb) on keyboard and mouse seats, Act 0 and the Act 4 fork. |
| 2026-08-11 | [Campaign split](2026-08-11_CAMPAIGN_SPLIT.md) | Twelve-agent study on splitting the advanced physics out of the main campaign. |
| 2026-08-17 | [Campaign reorder](2026-08-17_CAMPAIGN_REORDER.md) | Re-sequencing the early acts so incorporation isn't the first thing a player meets. |
| 2026-08-17 | [Cloud session handoff](2026-08-17_CLOUD_SESSION_HANDOFF.md) | Wrap-up when the work moved from cloud sessions to a local-first setup. |

The October 2026 campaign restructure, which replaced the hand-wired story
flags with one compiled spec, is described in [CAMPAIGN](../CAMPAIGN.md) rather
than here, because it is still the live design.
