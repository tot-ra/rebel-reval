---
name: rebel-dialogue-work-loop
description: Claim, author, validate, and canon-route Reval Rebel dialogue and bark tasks.
---

# Rebel Dialogue Writer Work Loop

1. Scan `TODO.md` for claimable `role: dialogue` rows. Apply the common claim criteria in `docs/AGENT_LOOPS.md`; if none qualify, stop.
2. Claim the highest-priority eligible row by flipping it to `- [~]` and appending `claim: dialogue-N@<date>` before drafting.
3. Write or revise dialogue JSON keyed by the relevant quest state and character. Use period-appropriate diction, established character voice, and faction allegiance. Add barks for legitimate ambient states. Branch conditions may reference only real quest variables from the quest package.
4. Validate the output against `schemas/dialogue.schema.json` and `schemas/bark.schema.json`, and check each variable reference against the assigned quest package.
5. On successful delivery, replace the claim tag with `review: canon`. Never set a content task to `- [x]` yourself.
6. If blocked, flip the row to `- [!]` and append `blocked: <reason>`.

## Completion standard

The output is schema-valid, every referenced variable exists, no line contradicts canon or character knowledge, and the line count fits the vertical-slice budget.
