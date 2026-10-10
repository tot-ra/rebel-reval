# ADR 0042: Regional site plans

**Reference:** maintainer request 2026-10-09 (session): rebuild the distant regions of the
global map (Paide, Saaremaa/Pöide, Padise, Pärnu, Kanavere, Sõjamäe, the Harju village,
the rebel kings' camp and the sacred grove) with the same data-driven pipeline as the
seamless Reval city.

Builds on [ADR 0031](0031-continuous-reval-city-plan.md) (Reval as one georeferenced plan)
and [`docs/SYSTEMS/SEAMLESS_CITY.md`](../SYSTEMS/SEAMLESS_CITY.md). Amends
[ADR 0027](0027-reval-hinterland-streaming-group.md) for `world.harju` and `world.sojamae`
and replaces the MapBlueprint route of the regional-maps pack (R-1336). Does not change the
AGENTS.md scope rule that distant regions keep an explicit journey with a loading transition.

## Status

**Accepted (maintainer-approved, 2026-10-10).** Tasks R-1520..R-1530 are unblocked; the
Paide pilot (R-1520) lands first. Nothing here is runtime truth until a task verifies it.

## Context

- Every destination outside Reval is a small greybox: `content/maps/world_*.rrmap`
  (50-64 x 28-36 cells of 32 px, `scope=prototype active=false`) mounted by the 2D host
  `scenes/world_travel/distant_location_level.gd`. Except Padise and Saaremaa they are
  1.5-4 KB sketches. They have no relief, sky, weather, water, vegetation or birds of the
  quality the city now has, so arriving from Reval is a visible drop.
- Reval has a working pipeline: `tools/city/build_reval_city_plan.py` merges a trimmed OSM
  extract, EU-DEM samples and a hand-authored 1343 overlay into
  `content/world/reval_city/{plan.json,height.json,splat.png,roads.png,minimap.png}`;
  `scenes/world/reval_city/reval_city.tscn` renders it with the shared sky, sun, moon and
  stars, clouds and weather, one wind, FFT sea and shore field, vegetation, birds,
  swimming and citizens. The builder hard-codes Reval (output dir, origin
  59.43725 N 24.74535 E, 1580 x 1580 m frame, coast).
- The open regional-maps pack (R-1336, RG-1..RG-5: R-1339..R-1343) plans these regions as
  full-scale MapBlueprint grid maps. ADR 0031 already found that route does not scale for
  terrain, angled buildings or performance, and dropped it for Reval.
- ADR 0027 planned to stream `world.harju` and `world.sojamae` as a `reval_hinterland`
  group on the grid (R-1133, R-1213, R-1216). Those grid connectors were built for the
  district maps that ADR 0031 retired.
- Existing gameplay hooks on these places: `scripts/world/padise_monastery_controller.gd`
  reads anchors from `world_padise.rrmap`; the Act 3 package
  `content/packages/act3_poide_siege` refers to the location `world_poide`; the travel
  graph (`content/transitions/active_destinations.json`, `scripts/ui/global_map_catalog.gd`,
  `scripts/city/city_travel.gd`) refers to location ids and their arrival spawn ids (`from_reval_*`, `from_world_*`).

## Decision

### 1. One builder, one plan directory per site

- The builder becomes site-parameterised: `tools/city/build_site_plan.py --site <site_id>
  [--check]`. Shared code (DEM sampling, splat, roads, footprints, overlay merge, minimap)
  moves there; `tools/city/build_reval_city_plan.py` stays as a thin wrapper with the same
  CLI so every existing command, test and hook keeps working.
- Each regional site has its own overlay `tools/city/sites/<site_id>_1343_overlay.json`,
  its own trimmed inputs `tools/city/data/osm_<site_id>_extract.json` and
  `tools/city/data/eudem25m_<site_id>.json`, and its own output directory
  `content/world/<site_id>/` with the same five files as Reval.
- Site parameters live in a `site` block at the head of the overlay: frame size, origin
  latitude and longitude, coast flag (computed, see section 3), feature flags (citizens,
  fauna), arrival spawns. Reval keeps its overlay at `tools/city/reval_1343_overlay.json`
  and its constants.
- **Reval stays byte-identical.** `python3 tools/city/build_reval_city_plan.py --check`
  must pass with no diff after the refactor; this is the refactor's acceptance gate.
- **Naming.** A "regional site" here is a whole travel destination. It is not an
  ADR 0032 landmark site (`site.raekoja_plats` under `content/world/reval_city/sites/`).
  Regional site ids are bare snake_case (`paide`), never `site.*`.

### 2. Size and frame per site

Reval is 1580 x 1580 m. A regional site is the castle, monastery or place plus its
immediate surroundings, 400-900 m per side. Frame centres below are approximate and are
fixed, with a confidence label in `docs/CANON.md`, by the site's task.

| site_id | Location id | Place | Frame | Centre (approx.) | Water | Task |
|---|---|---|---|---|---|---|
| `paide` | `world_paide` | Order castle on its hill, ditch, castle village, fields | 600 m | 58.885 N, 25.560 E | brook | R-1520 (pilot) |
| `parnu` | `world_parnu` | New Pernau, Order castle, river mouth, bay shore | 900 m | 58.384 N, 24.497 E | **sea** + river | R-1521 |
| `padise` | `world_padise` | Cistercian estate before the quadrangle, Kloostri river, mill pond | 800 m | 59.229 N, 24.137 E | stream, pond | R-1522 |
| `poide` | `world_poide` | Order convent house of Ösel, church, village | 700 m | 58.50 N, 23.00 E | sea only if inside the frame | R-1523 |
| `saaremaa` | `world_saaremaa` | Kaali crater, crater lake, village | 500 m | 58.373 N, 22.669 E | lake | R-1524 |
| `kanavere` | `world_kanavere` | raised bog battlefield | 600 m | chosen in task | bog pools | R-1525 |
| `sojamae` | `world_sojamae` | hill on the limestone plateau east of Reval | 600 m | 59.42 N, 24.85 E | none | R-1526 |
| `harju` | `world_harju` | cluster village, strip fields, pasture | 700 m | representative point | brook | R-1527 |
| `rebel_kings` | `world_rebel_kings` | the four kings' camp in a forest clearing | 500 m | representative point | stream | R-1528 |
| `sacred_grove` | `world_sacred_grove` | hiis on a rise, offering stones, spring | 500 m | representative point | spring | R-1529 |

- **Saaremaa is Kaali.** The old `world_saaremaa` greybox put the north-coast ferry beach
  and the Kaali crater on one map; they are about 18 km apart and cannot share a 900 m
  frame. The site is Kaali; the crossing to the island is the journey.
- **Composite sites** (`harju`, `rebel_kings`, `sacred_grove`, and `kanavere` if the
  battlefield cannot be placed) take DEM and land cover from one representative point
  named in the overlay with a confidence label. Everything built comes from the overlay.
- **History overrides geography, more strongly than in Reval.** Reval's modern street plan
  survives from the Middle Ages; a village, camp or bog does not. At regional sites OSM
  supplies terrain-adjacent data only (coastline, water, wetland, forest and field cover)
  unless the overlay explicitly keeps a feature. Modern buildings and roads are excluded by
  default; 1343 buildings, roads and fields are overlay records with confidence labels.

### 3. Shared systems

Every site runs on the same runtime as Reval (`scripts/city/*`), which takes the plan
directory, origin and flags from the plan instead of constants, and gets:

- sky, sun, moon and stars, with the sun and moon positioned from the **site's own
  latitude and longitude** (Pöide and Kaali sit about 1° of latitude south and 2° of
  longitude west of Reval);
- clouds and weather (`SkyWeather3D`), the one world wind, rain wetness and puddles;
- terrain relief, ground splat, road wear and prints;
- vegetation, grass, trees and farmland; birds with a per-position habitat;
- swimming in any water body deep enough (rivers, ponds, crater lake, sea).

**Sea and shore field only where there is coast.** The builder sets the coast flag when the
1343 shoreline (with the same post-glacial uplift correction as Reval) crosses the frame.
By current geography that is Pärnu only: Padise's frame ends well short of Pakri bay, and
Pöide's frame is expected to be inland (its task confirms it). Inland sites get no FFT sea,
no shore field and no surf.

People and animals (`citizens.json`, fauna) are off by default; a site gets them only
through a later task. Bespoke landmark assets (ADR 0032, AR-08 R-966) can replace plan
footprints later without changing the plan's ids.

### 4. Arrival and return

- The global travel map is unchanged: choosing a destination starts a journey with a
  loading transition that loads the site scene `scenes/world/sites/<site_id>.tscn`
  (shared level script `scenes/world/sites/site_level.gd`). Only the `path` of the
  location in `content/transitions/active_destinations.json` changes; location ids and
  their spawn ids (`from_reval_*`, `from_world_*`) stay, and each becomes an arrival spawn
  in the plan.
- Walking within the edge band of the frame opens the global travel map and sets the
  player back inside, as in Reval. Leaving a site always means choosing a destination.
- Returns to Reval keep their current gates and roads in `CityTravel`.
- **No seamless link between sites, or between a site and Reval.** Sõjamäe and Harju are
  loaded sites, not streamed hinterland (amends ADR 0027, see Consequences).

### 5. Stable IDs

- Location, map and spawn ids stay as they are (`world_paide`, `world.paide`,
  `from_world_sojamae`, `from_reval_west`, ...), so saves, the travel graph and quest packages keep working.
- Every new record id in a site plan is prefixed with the site id:
  `<site_id>.<kind>.<name>`, for example `paide.tower.main`, `paide.gate.north`,
  `paide.spawn.from_world_sojamae`, `padise.poi.chapter_house`. Kinds follow the Reval
  plan's record kinds.
- Anchors that existing hooks read keep their current ids: the Padise monastery
  controller's anchors move into `padise` plan points of interest under the same ids.
- Ids are never derived from OSM ids or array order; regenerating a plan must not rename
  them (as in [MAP_AUTHORING.md](../MAP_AUTHORING.md)).

### 6. Out of scope

- Quests, dialogue, NPC schedules, battles or siege gameplay inside the site scenes beyond
  the hooks that already exist (Padise monastery controller, the Pöide siege package by
  location id).
- Any seamless connection between sites or to Reval; an Estonia-wide world.
- Interiors beyond what the shared building builder already gives an enterable footprint.
- New towns or regions not on the list above.

### Equivalent-cost scope removal

Retired rather than delivered:

- The ten greybox prototypes `content/maps/world_{paide,poide,saaremaa,padise,parnu,
  kanavere,sojamae,harju,rebel_kings,sacred_grove}.rrmap`, their `scenes/world_travel/`
  scenes, the `distant_location_level.gd` host, their entries in
  `distant_location_definitions.gd`, the blueprint registry, map catalog and audit
  manifest, and any MapBlueprint migration and parity work for them. Each site task
  retires its own greybox; R-1530 removes the host.
- The regional-maps pack as MapBlueprint grid maps: R-1336 (RG-0) and RG-1..RG-5
  (R-1339..R-1343) are closed as superseded once their sites land.
- The `reval_hinterland` grid connectors for Harju and Sõjamäe from ADR 0027: R-1216
  (UF-15c) and the Harju parts of R-1133 (UF-15) and R-1213 (UF-15a) are re-scoped or
  cancelled by R-1526 and R-1527.

## Alternatives

- **Grow the greyboxes with MapBlueprint (the RG pack).** Same limits ADR 0031 measured
  for Reval: per-cell terrain and validation cost, no rotated buildings, no shared sky and
  water stack without re-plumbing; and a second authoring pipeline to keep alive.
- **Put the regions into the Reval plan or stream them.** Contradicts the AGENTS.md scope
  (explicit journeys for distant regions) and the size budget; Pärnu is over 100 km away.
- **One scene per site without the shared builder.** Faster for one site, but every site
  would fork the sky, water, wind and terrain code that the city keeps improving.

## Consequences

- One pipeline and one runtime for every outdoor place; improvements to sky, water, wind
  and ground reach every site.
- The builder refactor touches the most-used city tool; the byte-identical Reval check is
  the guard, and the pilot (Paide, R-1520) must land before any other site starts.
- OSM data stays ODbL with attribution per site in `docs/THIRD_PARTY_NOTICES.md` and
  `CREDITS.md`; EU-DEM needs attribution only.
- ADR 0027 is amended: `world.harju` and `world.sojamae` stay explicit travel and become
  loaded regional sites; the remaining `reval_hinterland` connectors (Kalamaja, Pirita,
  Viru approach) are unaffected by this ADR.
- Feature documentation lives in a new `docs/SYSTEMS/REGIONAL_SITES.md` (created by
  R-1520, extended by each site task).
- Verification per site: `python3 tools/city/build_site_plan.py --site <site_id> --check`,
  `python3 tools/city/build_reval_city_plan.py --check`, the Godot test suite, and captures
  of arrival, day and weather, and edge-to-travel-map in `docs/reports/images/sites/`.
