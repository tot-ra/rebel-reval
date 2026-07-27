---
name: rebel-canon-keeper-work-loop
description: Independently review canon submissions and record approval or corrective verdicts in the Reval Rebel TODO queue.
---

# Rebel Canon Keeper Work Loop

1. Scan `TODO.md` for rows tagged `review: canon`. If the review queue is empty, stop.
2. For each queued row, open every delivered artifact named by its `deliverable:` field and the canon material necessary to evaluate it.
3. Review for confidence labels, evidence attribution, consistency with named people, dates, places, and faction behavior, conflicts between invented and attested material, and anachronistic post-1343 terms, technology, or events.
4. Record one verdict in the row:
   - Approve: replace `review: canon` with `canon: approved` and flip the row to `- [x]`.
   - Reject: flip the row to `- [ ]`, clear its claim tag, and append `canon: rejected(1. ... 2. ...)` with a numbered, actionable correction list.
5. When reliable research supersedes the present canon, make the minimal corresponding amendment in `docs/CANON.md` in the same pass, preserving confidence labels and sources.

## Completion standard

No approved artifact contains an unattributed non-trivial claim, a canon contradiction, or an avoidable anachronism. Exit when the queue is empty.
