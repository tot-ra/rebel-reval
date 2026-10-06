# ADR 0029: Natural Reval maps, and a coast three times larger

**Reference:** maintainer request 2026-10-07; builds on [ADR 0023](0023-terrain-relief-as-gameplay.md) (relief), [ADR 0026](0026-streets-as-authored-network.md) (streets, proposed), [ADR 0019](0019-seamless-contiguous-location-streaming.md) and [ADR 0027](0027-reval-hinterland-streaming-group.md) (streaming groups). Supersedes the footprint numbers in the CO-03 contract ([`docs/tasks/coast/CO-03_shore_silhouette_and_depth.md`](../tasks/coast/CO-03_shore_silhouette_and_depth.md), board R-950) only where this ADR sets larger totals.

## Status

**Accepted (direction), Artjom Kurapov, 2026-10-07.** Maintainer request in session: rework the map of Tallinn and all districts so they look natural, with different relief heights, streets and back alleys. Make Kalamaja, the port and Pirita about three times larger. Reference points: Novigrad (The Witcher 3), Kingdom Come: Deliverance II, Red Dead Redemption 2.

This direction is also the footprint-growth approval that R-950 was blocked on.

**Equivalent-cost scope removal: not chosen yet.** It is tracked with ADR 0028's open removal in board row R-1183. Two parts need nothing more:
- Relief re-authoring (R-976) is already in accepted scope (ADR 0023) and may proceed now.
- Street geometry still waits for the maintainer's decision on ADR 0026.

Map growth and the new coastal maps may not merge until the removal is named.

## Context

- **Flat maps.** No `.rrmap` authors any `relief_*` statement yet. Every district renders on one plane, Toompea included, because the old `elevation_*` profiles contribute zero height (ADR 0023). WB-04 (R-976) is the ready row that changes this.
- **Grid-like blocks.** Districts read as house grids with no human street design. The `.rrmap` grammar has no street primitive (UF-01). The [1343 street register](../reports/reval_street_register_1343.md) (R-1111) records nine places where current geometry contradicts the historical street plan; for example, Lai is drawn east of Pikk.
- **Orthogonal-only streets.** ADR 0026 as proposed allows only horizontal and vertical trace segments ("stepped orthogonal segments represent angled routes; curves are not introduced"). That keeps the cell grid simple. It cannot produce the bending lanes, fan-shaped junctions and irregular plazas that make Novigrad, Kutná Hora (KCD2) or Saint Denis (RDR2) read as grown cities.
- **Small coast.** Kalamaja (`reval_harbor_east`) is 144 x 80 = 11,520 cells and the northern harbour (`reval_harbor_north`) is 160 x 108 = 17,280. Pirita (`viru_gate_foreland`) is 168 x 120 = 20,160. CO-03 already proposed 192 x 128 and 208 x 144 for the two harbour maps.
- **Residency.** The measured 19,456-cell Lower Town already exceeds the ADR 0019 caps: 15,088 nodes and 602 MiB against 7,500 and 280. One giant map per area would multiply that.

## Decision

### 1. Natural relief across all districts

Every Reval district gets authored relief on one shared datum. WB-04 (R-976) delivers the Reval relief datum table in `docs/MAP_AUTHORING.md`; this ADR extends WB-04's target from four maps to all ten `reval_outdoor` maps. Targets:

| Feature | Target | Basis |
|---|---|---|
| Toompea crest above the Lower Town datum | 22-26 world units (~19-22 m) | H01, H12; ADR 0023 range |
| Toompea faces | cliffs where impassable; at least two walkable ascents (Pikk jalg, Lühike jalg) no steeper than 35° | ADR 0023 / R-975 slope maximum |
| Coastal Gate above harbour ground | 6-9 world units (~5-8 m) | H11 |
| Lower Town | bounded fall toward the wet northern margin, ditches on drainage lines, `relief_noise` so no street is a plane | H08, H10 |
| Gate approaches | ditch and causeway outside each gate | H08-H10 |

Every seam still meets its neighbour within `RELIEF_SEAM_TOLERANCE` (0.05).

### 2. Streets and alleys as authored networks

Streets, lanes and back alleys follow the [1343 street register](../data/reval_street_register.json), with frontage derived from them (UF-03..UF-07). Before accepting ADR 0026, the maintainer should decide whether to amend its trace rule to allow **diagonal (45°) segments and gentle bends**. This ADR recommends the amendment for a natural look, under these limits:
- footprints stay cell-exact;
- collision and navigation stay on the logic plane;
- curvature is only lowered to stepped cells in the compiler, never hand-placed as dictionaries.

That amendment belongs in ADR 0026 itself, not here.

### 3. Composition rules taken from the references

These are authoring rules, checked by the UF-16 master-plan and visual gate (R-1136):
- **Street hierarchy.** One or two spines per district, lanes off them, and alleys and yard passages behind the frontage. No uniform block grid.
- **Organic edges.** Frontages step and bend. Junctions widen into small irregular squares. Plots vary within the 7-11 m band.
- **Landmarks.** A landmark is visible from every spine (Toompea, St Olaf's, St Nicholas', the gates) and used for orientation.
- **Vertical layering.** Stairs, ramps, terraces and retaining walls where relief changes. Views down over roofs from Toompea and up from the Lower Town.
- **Density gradient.** Dense core, looser gate suburbs, then open hinterland (P0-072 bands).

### 4. Coast three times larger, in bounded maps

Each coastal area grows to about three times its current ground area. The growth comes from enlarging the existing map plus adjacent new maps in the same streaming group, never from one giant map:

| Area | Today (cells) | Target total | How |
|---|---:|---:|---|
| Kalamaja | 11,520 | ~34,500 | `reval_harbor_east` to 192 x 128 (24,576, CO-03) plus `kalamaja_hinterland` (ADR 0027, about 10,000 instead of the 2,048 assumption) |
| Port | 17,280 | ~52,000 | `reval_harbor_north` to 208 x 144 (29,952, CO-03) plus a new adjacent shore map, planning ID `reval_harbor_sand_gate` (about 22,000), toward the Sand Gate |
| Pirita | 20,160 | ~60,000 | `viru_gate_foreland` to 224 x 144 (32,256) plus `pirita_road` (ADR 0027, about 28,000 instead of 2,048) |

- **Size cap.** No single location exceeds **32,768 cells**.
- **Activation.** Before any grown map activates in seamless mode, it passes the ADR 0019 residency caps through within-location view residency (WB-07 units, R-1006), measured, not estimated.
- **New member.** `reval_harbor_sand_gate` joins `reval_outdoor`; the streaming-plan census adds it as a planned row.
- **Stable IDs.** Every map, transition, spawn, anchor, prop and structure ID survives a resize. Coordinate shifts are recorded per map. Parity fixtures change only through the documented migration path with the expected deltas, never regenerated just to get green.
- **Ownership.** CO-04 (R-951) still owns the coastal elevation ladder, and its bands scale with the new footprints.

### 5. Order of work

1. Relief everywhere (R-976 first slice: Toompea and Archbishop's Garden; then the Lower Town and the Viru foreland; then the remaining districts).
2. The maintainer decides ADR 0026, including the curve amendment.
3. Street primitive and frontage (UF-03, UF-04), then district street authoring (UF-05..UF-07), fixing the register contradictions.
4. Coastal ladder (R-951), then coastal growth (R-950 with this ADR's totals), then the new coastal maps (UF-15 and a new row for `reval_harbor_sand_gate`).
5. The UF-16 visual gate signs each district.

## Alternatives

### Grow each coastal map threefold on its own

One 40,000-60,000-cell location per area is two to three times the measured Lower Town, which already breaks the node and memory caps. Seamless crossing would stall. Rejected in favour of bounded maps.

### Keep CO-03's smaller footprints only

This gives about 2.1x (Kalamaja) and 1.7x (port) and leaves Pirita unchanged. It does not meet the request. CO-03's numbers survive as the first step of this ADR.

### Keep orthogonal streets

Simplest compiler and validator. It produces the grid feel the maintainer wants removed. Left to the maintainer as part of the ADR 0026 decision.

## Consequences

- R-976's target widens to all ten urban maps in later slices. Its first slice (Toompea, Archbishop's Garden) needs no new approval.
- R-950 is unblocked on approval but not on the scope removal. Its contract keeps 192 x 128 and 208 x 144 as step one.
- ADR 0027's connector budget assumptions (2,048 cells) are replaced for `kalamaja_hinterland` and `pirita_road`.
- Expect parity, semantic snapshot and visual fixtures to change map by map with written deltas. Seam continuity (UF-08) must stay green throughout.
- AGENTS.md scope is unchanged: these are existing areas made larger and more natural, not a new area.
