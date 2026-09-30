# UF-14: ADR 0027 - a second streaming group for the Reval hinterland

Board row: **R-1129**. Priority: high. Depends on: **R-980**.

## Player-facing goal

Decide whether a player can walk out of Reval through a gate and continue into the surrounding countryside without a location-loading wait. The recommendation is a second, bounded `reval_hinterland` group connected to `reval_outdoor` at explicit gate seams, not a seamless Estonia campaign world.

**Decision pending maintainer acceptance, 2026-09-30.** Dev prepares the ADR and estimates; only the named maintainer can choose the scope. This contract does not claim that the choice has been made or that R-980's release gates have passed.

## Why this is needed

The membership census in docs/SEAMLESS_STREAMING_PLAN.md accounts for **29** source maps: **10 reval_outdoor + 9 door interiors + 10 travel**. ADR 0019 is `Accepted` on **2026-09-27 by Artjom Kurapov**. It keeps campaign travel non-physical; its operational census assigns **every world.* map to travel**, including world.harju and world.sojamae. Extending seamlessness beyond that boundary is a scope decision, not fixing a broken seam.

The first group already includes the Kalamaja shore (`reval_harbor_east`, 144 x 80 = 11,520 cells), the northern harbour (`reval_harbor_north`, 160 x 108 = 17,280 cells) and `viru_gate_foreland`. Do not count those existing maps as newly authored outskirts. The two nearby travel maps are small, non-contiguous prototypes: world.harju is **52 x 30 = 1,560 cells** and world.sojamae is **54 x 30 = 1,620 cells**. Their existence does not supply the missing connecting roads.

The measured startup report docs/reports/seamless_startup_baseline_2026-09-26.md uses a **19,456-cell** Lower Town on Apple M5 Pro, Godot 4.7.1, headless dummy renderer. It reports **148.87 ms** compact pipeline, **4,176.95 ms** warm 3D assembly, **17,267.53 ms** full scene startup, **15,088 nodes**, **601.70 MiB** static delta and **17.53 ms** idle p95. Full startup was contended by an editor process and is not minimum-hardware/GPU evidence. ADR 0019 allows **4 ms/frame** streaming work, **7,500 nodes**, **900 collision shapes**, **280 MiB**, p95 **16.67 ms**, p99 **25 ms**. One baseline scene already exceeds node and memory caps; adding maps is not free even if layout metadata is cheap.

Number check on 2026-09-30: `ls docs/adr/` ends at merged 0025; WB-09/R-981 reserves 0024, UF-01/R-1110 reserves 0026, and only this pack reserves 0027 in docs/tasks and TODO.md. Retain **0027**, rechecking before creating the ADR.

## Deliverable

1. docs/adr/0027-reval-hinterland-streaming-group.md with **Status / Context / Decision / Alternatives / Consequences**. Initially use `Proposed, 2026-09-30. Awaiting maintainer acceptance.` Replace with a named human decision and its actual ISO date only when given. Rejecting the recommendation does not unblock UF-15/R-1133.
2. Argue this recommended membership, with old and proposed tables side by side until accepted:
   - Keep all **10** existing `reval_outdoor` members there, including both harbour maps and Viru foreland. The second group's Kalamaja component is the landward continuation of the existing shore, not duplicate ownership of that shore.
   - Reassign **world.harju** and **world.sojamae** from travel to `reval_hinterland` only after acceptance and physical connection authoring in UF-15. Stable map/location IDs remain unchanged.
   - Proposed new connective map IDs: `kalamaja_hinterland`, `pirita_road`, `viru_approach_road`, `harju_approach_road`, `sojamae_approach_road`. These are planning IDs pending the maintainer and Map/Canon boundary review, not claims that files already exist. Specify each reciprocal endpoint, historical confidence and required aperture in the ADR before UF-15 starts: Kalamaja shore to its landward continuation; Viru foreland to Pirita and the Viru road; Harju gate approach to world.harju; the Viru/Sõjamäe road junction to world.sojamae. Verify the actual gate-owning map and transition IDs instead of inventing them.
   - Retain **8 distant travel maps**: world.saaremaa, world.padise, world.paide, world.parnu, world.poide, world.kanavere, world.sacred_grove and world.rebel_kings. Retain **9 interiors** on doors.
   - Existing-map accounting after the proposed amendment: **10 + 2 + 9 + 8 = 29**. With all five proposed connectors eventually authored: **10 + 7 + 9 + 8 = 34**. Label planned rows separately; do not pretend five files already exist. Every existing source has exactly one membership assignment.
3. Define cross-group seams explicitly. One map has one group and one stable identity; an inter-group gate bridge carries reciprocal endpoints and a deterministic coordinate transform between canonical group spaces. Crossing must retain the single host-owned player, camera, clock and session and one bounded residency envelope, not mount two complete worlds. This is an ADR contract, not a claim that current runtime supports group bridges. UF-15 must not be claimed until Producer names a dependency-safe Dev owner for any required bridge/layout-tool support outside its map-only scope.
4. Amend ADR 0019's membership reference and the streaming-plan census in the same decision change. While proposed, retain the current effective census and add a clearly labelled pending amendment; on acceptance make the new table the target, with flags still off. Specify the validator rule: membership, not the `world.` prefix alone, determines eligibility. Travel and interior members cannot have physical streaming seams. Same-group seams require opposite compatible reciprocal apertures; only explicitly allowlisted inter-group gate pairs may bridge groups. Unknown members, duplicate assignments and undeclared cross-group seams fail closed. Gate height/form checks remain UF-08/R-1117, not a new duplicate verifier.
5. Publish an estimate row for every added member, using the table below as a transparent sizing model. Before acceptance, replace provisional connector sizes with reviewed maximum cell counts and record measured/estimated separately. Do not represent the linear model as a benchmark or permission to exceed resident caps.
6. **Proposed equivalent-cost scope removed: WB-11/R-983 deliverables 4 and 7, the interactive relief-sculpting tool and docked live 3D editor preview.** Keep text-authored R-974 relief, existing preview/capture tools, the 2D content editor, diagnostics and safe serialization. Compare the removed editor interaction, overlay, live-preview lifecycle and test effort against five connectors plus group integration. This is a proposed trade, not an approved cut or a repeat of UF-01's WB-09 geometry saving. Require named WB-11 owner and maintainer agreement and a written cost comparison. If insufficient, the decision stays blocked until a different equivalent-cost cut is approved.

The exported allowed paths do not include the WB-11 contract. Producer must authorize a bounded amendment to docs/tasks/world/WB-11_rrmap_content_editor.md and docs/tasks/world/README.md before applying that trade there. Record the proposed cut in this row's ADR/TODO evidence, but do not mark the scope condition complete with contradictory WB-11 deliverables still in force.

### Planning cost model, not new benchmark results

Let `s = proposed cells / 19456`. Estimate pipeline `148.87*s` ms, warm view `4176.95*s` ms, contended full startup proxy `17267.53*s` ms, node proxy `15088*s`, memory proxy `601.70*s` MiB. Shared caches, fixed globals, terrain complexity and new assets make these uncertain. Frame slicing assumes ideal splittable work and 60 Hz: `ceil(warm_ms/4)` frames. Real atomic work and prefetch misses must be measured by the WB runtime gates.

| Added group member | Cells | Pipeline / warm view / full-startup proxy ms | Ideal warm slices / seconds | Node / memory proxy |
|---|---:|---|---|---|
| world.harju (existing) | 1,560 | 11.94 / 334.91 / 1,384.53 | 84 / 1.40 | 1,210 / 48.24 MiB |
| world.sojamae (existing) | 1,620 | 12.40 / 347.79 / 1,437.78 | 87 / 1.45 | 1,256 / 50.10 MiB |
| kalamaja_hinterland (proposed) | 2,048 maximum assumption | 15.67 / 439.68 / 1,817.63 | 110 / 1.83 | 1,588 / 63.34 MiB |
| pirita_road (proposed) | 2,048 maximum assumption | 15.67 / 439.68 / 1,817.63 | 110 / 1.83 | 1,588 / 63.34 MiB |
| viru_approach_road (proposed) | 2,048 maximum assumption | 15.67 / 439.68 / 1,817.63 | 110 / 1.83 | 1,588 / 63.34 MiB |
| harju_approach_road (proposed) | 2,048 maximum assumption | 15.67 / 439.68 / 1,817.63 | 110 / 1.83 | 1,588 / 63.34 MiB |
| sojamae_approach_road (proposed) | 2,048 maximum assumption | 15.67 / 439.68 / 1,817.63 | 110 / 1.83 | 1,588 / 63.34 MiB |

Seven added members total **13,420 cells** in this provisional plan. Serial warm CPU is approximately **2,881 ms**, **721** ideal 4 ms slices, **12.02 s** at 60 Hz; naive all-member residency proxies are approximately **10,407 nodes / 415 MiB**, already above caps. Consequently do not preload the whole second group. A three-connector ring alone projects about **4,765 nodes / 190 MiB**, excluding shared host and neighbours; an urban gate can still exceed caps. Keep the existing maximum-three-location envelope across both groups, measure crossing costs and retain flag-off/fallback until the existing caps actually pass.

### Alternative to reject on cost: one world-scale layout

This would additionally require physical connective corridors from Harju to Padise, Kanavere and Paide, Paide toward Pärnu, branches to the sacred grove and Rebel Kings, a mainland sea crossing to Saaremaa and an island corridor to Põide. These are **at least eight additional corridor packages**, not researched route attestations; realistic distances would require more than one package per corridor and a sea journey design absent from this task. Even an unrealistically small 2,048-cell proxy each adds **16,384 cells**, about **3,517 ms** warm CPU, **880** ideal slices (**14.67 s**), **12,706 nodes / 507 MiB** if resident, excluding the eight destination packages. Geography-wide loading cannot fit the unchanged caps. A bounded resident ring could still scale independently of world size, but it does not remove the authoring, sea-travel, prefetch, navigation, precision and save-boundary work for those corridors. There is no measured performance evidence or equivalent-cost scope removal for it. Recommend retaining explicit journeys rather than pretending distance is solved by joining layout files.

Also discuss keeping all outskirts travel-only: lowest new cost and current accepted behavior, but it does not meet the maintainer's surrounding-area request. Acceptance of either alternative must update the downstream task disposition explicitly.

## Allowed files

- docs/adr/0027-reval-hinterland-streaming-group.md
- docs/adr/0019-seamless-contiguous-location-streaming.md
- docs/SEAMLESS_STREAMING_PLAN.md
- docs/tasks/urban_form/README.md
- docs/tasks/urban_form/UF-14_adr_hinterland_group.md
- docs/tasks/urban_form/UF-15_hinterland_maps.md
- TODO.md

No WB-11 file is authorized by this list; request the exact-path contract amendment for the proposed scope trade. A number collision also requires an amended exact path/citation write set. This task-contract authoring pass writes only this contract.

## Constraints and non-goals

- No runtime, map, flag-default, activation or layout-manifest changes. No seamless interiors.
- R-980 must prove the existing Reval seam before this dependent decision row closes. Pending performance work is not waived by an accepted membership decision.
- CO-04/R-951 owns Kalamaja shore geometry and levels. Keep its maps single-owned; UF-15 consumes its ladder and connects the shore, not reauthors it independently.
- WB owns streaming runtime; UF owns membership and connective maps. Group-bridge implementation needs its own executable contract if not already supported.
- Named historical routes need evidence/confidence and Canon review. Proposed corridor labels and cell budgets are production assumptions, not 1343 facts.

## Verification

```bash
ls docs/adr/
grep -rn "ADR 0026\|ADR 0027" docs/tasks TODO.md
find content/maps -maxdepth 1 -name '*.rrmap' | wc -l
grep '^map ' content/maps/*.rrmap
python3 tools/generate_active_docs_report.py --check
git diff --check
```

Count-check the current effective census (and rerun after any accepted update):

```bash
python3 - <<'PY'
import re
from collections import Counter
from pathlib import Path
plan = Path('docs/SEAMLESS_STREAMING_PLAN.md').read_text()
census = plan.split('## Membership census', 1)[1].split('## Phases 3-5', 1)[0]
rows = re.findall(r'^\| `([^`]+)` \| `([^`]+\.rrmap)` \|', census, re.M)
counts = Counter(source for _, source in rows)
actual = {p.name for p in Path('content/maps').glob('*.rrmap')}
assert set(counts) == actual, (set(counts) - actual, actual - set(counts))
assert all(n == 1 for n in counts.values()), counts
print(f'{len(rows)} source maps, each assigned exactly once')
PY
```

Keep the proposed future table outside the effective census section so this check cannot double-count it. At initial acceptance the expected count remains 29; new source files later increase it, never reduce coverage.

- Named maintainer review: chosen membership, rejected alternatives, accepted scope cut, ISO date and R-1133 release/block disposition are explicit.
- Independent Dev/QA budget review: every added map has a cell bound, startup/streaming/residency estimate and uncertainty; no proxy is presented as a measured minimum-tier result. WB-11 owner signs the actual cut before the scope-change gate passes.
- Read-only benchmark reproduction when equipment is available: `tools/benchmarks/run_large_map_benchmark.sh build/benchmarks/seamless-startup-baseline.json --quick`. No visible Godot window; all non-render probes must be headless. Do not claim a new measurement if only this estimate was reviewed.

## Doc updates

Write the pending/accepted ADR, amend ADR 0019 and the streaming-plan target together, update the urban-form README/UF-15 contract and durable R-1129/R-1133 lines. Producer resolves the WB-11 path amendment and any missing Dev bridge dependency before implementation can become ready. Do not change effective membership or delete travel semantics merely because this proposed contract exists.

## TODO.md line

```text
- [ ] R-1129 | deps: R-980 | deliverable: ADR 0027 decision for bounded reval_hinterland gate-linked membership, complete census, per-map measured-baseline cost estimates and approved equivalent-cost scope removal | verify: named maintainer ISO-dated decision; independent scope/budget review; unique membership count check; python3 tools/generate_active_docs_report.py --check; git diff --check
```
