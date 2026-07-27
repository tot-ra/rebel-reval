---
name: rebel-character-work-loop
description: Claim, author, validate, and canon-route Reval Rebel character-design tasks.
---

# Rebel Character Designer Work Loop

1. Scan `TODO.md` for claimable `role: character` rows. Apply the common claim criteria in `docs/AGENT_LOOPS.md`. If none are available, stop.
2. Claim the highest-priority eligible row by flipping it to `- [~]` and appending `claim: character-N@<date>` before editing.
3. Author or revise the assigned `character.json`: physical description, faction allegiance, biography, and voice notes. Label every biographical claim with a confidence label. Create a portrait brief under `characters/` that describes one subject and is riggable where animation is required. If the deliverable creates an art dependency, state that need in the task so the Producer can open a `role: art` row.
4. Validate the data against `schemas/character.schema.json` and verify allegiance against the faction ledger and relevant canon.
5. On successful delivery, replace the claim tag with `review: canon`. Never set a content task to `- [x]` yourself.
6. If blocked, flip the row to `- [!]` and append `blocked: <reason>`.

## Completion standard

The character data is schema-valid, has a stable role in the faction ledger, supports the requested gameplay and dialogue use, and contains no attested-contradicting biographical claim.
