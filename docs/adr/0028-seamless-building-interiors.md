# ADR 0028: Enter buildings without a loading transition (in-place interiors)

**Reference:** amends the interior rule of [ADR 0019](0019-seamless-contiguous-location-streaming.md) ("building interiors ... retain explicit transitions") and the interior census in [`docs/SEAMLESS_STREAMING_PLAN.md`](../SEAMLESS_STREAMING_PLAN.md#membership-census). Works with [ADR 0027](0027-reval-hinterland-streaming-group.md), [ADR 0015](0015-default-third-person-camera.md) and [ADR 0011](0011-optional-first-person-camera.md).

## Status

**Accepted (direction), Artjom Kurapov, 2026-10-07.** Maintainer request in session: seamless movement means large areas of Tallinn and the surroundings *and the ability to walk into buildings*. Distant locations such as Saaremaa keep a loading transition.

**Equivalent-cost scope removal: not chosen yet.** AGENTS.md requires a named removal for a scope change. The maintainer was asked on 2026-10-07 and did not pick one. Candidates are listed under [Scope cost](#scope-cost). Until the maintainer names one, only documentation and contract rows may land. **No interior-streaming code may merge**, the same rule ADR 0021 applies to its open removal.

Even after the removal is named, runtime stays behind `world_host/inplace_interiors_enabled` (default `false`) until the gates below pass. The door scene-swap path stays as the fallback for at least one save-version cycle.

**Amended by [ADR 0032](0032-bespoke-landmark-sites-in-the-city.md), 2026-10-07:** in-place
interiors for the **district maps** are removed from scope (they stay on the door scene-swap path).
Interiors in the seamless city are in place by construction (ADR 0031, ADR 0032 sites).

## Context

ADR 0019 kept every interior on an explicit door transition. Today `DoorNavigator` swaps the whole scene: the player leaves the street, the interior `.rrmap` loads as a new current scene, and the street is destroyed. The census in the streaming plan lists nine door interiors.

Every interior is larger than the building that contains it. Measured from `content/maps/*.rrmap` on 2026-10-07, in cells (~0.87 m):

| Interior map | Interior size | Exterior building (map) | Exterior footprint | Ratio (area) |
|---|---|---|---|---:|
| `kalev_smithy` | 26 x 14 | `kalev_smithy` (`lower_town_slice`) | 10 x 8 | 4.6 |
| `town_hall` | 40 x 24 | `town_hall_mass` (`market_civic_quarter`) | 24 x 14 | 2.9 |
| `holy_spirit_church` | 30 x 22 | `church_silhouette` (`market_civic_quarter`) | 14 x 10 | 4.7 |
| `st_olafs_guild_hall` | 32 x 20 | `guild_frontage` (`market_civic_quarter`) | 12 x 10 | 5.3 |
| `oleviste_church` | 36 x 24 | `st_olaf_silhouette` (`monastery_quarter`) | 22 x 14 | 2.8 |
| `nunnatorn_interior` | 18 x 18 | `monastery_wall_tower_northwest` | 8 x 8 | 5.1 |
| `kuldjala_interior` | 18 x 16 | `monastery_wall_tower_west_mid` | 8 x 8 | 4.5 |
| `rentenitorn_interior` | 18 x 18 | `merchant_wall_tower_northwest` (`north_quarter`) | 8 x 8 | 5.1 |
| `toompea_small_castle` | 32 x 24 | `castle_mass` (`toompea_quarter`) | 16 x 14 | 3.4 |

A door scene swap hides this "bigger on the inside" mismatch. A seamless entry cannot. The reference games (Kingdom Come: Deliverance II, Red Dead Redemption 2, The Witcher 3) place interiors physically inside the exterior shell, at the same world coordinates.

The 3D view already has the start of a cutaway: `MapViewRuntimeCameraSafety.update_occlusion_ghost()` ghosts the occluding building and pulls the camera out of walls (`scripts/map/view3d/map_view_runtime_camera_safety.gd`). The forge interior has its own view builder (`map_view_kalev_smithy_interior.gd`).

## Decision

### 1. In-place interiors

An enterable building's interior occupies the same global cells as its exterior footprint, inside the same world group as the street (`reval_outdoor` or `reval_hinterland`). Entering is walking through a physical doorway. There is no `change_scene_to_packed()`, no fade to black and no loading screen. The player, camera, clock, weather, HUD and session stay the ADR 0019 host globals.

- An interior keeps its own `.rrmap` and stable map ID. It becomes a **building sub-package** owned by the outdoor location that holds the building, bound by the exterior `building_id` (for example `kalev_smithy`, `town_hall_mass`). It is not a seam and not a group member.
- Interior bounds plus wall thickness must fit inside the exterior footprint. Upper floors fit inside the building height; cellars may go below ground (Reval cellars are attested, H04).
- Doors are physical: an opening with collision and an open/close state. One navigation graph connects street and interior through the doorway, so NPCs can walk in and out.
- Not every building must be enterable. A building is enterable only when it has an interior sub-package. Others keep closed or locked doors.

### 2. Streaming

- An interior sub-package is prefetched when the player is inside a door band of its entrance (starting value 12 cells; derive it from measured mount time, as R-1072 does for seams). It is mounted under the shared 4 ms per-frame budget and evicted with hysteresis.
- Interior nodes, collision shapes and memory count against the same ADR 0019 residency caps (7,500 nodes, 900 shapes, 280 MiB).
- Outside the band the building shows only its exterior shell. Interior detail never pops in while the camera can see it.

### 3. Camera and presentation

- When the player is inside, the third-person camera (ADR 0015) cuts away the roof, upper floors above the player's level and the camera-side walls. This extends the existing occlusion ghost. First-person mode (ADR 0011), if kept, needs no cutaway.
- Interior light comes from an interior ambient zone that blends with the outdoor sun and sky. The environment never resets. Rain stops at the roof line. Audio crossfades to an interior reverb zone.

### 4. Saves and identity

- Object identity stays `{location_id, object_id}`, with the interior map ID as `location_id`.
- Player position stays a global cell or sub-cell plus a floor index. Chunk coordinates, node paths and instance IDs are never persisted.
- A save made inside a building restores inside it with or without the flag; with the flag off, the door path places the player at the interior spawn.

### 5. Reconciling sizes, one building at a time

Each of the nine interiors migrates only after its size is reconciled. Choose per building, and keep the 1343 evidence:

- **Shrink the interior** to the footprint. The towers (8 x 8 cells, about 7 m) and the forge are the likely candidates.
- **Grow the exterior** where history allows. The 1343 Town Hall is a ~22-28 m hall ([Raekoja plats dossier](../../history/dossiers/topography/raekoja-plats-extents-1343.md)), so `town_hall_mass` may grow toward ~26-32 cells. Church exteriors should match their 1343 mass (H14, H31).
- Interior gameplay anchors and stable IDs survive the resize. Parity and visual checks must pass per building. Fixtures are not regenerated just to get green.

Until a building migrates it keeps its door transition. Migration order: `kalev_smithy` first (the hub on the playable route), then `town_hall`, then the rest.

### 6. What keeps a loading transition

- Distant travel: `world.saaremaa`, `world.padise`, `world.paide`, `world.parnu`, `world.poide`, `world.kanavere`, `world.sacred_grove`, `world.rebel_kings` (ADR 0027).
- Any interior on an explicit allowlist that cannot fit its building, with a written reason per entry. Scripted cutscene teleports are allowed as well.

## Scope cost

This is a new major system (interior residency, cutaway camera, nine migrations), estimated at **60-80 hours** plus per-building art work. Candidate removals offered to the maintainer on 2026-10-07, none selected:

1. Retire the optional first-person camera (ADR 0011 / ADR 0012). One camera mode makes the cutaway and the interior framing simpler.
2. Drop `world.kanavere` and `world.rebel_kings` as separate playable maps; keep their events as travel scenes.
3. Defer swimming and diving (ADR 0021, R-910, ~40 h) past Act 1.

The maintainer may name a different removal. The chosen item and its date are recorded in this Status section before any interior code merges.

## Alternatives

### Keep door scene swaps (ADR 0019 status quo)

Cheapest and already working. It does not meet the request to walk into buildings without loading. It stays as the fallback path.

### Pocket interiors streamed in the same host

The interior is mounted off-map in the same WorldHost and the player is moved there behind a short fade. This hides loading but still breaks continuity: no view through doors or windows, NPCs cannot follow, and the fade remains. It is rejected as the target but allowed for allowlisted exceptions.

### Non-Euclidean "bigger on the inside" portals

Rendering a larger interior behind the door through a portal would keep the current interior sizes. It breaks navigation, sight lines, physics and global-cell save coordinates. Rejected.

## Acceptance gates (flag flip)

- No `change_scene_to_packed()` and no fade when entering or leaving a migrated building, in both directions, after repeated entries.
- The same player, camera, clock and weather instances survive. Position stays continuous within 0.01 logic units.
- Main-thread interior mount work stays at or below 4 ms per frame. Frame p95 stays at or below 16.67 ms and p99 at or below 25 ms while entering. Residency stays inside the ADR 0019 caps with an interior mounted.
- No roof pop, missing wall or lighting reset is visible from the street or from inside (captured plates for day and night).
- Keyboard, mouse and gamepad entry work, and click navigation crosses a doorway.
- A save inside a building restores inside it. A save mid-mount restores without duplicates.
- At least one NPC walks in and out through a door on its schedule.

## Consequences

- The interior section of the streaming-plan census changes from "explicit door transitions" to "in-place target, door until migrated". All nine maps stay assigned.
- Map authoring gains a constraint: interior bounds fit their exterior footprint. `docs/MAP_AUTHORING.md` adds it when the first migration task lands.
- New rows are needed (none claimable until the removal is named): interior sub-package residency in WorldHost, cutaway camera, and one migration row per interior starting with `kalev_smithy`.
- AGENTS.md and README scope lines are updated: walking into buildings is in scope, gated by this ADR.
