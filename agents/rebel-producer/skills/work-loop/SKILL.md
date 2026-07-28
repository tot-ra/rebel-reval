---
name: rebel-producer-work-loop
description: Reconcile the Reval Rebel task queue and maintain a dependency-safe, role-tagged production plan.
---

# Rebel Producer Work Loop

Perform each tick in order.

1. **Reconcile.** Read the `## Downstream requests` table in `history/RESEARCH_INDEX.md` and the same table in `docs/reports/art_downstream_requests.md`, and turn each open entry into a row for the responsible role. Then scan `TODO.md` for `- [!]` rows and re-scope them by splitting, rewording, fixing dependencies, or dropping them with a note in `docs/ROADMAP.md`. Return a blocked row to `- [ ]` only after it has been re-scoped. Reopen or adjust tasks marked `canon: rejected(...)` or `qa: failed(...)` so the originating role can reclaim them. Clear stale `claim:` tags older than one day back to `- [ ]`.
2. **Plan.** Read `docs/ROADMAP.md` under `Current focus`. When the current milestone has fewer than two claimable rows per active role, decompose the next approved milestone work into rows using `- [ ] ID | role: <loop> | deps: ID,ID or none | deliverable: ... | verify: ...`. Apply the full AGENTS.md task contract. Keep IDs stable and never rename existing rows.
3. **Order.** Keep `TODO.md` sorted by lower campaign band first and smaller work before larger work. Update its priority-count table and the `Current focus` section of `docs/ROADMAP.md` to match the actual plan.

## Hard rules

- Never edit code, content, scenes, or assets. Write a task for the responsible role instead.
- Phrase every content-producing task so it closes through `review: canon`.
- Do not leave two open tasks of the same role targeting the same file.
- The `## R - Historical research backlog` section belongs to the Researcher loop and the `## A - Art and animation backlog` section belongs to the Art loop. Never create, re-order, or delete `R-###` or `A-###` rows; reconcile their claim, blocked, and canon tags like any other row.
- Art rows you author yourself go in the campaign bands as usual. Do not duplicate an `A-###` row that already covers the same asset; if the two overlap, drop yours and let the Art loop own it.
- Stop when the current milestone has no open work and QA has accepted the candidate.
