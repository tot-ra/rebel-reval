# Equipment variants: pipeline, art bible and the watch spear pilot

Status: implemented (task **R-2003**, EQ-1 of epic **R-2002**). The pipeline and art bible are in place and proven on one item: the town-watch spear variant `spear_p1_w1`, now carried by every `watch` and `crown` duty kit in the seamless city.

Scope: how a period-accurate item brief becomes a game-ready Godot asset in several prestige and wear variants; the rules every equipment variant follows; the pilot.
Out of scope: runtime variant selection by rank or wear (R-2004), every other item family (R-2005..R-2034, one task each), retiring the legacy primitives (R-2035), the walk-cycle arm pose (R-2036).

![Watchman with the pilot spear: idle and walk, three-quarter and side](../reports/images/equipment/watch_spear_capture.png)

## Two routes, one rule

| Item kind | Route | Why |
|---|---|---|
| Rigid: weapons, helmets, shields, shoes, belt gear, buckles | Leonardo reference -> Meshy image-to-3D -> Blender cleanup (`tools/assets/equipment/cleanup_equipment.py`) -> GLB | Meshy copies a good reference with real riveting, forging marks and wear |
| Fitted garments: aketon, tunics, hose, mail, surcoats, hoods | stay `garments.py` meshes skinned to the shared 71-bone rig; only their surface changes, from tileable PBR plates (`tools/assets/equipment/derive_tileable_pbr.py`) | a Meshy scan is a rigid shell; a garment must keep the body topology to deform |
| Long poles (spear, glaive, bill shafts) | only the iron is scanned; the shaft is built procedurally by the cleanup script | Meshy cannot resolve a 2 m pole 3 cm thick |

## Variant axes and naming

- **Prestige** `p1` munition / peasant (plain, issued, homemade), `p2` burgher (good materials, maker's care), `p3` noble (fine work plus a faction finish: crown red, Order white, the town's colours). The finish is colour and material only, never invented heraldry.
- **Wear** `w0` new, `w1` used (the default), `w2` battered: rust, dents, patches. Wear is modelled into the scan or plate, not only a runtime tint.
- **File name** `<family>_<p>_<w>.glb` under the family's folder: `assets/props/weapons/<family>/variants/`, `assets/props/armour/<family>/variants/`, `assets/props/clothing/<family>/variants/`. Textile plates under `assets/materials/equipment/<plate>/`.
- **Stable ids:** the variant id is the file stem (`spear_p1_w1`); the item it belongs to is its object-catalog id (`obj.spear_watch`, [`OBJECT_CATALOG.md`](./OBJECT_CATALOG.md)), which links on to combat `item.*` records. Variant ids never change once shipped; a remodel gets a new wear or prestige slot, not a reused name.
- Not every cell of the 3x3 grid exists; each item task lists the cells it ships.

## Budgets

| Kind | LOD0 tris | LOD1 tris | Textures |
|---|---|---|---|
| Hand weapon (spear, sword, axe) | <= 4k | <= 1k | 1024 px base colour, normal, ORM |
| Helmet | 3-6k | <= 1.5k | 1024 px |
| Shield | <= 3k | <= 1k | 1024 px |
| Fitted garment | keeps the body topology | Godot import LODs | tileable plates, 512-1024 px |

ORM: occlusion in R, roughness in G, metal in B, as one image (glTF reads R as occlusion and G/B as roughness/metal from the same texture). Godot generates mesh LODs at import; the cleanup script also writes a LOD1 GLB to `build/equipment/` to check that the item survives the LOD1 budget.

## Attach sockets

Every rigid variant's origin is where it attaches, so code mounts it with a turn and no offset. Socket empties export as child nodes:

| Socket | Used by | Slot on `SharedCharacterRig` |
|---|---|---|
| `socket_grip` (origin) | hand weapons: where the right hand closes | `right_hand` |
| `socket_butt`, `socket_tip` | hafted weapons: ground contact, thrust point | - |
| `socket_forearm` (origin) | shields, strapped to the left forearm | `left_hand` |
| `socket_hip`, `socket_back` | sheathed sword, slung shield or bow (R-2004) | planned |
| `socket_head` (origin) | helmets and hats: the top of the head cavity | head bone |

Axes: the item's long axis is Godot +Y (point up), its flat face toward Godot +Z. The hand slot's X axis points down the forearm, so `Basis(Vector3.BACK, PI * 0.5)` turns the item's +Y up along the hand (`scripts/city/citizen_gear.gd`).

## Art bible

- **Iron and steel:** wrought iron is grey-black, matte, hammer-marked; bright metal only on a freshly filed edge. No chrome, no mirror plate, no blued or gilded fittings below `p3`. The cleanup script floors roughness (`rough_floor`, 0.45 on the pilot) and caps metal.
- **Wood:** ash for spear and polearm shafts, birch or ash for tool hafts; pale grey-cream to honey, greyer and grimier with wear. No dark walnut, no varnish.
- **Textiles:** undyed grey-brown wool for labourers and the watch, woad blue and madder red for burghers, scarlet (fine fulled wool) only for the rich, linen for shirts, coifs and aketon covers. Quilting runs vertically.
- **Leather:** vegetable-tanned brown, darkening with wear; no black patent, no studs as decoration.
- **Forbidden:** fantasy ornament, spikes, engraving and etched blades, invented heraldry or faction badges, Renaissance or later forms (plate armour harness, ruffs, rapiers), modern straps and buckles.
- **Look target** for the watch, generated in the R-2002 feasibility check:

![Watchman 1343 look target: kettle hat with comb, laced aketon, leaf-blade ash spear](../reports/images/equipment/pilot/watchman_1343_target_sheet.jpg)

## Historical checklist per item

Every item task fills this in its manifest or task body before generating, and cites the dossiers [`arms-and-armour-livonia-1340s.md`](../../history/dossiers/military/arms-and-armour-livonia-1340s.md) and [`clothing-and-status-markers.md`](../../history/dossiers/dailylife/clothing-and-status-markers.md):

1. Who carries it in Reval 1343 (watch, crown men-at-arms, Order, burgher, Estonian levy) and in which prestige cells.
2. Who made it (town smith, imported, carpenter, home) and so how fine `p2`/`p3` can be.
3. Shape and size from the dossier ledger, with the shapes it must not have (later or fantasy forms).
4. Materials and colours from the art bible above.
5. Evidence level (plausible composite or source-backed) copied from the dossier.

Pilot answers (spear): carried by the burgher watch and crown men-at-arms ("padded jack, iron cap, sword, crossbow or spear", arms dossier); head by the town smith, ash shaft by a carpenter (item ledger row 1); socketed leaf blade, no barbs, no wings, no langets; wrought iron and ash; plausible composite.

## Pipeline

All tools live in [`tools/assets/equipment/`](../../tools/assets/equipment/); prompt templates in [`prompts.md`](../../tools/assets/equipment/prompts.md). Blender runs headless with `--factory-startup`; Godot only with `--headless` or `tools/godot_render.sh`.

1. **Reference** (Leonardo): one isolated object on white, from the template. Inspect it: Meshy copies its mistakes.
2. **Scan** (Meshy image-to-3D, PBR on, `target_polycount` 3000-6000). Move the raw GLB to gitignored `build/<set>/` and put its SHA-256 in the item manifest `tools/assets/equipment/items/<variant>.json`.
3. **Clean up and export:** `python3 tools/assets/equipment/build_equipment.py tools/assets/equipment/items/<variant>.json` checks the raw hash, runs `cleanup_equipment.py` in Blender (align and real-size scale, wearable cavity cut with a liner, procedural shaft, roughness floor, AO bake and ORM repack, pivot and sockets, decimate, LOD1 to `build/equipment/`; the GLB goes to the manifest's `out` under `assets/`, never `generated/`), then renders the turntables with `render_turntable.py`.
4. **Textile and wood plates:** generate a flat texture photo (Leonardo Nano Banana or the ComfyUI graph `comfyui_tileable_textile.json`), then `python3 tools/assets/equipment/derive_tileable_pbr.py --src ... --out-dir assets/materials/equipment/<plate> --stem <plate> --tint r,g,b --preview docs/reports/images/equipment/<plate>_plate.png` makes it seamless (terrain-plate helpers, as in `tools/assets/derive_plate_normals.py`) and derives normal and roughness. Garments use the same plates for their surface.
5. **Import:** `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import` writes the `.import` sidecars and the extracted `<variant>_*.jpg` textures; commit them all.
6. **Provenance:** one `assets/SOURCES.csv` row for the GLB (full prompt, Leonardo generation, Meshy task, raw and output SHA-256, cleanup parameters) and one per extracted texture and plate; `python3 tools/validate_asset_sources.py`.
7. **Mount** in code by the variant's socket, and capture it on a character.

## The pilot: watch spear `spear_p1_w1`

- Asset: [`assets/props/weapons/spear/variants/spear_p1_w1.glb`](../../assets/props/weapons/spear/variants/spear_p1_w1.glb), manifest [`items/spear_p1_w1.json`](../../tools/assets/equipment/items/spear_p1_w1.json). 2.33 m overall: a 0.34 m Meshy leaf-blade head (2.4k tris, Leonardo gpt-image-1.5 reference) on a 2.0 m ash shaft, 1.7 cm butt radius, thickest a third of the way up, top matched to the scanned socket. 2,580 tris LOD0, 1,000 LOD1, 512 KiB.
- Shaft plate: [`assets/materials/equipment/ash_shaft_used/`](../../assets/materials/equipment/ash_shaft_used/) from a Leonardo Nano Banana photo, tinted warm (the generator gave white laminate). The forge set's `spear_WeaponAshWood_albedo.png` is dark walnut-brown and was not used.
- Runtime: `CitizenGear.SPEAR` (`scripts/city/citizen_gear.gd`) mounts it on `right_hand` for the `watch` and `crown` kits ([`GATE_GARRISONS.md`](./GATE_GARRISONS.md)); origin at the grip, 0.83 m above the butt, so the idle watchman's butt rests on the ground. Brawling watchmen keep their spear profile ([`COMBAT.md`](./COMBAT.md)). The legacy primitive `assets/characters/shared/spear.tscn` stays in the repo until R-2035.

Turntables (yaw 0-315 deg in 45 deg steps, then from below):

![spear_p1_w1 turntable](../reports/images/equipment/spear_p1_w1_turntable.png)
![spear_p1_w1 head detail](../reports/images/equipment/spear_p1_w1_detail.png)
![Ash shaft plate tiled 2x2 with its normal and roughness](../reports/images/equipment/ash_shaft_used_plate.png)
![Close-up: kettle hat and spearhead in game](../reports/images/equipment/watch_spear_closeup.png)

Feasibility input for EQ-13 (kettle hat), from the R-2002 check: reference and Meshy views (underside capped solid, chin strap fused across the brim; `cleanup_equipment.py`'s `cavity` step cuts the head volume and lines it):

![Kettle hat reference](../reports/images/equipment/pilot/kettle_hat_reference.jpg)
![Kettle hat Meshy scan views](../reports/images/equipment/pilot/kettle_hat_meshy_views.jpg)

## Verify

- Rebuild and turntables: `python3 tools/assets/equipment/build_equipment.py tools/assets/equipment/items/spear_p1_w1.json` (needs the raw scan in `build/equipment_pilot/`; re-download it from Meshy by the manifest's task id if missing, the hash check confirms it).
- In game: `tools/godot_render.sh --script tools/capture_watch_spear.gd` writes `docs/reports/images/equipment/watch_spear_capture.png` (idle and walk, three-quarter and side) and `watch_spear_closeup.png`.
- Tests: `test_watch_carries_the_spear_variant` in `tests/godot/test_citizen_wardrobe.gd` (variant mounted, sockets exported, 2.1-2.4 m, origin at the grip); `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_citizen_brawl,test_citizen_roster,test_citizen_wardrobe` and `python3 -m pytest tests/python/test_citizen_wardrobe*.py`.

## Limits

- The spear is held with the same hand turn as the old primitive, so in the idle pose it leans about 10 degrees across the body; the walk cycle holds it upright. The walk arms are the separate T-pose bug R-2036.
- One variant only; `p2`/`p3` and `w0`/`w2` spears and runtime choice are R-2004 and the spear family task.
- Meshy bakes soft studio light into the base colour, so a scan reads slightly flat under hard sun.
- The cavity cut is implemented but not yet used on a shipped wearable (first use: EQ-13 kettle hat). The ComfyUI textile graph was not run in R-2003 (server offline); the Leonardo route was.
- The wearable `socket_head`, `socket_hip` and `socket_back` conventions are defined here, not yet mounted.
