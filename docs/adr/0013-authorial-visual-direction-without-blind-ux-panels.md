# ADR 0013: Authorial visual direction without blind UX panels

**Reference:** Maintainer decision 2026-07-23; cancels TODO P0-039 and P0-122  
**Amends:** [ADR 0007](0007-ai-generated-isometric-presentation.md), [ADR 0004](0004-clean-painted-visual-style-candidate.md) (historical)

## Status

Accepted

## Context

Reval Rebel is an authorial project: the maintainer sets product vision and direction; implementation agents and contributors realize that vision with documented interpretation and proposals.

[ADR 0007](0007-ai-generated-isometric-presentation.md) already accepted programmatic 3D isometric presentation as the production direction. TODO **P0-039** added a blind five-participant gameplay-scale readability panel as a hard gate before **P0-040** could freeze ART_BIBLE v2. That gate modeled consumer-product UX research, not the project's actual decision process.

The maintainer confirmed on 2026-07-23 that:

- 3D isometric presentation is already decided and is not reopening for panel comparison.
- Blind participant studies are out of scope for this repository's approval workflow.
- Visual readability remains important, but it is owned by maintainer review, in-engine iteration, and automated technical evidence (for example **P0-038** performance baselines and capture review), not external unlabeled stimulus panels.

## Decision

1. **Cancel P0-039 and P0-122.** The blind readability protocol, stimulus pack, and facilitator session are not required for style approval or district conversion.
2. **Remove P0-039 as a P0-040 dependency.** **P0-040** closes when the maintainer records ART_BIBLE v2 approval and the technical baseline from **P0-038** is satisfied.
3. **Keep P0-039 scaffold artifacts as optional reference only.** Files under `docs/reports/p0_039_*`, `tools/generate_p039_readability_pack.py`, and `tools/verify_p039_readability_results.py` may remain for historical evidence but are not CI gates or release blockers.
4. **Readability feedback path.** Maintainers and contributors judge gameplay readability through authored captures, playable review, and implementation proposals. Agents may suggest visual fixes without running formal user panels.

## Alternatives

- **Keep P0-039 as a hard gate.** Rejected. It duplicates a decision already made in ADR 0007 and conflicts with the authorial workflow.
- **Replace blind panels with maintainer-only heuristic scoring.** Rejected as a mandatory gate. Informal review is sufficient; no new scored checklist task is required before P0-040.
- **Delete all P0-039 files immediately.** Rejected. Keeping the scaffold preserves audit history and avoids churn in tests that already landed.

## Consequences

- **Positive:** P0-040 unblocks on maintainer sign-off plus P0-038 technical evidence, matching how other authorial gates (for example ADR 0003 offline dialogue) work.
- **Positive:** CI and roadmap text stop implying that five external participants are required before art production.
- **Negative:** No repository-managed external panel guards against readability regressions; that risk is accepted and owned by maintainer review.
- **Process impact:** Update TODO **P0-040**, ROADMAP, ART_BIBLE approval steps, and ADR 0007 consequence bullets to reference this ADR instead of P0-039.
