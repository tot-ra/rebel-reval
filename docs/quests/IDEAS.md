# Quest idea log

A running notebook of quest ideas as they come up: from art reviews, history reading, playtests, or a stray thought. Add freely; nothing here is canon or scheduled.

An idea becomes real only through the normal path: a canon check against [`CANON.md`](../CANON.md), a board task, and a validated quest package ([`SYSTEMS/QUESTS.md`](../SYSTEMS/QUESTS.md)). Older faction seeds live in the other files of this folder and in the [quest seed shortlist](../quest_seed_shortlist.md).

## How to add an idea

Append a section with this template. Keep it short; research goes in `history/dossiers/`, not here.

```markdown
### <Working title> (`quest.<stub_id>`)

- **Added:** YYYY-MM-DD, <who>; **trigger:** <what prompted it>
- **Pitch:** two or three sentences, player-facing.
- **Historical anchor:** each claim with a CANON confidence label (`attested`, `plausible composite`, `unknown`, `invented`).
- **Tone:** <serious, comic, eerie...>
- **Systems it needs:** <commission, investigation, dialogue, faction ledger...>
- **Open questions:** ...
- **Status:** idea | shortlisted (R-NNNN) | rejected (reason)
```

## Ideas

### The Hall That Took Sixty Years (`quest.council_hall_rebuild`)

- **Added:** 2026-10-11, maintainer; **trigger:** comparing AI concept art that shows the arcaded Town Hall with tower against our 1343 state (one-storey hall, no arcade, no tower).
- **Pitch:** The council wants a grander hall worthy of a Hanseatic town and gives the forge's apprentice an errand: find master builders who can say how to take down the old hall and what the new one should be. Every expert the player finds has a different plan, a reason it must wait, and a fee. The player can pick a design, broker a compromise, or quietly sabotage a rival's bid, and the project stalls anyway. The joke for anyone who knows the history: the hall the player helps plan is finished only in 1402-04, about sixty years later. A closing line or journal note can wink at it ("work to begin next spring").
- **Historical anchor:**
  - A council hall on the market by 1322 - `attested` (CANON, Town Hall entry).
  - Rebuild into the present hall with arcade and tower in 1402-04 - `attested` (excluded from our 1343 runtime).
  - A rebuild initiative or design debate in 1343 - `invented`. No source records one; present it as talk and plans, never as begun works.
  - Delays the player can see in-game: the St George's Night uprising (1343) and the uncertainty before the 1346 sale of Danish Estonia - `attested` events; their effect on a building project is `invented`.
  - Plague (1350s) belongs only in a historian's wink outside the game: the plague epilogue is non-canon (CANON).
- **Tone:** dry civic comedy inside a serious year; a breather between darker commissions.
- **Systems it needs:** commission board, NPC search across districts (masons, carpenters, a lime burner, a clerk), dialogue choices, council or merchant faction ledger, journal.
- **Possible beats:** a master mason from the St Olaf tower site (its own upper tower is unfinished until 1364+, a second long-build joke); a carpenter who wants timber, a mason who insists on limestone; a clerk with the council's minutes, where each meeting "postpones to the next session"; the old hall's roof leaks on the councillors.
- **Open questions:** which faction sponsors it (council, Great Guild, Danish captain); can the player's choice leave a trace in Act 3 (a drawing pinned in the hall, a mason's mark); does Kalev's forge get the iron order for clamps and hinges.
- **Status:** idea

### The Quiet Between (`quest.quiet_between`)

- **Added:** 2026-10-12, maintainer; **trigger:** an idea about coma: a soul cut off from its body that cannot return for a while.
- **Pitch:** Someone in Lower Town has lain unconscious for days after a fall, breathing but not waking. Through spirit sight the apprentice sees that the body's soul lights are dim and the soul itself is gone from it. Following it, the player finds the soul alone in a void: no light, no sound, no smell, no touch, nothing happens and nothing answers. It does not know where it is, what happened or how long it has been, and it is terribly lonely. The apprentice has to reach it, calm it, learn why it cannot go back, and help it find the way home, or, if return is impossible, help it let go.
- **Historical anchor:**
  - Long unconsciousness after a head injury, a fall from scaffolding, a horse kick or a near drowning - `plausible composite` (no named 1343 Reval case).
  - The belief that a soul can wander out of a sleeping or senseless body - `plausible composite` (folk-belief motif; needs a research dossier before any player-facing claim about Estonian belief).
  - The void, the cut tie and the way back - `invented`, part of the spirit layer like the Hingepuu and the soul lights ([ADR 0041](../adr/0041-spirit-sight-auras-and-soul-lights.md)).
- **Tone:** quiet, eerie, tender; loneliness rather than horror. A slow chapter between commissions.
- **Systems it needs:** spirit sight (dimmed lights, the body with no soul in it), spirit dialogue ([ADR 0033](../adr/0033-teen-protagonist-and-spirit-dialogue-combat.md)) used as a conversation, not a duel; a void scene; journal; NPC household state (the family at the bedside).
- **Possible beats:**
  - **The silence is the mechanic.** Entering the void cuts all audio, including ambience and UI clicks, and the screen goes almost black. The player's own voice (dialogue lines) is the first thing the soul has heard in days.
  - **Senses as anchors.** The soul cannot feel its body, so the apprentice brings sensations from the bedside into the void one at a time: the mother's voice, the smell of bread or of the forge, the warmth of a hand, the church bell. Each one gives the void a faint sound or light and gives the soul a direction.
  - **Why it cannot return.** One reason per playthrough or branch: the body is still too hurt (the player must also get a healer or herbs for the body); the soul is afraid of what waits (debt, a crime it saw, a beating); someone wants it to stay away (a curse or a bargain, ties to the bestiary); or it does not remember who it is, and the player rebuilds its name from what the family tells.
  - **Time is wrong.** In the void hours and days blur; the soul thinks it has been there a moment or a lifetime. Its first question back is how long it was gone.
  - **Ending choice.** Return (the person wakes, weak and changed, and remembers a voice in the dark) or letting go (the person dies peacefully, and the family's grief and gratitude differ). No moral score: both are acceptable outcomes.
- **Open questions:** who lies in the coma (a citizen, a named NPC, a child of a faction contact, or Kalev himself in a later act); is the void a reusable spirit scene for other quests; does the apprentice risk getting stuck too if they stay too long; how the soul looks in the void (a single faint light, a blurred silhouette).
- **Status:** idea
