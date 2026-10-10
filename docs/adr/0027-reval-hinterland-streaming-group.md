# ADR 0027: A second streaming group for the Reval hinterland

**Reference:** UF-14 / board **R-1129**; amends the membership census of [ADR 0019](0019-seamless-contiguous-location-streaming.md); contract [`docs/tasks/urban_form/UF-14_adr_hinterland_group.md`](../tasks/urban_form/UF-14_adr_hinterland_group.md).

## Status

**Accepted, Artjom Kurapov, 2026-09-30.** The maintainer approved the recommended bounded group and the equivalent-cost trade below before this ADR was written. On **2026-10-07** the maintainer restated the target: seamless movement across large areas of Tallinn and its surroundings, with loading kept for distant locations such as Saaremaa. That matches this membership and does not widen it.

Acceptance is a membership and contract decision only. It does not enable runtime behaviour. Streaming flags stay off until the [R-980 release criteria](../SEAMLESS_STREAMING_PLAN.md#r-980-release-criteria) pass inside `reval_outdoor` and then pass again for every hinterland seam. R-1129 stays open until R-980 proves the first group. Interiors are decided separately in [ADR 0028](0028-seamless-building-interiors.md).

**Amended by [ADR 0042](0042-regional-site-plans.md) (accepted 2026-10-10).** `world.harju` and `world.sojamae` leave the planned `reval_hinterland` membership below: they stay explicit travel and load as regional sites. Harju is built (R-1527: `scenes/world/sites/harju.tscn`; the `world_harju.rrmap` greybox is retired), Sõjamäe follows in R-1526. `harju_approach_road` and `sojamae_approach_road` no longer end on a hinterland map, the `world.harju road_to_sojamae` / `world.sojamae road_to_harju` seam-side fix is void, and the Harju parts of UF-15 (R-1133) and UF-15a (R-1213) are re-scoped (notes on both rows and in [`UF-15_hinterland_maps.md`](../tasks/urban_form/UF-15_hinterland_maps.md)). The Kalamaja, Pirita and Viru-approach connectors are unaffected. The sections below keep their 2026-09-30 text.

## Context

ADR 0019 makes the ten physically adjacent Reval districts and harbours one streaming group, `reval_outdoor`. Its census assigns every `world.*` map to explicit travel, including the two small nearby prototypes `world.harju` (52 x 30 = 1,560 cells) and `world.sojamae` (54 x 30 = 1,620 cells). The maintainer asked for seamless movement in Tallinn *and the surrounding areas*. Extending seamlessness past the wall is a scope decision, not a broken seam.

Facts checked on 2026-10-07 against `content/maps/*.rrmap`:

- `reval_harbor_east` (the Kalamaja shore) has a single transition, `to_harbor_north`. There is no landward exit yet.
- `viru_gate_foreland` reaches `world.harju` through `to_world_harju`, marked `alignment=travel`. `world.harju` marks all five of its exits as travel.
- `world.sojamae` connects only to `world.harju` and `world.paide`. It has no junction with the Viru road.
- No map has a Harju Gate. The south curtain on `south_quarter` carries the Karja Gate exit `to_world_sacred_grove` ([street register](../reports/reval_street_register_1343.md), R-1111).

Measured cost baseline ([seamless startup baseline](../reports/seamless_startup_baseline_2026-09-26.md), Apple M5 Pro, Godot 4.7.1, headless): a 19,456-cell Lower Town takes 148.87 ms to compile, 4,176.95 ms for warm 3D assembly, 15,088 nodes and 601.70 MiB static delta. ADR 0019 allows 4 ms/frame of streaming work, 7,500 nodes, 900 collision shapes, 280 MiB, p95 16.67 ms, p99 25 ms. One baseline location already exceeds the node and memory caps. Adding maps is not free even if layout metadata is cheap.

## Decision

### 1. Two groups, one host

Add a second streaming group, `reval_hinterland`, for the physically contiguous outskirts. It joins `reval_outdoor` at explicit gate seams. Genuinely distant regions keep an explicit journey with a loading transition.

| Group | Members |
|---|---|
| `reval_outdoor` (unchanged) | `lower_town_slice`, `market_civic_quarter`, `monastery_quarter`, `north_quarter`, `south_quarter`, `toompea_quarter`, `archbishops_garden`, `viru_gate_foreland`, `reval_harbor_north`, `reval_harbor_east` |
| `reval_hinterland` (existing maps) | `world.harju`, `world.sojamae` |
| `reval_hinterland` (planned, not yet authored) | `kalamaja_hinterland`, `pirita_road`, `viru_approach_road`, `harju_approach_road`, `sojamae_approach_road` |
| Travel (loading kept) | `world.saaremaa`, `world.padise`, `world.paide`, `world.parnu`, `world.poide`, `world.kanavere`, `world.sacred_grove`, `world.rebel_kings` |
| Interiors | the nine door interiors; target behaviour in ADR 0028 |

Map and location IDs do not change. `world.harju` and `world.sojamae` move from travel to `reval_hinterland` only when UF-15 (R-1133) authors their physical connections. The planned connector IDs are planning IDs pending Map and Canon boundary review, not claims that files exist.

### 2. Census, old and new

| Kind | ADR 0019 census | Target after this ADR |
|---|---:|---:|
| `reval_outdoor` | 10 | 10 |
| `reval_hinterland` (existing maps) | 0 | 2 |
| Interiors | 9 | 9 |
| Travel | 10 | 8 |
| **Existing source maps** | **29** | **29** |
| `reval_hinterland` (planned connectors) | - | +5 (total 34 once authored) |

Every existing source keeps exactly one assignment. The table in [`docs/SEAMLESS_STREAMING_PLAN.md`](../SEAMLESS_STREAMING_PLAN.md#membership-census) is updated in the same change and keeps planned rows separate.

### 3. Reciprocal endpoints

| Connector (planned) | Reval-side endpoint | Far endpoint | Historical confidence | Aperture to author |
|---|---|---|---|---|
| `kalamaja_hinterland` | `reval_harbor_east` (new landward exit; today only `to_harbor_north`) | open shore hinterland | plausible composite ([Kalamaja shore dossier](../../history/dossiers/topography/kalamaja-fishing-shore-1343.md)) | new reciprocal land seam; CO-04 / R-951 keeps shore geometry ownership |
| `viru_approach_road` | `viru_gate_foreland` east edge (replaces travel `to_world_harju`) | `pirita_road` and `sojamae_approach_road` | plausible composite (Viru - Iru - Pirita corridor, [Harju approach dossier](../../history/dossiers/hinterland/harju-rebel-camp-and-pirita-approach-1343.md)) | width-matched road seam |
| `pirita_road` | `viru_approach_road` | Pirita valley | plausible composite; 1343 bridge uncertain | river crossing as reversible reconstruction |
| `sojamae_approach_road` | `viru_approach_road` junction | `world.sojamae` (new west/north seam) | plausible composite | new reciprocal seam on `world.sojamae` |
| `harju_approach_road` | Harju Gate on `south_quarter`, **not yet authored** | `world.harju` (replaces travel `road_to_reval`) | plausible composite ([street register](../reports/reval_street_register_1343.md) `street.harju_road_extramural`) | Harju Gate aperture on the south curtain first |

`world.harju` keeps travel exits toward the sacred grove, Rebel Kings and Kanavere. `world.sojamae` keeps its travel exit toward Paide.

### 4. Cross-group seams

- One map belongs to one group and keeps one stable identity.
- An inter-group gate bridge is a listed pair of reciprocal transitions. It carries a deterministic coordinate transform between the two canonical group spaces.
- Crossing keeps the single host-owned player, camera, clock and session (ADR 0019 globals) and the one bounded residency envelope. The host never mounts two complete worlds.
- This is a contract. The current runtime has no group bridges. UF-15 must not be claimed until the Producer names a Dev owner for bridge and layout-tool support.

### 5. Validator rule

- Membership determines eligibility, not the `world.` prefix.
- Travel and interior members cannot have physical streaming seams. Interior entry follows ADR 0028 and is not a seam.
- Same-group seams need opposite, width-compatible, reciprocal apertures.
- Only allowlisted inter-group gate pairs may bridge groups.
- Unknown members, duplicate assignments and undeclared cross-group seams fail closed.
- Gate height and form continuity stay with the UF-08 gate (R-1117). No duplicate verifier.

### 6. Budget estimate per added member

Planning model, not a benchmark. Let `s = cells / 19456`. Pipeline is `148.87*s` ms, warm view `4176.95*s` ms, contended full startup proxy `17267.53*s` ms, nodes `15088*s`, memory `601.70*s` MiB. Ideal slices are `ceil(warm/4)` at 60 Hz. Connector sizes are a 2,048-cell maximum assumption until UF-15 reviews them.

| Added member | Cells | Pipeline / warm / startup proxy (ms) | Ideal slices / s | Nodes / memory proxy |
|---|---:|---|---|---|
| `world.harju` (existing) | 1,560 | 11.94 / 334.91 / 1,384.53 | 84 / 1.40 | 1,210 / 48.24 MiB |
| `world.sojamae` (existing) | 1,620 | 12.40 / 347.79 / 1,437.78 | 87 / 1.45 | 1,256 / 50.10 MiB |
| each planned connector (x5) | 2,048 max | 15.67 / 439.68 / 1,817.63 | 110 / 1.83 | 1,588 / 63.34 MiB |

Seven added members total about 13,420 cells: ~2,881 ms serial warm CPU (721 slices, 12.02 s), ~10,407 nodes and 415 MiB if all were resident. That is above the caps, so the group is never preloaded. The existing envelope of at most three resident locations applies across both groups. A three-connector ring projects about 4,765 nodes and 190 MiB, excluding the shared host and the urban neighbour.

### 7. Equivalent-cost scope removed

**WB-11 / R-983 deliverables 4 and 7: the interactive relief-sculpting tool and the docked live 3D editor preview.** These were approved by the maintainer on 2026-09-30 with this decision. Text-authored relief (R-974), existing preview and capture tools, the 2D content editor, diagnostics and safe serialization stay.

Cost comparison (estimate, not measured):

| Removed (WB-11 d4 + d7) | Added (this ADR) |
|---|---|
| Brush tool, overlay rendering, undo for heightfield edits | Five connector maps at <= 2,048 cells each, authored through existing primitives |
| Live preview lifecycle: hosted MapView3D in the editor, hot recompile, camera sync | Group-bridge transform and allowlist in the layout tool |
| Editor test harness for interaction, preview teardown and leaks | Validator rule above plus census tests |
| Ongoing editor maintenance across Godot versions | Runtime residency is shared with ADR 0019; no new runtime system |

The cut is judged to cover the added cost because the group reuses the ADR 0019 host, scheduler and manifest, and connectors use existing authoring. Before the cut is applied to the WB-11 contract, the Producer must authorize the exact WB-11 paths and notify the named WB-11 owner. If UF-15 measures more than five connectors or larger maps, bring a larger cut back to the maintainer.

## Alternatives

### Keep all outskirts as travel (ADR 0019 status quo)

Cheapest and already accepted. It does not meet the maintainer's request for seamless surroundings. Rejected.

### One world-scale layout for all of Estonia

This would need physical corridors from Harju to Padise, Kanavere and Paide, Paide toward Pärnu, branches to the sacred grove and Rebel Kings, and a sea crossing to Saaremaa and Põide. That is at least eight more corridor packages, most without researched route attestations, plus a sea-journey design. Even at 2,048 cells each it adds 16,384 cells, ~3,517 ms warm CPU (14.67 s of slices), 12,706 nodes and 507 MiB if resident, before the eight destinations. A resident ring could bound runtime cost, but not the authoring, navigation, precision and save-boundary work. Rejected on cost. The maintainer confirmed on 2026-10-07 that distant locations keep loading.

## Consequences

- `reval_hinterland` becomes the target census. `REVAL_OUTDOOR_MEMBERS` and the checked-in layout manifest do not change until UF-15 (R-1133) authors the connections and a Dev row adds group bridges.
- A Harju Gate aperture on `south_quarter` becomes a prerequisite for `harju_approach_road`.
- `world.harju` and `world.sojamae` keep their travel exits until their physical seams exist. No player-facing change lands with this ADR.
- WB-11 deliverables 4 and 7 are removed once the Producer applies the contract amendment.
- AGENTS.md and README scope lines now read: seamless Reval and its hinterland are in scope; a seamless Estonia-wide open world is not.
