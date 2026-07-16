# ADR 0007: AI-generated painted isometric presentation

**Reference:** TODO P0-040 rework, P0-051 through P0-053, P0-037 rework
**Recorded:** 2026-07-16
**Supersedes:** ADR 0004 (clean-painted candidate). **Amends:** ADR 0002 (presentation and direction-count rules).

## Status

Accepted

## Context

The pre-scope-cut prototype (`img/Screenshot 2025-08-26 at 16.42.48.png`, still the README hero image) was an AI-generated painted isometric scene: timber-framed buildings with visible facades and roof mass, textured terrain, a readable well and work props, dense Fallout/Stoneshard-like mood. That image is the product vision players were shown.

The scope-reduction chain then degraded the visible game in two steps:

1. **ADR 0002** replaced diamond-isometric physics with an orthogonal gameplay plane. Its stated intent explicitly preserved the look — "the art may look isometric" — and that intent was correct: flat-plane physics, four-way navigation, and simple Y-sort are real wins and none of them require flat art.
2. **ADR 0004** chose a "clean-painted" style whose only existing implementation is programmatic flat-color rendering: `map_visual_style.gd` maps every terrain and role to a single `Color`, and the terrain/building/prop renderers draw untextured rectangles and polygons. The result on screen is a top-down colored-rectangle diagram, not a three-quarter painted town. The "art may look isometric" promise from ADR 0002 was silently dropped — no facade, no roof mass, no texture, no light.

Meanwhile the project's actual strategic asset-production bet is AI generation: maps are already LLM-authorable declarative definitions (`scripts/map/definitions/`, contract-tested, deterministic fingerprints), the prototype art and music were AI-generated, and there is no artist on the team. The 2026 pipeline reality is that image models produce coherent painted isometric scenes and sprites cheaply, and the historical Fallout production method (pre-rendered 3D to fixed-camera sprites) is now automatable end to end. The cost argument that justified cutting directions and texture no longer holds.

## Decision

Adopt an **AI-generated painted isometric presentation** on top of the existing orthogonal logic layer. "Fallout-looking" is the reference bar: fixed dimetric camera, pre-rendered painted assets, gritty readable town.

1. **Logic layer is kept unchanged.** Declarative map definitions, anchors, footprints, collision, navigation, activation guards, and fingerprints remain the single source of truth. Physics and pathfinding stay on the flat orthogonal plane (ADR 0002 core, reaffirmed). All existing map contracts and tests remain valid; this decision changes rendering only.
2. **Presentation becomes true 2:1 dimetric isometric.** A deterministic projection maps logic cells to screen diamonds (one 32 px logic cell → one 64 x 32 px screen diamond; exact constants frozen in ART_BIBLE v2). Terrain renders from AI-generated isometric ground tiles or baked ground plates; buildings and props render as pre-composed AI-generated isometric sprites anchored at their definition ground pivots; Y-sort continues to use definition anchors.
3. **Assets are AI-generated under a style-lock kit.** A frozen generation spec — camera (2:1 dimetric, light from north-west), palette (carried from the current ART_BIBLE material families), texture-density and outline rules, prompt block, and reference image set — is the contract every generated asset must satisfy. Acceptance is by asset lint (dimensions, pivot, alpha bounds) plus rubric review, and every asset gets a SOURCES.csv provenance row.
4. **Characters use a prerender pipeline, not a cutout rig.** Concept via image model → 3D model (AI mesh generation or manual low-poly) → fixed ortho camera rig renders direction sets and animations to sprite sheets. This is the Fallout method with the manual labor automated.
5. **The four-direction cap from ADR 0002 is lifted for prerendered characters.** Direction count becomes a render-farm setting, not an art budget. Target is 8 directions; 4 remains an acceptable fallback if the spike shows quality problems.
6. **Day/night remains one day master plus a deterministic grade** (shader or modulate), preserving the ART_BIBLE night rules. No per-phase asset regeneration.

### Map-art modes

Two production modes are permitted and the P0-040 gate picks the slice default:

- **Modular kit** (default candidate): iso ground tiles plus modular building/prop sprites assembled by the existing definitions. Best reuse, supports phase states and day/night grading directly.
- **Baked plate**: one AI-generated background plate per map with the definition supplying walkmask, collision, and anchors; props still overlay as sprites. Fastest route to the Fallout look for one-off event maps; harder for phase changes, so it is reserved for maps without state variation.

## Alternatives

- **Keep clean-painted flat rendering (ADR 0004).** Rejected. The on-screen result reads as a placeholder diagram; it fails the product's own value-hierarchy goals (building identity tier has no identity) and contradicts the published vision image.
- **Return to diamond-isometric physics.** Rejected. The orthogonal logic plane is proven, tested, and invisible to players; reprojecting collision onto a skewed grid buys nothing visual.
- **Hand-authored pixel/painted tileset.** Rejected for capacity reasons: no artist, and AI models are poor at seamless micro-tilesets but strong at coherent iso sprites and plates — the pipeline should play to that strength.
- **Full 3D.** Rejected. Engine, tests, and scope are 2D; 3D re-opens every solved problem for an aesthetic that pre-rendered sprites deliver anyway.

## Consequences

- ADR 0004 is superseded; the clean-painted flat-color profiles in `map_visual_style.gd` become comparison evidence and are replaced by the iso presentation layer (P0-052).
- `docs/ART_BIBLE.md` scale, pivot, value-hierarchy, shadow, and night-grade rules carry forward; its "clean-painted candidate" section is superseded pending ART_BIBLE v2 with the style-lock kit (P0-051).
- P0-037 is reframed from cutout rig to the prerendered character pipeline; P0-038/P0-039 measure and readability-test the iso candidate; P0-040 remains the human decision gate.
- Existing map definitions, catalogs, activation guards, prototypes, and their tests continue to pass unmodified; renderer swap must not change any fingerprint.
- Risk: AI style drift across generation sessions. Mitigated by the style-lock kit, lint, and the two-session consistency check in P0-051's verify clause.
- Risk: model/tool churn. The kit records model, version, and full generation parameters per asset in SOURCES.csv so any asset can be regenerated or matched later.
