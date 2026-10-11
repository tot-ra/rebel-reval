# City doors: household wealth and landmark entrances

Status: implemented (task **R-1692**).

Scope: procedural hinged leaves in the seamless city, ordinary housing and existing landmark sites. This is a visual refinement of ADR 0031/0032, not a new interaction system. Locks, sound, saved door states, altered portals and exact archaeological replicas are out of scope.

## Player-facing behaviour

Walk towards an enterable building with the normal keyboard or gamepad movement controls. The existing proximity rule swings its leaves inward and closes them after departure; non-enterable houses stay shut. No new input binding is needed. Street and interior sides now have different hardware. Double leaves show their decorated sides towards the street regardless of authored endpoint order.

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

## Limits

- Rectangular leaves fill existing rectangular lower apertures. Existing pointed stone surrounds/blind heads are not rebuilt or converted into arched leaves.
- Hardware relief is visual: no physical key/lock interaction or moving ring animation.
- Profile differences communicate expense and entrance role, not documented personal ownership or an authenticated original church door design.
- Task **R-1693** tracks evidence-led portal masonry and full-city draw/triangle budgets in a separate measured pass before further detail is added. Existing unrelated hero accessory UID warnings may occur during captures.

The priest-door capture at St Mary was rejected because it was almost fully white in the isolated scene; the evidence plate uses the south entrance instead. The priest-door profile and orientation are covered by headless tests, but its close-up visual sign-off remains open.
