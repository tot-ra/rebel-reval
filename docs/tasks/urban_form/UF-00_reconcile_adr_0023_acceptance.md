# UF-00: Reconcile ADR 0023 acceptance with landed relief code

Board row: **R-1109**. Priority: high. Depends on: none.

**Closed 2026-09-30: ADR 0023 was ACCEPTED by Artjom Kurapov.** The decision, the sequencing-breach
record and the released rows are in [ADR 0023](../../adr/0023-terrain-relief-as-gameplay.md),
"Acceptance record (UF-00, R-1109)". The `Accept` row of the outcome matrix below is the one in
force. The rest of this document is the contract as written, kept for review.

## Player-facing goal

Give the climb from the Lower Town to Toompea an explicit, approved gameplay-height contract before more streets or buildings depend on it. This is a **maintainer decision, not agent implementation work**. Producer records the decision and its dependency consequences; an agent cannot supply the human acceptance.

## Why this is needed

Checked on 2026-09-30. The actual Status paragraph in docs/adr/0023-terrain-relief-as-gameplay.md is:

> **Proposed, 2026-09-26. Awaiting maintainer acceptance.** Task: WB-01 (board R-973). Gates WB-02
> (R-974), WB-03 (R-975) and WB-04 (R-976). No relief code may land until this line records the
> maintainer's acceptance with an ISO date.

The exported board contract reports two relief rows already in review, R-974 and R-975, and four landed relief-dependent water rows, R-1003, R-1022, R-1023 and R-1024. Repository evidence independently confirms six relief commands in the parser, compiled relief storage in scripts/map/map_definition.gd, and a completed R-1024 line in TODO.md. The board states are supplied by the export, not inferred from these files.

The decision fixes a -8.0 to +32.0 world-unit total height range, 1/64-unit quantisation and a 35-degree walkable slope limit. WB-04/R-976 and UF-07/R-1116 need those rules, not a retrospective assumption that code presence means approval.

## Deliverable

1. A named maintainer records either `Accepted, <name>, <YYYY-MM-DD>` or `Rejected, <name>, <YYYY-MM-DD>` in ADR 0023 Status. Do not backdate the decision. Record the supplied evidence and decision rationale in Consequences, including that code landed before the required Status acceptance.
2. If accepted, explicitly ratify or correct the implemented interpretation without weakening the original sequencing rule. Acceptance removes the ADR gate only; it does not approve pending implementation or QA evidence.
3. If rejected, name the relief behavior to withdraw from WB-02/R-974 and WB-03/R-975, and the dispositions of R-1003, R-1022, R-1023 and R-1024. Producer must link bounded rollback/re-scope board work for the relevant Dev owners. No rollback is performed in this documentation-only row.
4. Record this exact outcome matrix against the row tables in docs/tasks/world/README.md and docs/tasks/urban_form/README.md:

| Outcome | Rows released from this decision gate | Rows not released |
|---|---|---|
| Accept | WB-01/R-973 can close its decision gate; WB-02/R-974 and WB-03/R-975 can continue independent acceptance; WB-04/R-976 can proceed after R-975 acceptance; UF-07/R-1116 can proceed after R-1113 and R-976 as well | No implementation, Canon or QA dependency is waived |
| Reject | UF-00/R-1109 can close as a recorded decision; **no relief implementation row is unblocked**. Only separately contracted rollback/re-scope work may become ready | WB-02/R-974, WB-03/R-975, WB-04/R-976 and UF-07/R-1116 cannot continue on rejected relief authority |

The transitive consequences are also explicit: WB-09/R-981 depends on R-974; WB-11/R-983 and WB-13/R-985 depend on R-981; WB-14/R-986 depends on R-985 and R-976. UF-12/R-1122 depends on UF-07/R-1116 and UF-15/R-1133 depends on R-976. Acceptance clears only their inherited ADR blocker, not their other dependencies. Rejection keeps those dependent relief paths blocked pending re-scope. Street research and UF-01 are not relief-decision dependants.

5. Add a reusable agents/playbook.md lesson: an ADR-gated pack shipped relief code before Status recorded acceptance; check the named ADR Status before claiming a gated row, and do not mistake merged files for human approval.

## Allowed files

Implementation of this decision row is limited to:

- docs/adr/0023-terrain-relief-as-gameplay.md
- docs/tasks/world/README.md
- TODO.md
- agents/playbook.md

This task-contract authoring pass writes only this contract; the paths above describe the later decision row, not permission to edit them now.

## Constraints and non-goals

- No relief code, map, test, asset or runtime-flag edits. No silent rollback of another worker's changes.
- Keep the original no-code-before-acceptance rule and document the sequencing breach rather than deleting it.
- Do not treat rejection as acceptance merely because R-1109 is closed. Dependencies requiring accepted relief must carry an explicit decision blocker after rejection.
- Keep stable IDs and existing review evidence. Named maintainer acceptance is required; Producer and agent reviews cannot substitute.

## Verification

```bash
sed -n '1,12p' docs/adr/0023-terrain-relief-as-gameplay.md
python3 tools/generate_active_docs_report.py --check
git diff --check -- docs/adr/0023-terrain-relief-as-gameplay.md docs/tasks/world/README.md TODO.md agents/playbook.md
```

- Human decision review: maintainer name, actual ISO date and `Accepted` or `Rejected` appear in Status; Consequences names the prematurely landed code and retained/withdrawn behavior.
- Independent Producer/QA dependency review: compare the outcome matrix with both pack row tables; on rejection no R-974/R-975/R-976/R-1116 acceptance gate is marked satisfied. Rollback needs have board refs, owners, exact paths and reproducible verification before becoming ready.
- Playbook review: the lesson requires checking Status before a gated claim, not merely checking that an ADR file exists.

## Doc updates

ADR 0023 records the human decision and breach; the world-pack README and durable TODO rows record the corresponding gates; agents/playbook.md records the prevention rule. Producer updates the existing board rows using the exported refs when operating in the parent project. Do not edit urban-form content or execute rollback in this row.

## TODO.md line

```text
- [ ] R-1109 | deps: none | deliverable: named maintainer acceptance or rejection of ADR 0023 with ISO date, premature-relief-code consequences, exact dependent-row disposition and prevention lesson | verify: ADR Status and Consequences human review; dependent-row audit against WB/UF tables; python3 tools/generate_active_docs_report.py --check; git diff --check
```
