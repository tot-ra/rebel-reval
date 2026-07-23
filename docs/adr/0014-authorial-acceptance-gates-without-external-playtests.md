# ADR 0014: Authorial acceptance gates without external playtests

**Reference:** Maintainer decision 2026-07-23; extends [ADR 0013](0013-authorial-visual-direction-without-blind-ux-panels.md)  
**Cancels:** TODO P3-003, P3-004, P3-006  
**Rewrites:** P3-005, P3-014, P4-012, P5-010, P6-007, P0-111, P0-072 dependency

## Status

Accepted

## Context

[ADR 0013](0013-authorial-visual-direction-without-blind-ux-panels.md) removed blind UX readability panels as release blockers. The maintainer confirmed the same authorial model applies to the rest of the acceptance workflow:

- External playtest rounds with fixed player quotas are consumer-product research, not how this repository approves slices or acts.
- Independent historian or consultant sign-off gates duplicate maintainer ownership of historical confidence and creative direction.
- Automated traversal, CI, and maintainer playable review already provide faster feedback for an authorial project.

TODO still contained a broken external-playtest chain (P3-003 depends on missing P3-002), slice and act gates requiring five or more external players (P3-014, P4-012, P5-010, P6-007), and P0-111 blocking P0-072 on independent historian review.

## Decision

1. **Cancel P3-003, P3-004, and P3-006.** External playtest rounds are not required for slice, act, or campaign approval.
2. **Retarget P3-005** to depend on **P2-012** instead of the cancelled playtest chain. Choice-distinctness review remains useful content work.
3. **Rewrite P3-014** as a maintainer vertical-slice gate backed by automated traversal, export checks, and `tools/release_candidate_check.py`; remove the five-player comprehension quorum.
4. **Rewrite P4-012, P5-010, and P6-007** to use maintainer playable review plus automated branch traversal and save fixtures; remove external playtest quotas.
5. **Simplify P0-111** to maintainer sign-off on `docs/HISTORICAL_AUDIT.md` review rows.
6. **Remove P0-111 as a P0-072 dependency.** Structural dossier completion is tracked separately from maintainer sign-off; P1-036 and district quality passes still require signed review rows per `tools/verify_historical_dossier.py`.

## Alternatives

- **Keep external playtests as optional evidence.** Rejected as mandatory gates. Maintainers may still record informal feedback, but no task requires a player quota.
- **Delete playtest-related tooling.** Rejected. Traversal harnesses and release-candidate checks remain the primary automated path.
- **Remove P0-111 entirely.** Rejected. Maintainer sign-off on historical ranges stays explicit, but no longer requires an independent historian.

## Consequences

- **Positive:** P3 slice validation unblocks from a nonexistent P3-002 dependency; P0-072 structural work no longer waits on an external historian gate.
- **Positive:** Act gates align with ADR 0013 authorial workflow: maintainer review plus automation.
- **Negative:** No repository-managed external playtest guards comprehension or pacing regressions; that risk is accepted and owned by maintainer review.
- **Process impact:** Update TODO, ROADMAP, and gate-report paths under `docs/reports/` when those tasks close.
