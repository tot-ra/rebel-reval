---
name: rebel-researcher-work-loop
description: Deliver sourced production evidence for 1343 Reval and proactively maintain a bounded demand-driven research backlog without substituting invention for missing history.
---

# Rebel Historical-Geo Researcher Work Loop

Read `agents/WORK_PROTOCOL.md`, `history/RESEARCH_INDEX.md`, and the dossier-standard skill first.

## Task board handoffs

Use the `tasks` tool for execution and follow-up work, not a prose-only note:

1. Start with `tasks.stats` and scoped `tasks.list`/`tasks.get`; claim only the selected board item with `tasks.next` (`claim: true`).
2. On delivery, use `tasks.update` to record dossier paths, citations, plate IDs, checks, and the next handoff. Use `in_review` while Canon is pending; release blocked work to `todo` with the typed clearing condition.
3. When research makes a concrete downstream need ready - for example a map adjustment, a model of a tool/person/animal/building, or placement of that model - call `tasks.create` with status `idea`, the downstream `role`, parent dossier/task, stable IDs, exact allowed paths, evidence, dependencies, verification, and handoff. Do not create one vague mega-task.
4. Keep a request card only for an unresolved decision, rights issue, or missing evidence. The Producer converts accepted ideas into `todo` work; do not claim or implement another role's task.

## Deliver mode

1. Select the highest-priority ready `role: research` row, including `R-###`. Preflight local sources, web access, reference-fetch tooling, rights constraints, and exact paths before claiming with a lease.
2. Start with the downstream decision: what form, behavior, institution, language, route, material, exclusion, or uncertainty must another role act on?
3. Produce the named dossier with a requesting-role brief of no more than 20 lines, sourced findings, confidence labels, `## Production hooks`, `## Reference plates`, `## Cross-references`, `## Open questions`, and `## Sources`. Address Reval, Danish Estonia, Hanseatic, Livonian Order, and seasonal context where relevant.
4. Cite every non-trivial factual claim. Separate direct evidence, inference, comparative transfer, folklore, and absence. Never smooth conflicting sources into certainty.
5. For Art, Map, or Character consumers, gather 3-8 decision-relevant plates in the same tick when available. Search local PDFs and Estonian/institutional sources first. Record source, object date/place, transfer rationale, rights, status, and checksum in `history/reference/plates.csv`; download only allowed licenses. Cite plate IDs from the hooks they support. Generated images are never evidence.
6. Link the dossier from `history/RESEARCH_INDEX.md` and add reciprocal cross-links. Convert unresolved same-role questions into bounded `R-###` work only when they matter to current production; create concrete cross-role follow-ups with `tasks.create` and use `docs/reports/work_requests/` only for unresolved decisions, rights, or evidence gaps.
7. Verify links, citations, plate manifest/fetch checks, and that the downstream role can make the named decision without reading the full source corpus.
8. On success, release the claim and leave `- [~] + review: canon`. If blocked, release the claim, set a typed blocker, and create one board follow-up naming the clearing owner when the clearing work is executable; otherwise create one request.

## Improve mode - demand-driven research scout

Audit in this order: evidence needed by open current-slice Art/Map/Character/Quest/Dialogue/Narrative work; current deliverables relying on unsupported historical claims; visual-consumer dossiers missing plates; unresolved open questions blocking production; then absent/stub index domains.

Research may maintain only `R-###` rows in the historical backlog. Refill below three grounded open rows and cap at eight. One row covers one 20-60 minute decision-sized topic. Never create background research merely to fill capacity, and never touch another campaign row.

If no current or near-term production decision lacks evidence, correct stale index status, report `idle: healthy`, and exit.

## Completion standard

The evidence is sourced, regionally and chronologically bounded, visually actionable where needed, honest about uncertainty, linked into the research graph, and translated into concrete hooks and exclusions without altering canon or downstream content.
