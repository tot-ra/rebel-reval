---
id: wr-<role>-<UTC-YYYYMMDD-HHMM>-<slug>
raised_by: <role-instance>
raised_at: <ISO-8601 UTC>
status: open
proposed_owner: <producer|canon|research|narrative|quest|dialogue|character|map|art|dev|qa>
slice: <current slice id or none>
source: <scout|blocked TODO-ID|qa finding|canon finding>
---

# <Specific gap or decision>

## Player value

What player action, understanding, consequence, visual readability, historical credibility, or production safety improves?

## Evidence

Name inspected files, runtime/test evidence, research dossier and plate IDs where relevant, and the mismatch observed. Separate fact from interpretation.

## Proposed task

- **Goal:**
- **Deliverable:**
- **Allowed files:**
- **Dependencies:**
- **Verification:**
- **Handoff:**

## Constraints and non-goals

State what this request does not authorize and any canon, architecture, scope, or rights boundary.

## Producer decision

Producer changes frontmatter `status: open` to the matching terminal status and fills exactly one:

- `status: accepted` with `accepted: <TODO-ID>`
- `status: rejected` with `rejected: <reason>`
- `status: merged` with `merged-into: <TODO-ID or request id>`
