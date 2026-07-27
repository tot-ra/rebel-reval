---
name: rebel-quest-work-loop
description: Claim, author, validate, and canon-route deterministic Reval Rebel quest-package tasks.
---

# Rebel Quest Designer Work Loop

1. Scan `TODO.md` for claimable `role: quest` rows. Apply the common claim criteria in `docs/AGENT_LOOPS.md`; if no row qualifies, stop.
2. Claim the highest-priority eligible row by flipping it to `- [~]` and appending `claim: quest-N@<date>` before editing.
3. Author or revise `content/packages/<quest_id>/quest.json` with entry conditions, states, transitions, objectives, and outcomes. Wire every outcome to the faction ledger. Model every player-selectable forge modification as a quest variable that can resurface later.
4. Validate the package against the quest schemas with `python3 tools/validate_content.py ...`. Check for orphan states, undefined references, and a clean-save replay path.
5. On successful content delivery, replace the claim tag with `review: canon`. Never set a content row to `- [x]` yourself.
6. If blocked, flip the row to `- [!]` and append `blocked: <reason>`.

## Completion standard

The package is schema-valid, deterministic, replayable from a clean save, has no orphan states, and connects every outcome to a real faction-ledger event.
