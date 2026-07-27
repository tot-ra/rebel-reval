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
3. Produce the dossier at the path named by the row, in the structure the dossier standard defines: a requesting-role brief of no more than 20 lines, then sourced findings, then `## Production hooks`, `## Reference plates`, `## Cross-references`, `## Open questions`, `## Sources`. Give every non-trivial fact a citation and a confidence label, distinguish attested record from plausible composite, address Danish Estonia, Hanseatic Reval, and Livonian Order context where relevant, and flag thin or conflicting evidence instead of smoothing it over.
4. **Gather reference plates in the same tick, not later.** Text alone cannot brief an art or map role. Search for primary visual evidence of what the topic looks like - garment cut and layering, floor plans and sections, facades and gable forms, doors and ironwork, interiors and hearths, tools and workshop layout, ships and harbour gear, seals and coins - starting with the measured drawings and finds photography inside `history/*.pdf`, then Estonian institutional collections, then Wikimedia and museum open data. For each keeper: append a row to `history/reference/plates.csv` with what it shows, source, date, origin, and licence; run `python3 tools/research/fetch_reference_plates.py --slug <slug>` to download and checksum the openly licensed ones; leave the rest as `status: linked`. Cite the plate IDs from the `## Production hooks` bullets that rely on them, so the consuming role is pointed at the picture that settles the question. Aim for 3-8 plates; if the topic genuinely has no licensed visual record, say so in one line rather than padding with decorative images.
5. Wire it into the web in the same pass: set the topic's status and link in `history/RESEARCH_INDEX.md`, and add a reciprocal link in every dossier you cross-referenced. An unlinked dossier is not delivered.
6. Convert leftovers into work: anything you uncovered but did not cover becomes a new backlog row (Mode B, rule 3), and any need that belongs to another role goes under `## Downstream requests` in the index. Never leave a dangling note.
7. Close by replacing the claim tag with `review: canon`. Never set a research row to `- [x]` yourself.
8. If the topic cannot be researched at its assigned scope, flip the row to `- [!]` and append `blocked: <reason>`.

## Mode B - refill the backlog (run whenever no row is claimable)

Never stop merely because the queue is empty; an empty queue is itself the task.

1. **Audit.** Walk the domain taxonomy in `history/RESEARCH_INDEX.md` and check each coverage claim against what is actually on disk in `history/` and `docs/lore/`. Correct stale statuses before planning anything.
2. **Prioritise by production demand, not by interest.** In order: (a) evidence that currently open `role: map`, `role: art`, `role: character`, `role: quest`, `role: dialogue`, and `role: narrative` rows in `TODO.md` will need; (b) delivered dossiers whose consumers include `art`, `map`, or `character` but that carry no `## Reference plates` - a text-only dossier for a visual consumer is a gap, not a delivery; (c) unresolved `## Open questions` accumulated across existing dossiers; (d) domains still marked `absent` or `stub`; (e) depth passes on `partial` domains.
3. **Write rows** into the `## R - Historical research backlog` section of `TODO.md`:
   `- [ ] R-### | role: research | deps: <IDs or none> | deliverable: history/dossiers/<domain>/<slug>.md - <scope> | verify: <what makes it usable downstream>`.
   A plate-gathering row names the plate directory instead:
   `- [ ] R-### | role: research | deps: <IDs> | deliverable: history/reference/<domain>/<slug>/ - <what must be visible> | verify: N licensed plates in plates.csv, fetched and cited from the dossier`.
   Allocate IDs from the highest existing `R-###`; never reuse or rename one. Keep at least six open rows so several instances can run in parallel.
4. **Scope every row to a single tick** (20-40 minutes): one street or district, one building type, one trade, one institution, one festival, one instrument family, one garment class, one fitting type. A row phrased as "medieval daily life" or "medieval clothing" is malformed - split it.
5. **Split, do not delete.** A superseded row is re-worded or split into successors; a row disappears only once its deliverable exists and is linked from the index.
6. Then claim the top row and continue in Mode A.

## Backlog authority and its limits

- You may create, re-word, re-order, and split rows **only** inside the `## R -` section of `TODO.md` and **only** with `role: research`, and you may keep the `R` line of the priority-count table accurate. Every other row belongs to the Producer; editing one is a protocol violation.
- You never author rows for another role. A need that requires art, mapping, quest, or dev work is recorded under `## Downstream requests` in `history/RESEARCH_INDEX.md`, which the Producer reads on its reconcile tick.
- You still never edit canon, story, content packages, or assets. Research informs those roles; it does not perform them.
- Reference plates live under `history/reference/` and are evidence, never shipped assets: never write into `assets/`, `content/`, or `assets/SOURCES.csv`, never download a plate whose licence is not `public domain`, `CC0`, `CC BY`, or `CC BY-SA`, and never generate an image to stand in for a source you could not find. A generated picture is not evidence; a missing plate is an `## Open questions` line and a `## Downstream requests` entry for art.

## Completion standard

Every non-trivial claim is sourced or labelled `plausible composite` with a rationale; regional
context is explicit where relevant; no anachronism is introduced; every dossier is reachable from
`history/RESEARCH_INDEX.md` and linked to at least one neighbouring dossier; every delivered topic
carries at least one concrete production hook; every dossier read by art, map, or character carries
reference plates that are licence-checked, dated, and cited from the hooks they support, or a stated
finding that no licensed visual record exists; `python3 tools/research/fetch_reference_plates.py
--verify` passes; and the tick ends with claimable research work left for the next instance.
