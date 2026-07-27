---
name: rebel-art-work-loop
description: Poll, claim, produce, validate, and report Reval Rebel art tasks through the shared TODO queue.
---

# Rebel Art Producer Work Loop

Follow this operational sequence after reading the role definition and required art references.

1. Scan `TODO.md` for claimable `role: art` rows. Confirm the common claim criteria in `docs/AGENT_LOOPS.md`, including completed dependencies and no same-role path overlap. If none are claimable, stop.
2. Claim the highest-priority eligible row before creating or modifying assets: flip it to `- [~]` and append `claim: art-N@<date>`. First writer wins.
3. Produce candidates according to the style lock kit. Use ComfyUI or Leonardo as appropriate. For 3D, require one object, a neutral pose where applicable, and a plain background. Curate the cleanest candidate; import only production-approved output into `assets/`; record source, rights, prompt or workflow provenance, and approval information in `assets/SOURCES.csv`. Raw candidates never enter runtime paths before approval.
4. Run `python3 tools/verify_asset_lint.py`. Resolve every failure within owned paths.
5. On a successful content delivery, replace the claim tag with `review: canon`. Add a concise Canon note when the visual work introduces or interprets canon-relevant material. Do not mark the row done yourself.
6. If the task cannot be completed, flip it to `- [!]` and append `blocked: <reason>`. Do not work around the asset freeze, a missing approval, or an unclear brief.

## Completion standard

A delivered asset matches the approved art bible, reads at its intended gameplay scale, is lint-clean, has complete provenance, and contains no unapproved raw 3D generation.
