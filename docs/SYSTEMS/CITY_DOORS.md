# City doors: household wealth and landmark entrances

Status: implemented (tasks **R-1692**, **R-1693**).

Scope: procedural hinged leaves in the seamless city, ordinary housing and existing landmark sites (R-1692), and evidence-led masonry portals with leaves cut to their heads at eight landmark church entrances plus the council hall's rectangular apertures (R-1693, see [Landmark portals](#landmark-portals-r-1693)). This is a visual refinement of ADR 0031/0032, not a new interaction system. Locks, sound, saved door states, new areas and exact archaeological replicas are out of scope.

## Player-facing behaviour

Click an enterable city door with the left mouse button while Kalev is within 2.4 city units to swing it inward. Walking past or standing near a closed door does not open it. Once opened, the door stays clear while Kalev is inside the building/site and closes after he leaves; non-enterable houses stay shut. The click uses the active 3D camera view and requires the visible door leaf/aperture to be under the cursor. No gamepad door-selection path exists yet. Street and interior sides have different hardware. Double leaves show their decorated sides towards the street regardless of authored endpoint order.

Doors use the same `CityHouseWealth` census class mapping as [windows](./COTTAGE_WINDOWS.md): poor, master/middling, merchant/great/rich. Census classification wins over wall material; a poor household in a stone building does not automatically receive an expensive door. Without a census entry, the existing fabric/area/stable-ID fallback applies. Outbuildings always use rough boarding, wood ledges and a wooden latch.

| Role | Construction |
|---|---|
| Poor house | Bare ledged/plank boarding, modest straps and small ring |
| Master household | Braced or strapped boards, rear structural ledges |
| Merchant/great household | Narrow edge fillets, border nails, escutcheon and larger ring; restrained central nail variant |
| Council entrance | Three branched forged straps, lance terminals, rivets and ring on a shaped escutcheon |
| Parish entrance | Two branched straps; no civic third strap |
| Principal church entrance | Three branched straps, border fastenings and ring |

Physical board joints, board tone variation, rear ledges and braces, strap terminals, hinge knuckles, hexagonal nail heads, escutcheon, key slit relief and round ring pulls replace the single textured box. Iron has a separate metallic/rough surface and never samples the timber texture. Existing project timber maps are reused; no website photography or generated image assets enter runtime.

## Runtime and stable IDs

- `scripts/city/city_doors.gd` mounts the geometry in `CityWorld3D.create`, binds census wealth, applies wood material only to the wood surface, and retains the original proximity/opening logic.
- `scripts/city/city_door_details.gd` owns deterministic profile selection and cached geometry. Its cache key includes exact width, height, profile and one of three stable-ID board variants. Each leaf has at most two surfaces and stays below the tested 4,500-triangle bound.
- Ordinary building IDs seed appearance independently of the wall/window RNG. No geometry, navigation, building, floor or transition IDs change.
- Explicit entrance overrides (not site-wide decoration): `door.council_hall.north` -> civic; `door.council_hall.dornse` -> merchant; `door.holy_spirit.north`, `door.st_olaf.south`, `door.st_nicholas.west`, `door.st_mary.south` -> parish; `door.st_olaf.west`, `door.st_nicholas.north`, `door.st_mary.priests` -> ecclesiastical.
- Remaining site doors preserve their authored profile, including almshouse, yard, screen, gate and smithy doors, while receiving the improved shared construction. Unknown site IDs fall back to their manifest style.
- Runtime reads `content/world/reval_city/sites/*.json` through `CitySiteRegistry` without rewriting it. Door width, height, floor, opening radius, swing speed and leaf count remain unchanged.

Appearance is deterministic and regenerated on load. Nothing is written to saves; the city's existing unsaved door-state limitation remains.

## Historical boundaries and user decisions

The user requested substantial detail, social differentiation like windows, and updates to key buildings in this session, citing [Doors of Tallinn](https://doorsoftallinn.com/). The collection is a modern photographic survey, not a 1343 inventory: proportions, the contrast of timber and dark fittings, and individual entrance identity are design prompts only. Bright modern paint, glazed domestic entrance doors, Renaissance/Baroque raised panels and modern locks are not copied.

All new landmark hardware is a **plausible composite**, not an assertion about the surviving original fittings of a named church. See [canon qualification](../CANON.md#door-construction-and-entrance-hardware-r-1692).

A useful local construction analogy is Läänelaid et al., *Investigating the age of the door of the King's Chapel in Tallinn Dome*, [DOI 10.1016/j.dendro.2025.126462](https://doi.org/10.1016/j.dendro.2025.126462). Its abstract describes pine planks, inclined bars and outer oak boarding; the [accessible secondary account](https://arkeonews.net/one-of-northern-europes-oldest-doors-found-estimated-to-be-650-years-old/) reports oak cut around the early 1380s. This is later than the game: it informs a conservative construction analogy, not a dated 1343 reconstruction. The publisher full text was not accessible during this pass.

## Verification and evidence

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- \
  --filter=test_city_doors,test_city_windows,test_city_sites,test_city_plan
python3 -m gdtoolkit.linter scripts/city/city_doors.gd \
  scripts/city/city_door_details.gd tests/godot/test_city_doors.gd tools/capture_city_doors.gd
tools/godot_render.sh --script tools/capture_city_doors.gd
for site in raekoja_plats holy_spirit st_olaf st_nicholas st_mary; do
  tools/godot_render.sh --script tools/capture_city_doors.gd -- --site=$site
done
```

`test_city_doors.gd` covers wealth selection/census override, bounded geometry, separate iron material, caching/variant identity, both inward normals, single/double leaves, all explicit site IDs, service fallback, and actual plan open/close. The focused regression run passed **47 tests, zero failures/errors**. The separate site validator passed. Independent agent review could not run (provider returned an empty response); R-1692 remains `in_review` pending human sign-off. Captures use a minimized GPU window, actual landmark builders, actual site transforms and actual door records (isolated from the rest of the city, with neutral review lighting). They are not full-world performance measurements.

- [Repertoire](../reports/images/city/doors/repertoire.png)
- [Council hall](../reports/images/city/doors/raekoja_plats.png)
- [Holy Spirit](../reports/images/city/doors/holy_spirit.png)
- [St Olaf](../reports/images/city/doors/st_olaf.png)
- [St Nicholas](../reports/images/city/doors/st_nicholas.png)
- [St Mary, south entrance](../reports/images/city/doors/st_mary.png)

The plates above were regenerated with the R-1693 portals; the full R-1693 set follows below.

## Landmark portals (R-1693)

Player-facing result: church entrances read as constructed stone portals. Stepped orders with chamfered or rolled arrises frame the opening, the leaf is cut to the pointed (or nearly round) head instead of a rectangle under an open arch, and from inside the leaf hangs in a wider rear arch with a dressed stone stop around it. Walking up opens it inward as before; it now opens flat against the rear arch (90 degrees) instead of swinging into masonry. The council hall keeps its flat lintel under a tympanum, and its leaves now fill their rectangular apertures.

### Evidence and confidence

| Source | What it supports | Label |
|---|---|---|
| [medievalheritage.eu, Holy Spirit](https://medievalheritage.eu/en/main-page/heritage/estonia/tallinn-holy-spirit-church-puha-vaimu-kirik/), after Naha and Peets 1933 and Neumann and Nottbeck 1904 | North entrance is "a stepped portal with a moulded archivolt and a pointed arch"; simpler portals south and west; the Gothic rebuild ran from about the mid-14th century (lime donations, 1360s fabric gifts) | **`attested`** portal, **later than 1343** |
| [medievalheritage.eu, St Nicholas](https://medievalheritage.eu/en/main-page/heritage/estonia/tallinn-st-nicholas-church/); [grande flanerie survey](https://grandeflanerie.com/gothictallinn/) | Pointed, moulded portals in the tower ground floor and the aisle; an early Gothic south portal with a trefoil in the archivolt (13th century); north and south portals dated late 13th century | **`attested`** existence and approximate date; profiles **`plausible`** |
| [medievalheritage.eu, St Mary (Dome)](https://medievalheritage.eu/en/main-page/heritage/estonia/tallinn-cathedral-of-the-virgin-mary/); [grande flanerie survey](https://grandeflanerie.com/gothictallinn/) | "The most impressive, stepped pointed portal" in the south aisle; south-east portal early 14th century | **`attested`**; richest profile on the rising 1343 nave is **`plausible`** |
| St Olaf | No portal-specific evidence found in this pass | profiles **`speculative`** |
| [Havdhem church door](https://commons.wikimedia.org/wiki/File:Havdhems_kyrka_medeltida_d%C3%B6rr_Gotland.jpg) (Gotland, RAÄ 21300000002756); Stånga south portal, mid-14th century ([Lagerlof and Stolt, *Sveriges kyrkor* 1968, via guteinfo](http://guteinfo.com/index.asp?id=3853)) | Regional analogy: medieval church leaves cut to the portal head; elaborate stepped portals around the 1340s on Gotland | **`attested`** regional analogy, not Tallinn evidence |
| Paju, [*Baltic Journal of Art History* 23 (2022)](https://doi.org/10.12697/BJAH.2022.23.02) | Tallinn's "medieval" portals can be largely 20th-century restorations (Pikk 7) | caution: do not copy surviving portals literally |
| Läänelaid et al. 2025 (King's Chapel door, see R-1692 above); Läänelaid et al., *A Door in Use in Tallinn Appeared to Be Over 600 Years Old*, BJAH 2021 (abstract only) | Plank-and-ledge construction of surviving Tallinn doors | **`attested`** later comparison |
| Rear arch (embrasure) and stop | Construction logic of a leaf cut to a pointed head that opens inward | **`plausible`** |

Later surviving doors (Doors of Tallinn photography, Renaissance and Baroque panelled doors, the 1597 Holy Spirit portal) are not copied. Hardware keeps the R-1692 restrained profiles; arched leaves only add a rear head ledge and, on rich profiles, nails following the head.

### Decisions per entrance

| Door ID | Aperture (w x spring/apex) | Decision | Orders (outside -> in) |
|---|---|---|---|
| `door.holy_spirit.north` | 1.8 x 2.6/3.7 | Shaped leaf; restrained two-order predecessor of the attested later portal | chamfer, chamfer, chamfered stop |
| `door.st_olaf.west` | 2.2 x 3.2/4.6 | Shaped leaf at the inner end of the 3.2 m tower wall | chamfer, roll, chamfer, rolled stop |
| `door.st_olaf.south` | 2.4 x 3.3/5.0 | Shaped double leaf | chamfer, roll, chamfered stop |
| `door.st_nicholas.north` | 2.2 x 3.0/4.4 | Shaped leaf; two shallow orders in the 0.8 m porch wall | chamfer, roll, chamfered stop |
| `door.st_nicholas.west` | 2.0 x 3.0/4.3 | Shaped leaf; moulded tower portal | chamfer, roll, chamfer, rolled stop |
| `door.st_nicholas.south` | 1.8 x 2.7/3.8 | Shaped leaf; the attested trefoil archivolt is not modelled | chamfer, chamfer, chamfered stop |
| `door.st_mary.south` | 2.0 x 2.8/3.8 | Shaped leaf; the richest portal, in the rising nave | chamfer, roll, roll, chamfered stop |
| `door.st_mary.priests` | 1.5 x 2.8/3.5 (sill 0.57) | Shaped leaf; one chamfered order. The old leaf (2.65 m) ran past the springing into the head | chamfer, chamfered stop |
| `door.st_catherine.west` | 2.2 x 3.1/4.6 | Shaped leaf; the surviving stepped Dominican west portal (date unrecorded, `plausible`), carved capital friezes not modelled (R-1718) | chamfer, roll, chamfer, chamfered stop |
| `door.council_hall.north` | 1.4 x 2.35 (builder) | Flat lintel under a tympanum kept; jambs and lintel chamfered; leaf widened from 1.3 to the aperture | builder `_portal` |
| `door.council_hall.dornse` | 1.4 x 2.35 (partition) | Rectangular leaf widened from 1.3 to the partition door | none |

Unprofiled site doors (Holy Spirit south and almshouse, St Nicholas Barbara chapel, St Mary gate and screen, the smithy) keep their R-1692 behaviour.

### Geometry and runtime

- `scripts/city/sites/site_portals.gd` (`CitySitePortals`) owns `PROFILES` (door ID -> orders), matches each door record to exactly one fabric `door` opening, and builds the section rings: concentric orders (each arris chamfered 0.05 m or rolled 0.07 m), the stop (the manifest aperture), and the rear arch (`REBATE` 0.18 m a side, springing `HEAD_CLEAR` above the leaf's apex). Orders and stop are ashlar; the rear arch takes the wall's interior finish.
- `CitySite.from_manifest` calls `CitySitePortals.annotate`, which tags the matching opening with `portal: {door, depth}` at load time. Manifests on disk are unchanged.
- `CitySiteKit.wall` opens the outer face to the outermost order and the inner face to the rear arch, then builds the rings. `walk_walls` still cuts the walk gap at the manifest aperture, so collision is unchanged.
- `CityDoors.portal_hang` places a profiled door's leaves: pushed back behind the orders when the authored hinge line is too close to the face (never pulled outward), widened by `OVERLAP` 0.05 m a side onto the stop, cut to the arch (`CityDoorDetails.mesh(..., head)`), and opened to `CitySitePortals.OPEN_ANGLE` (90 degrees). Proximity still uses the authored door centre.
- Boards butt without a see-through slot (R-1692 left 4 mm gaps); four-sided boards keep two triangles a face.
- Fixes found by the captures: the council hall builder dressed its portal as a window (float32 `Rect2` width compared with `PORTAL_W`), adding frame, grille and shutters; and St Mary's south chancel buttress (bay line x = 4) stood directly on the priests' door. The chancel bay line moves to x = 6 (`CHANCEL_BAY`, vaults 12 m + 8 m, windows still mid-bay); this is what made the earlier isolated priests' door capture white.

Stable IDs: no door, floor, transition, anchor, site or fabric ID changes. Data changes: `raekoja_plats.json` council door records widened to their apertures (`a`/`b` +-0.7 and 1.5..2.9, height 2.38), matching the builder constants and the existing walk gap. Nothing is saved; appearance is regenerated on load.

### Verification (R-1693)

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/run_godot_tests.gd -- \
  --filter=test_city_doors,test_city_windows,test_city_sites,test_city_plan
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_city_sites.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tools/capture_city_doors.gd -- --budget
# per door and view (outside | inside | open), minimized GPU window:
tools/godot_render.sh --script tools/capture_city_doors.gd -- \
  --site=st_mary --door=door.st_mary.priests --view=open
```

`test_city_doors.gd` adds: one aperture per profiled door and an unchanged walk gap; orders inside their wall, below its top and clear of other openings; leaf depth inside the wall; rear arch above the leaf apex; strap ironwork inside the rebate at 90 degrees; shaped leaves meeting springing and apex within the triangle bound; runtime leaves shifted by the profile and opening 90 degrees; council leaves equal to their apertures; St Mary's buttress clear of the priests' door.

Measured budget (`--budget`, headless, A/B in one run, minimum of three builds):

| Site | Triangles without -> with portals | Surfaces | Build ms |
|---|---|---|---|
| Holy Spirit | 34,057 -> 34,807 | 35 -> 35 | 39.7 -> 40.4 |
| St Olaf | 71,336 -> 73,578 | 51 -> 51 | 59.3 -> 61.8 |
| St Nicholas | 79,788 -> 82,734 | 70 -> 70 | 73.5 -> 75.3 |
| St Mary | 41,787 -> 43,611 | 54 -> 54 | 31.9 -> 33.7 |
| Council hall, smithy | unchanged | unchanged | within noise |

All 733 city leaves draw 825,354 triangles (658 cached meshes, 727 ms to build them all); the eight shaped portal leaves cost 19,830 triangles against 18,056 for flat leaves of the same styles. No new materials or surfaces, so draw calls do not change. These are CPU build and mesh measurements, not frame times.

Captures (isolated actual site builders and door records, neutral review lighting):

- Exterior: [Holy Spirit](../reports/images/city/doors/holy_spirit.png), [St Olaf west](../reports/images/city/doors/st_olaf.png), [St Olaf south](../reports/images/city/doors/st_olaf_south.png), [St Nicholas north](../reports/images/city/doors/st_nicholas.png), [St Nicholas west](../reports/images/city/doors/st_nicholas_west.png), [St Nicholas south](../reports/images/city/doors/st_nicholas_south.png), [St Mary south](../reports/images/city/doors/st_mary.png), [St Mary priests' door](../reports/images/city/doors/st_mary_priests.png), [council hall](../reports/images/city/doors/raekoja_plats.png)
- Interior: [Holy Spirit](../reports/images/city/doors/holy_spirit_inside.png), [St Olaf west](../reports/images/city/doors/st_olaf_inside.png), [St Olaf south](../reports/images/city/doors/st_olaf_south_inside.png), [St Nicholas north](../reports/images/city/doors/st_nicholas_inside.png), [St Nicholas west](../reports/images/city/doors/st_nicholas_west_inside.png), [St Nicholas south](../reports/images/city/doors/st_nicholas_south_inside.png), [St Mary south](../reports/images/city/doors/st_mary_inside.png), [St Mary priests' door](../reports/images/city/doors/st_mary_priests_inside.png), [council hall](../reports/images/city/doors/raekoja_plats_inside.png)
- Open: [Holy Spirit](../reports/images/city/doors/holy_spirit_open.png), [St Olaf west](../reports/images/city/doors/st_olaf_open.png), [St Olaf south](../reports/images/city/doors/st_olaf_south_open.png), [St Nicholas north](../reports/images/city/doors/st_nicholas_open.png), [St Nicholas west](../reports/images/city/doors/st_nicholas_west_open.png), [St Nicholas south](../reports/images/city/doors/st_nicholas_south_open.png), [St Mary south](../reports/images/city/doors/st_mary_open.png), [St Mary priests' door](../reports/images/city/doors/st_mary_priests_open.png), [council hall](../reports/images/city/doors/raekoja_plats_open.png)

## Limits

- Unprofiled doors (street, flat site doors, council hall) now open 90 degrees (was 100, which drove the leaf into the jamb) with the hinge pulled `JAMB_CLEARANCE` 0.05 m toward the opening, so the open leaf lies flat against the reveal. Double leaves are 0.05 m narrower, leaving a thin slit at each jamb when shut. Portal doors open 90 degrees into their rear arch as before.
- The attested trefoil archivolt of St Nicholas's south portal, capitals, shafts and carved imposts are not modelled. Orders are concentric with the manifest arch, so St Mary's nearly semicircular apertures stay nearly round.
- Hardware relief is visual: no physical key/lock interaction or moving ring animation.
- Profile differences communicate expense and entrance role, not documented personal ownership or an authenticated original church door design.
- At the time of R-1693 an uncommitted churchyard wall from a concurrent session (`churchyard.wall.00` in `st_nicholas.json`) ran 1.4 m outside `door.st_nicholas.south` without an opening, so `validate_city_sites.gd` reported that door blocked. R-1693 does not change walls or solids.
- Existing unrelated hero accessory UID warnings may occur during captures.
