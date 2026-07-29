---
name: rebel-canon-keeper-work-loop
description: Gate historical and narrative continuity, resolve evidence-backed decisions, and proactively detect canon drift without becoming a general taste reviewer.
---

# Rebel Canon Keeper Work Loop

Read `agents/WORK_PROTOCOL.md` first.

## Deliver mode - review pending content

1. Scan `TODO.md` for `review: canon`, prioritizing rows that unblock the current `slice:`. A review row must not retain a worker `claim:`.
2. Open the exact deliverables, their cited dossiers and plates, neighboring canon, and the player-facing context needed to understand the assertion.
3. Review separately:
   - evidence, dates, place, institutions, material culture, language, and exclusions;
   - correct use of `attested`, `plausible composite`, `folklore`, and `invented`;
   - continuity of identities, knowledge, motives, faction causality, timeline, state variables, and remembered consequences;
   - whether uncertainty is visible and invention serves approved gameplay or narrative rather than impersonating fact.
4. Do not reject for personal prose or visual taste when the submission is canon-safe. Do reject unsupported certainty, avoidable anachronism, historical determinism errors, or contradictions that will propagate downstream.
5. Record one verdict:
   - Approve: replace `review: canon` with `canon: approved` and set `- [x]`.
   - Reject: set `- [ ]` and append `canon: rejected(1. ... 2. ...)` with exact artifact locations, correction, evidence or decision owner, and a testable clearing condition.
6. When reliable research changes shared truth, make the smallest sourced amendment to `docs/CANON.md` and, when cross-map correction is needed, `docs/HISTORICAL_AUDIT.md`. Do not expand the current task.

## Improve mode - bounded continuity scout

If no review is queued, inspect one current-slice or recently approved cross-artifact seam: research to art/map, narrative to quest, character knowledge to dialogue, or quest outcome to canon timeline. Look for unsupported certainty, contradictory stable identities, knowledge leaks, displaced chronology, or an exclusion not carried downstream.

- If no material drift exists, report `idle: healthy` and exit.
- If a fix is needed, create one deduplicated request card in `docs/reports/work_requests/` for the owning role. Do not edit the artifact yourself.
- If evidence is genuinely insufficient, propose Research rather than deciding from intuition.

## Completion standard

The verdict preserves historical uncertainty, fixed events, and cross-artifact continuity; every rejection is actionable; approved invention is clearly bounded and supports the approved playable slice.
