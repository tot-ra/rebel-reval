# R-929 Harbor East and Saaremaa crib visual review

**Review date:** 2026-09-26
**Task:** R-929 / R-921 follow-up (WS-13e)
**Parent:** R-921 / WS-13e saddle notches and stone fill
**Reviewer:** independent agent pass against the six R-921 plates
**Status:** **REJECT** - do not close WS-13e visual acceptance. Do not restyle from the Compatibility under-water frames.

## Decision

Harbor East and Saaremaa cribs do **not** yet read as notched, stone-filled landings on the named packet.

Metal under-water frames show a stacked-log crib with guide piles on the rendered bed, so the massing is no longer "pipes dropped on bare sand". The WS-13e extras fail the named read:

1. **Cubic corner fill: revise.** Harbor East Metal puts a pale diamond / A of axis-aligned boxes in the front face. That reads as leftover cubes, not packed rubble inside the crib. Saaremaa Metal shows a cubic stub at the staggered tip, not an interior stone fill.
2. **Saddle notches: keep on Harbor East, revise on Saaremaa.** Harbor East Metal has a crossing corner that can pass as a U-saddle at a glance. Saaremaa Metal tip ends are truncated pipes of mixed length, not a cabin-corner notch.
3. **Compatibility under-water frames: invalid geometry evidence.** Both GL `under_horizontal` plates show only the water underside (flat sea plus a sky limb). The crib is not in frame. Same authored pose on Metal shows the landing. Hand that split to board R-932; do not restyle the builder from these two PNGs.
4. **GL overviews: keep.** Harbor East and Saaremaa top-down plates keep cribs under the waterline. Decks, beaches, and water silhouette stay readable. This only proves the WS-13d waterline budget, not the notch or rubble read.

## Per-plate

| Plate | Map | Renderer | What is visible | Result |
|---|---|---|---|---|
| [`ws13e_harbor_east_under_horizontal_metal.png`](images/ws13e_harbor_east_under_horizontal_metal.png) | Harbor East (`reval_harbor_east`) | Metal | Stacked logs, guide piles, sandy bed. Front face has a diamond / A of cubes. Left corner crossing is the only saddle candidate. | **PARTIAL** - crib massing pass; cubic fill revise |
| [`ws13e_harbor_east_under_horizontal_gl.png`](images/ws13e_harbor_east_under_horizontal_gl.png) | Harbor East | Compatibility | Water underside only. No crib, piles, or bed. | **INVALID** - not a crib plate |
| [`ws13e_saaremaa_under_horizontal_metal.png`](images/ws13e_saaremaa_under_horizontal_metal.png) | Saaremaa (`world.saaremaa`) | Metal | Long log wall and piles. Right tip is staggered truncated pipes plus a cubic stub. Interior rubble not readable. | **FAIL** - still pipe ends, not a notched stone-filled landing |
| [`ws13e_saaremaa_under_horizontal_gl.png`](images/ws13e_saaremaa_under_horizontal_gl.png) | Saaremaa | Compatibility | Water underside only. | **INVALID** - not a crib plate |
| [`ws13e_harbor_east_overview_gl.png`](images/ws13e_harbor_east_overview_gl.png) | Harbor East | Compatibility | Three timber landings stay under the water sheet. No crib punch-through. | **PASS** waterline budget |
| [`ws13e_saaremaa_overview_gl.png`](images/ws13e_saaremaa_overview_gl.png) | Saaremaa | Compatibility | Ferry and strait decks stay under the water sheet. | **PASS** waterline budget |

## Explicit rejection checks

| Rejected form | Review result |
|---|---|
| Stacked pipes on bare sand | **No rejection on Metal massing.** Both Metal frames sit the crib on the basin bed with a log face and piles. |
| Cubic corner fill reads as boxes, not stone | **Reject.** Harbor East diamond / A and Saaremaa stub are boxes. |
| Tip is a round cap or truncated pipe, not a saddle | **Reject on Saaremaa.** Harbor East crossing corner may be kept as the notch reference. |
| Crib rises through the rest surface on overview | **No rejection.** Both GL overviews keep the WS-13d waterline budget. |
| Compatibility under-water plate used as a geometry fail | **No rejection of the builder from those frames.** They do not show the crib. |

## Cubic corner fill call

**Revise.** Keep the two MeshInstance child cap and the under-`CRIB_TOP_CLEARANCE` rule. Replace the regular box pile so a reviewer can read wet stone inside the crib on Harbor East and Saaremaa Metal `under_horizontal` frames. Do not treat the Compatibility pair as a before/after until R-932 (or a recapture that actually aims at the crib on GL) lands.

## Non-blocking notes

1. The Metal cribs are untextured dark cylinders. That is acceptable for this review; the fail is the corner read, not bark or algae.
2. Harbor East Metal still reads as a landing more than as a mound. That WS-13d goal holds on Metal.
3. File sizes are non-empty (under-water Metal ~289-388 KiB, GL ~316-289 KiB, overviews ~1.5 MiB). The GL under-water frames are not blank; they are aimed at the surface.

## Verification

R-929 allowlist is review-only. No Godot harness and no builder edit. Plate inventory (all present on 2026-09-26):

- `docs/reports/images/ws13e_harbor_east_under_horizontal_metal.png`
- `docs/reports/images/ws13e_harbor_east_under_horizontal_gl.png`
- `docs/reports/images/ws13e_saaremaa_under_horizontal_metal.png`
- `docs/reports/images/ws13e_saaremaa_under_horizontal_gl.png`
- `docs/reports/images/ws13e_harbor_east_overview_gl.png`
- `docs/reports/images/ws13e_saaremaa_overview_gl.png`

## Handoff

- R-929: move to done. Named review is this file.
- WS-13e / R-921: stay in review. Visual acceptance stays fail-closed.
- Follow-up (crib builder): revise cubic fill and the Saaremaa tip saddle so Metal `under_horizontal` frames read as notched stone-filled landings. Keep two MeshInstance children.
- Follow-up (renderer): Compatibility under-water crib invisibility is the same family as board R-932 (Compatibility shows more / different water bed than Metal). Recapture GL `under_horizontal` only after that split is understood, or with a pose that still shows the crib on Compatibility.
