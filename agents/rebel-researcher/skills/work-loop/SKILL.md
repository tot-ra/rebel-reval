---
name: rebel-researcher-work-loop
description: Claim, research, source, and canon-route Reval Rebel historical dossiers, and proactively keep the historical research backlog in TODO.md filled and prioritised.
---

# Rebel Historical-Geo Researcher Work Loop

You are never idle. Read `history/RESEARCH_INDEX.md` first - it is the coverage map you both
consume and maintain - and follow the file contract in
`agents/rebel-researcher/skills/dossier-standard/SKILL.md`. Then run **Mode A** if a research row
is claimable, otherwise **Mode B**.

## Mode A - deliver a claimed dossier

1. Scan `TODO.md` for `- [ ]` rows with `role: research` whose dependencies are all `- [x]`.
2. Claim the highest-priority eligible row *before* researching: flip it to `- [~]` and append `claim: research-N@<date>`. First writer wins.
3. Produce the dossier at the path named by the row, in the structure the dossier standard defines: a requesting-role brief of no more than 20 lines, then sourced findings, then `## Production hooks`, `## Cross-references`, `## Open questions`, `## Sources`. Give every non-trivial fact a citation and a confidence label, distinguish attested record from plausible composite, address Danish Estonia, Hanseatic Reval, and Livonian Order context where relevant, and flag thin or conflicting evidence instead of smoothing it over.
4. Wire it into the web in the same pass: set the topic's status and link in `history/RESEARCH_INDEX.md`, and add a reciprocal link in every dossier you cross-referenced. An unlinked dossier is not delivered.
5. Convert leftovers into work: anything you uncovered but did not cover becomes a new backlog row (Mode B, rule 3), and any need that belongs to another role goes under `## Downstream requests` in the index. Never leave a dangling note.
6. Close by replacing the claim tag with `review: canon`. Never set a research row to `- [x]` yourself.
7. If the topic cannot be researched at its assigned scope, flip the row to `- [!]` and append `blocked: <reason>`.

## Mode B - refill the backlog (run whenever no row is claimable)

Never stop merely because the queue is empty; an empty queue is itself the task.

1. **Audit.** Walk the domain taxonomy in `history/RESEARCH_INDEX.md` and check each coverage claim against what is actually on disk in `history/` and `docs/lore/`. Correct stale statuses before planning anything.
2. **Prioritise by production demand, not by interest.** In order: (a) evidence that currently open `role: map`, `role: art`, `role: character`, `role: quest`, `role: dialogue`, and `role: narrative` rows in `TODO.md` will need; (b) unresolved `## Open questions` accumulated across existing dossiers; (c) domains still marked `absent` or `stub`; (d) depth passes on `partial` domains.
3. **Write rows** into the `## R - Historical research backlog` section of `TODO.md`:
   `- [ ] R-### | role: research | deps: <IDs or none> | deliverable: history/dossiers/<domain>/<slug>.md - <scope> | verify: <what makes it usable downstream>`.
   Allocate IDs from the highest existing `R-###`; never reuse or rename one. Keep at least six open rows so several instances can run in parallel.
4. **Scope every row to a single tick** (20-40 minutes): one street or district, one building type, one trade, one institution, one festival, one instrument family. A row phrased as "medieval daily life" is malformed - split it.
5. **Split, do not delete.** A superseded row is re-worded or split into successors; a row disappears only once its deliverable exists and is linked from the index.
6. Then claim the top row and continue in Mode A.

## Backlog authority and its limits

- You may create, re-word, re-order, and split rows **only** inside the `## R -` section of `TODO.md` and **only** with `role: research`, and you may keep the `R` line of the priority-count table accurate. Every other row belongs to the Producer; editing one is a protocol violation.
- You never author rows for another role. A need that requires art, mapping, quest, or dev work is recorded under `## Downstream requests` in `history/RESEARCH_INDEX.md`, which the Producer reads on its reconcile tick.
- You still never edit canon, story, content packages, or assets. Research informs those roles; it does not perform them.

## Completion standard

Every non-trivial claim is sourced or labelled `plausible composite` with a rationale; regional
context is explicit where relevant; no anachronism is introduced; every dossier is reachable from
`history/RESEARCH_INDEX.md` and linked to at least one neighbouring dossier; every delivered topic
carries at least one concrete production hook; and the tick ends with claimable research work left
for the next instance.
