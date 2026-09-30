# ADR 0026: Streets are an authored network

## Status

**Proposed, 2026-09-30. Awaiting maintainer acceptance.** Task: UF-01 / R-1110.
This is a documentation-only proposal, not authorization to implement UF-03 / R-1112.
Named WB-09 / R-981 owner agreement to the scope exchange below and named, ISO-dated
maintainer scope approval are both outstanding. No acceptance is inferred from publishing,
merging, or reviewing this document. UF-03 stays blocked until those decisions are recorded.

## Context

The current `.rrmap` dispatcher has 32 statement kinds plus the `rrmap` version header;
23 kinds occur in the 29 legacy map files. Neither vocabulary includes a street. The six
relief commands, `grade`, `package`, `prefab` and `override` remain supported even where
that authored-file census does not list them. `lower_town_slice` has 97 building rows
and 63 style rows. Terrain rectangles and strokes describe coverage, not the identity,
width continuity, endpoints or frontage of a lane. Houses placed independently can form
a matrix without a continuous route, and no semantic validator can explain that failure.

WB-09 / R-981 proposes plots with frontage, depth and a street reference. Independent
plot/street geometry there would compete with UF-03. [ADR 0009](0009-map-blueprint-authoring-architecture.md)
requires one typed blueprint compiler, one definition and one canonical fingerprint.
Street existence, trace and width in 1343 remain historical claims owned by UF-02 / R-1111;
this representation does not make any particular placement attested.

## Decision

The following rules are proposed together. They become normative only on acceptance.

### 1. Authored primitive and units

Add an ID-first typed `street` primitive to `MapBlueprint`, represented in `.rrmap` by a
stable ID, an ordered trace of integer cell coordinates, an integer width at each trace
vertex, an existing terrain surface ID, and a class. A constant width is shorthand for
repeating that width at every vertex. UF-03 fixes the concrete token syntax and tests its
canonical round trip; it must not invent another geometry interpretation.

Classes are `spine`, `lane`, `alley`, `ramp`, `square_edge` and `extramural_road`. The last
is the same primitive for UF-15 hinterland roads, not a second road language. Class names
express intended connectivity, not proof of historical status. Width is **1..16 cells**
(approximately **0.87..13.92 m**, at 0.87 m/cell). Wider open spaces are authored square
terrain, not a street silently widened beyond that bound. Each trace has at least two
distinct vertices, no zero-length segments and only horizontal or vertical segments.
Stepped orthogonal segments represent angled routes; curves are not introduced.

The trace is an edge-aligned reference line, **not a symmetric geometric centreline**:
like `stroke`, a horizontal run grows in +y and a vertical run grows in +x, regardless
of travel direction. For a constant width w, inclusive segment endpoints lower to
`Rect2i(min(x0,x1), y0, abs(x1-x0)+1, w)` or
`Rect2i(x0, min(y0,y1), w, abs(y1-y0)+1)`. Turning segments use their footprint union;
a cell covered twice by the same street is emitted once. This preserves stroke's
edge-grown thickness rather than displacing an even-width lane by half a cell.

For a variable-width segment, sample each reference-line cell in authored travel order.
Interpolate its endpoint widths by Manhattan distance, then round positive values with
`floor(value + 0.5)`. Grow that sampled cross-section in the same +x/+y direction.
Width may change by at most **1 cell per 4 cells** of trace: for a segment of length L,
`abs(w1-w0) * 4 <= L`. Constant-width segments meet this rule at any positive length.

IDs share the blueprint's existing uniqueness validation; no coordinates, list indices,
chunk coordinates or generated node paths become identity. Canonical streets sort by
stable ID. Vertex order is preserved because travel direction defines frontage offset.
Width profiles and surfaces participate in the semantic record. Geometry emission follows
the existing terrain layer/order mechanism with stable street ID as its final tie-break;
new street surfaces have explicit authored precedence and do not rely on filesystem order.

### 2. Compiled authority and compatibility

Compile to a typed `StreetNetwork` on `MapDefinition.street_network`. Its immutable
records carry the stable ID, trace, sampled widths, surface, class and resolved connections.
The network is part of the canonical fingerprint **only when non-empty**. Street terrain
coverage is lowered through the existing terrain primitives, not a second renderer,
navigation graph or mutable city-state store. Both gameplay and view consume the same
compiled definition. Chunking is disposable output and does not partition street identity.

`stroke`, `terrain_rects`, legacy building origins, relief and every existing statement
retain their meanings. For all 29 legacy maps authoring no street, the fingerprint,
canonical serialized bytes and walkability must remain bit-identical. Omit the empty
network from the legacy fingerprint payload; do not insert an empty field or change a
compiler-version salt on that path. UF-03 must prove this against committed fixtures,
not regenerate them to make the gate green. Streets are additive opt-in authoring, not
an automatic migration or authorization to activate a map.

### 3. Connections, overlaps and diagnostics

Two street footprints connect when they share a cell or have a 4-neighbour boundary
contact; diagonal contact does not connect them. An endpoint connects when its terminal
cross-section shares a cell or has a 4-neighbour contact with another street or an
explicitly identified gate, square or physical transition footprint. A nearby label,
building origin or arbitrary terrain cell is not a destination. UF-03 resolves typed
stable destination IDs from authored semantics; it must not infer squares from paving
colour or treat logical teleports as physical street exits.

Different street surfaces may meet at a 4-neighbour boundary. Intersections sharing
cells require equal surface IDs; incompatible surfaces are rejected, not selected by
last-write wins. Same-surface crossing or endpoint junctions are allowed. Parallel
shared-cell runs longer than **2 cells** are duplicate/ambiguous street geometry and
rejected even with equal surfaces. A valid perpendicular junction is exempt from that
parallel-run rule. Full-width joins require a sampled-width difference of at most
**1 cell**; a narrower alley ending against the side of a spine is a branch, not a
width continuation. Endpoint gaps have **zero empty-cell tolerance**.

Reserve these stable `MapBlueprintDiagnostic.code` values:

| Code | Severity and rule |
|---|---|
| `MAP_STREET_ORPHAN` | Error: the street has no connection to another street, gate, square or physical transition. Check every record; also reject an entire connected component with no gate/square/physical-transition destination. |
| `MAP_STREET_WIDTH_JUMP` | Error: a segment violates `abs(w1-w0)*4 <= L`, or a full-width continuation differs by more than 1 cell. |
| `MAP_STREET_DEAD_END` | Error for `spine`, `lane`, `ramp`, `square_edge` and `extramural_road` if either endpoint has no connection. Warning for `alley` if exactly one endpoint is unconnected; review must explicitly accept that authored cul-de-sac. For `alley`, two unconnected endpoints produce a `MAP_STREET_DEAD_END` error. Endpoint count alone does not trigger `MAP_STREET_ORPHAN`; that code follows the record/component connectivity rules above. |
| `MAP_STREET_OVERLAP` | Error for incompatible-surface shared cells, non-junction parallel overlap longer than 2 cells, or street coverage intruding into blocking building/wall footprints outside an explicitly authored gate opening. |

Malformed traces, missing references, out-of-bounds coverage, invalid class/surface,
width outside 1..16, and duplicate IDs remain errors using existing primitive/source
validation conventions. UF-03 records any additional diagnostic codes as stable API.
Warnings are reviewed, never silently suppressed. The default maximum width is a
validation limit, not permission to assert that a 1343 lane was 13.92 m wide.

### 4. Frontage and ownership

Buildings may bind `street=<id> side=<n|s|e|w> offset=<cells>`. Offset is a non-negative
integer Manhattan distance from the trace's first vertex, bounded by its total length;
an interior vertex belongs to its outgoing segment, and the last vertex to its incoming
segment. Side is a cardinal outward direction from that local edge-aligned street
footprint (n = -y, s = +y, e = +x, w = -x). Horizontal segments allow n/s and vertical
segments e/w; a mismatch is an error, not an implicit rotation. Seating uses the actual
width-bearing footprint edge, not an assumed centred line.

UF-03 parses and resolves references but does not reposition buildings. UF-04 / R-1113
owns frontage seating, corner/block subdivision and the anti-grid gate, including
rejecting conflicts between explicit placement and derived frontage. No building IDs
are renamed when that binding is later applied. WB-13 / R-985 owns plot contents and
prefab-local identities; AR-13 / R-971 owns appearance repetition. Relief, sea level,
streaming, navigation costs, traffic and procedural quest systems stay out of this ADR.

### 5. Equivalent-cost scope exchange with WB-09 / R-981

**Remove WB-09's independent free-form plot/street geometry layer**: its own trace,
width, edge-offset and frontage-geometry vocabulary, geometry parser/serializer rules,
geometry validation, geometry lowering and the duplicate geometry test matrix. UF-03
owns street trace/width/surface compilation; UF-04 owns frontage seating. WB-09 plot
statements consume those street IDs and resolved geometry instead of redefining them.
They still specify plot depth, wealth, age, upkeep and authorial descriptions, and
lower through reviewed prefabs with unchanged stable-ID rules.

This is not a zero-cost rename. The exchanged work consists of one independent
geometry vocabulary and its parser/serializer round-trip, compiler, boundary/overlap
validation and determinism/negative fixtures on each side. The street proposal adds
endpoint connectivity and typed network records; retiring independent WB-09 frontage
lowering and tests funds that addition. WB-09 retains style presets, descriptions,
summary headers and semantic prefab lowering, so it is **not** removed wholesale.
If the named WB-09 owner or maintainer finds that exchange unequal, revise or remove
scope before acceptance; do not implement both and promise later consolidation.

WB-09's geometry-consuming implementation depends on UF-03 and UF-04 acceptance;
its ADR 0024 may still be drafted independently. Its existing R-982 and R-974 gates
remain. Owner agreement: **pending named WB-09 review**. Scope approval and ADR
acceptance: **pending named maintainer decision with ISO date**.

## Alternatives

- **Infer streets from terrain gaps:** rejected; coverage cannot identify destinations,
  intended continuity, a historically named route or frontage relationships.
- **Put independent geometry inside WB-09 plots:** rejected; duplicates trace, width,
  validation and lowering and allows neighbouring plots to disagree on the same lane.
- **Centred or curved streets and a new navigation-cost graph:** deferred; neither is
  needed for this orthogonal authoring contract and both expand the exchanged scope.
- **Keep absolute placement only:** valid for legacy maps and explicit exceptions, but
  insufficient as the only production authoring model. No automatic migration follows.

## Consequences

Authors can name and inspect a continuous route before lining it with buildings.
The compiler can diagnose breaks and ambiguity without treating generated scene nodes
as authored state. Orthogonal stepping and bounded widths deliberately constrain the
vocabulary; deliberate cul-de-sacs remain reviewable rather than invisible exceptions.

Implementation order after acceptance: UF-02 supplies historical confidence; UF-03
proves network compilation, round trips, negative cases and 29-map no-street parity;
UF-04 adds frontage/block tests; WB-09 consumes their geometry; map reauthoring stays
with UF-05..07 and activation with each map's existing task. No runtime, parser, test,
map or asset implementation is included in R-1110.

Independent technical review is required before the named human decision. Validation
includes the [MAP_AUTHORING](../MAP_AUTHORING.md) pre-commit gate and active-doc links.
Reviewing or merging a **Proposed** ADR does not satisfy the human acceptance gate.
