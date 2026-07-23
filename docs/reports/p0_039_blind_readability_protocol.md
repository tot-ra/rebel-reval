# P0-039 blind gameplay-scale readability protocol

**Status:** Cancelled - optional reference only ([ADR 0013](../adr/0013-authorial-visual-direction-without-blind-ux-panels.md), 2026-07-23)

Recorded: 2026-07-23  
Task: **P0-039** (cancelled)  
Evidence pack: [`data/p039_readability_pack.json`](data/p039_readability_pack.json)  
Blind stimuli: [`../images/p039_blind_pack/`](../images/p039_blind_pack/)  
Results template: [`data/p039_readability_results.template.json`](data/p039_readability_results.template.json)

## Purpose

Run a blind readability review of the programmatic 3D isometric candidate at native gameplay framing. This protocol was drafted for a human gate named in [ADR 0007](../adr/0007-ai-generated-isometric-presentation.md). **ADR 0013 cancelled the gate; do not treat this document as a release blocker.**

This document is **not** a substitute for participant recruitment. It defines the facilitator procedure, rubric, and machine-checkable results contract.

## Independence rules

1. Show only blind-labelled PNGs from `docs/reports/images/p039_blind_pack/`.
2. Do not reveal map IDs, engine names, renderer settings, or style candidate names.
3. Do not use the P0-036 heuristic UX review scores as participant answers.
4. Collect at least five independent participants who did not author the captures or this protocol.

## Recognition targets

Every participant answers for every stimulus on four targets:

| Target | Question |
|--------|----------|
| Silhouette | Which buildings, characters, props, or routes are identifiable by shape alone? |
| Interaction | What would you approach, inspect, or use first? |
| Depth | What reads as foreground, midground, or background? |
| Motion | For animated stimuli only: is movement direction and foot contact readable? For static stimuli, record `null` for the motion score and explain static depth cues instead. |

## Rubric

Score each target **1-5**:

| Score | Meaning |
|------:|---------|
| 1 | Unreadable or guessed |
| 2 | Vague impression only |
| 3 | Partly readable with effort |
| 4 | Clear at gameplay scale |
| 5 | Immediately clear without labels |

Each score must include a short free-text note naming the elements the participant cited.

## Session procedure

1. Verify the pack with `python3 tools/generate_p039_readability_pack.py --check`.
2. Open only the blind PNGs (`stimulus_a.png` through `stimulus_f.png`).
3. Present stimuli in blind-label order without map or time-of-day narration.
4. Record one JSON object per participant in `docs/reports/data/p039_readability_results.json` using the template.
5. Verify results with `python3 tools/verify_p039_readability_results.py docs/reports/data/p039_readability_results.json`.
6. Summarize pass/fail against the acceptance thresholds below.

## Acceptance thresholds

The session passes **P0-039** when all of the following hold:

- At least five participants complete every stimulus.
- Median silhouette, interaction, and depth scores are **>= 4** on every stimulus.
- The motion stimulus (`Stimulus E`) median motion score is **>= 4**.
- No stimulus records more than one participant at score **<= 2** on any non-motion target.
- Facilitator notes contain no style-name leakage.

## Regeneration

When slice captures change, refresh the pack:

```bash
python3 tools/generate_p039_readability_pack.py --write
python3 tools/generate_p039_readability_pack.py --check
```

Commit the updated manifest and blind PNG copies together.

## Related evidence

- Development performance baseline: [`p0_038_3d_view_comparison.md`](p0_038_3d_view_comparison.md)
- Heuristic contrast review (not blind): [`visual_targets_p0_036_ux_review.md`](visual_targets_p0_036_ux_review.md)
- Slice surface captures: [`../images/view3d/`](../images/view3d/)
