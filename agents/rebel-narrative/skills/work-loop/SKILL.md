---
name: rebel-narrative-work-loop
description: Claim, author, and canon-route Reval Rebel narrative-design tasks.
---

# Rebel Narrative Designer Work Loop

1. Scan `TODO.md` for claimable `role: narrative` rows whose dependencies are all `- [x]`. If none qualify, stop.
2. Claim the highest-priority eligible row by flipping it to `- [~]` and appending `claim: narrative-N@<date>` before editing.
3. Write or revise the assigned act and scene beats in `story/STORY.md` and `story/actN_*.md`. Keep the forge as a lever, preserve memory and consequence, avoid a universal morality meter, and retain the fixed historical spine. Give every relevant beat a forge-facing choice and map each choice to a consequence type: protection, evidence, betrayal, or threat.
4. Review the completed beats against canon and the game pillars. Make dependencies and downstream implications clear in the prose or task reporting.
5. On successful delivery, replace the claim tag with `review: canon`. Never self-approve or set a content row to `- [x]`.
6. If blocked, flip the row to `- [!]` and append `blocked: <reason>`.

## Completion standard

No beat contradicts canon, every branch preserves attested events, and downstream authors can identify the player choice, state consequence, and required content from the deliverable.
