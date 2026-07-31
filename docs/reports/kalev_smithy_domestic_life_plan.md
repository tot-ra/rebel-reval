# Kalev's Smithy domestic-life plan (26×14)

Recorded: 2026-07-28  
Revised: 2026-07-30 (living-bay kitchen re-dressing)
Task: **P2-053**  
Map: `content/maps/kalev_smithy.rrmap` (`loc.kalev_smithy`)  
Grid: **26 × 14 cells** at **32 px** per cell. **One cell renders as one metre** in the 3D view (`MapViewBridge.WORLD_UNITS_PER_CELL = 1.0`), so the interior is **26 m × 14 m** and the living bay is **13 m × 12 m**.
Confidence: conservative reconstruction for a **middling Lower Town master smith**, April–May **1343**

> **Correction (2026-07-30).** The original header read the grid as ≈ 8.3 m × 4.5 m. That is wrong: props are authored in metres and the view bridge maps one cell to one world unit, so the interior is three times the assumed size. The 2×2 and 3×3 "zone band" footprints in the tables below were therefore far larger than the shipped GLBs (hearth **1.0 m** wide, chair **0.55 m**, kitchenware **0.1–0.6 m**), which is what left the hearth stranded mid-corner and the small items scattered on bare boards. Placement is now sized to the model, not to the zone band. See [Living-bay kitchen re-dressing](#living-bay-kitchen-re-dressing-2026-07-30).

## Decision summary

1. **Household form:** Kalev occupies a **street-front craft dwelling** with a **smoke-darkened forge bay (~55%, east)** and a **limewashed living bay (~45%, west)** separated by `wall.divider`, matching the existing map partition and [`smithy-workshop-layout.md`](../../history/dossiers/architecture/smithy-workshop-layout.md).
2. **Domestic hearth (cooking/heating):** Install a **hooded masonry cooking hearth** with **iron pot-hook / crane**, **suspended lidded cauldron**, and a **short hood-to-flue** treatment in the **living bay north wall**. This is **not** the industrial `forge_furnace`; the forge hearth stays in the work bay only.
3. **Approved artisan meal:** **Coarse rye bread + pea-and-onion pottage + salted herring**, with **thin household beer** at supper - the **middling craft** tier in [`food-and-drink.md`](../../history/dossiers/dailylife/food-and-drink.md). No player hunger meter; meal beats are **readable ambience**, not chores.
4. **Occupancy canon:** Kalev is the **sole human resident** and player. **Mart is absent** while `mart_missing` is active (prologue and early slice). **Henning is a visitor**, never a resident. **Forge cat** is the only other permanent inhabitant.
5. **Protected gameplay:** All existing prop IDs, anchors, transitions, spawn, camera rect, and route tests in `test_kalev_smithy_map.gd` remain valid. New domestic dressing must not block routes to **bed**, **ledger**, **anvil**, **courtyard door**, or the **partition passage**.

## Historical brief

### What a 1343 Reval craft household eats and cooks

| Topic | Approved read | Confidence |
|---|---|---|
| Staples | **Rye bread** and **beer** daily; **fish** common after Easter (13 Apr 1343); **dried peas**, **onions**, **cabbage** in pottage | plausible composite [1][2] |
| Kalev's tier | **Master craftsman / middling burgher** - not merchant luxury, not Estonian haulier poverty | plausible composite [1] |
| Meal rhythm | **Dinner (Mittagessen)** late morning–midday = main hot meal; **supper** = bread, beer, leftovers; **breakfast** = practical working food if shown at all | plausible composite [1][3] |
| Kitchen location | **Living bay** or rear yard at an **open or hooded hearth**; grain and beer in **cellar/chest**; **no separate modern kitchen room** on a *boda* plot | plausible composite [3][4] |
| Forge vs kitchen fire | **Industrial charcoal hearth** in forge bay; **domestic wood-kindling fire** for food - must be **visually and spatially distinct** | plausible composite [4][5] |

### Selected cooking/heating fixture

**Approved fixture:** **Hooded brick cooking hearth** (`prop.domestic_hearth`) with:

- **Masonry or tile-lined firebox** (~0.8–1.0 m wide) built into the living-bay north wall
- **Iron fire grate** and **adjustable pot hook / crane** (Low German *Haken* / *Kettlehaken* tradition)
- **Suspended iron or ceramic lidded cauldron** (*Kessel*) for pottage
- **Hood throat** rising to a **plastered flue** toward the north gable - smaller and cleaner than the forge smoke hood
- **Fuel:** split **birch/pine kindling** and small logs in a **roofed indoor wood nook** - **not** forge charcoal

**Why not reuse `forge_furnace`:** The existing furnace models an **industrial raised smithing hearth** (charcoal, tuyere, bellows coupling). Baltic urban practice and project art direction require a **separate domestic fire** so players never confuse food preparation with hot-work [`smithy-workshop-layout.md`](../../history/dossiers/architecture/smithy-workshop-layout.md) [5].

**Uncertainty:** No measured **1343 Reval domestic hearth** survives. Hood vs smoke-hole prevalence on craft houses is **unknown**; the hooded form is chosen for **in-town fire safety** and readable separation from the forge bay [4][5].

### Selected simple artisan meal

**Approved meal ID:** `meal.kalev_midday_pottage`

| Component | Props / state groups | Notes |
|---|---|---|
| **Coarse rye loaf** | `provision.rye_bread_loaf`, `provision.rye_bread_cut` | Purchased or bartered; Kalev does not operate a bake oven |
| **Pea-onion pottage** | `provision.dried_peas_bin`, `provision.onion_braid`, `kitchenware.cooking_pot_lidded` on hearth | Main hot meal; herring optional on top |
| **Salted herring** | `provision.herring_filleted` | Hanse staple for a port smith [`food-and-drink.md`](../../history/dossiers/dailylife/food-and-drink.md) [1] |
| **Thin beer** | `provision.beer_jug` (supper only) | House or tavern beer; not imported wine |
| **Excluded** | Coffee, tea, potatoes, fine wheat rolls, daily meat joints | Out of period / wrong tier [1] |

## Annotated 26×14 zone plan

Coordinate system: **x** increases east, **y** increases south. **Living bay** = cells **x 0–13**; **forge bay** = **x 14–25**. South wall holds the courtyard door.

```text
y=0  NORTH WALL (interior windows at x=5 and x=20)
     ┌────────────────────────────┬─────────────────────────────┐
     │ LZ-C HEARTH & PROVISIONS   │ FZ-A FORGE HEARTH MOUTH     │
     │  (1,1)-(4,3)               │  forge_furnace (19,1)       │
     │ LZ-B LEDGER NOOK           │ FZ-B BELLOWS STATION        │
     │  forge_ledger (4,3)        │  forge_bellows (16,2)       │
     │  cloak_banner (5,2)        │ FZ-C TOOL WALL              │
     │ LZ-D WASH / WATER CORNER   │  tool_shelf (22,2)          │
     │  (10,1)-(12,2)             │ FZ-D STOCK & SCRAP          │
y≈6  │ window.west (0,6)          │  coal / scrap (21–23,4–5)   │
     │                            │ FZ-E WORK TRIANGLE          │
     │ LZ-F STORAGE               │  forge_anvil (18,5)         │
     │  chest (2,7)               │  quench (16,5)              │
     │ LZ-A SLEEP ALCOVE          │  spawn.main (19,7)          │
     │  bed (3,9)                 │                             │
     │ LZ-E EAT / PREP            │ window.east (25,6)          │
     │  food_table (6,10)         │                             │
     │  work_chair (10,10)        │                             │
     │  table_candle (8,11)       │                             │
y=13 └────────────────────────────┴─────────────────────────────┘
     door_courtyard (12,13) ──► courtyard / loc.lower_town_slice
     partition door at wall.divider (14,7)  |  camera 0,0,26,14
```

### Zone table

| Zone ID | Cells (approx.) | Function | Existing props | New dressing (P2-054–057) |
|---|---|---|---|---|
| `LZ-A` | x 2–6, y 8–11 | Sleep / wake / evening rest | `bed` | folded linen, wool blanket state on bed |
| `LZ-B` | x 2–6, y 2–4 | Ledger, maker-mark evidence | `forge_ledger`, `cloak_banner` | none blocking ledger anchor |
| `LZ-C` | x 1–4, y 1–3 | Domestic hearth, provisions, kindling | *(none)* | `domestic_hearth`, pot hook, cauldron, kindling nook, pea bin |
| `LZ-D` | x 10–12, y 1–2 | Wash, water staging | *(none)* | `wash_basin`, `water_bucket`, wiping cloth |
| `LZ-E` | x 6–10, y 10–12 | Prepare, eat, clear, visitor talk | `food_table`, `work_chair`, `table_candle` | place settings, prep board, bowls |
| `LZ-F` | x 2–3, y 7–8 | Locked storage | `chest` (`chest.burgher`) | grain sack in chest grouping |
| `LZ-G` | x 10–13, y 12–13 | Courtyard entry corridor | `door_courtyard` transition | firewood carry path, ash scoop by door |
| `FZ-A`–`FZ-E` | x 15–25 | Hot work only | forge kit | unchanged; **no food props** |

### Protected routes and anchors (must stay open)

| ID | Type | Map position | Protected use |
|---|---|---|---|
| `bed` / `bed_alcove` | prop + anchor | (3,9) | Prologue rest gate; sleep/wake activity |
| `forge_ledger` / `ledger` | prop + anchor | (4,3) | Maker's Mark ledger choice |
| `forge_anvil` / `anvil` | prop + anchor | (18,5) | Commissions, Henning inspect beat |
| `door_courtyard` | transition | (12,13) | Courtyard entry; visitor enter/leave |
| `smithy_start_spawn` | transition | (19,7) | Default spawn / work-bay entry |
| `spawn.main` | spawn | (19,7) | Route tests origin |
| `wall.divider` opening | passage | (14,7) | Living ↔ forge crossing |
| `camera` | viewport | 0,0,26,14 | Full interior framing |

**Route contract (automated):** spawn → anvil, ledger, bed_alcove, door_courtyard - per `test_kalev_smithy_door_and_work_triangle_reachable`.

## Actor occupancy by phase

Human roles only; the forge cat is listed separately below.

| Phase | Kalev (`char.kalev`) | Mart (`char.mart`) | Henning (`char.henning`) |
|---|---|---|---|
| `phase.prologue_day` | **Resident + player.** Works forge, handles ledger, may show morning wash/meal vignettes before Henning arrives. | **Absent.** `mart_missing=true`; no bed roll, no apprentice props implying presence. | **Visitor.** Enters from `door_courtyard`, inspects evidence, may sit `work_chair` during dialogue only; leaves before day end. |
| `phase.investigation_morning` | **Resident + worker.** Forge open; domestic beats optional ambience. | **Absent** while `mart_missing` remains set. | **Absent** unless a future quest explicitly schedules a return visit. |
| `phase.investigation_night` | **Off-site default** (Lower Town night loop). Smithy may be empty or cat-only. | **Absent** while `mart_missing`. | **Absent.** |
| `phase.consequence_night` | **Off-site default** (night consequence host is `reval_east`). | **Absent** while `mart_missing`. | **Absent.** |
| `phase.reflection_morning` | **Resident.** Quiet forge; evening-rest staging possible. | **Absent** until `mart_missing` cleared by story. | **Absent.** |
| `phase.act1_climax` | **Resident.** Forge as narrative hub. | **May be present** only after `mart_missing` cleared (Act 1 cycles); uses apprentice stations, never resident bed claim in prologue. | **Visitor only** if authored; never overnight. |

**Canon flags referenced:** `mart_missing`, `prologue_maker_mark_incident`, `forge_ledger_status` [`the-makers-mark.md`](../SCENES/the-makers-mark.md).

### Forge cat (`char.forge_cat`)

| Phase | Role |
|---|---|
| All smithy-active phases | **Resident animal.** Sleep near `LZ-A` or warmth-seek at `LZ-C` hearth embers; never occupies human activity points. |
| Prologue with Henning present | **Background only** - no interaction blocking visitor route. |

## Readable daily beats (not survival chores)

These beats inform **P2-058** activity points and **P2-059** vignettes. None impose hunger, stamina, or failure for skipping.

| Beat | Time band | Activity point(s) | Props touched | Notes |
|---|---|---|---|---|
| **Wake** | Dawn | `ap.sleep.wake` | `bed` | Short camera-capable staging; player not forced |
| **Wash** | Morning | `ap.wash.basin` | `wash_basin`, `water_bucket` | Face/hands wash; water fetched from courtyard |
| **Fetch water** | Morning | `ap.fetch.water` | `water_bucket` | Door to courtyard well (off-map); bucket returns to `LZ-D` |
| **Prepare** | Late morning | `ap.prepare.board` | `prep_board`, `kitchenware.knife`, onions | Before hearth light |
| **Tend hearth** | Late morning | `ap.hearth.tend` | `domestic_hearth`, kindling | Domestic fire only |
| **Stir / cook** | Midday | `ap.hearth.cookpot` | `kitchenware.cooking_pot_lidded` | Pottage simmer; herring added late |
| **Eat** | Midday | `ap.eat.table` | `food_table`, bowls, bread | Kalev + later Mart when present |
| **Clear** | After meal | `ap.clear.table` | bowls → wash basin | Quick reset |
| **Forge work** | Day | `ap.forge.anvil`, `ap.forge.bellows`, `ap.forge.quench` | existing forge kit | Core gameplay loop |
| **Inspect ledger** | Any day | `ap.ledger.inspect` | `forge_ledger` | Quest / commission hook |
| **Carry fuel** | As needed | `ap.carry.fuel` | kindling, ash scoop | Domestic wood only in living bay |
| **Sweep** | Evening | `ap.sweep.floor` | `broom` | Living bay ash tracking |
| **Bank hearth / rest** | Evening | `ap.hearth.bank`, `ap.sleep.rest` | `domestic_hearth`, `bed` | Domestic fire banked; forge fire separate curfew rule |
| **Visitor enter** | Prologue | `ap.visitor.enter` | `door_courtyard` | Henning only in authored beats |
| **Visitor wait / inspect / talk / leave** | Prologue | `ap.visitor.wait`, `.inspect`, `.talk`, `.leave` | anvil area, `work_chair` | Henning never uses bed or ledger |

## Existing asset inventory

### Reuse as-is (shipped GLB or kit)

| Stable prop ID | Kind | Asset / variant | Reuse decision |
|---|---|---|---|
| `bed` | `bed` | `assets/props/furniture/smithy_bed.glb` | **Reuse** |
| `chest` | `chest` | `chest.burgher` GLB via `MapViewChestModels` | **Reuse** |
| `food_table` | `table` | generic table mesh builder | **Reuse** (add place settings in P2-055) |
| `work_chair` | `chair` | `assets/props/furniture/smithy_chair.glb` | **Reuse** |
| `table_candle` | `candle` | medieval lighting kit `artisan_tallow` | **Reuse** |
| `forge_ledger` | `ledger` | procedural / interior ledger mesh | **Reuse** |
| `cloak_banner` | `banner` | faction `black_cloaks` | **Reuse** |
| `tool_shelf` | `shelf` | `shelf.common_open` GLB | **Reuse** (tool hooks in forge bay) |
| `forge_anvil` | `anvil` | `smithy_anvil.glb` | **Reuse** |
| `forge_furnace` | `furnace` | `smithy_furnace.glb` | **Reuse** (industrial only) |
| `forge_bellows` | `bellows` | `smithy_bellows.glb` | **Reuse** |
| `quench` | `quench_bucket` | `smithy_quench_bucket.glb` | **Reuse** |
| `coal_store` | `charcoal_pile` | district-life mesh | **Reuse** |
| `iron_scrap_store` | `iron_scrap_pile` | district-life mesh | **Reuse** |

### Reuse kind, new map placement (P2-057)

| Stable prop ID | Kind | Asset | Reuse decision |
|---|---|---|---|
| `wash_basin` | `wash_tub` | district-life `wash_tub` mesh | **Reuse kind**, new prop ID at `LZ-D` |
| `water_bucket` | *(grouped)* | P2-056 household kit | **New model**, bucket from clutter kit |
| `broom` | *(grouped)* | P2-056 household kit | **New model** |
| `ash_scoop` | *(grouped)* | P2-056 household kit | **New model** near door |

### New models required (downstream tasks)

| Stable prop ID | Kind | Task | Notes |
|---|---|---|---|
| `domestic_hearth` | `hearth` | **P2-054** | Hooded masonry body, grate, crane, flue, flame/smoke anchors |
| `hearth_kindling_store` | *(grouped)* | **P2-056** | Split wood beside hearth |
| `prep_board` | *(grouped)* | **P2-055** | Oak board on table or shelf |
| `kitchenware.*` | *(grouped)* | **P2-055** | Knife, spoon, bowls, cups, jars, jug |
| `provision.*` | *(grouped)* | **P2-056** | Bread, peas, onions, herring, beer, salt crock |
| `linen_folded` | *(grouped)* | **P2-056** | Bed and shelf clutter |
| `apron_hook` | *(grouped)* | **P2-056** | Near hearth / door |

## Activity point registry (stable IDs)

All IDs are reserved for **P2-058**; transforms are approximate cell centres until `.rrmap` placement lands in **P2-057**.

| Activity ID | Zone | Approach cell | Primary prop | Actor |
|---|---|---|---|---|
| `ap.sleep.wake` | LZ-A | (4,10) | `bed` | Kalev |
| `ap.sleep.rest` | LZ-A | (4,10) | `bed` | Kalev |
| `ap.wash.basin` | LZ-D | (11,2) | `wash_basin` | Kalev, Mart (when present) |
| `ap.fetch.water` | LZ-G | (12,12) | `door_courtyard` | Kalev, Mart |
| `ap.prepare.board` | LZ-E | (7,10) | `food_table` | Kalev, Mart |
| `ap.hearth.tend` | LZ-C | (2,2) | `domestic_hearth` | Kalev |
| `ap.hearth.cookpot` | LZ-C | (2,2) | `domestic_hearth` | Kalev, Mart |
| `ap.hearth.bank` | LZ-C | (2,2) | `domestic_hearth` | Kalev |
| `ap.eat.table` | LZ-E | (8,11) | `food_table` | Kalev, Mart |
| `ap.clear.table` | LZ-E | (7,11) | `food_table` | Kalev, Mart |
| `ap.sweep.floor` | LZ-G | (11,11) | `broom` (floor) | Kalev, Mart |
| `ap.carry.fuel` | LZ-G → LZ-C | (12,12) → (2,2) | kindling | Kalev, Mart |
| `ap.ledger.inspect` | LZ-B | (4,3) | `forge_ledger` | Kalev |
| `ap.forge.anvil` | FZ-E | (19,7) stand south of anvil | `forge_anvil` | Kalev, Mart |
| `ap.forge.bellows` | FZ-B | (16,2) | `forge_bellows` | Kalev, Mart |
| `ap.forge.quench` | FZ-E | (16,5) | `quench` | Kalev, Mart |
| `ap.visitor.enter` | LZ-G | (12,13) | `door_courtyard` | Henning |
| `ap.visitor.wait` | FZ-E | (17,7) | — | Henning |
| `ap.visitor.inspect` | FZ-E | (18,7) stand south of anvil | `forge_anvil` | Henning |
| `ap.visitor.talk` | LZ-E | (10,10) | `work_chair` | Henning |
| `ap.visitor.leave` | LZ-G | (12,13) | `door_courtyard` | Henning |
| `ap.cat.sleep` | LZ-A | (5,10) | `bed` (floor beside) | `char.forge_cat` |
| `ap.cat.warmth` | LZ-C | (3,3) | `domestic_hearth` (embers) | `char.forge_cat` |
| `ap.cat.feed` | LZ-C | (3,3) | floor scrap | `char.forge_cat` |

**Occupancy rule:** Only one human actor per activity point at a time; cat points never overlap human eat/wash/sleep points.

## Uncertainties and explicit gaps

| Topic | Status |
|---|---|
| Attested **1343 Reval smithy interior** floor plan | **Absent** - gameplay map is compressed composite [5] |
| Attested **domestic hearth** example in Reval | **Absent** - hooded masonry form is Hanse/craft composite [3][4] |
| **Chimney vs smoke hole** on craft houses | **Unknown** for 1343 Reval |
| Kalev **well vs public well** for water | **Plausible composite** - fetch beat uses courtyard/yarded well off interior map [3] |
| **Mart's return date** after prologue | **Story-gated** by `mart_missing` clearance, not spatial plan |
| **Henning overnight stay** | **Excluded** - visitor canon only |
| Bake oven in smithy | **Excluded** - bread bought, not baked on site [1] |

## Living-bay kitchen re-dressing (2026-07-30)

Playtest feedback on the living bay: the hearth sat in the corner facing its own
back wall, the Black Cloak banner hung in open air, small items lay on the floor,
and the kitchen had no work surface or seating - *"на чём вообще готовили?"*

### Decisions

1. **One cell is one metre.** Prop footprints are sized to the GLB from now on.
   Zone bands (`LZ-*`) stay as *review regions*, never as footprints.
2. **Interior kits front toward local −Z (map north).** A new opt-in `facing`
   cardinal on `prop` rotates the 3D model onto that direction
   (`MapTypes.prop_facing_yaw`). The allowlist is narrow -
   `MapTypes.FACING_AWARE_PROP_KINDS` - so no shipped map changes silhouette by
   accident. `banner` declares `+X` as its model front because its wall arm and
   cloth project along `+X`.
3. **The kitchen is a range along the north wall**, west to east:
   `wash_basin` → `kitchen_dresser` → `kitchen_work_table` → `hearth_kindling_store`
   → brick `domestic_hearth` at mid-building cells `(11,1)` near the bay divider
   (`facing=south`, mouth into the room). `kitchen_stool` faces the bench.
   **Decision (2026-07-31):** playtest rejected the pale limestone corner heater;
   the cooking fire is brick masonry and sits mid-building against the plaster.
4. **Small items ride surfaces, not floors.** `visual_offset_px` lifts each item
   onto its host: trestle top **0.822**, eating board **0.792**, cupboard head
   **1.52**, wash-stand shelf **0.32**, mattress **0.79**. X offsets space
   clusters along the board so nothing overhangs an edge.
5. **The eating board is `table.long_board` (2.3 m).** The 1.5 m household table
   could not hold place settings, the cleared stack, and the candle at once - the
   candle overhung the end. Two stools sit on the north side so the meal-beat
   approach cells **(7,11)** and **(8,11)** stay clear.
6. **Wash corner is furniture, not a puddle.** New `wash_tub` variant
   `wash.stand_basin`: oak stand, recessed pewter basin with the water plane
   **below** the rim, metal ewer, and a slate linen towel on a back rail. The
   yard `wash.yard_tub` is unchanged for well aprons and service plots.
7. **Wall hangings sit on plaster.** `cloak_banner` mounts on the living-bay west
   wall (`facing=east`, `visual_offset_px=-16,0` puts the bracket on the wall
   face at x = 1.0); `apron_hook` hangs on the same wall with `facing=east` so
   its 0.02 m panel is not seen edge-on.
8. **Chest turned along the west wall** under the window (`facing=east`) instead
   of standing a metre out on open floor.

### Routine consequences

| Activity | Change |
|---|---|
| `ap.prepare.board` | Now binds `kitchen_work_table`, approach **(6.5, 2.5)** facing north - prep happens at the bench by the fire, not at the eating board |
| `ap.hearth.tend` / `.cookpot` / `.bank` | Approach **(12.0, 2.5)** facing **north**; south of the mid-building brick hearth mouth |
| `ap.cat.warmth` | Moved to **(12.0, 3.5)** facing north, the open side of the fire |
| `ap.wash.basin` | Approach **(2.5, 2.5)** facing north, due south of the west-end wash stand |
| `ap.prepare.board` | Approach **(7.5, 2.5)** facing north at the trestle west of the fire |
| `ap.visitor.talk` | Faces **east** toward the single-cell `work_chair` at (11.5, 10.5) |

### Contract

`tests/godot/test_smithy_kitchen_dressing.gd` guards the yaw maths, the authored
`facing` values, the surface lifts, the reserved meal approach cells, the
furniture kits, and the sunk basin water. The fixture
`tests/fixtures/maps/kalev_smithy_domestic_life.json` gained
`surface_mounted_props` and `meal_approach_cells`.

**Known remaining gap:** the living bay is a 13 m × 12 m hall for one master
smith. That is generous for a Lower Town craft *boda* and leaves large empty
floor areas between furniture groups. Shrinking the interior shell would move the
spawn, transitions, camera rect, and every route test, so it is deliberately out
of scope here and recorded as a separate concern.

## Downstream task handoff

| Task | Depends on this plan |
|---|---|
| **P2-054** | `domestic_hearth` fixture spec and hood/flue treatment |
| **P2-055** | `kitchenware.*` stable IDs and place-setting groupings |
| **P2-056** | `provision.*`, `linen_folded`, `broom`, kindling, ash tools |
| **P2-057** | `.rrmap` prop placements in `LZ-C`–`LZ-G` without breaking protected routes |
| **P2-058** | Activity point table above |
| **P2-059** | Kalev player-facing vignette sequencing |
| **P2-060** | Henning visitor-only activity graph |
| **P2-061** | Mart absence/presence + cat anchors |

## Sources

1. [`history/dossiers/dailylife/food-and-drink.md`](../../history/dossiers/dailylife/food-and-drink.md) - staples, tiers, meal rhythm, kitchen equipment (project dossier, 2026-07-28).
2. [`history/dossiers/religion/liturgical-calendar-spring-1343.md`](../../history/dossiers/religion/liturgical-calendar-spring-1343.md) - Easter 1343 fast/meat boundary (project dossier).
3. [`history/dossiers/architecture/burgher-house-plan.md`](../../history/dossiers/architecture/burgher-house-plan.md) - diele/dornse, corner hearth, craft *boda* (project dossier, 2026-07-28).
4. [`history/dossiers/architecture/domestic-storage-furniture.md`](../../history/dossiers/architecture/domestic-storage-furniture.md) - chests, shelves, cupboards (project dossier, 2026-07-28).
5. [`history/dossiers/architecture/smithy-workshop-layout.md`](../../history/dossiers/architecture/smithy-workshop-layout.md) - forge/living partition, smoke separation (project dossier, 2026-07-28).
6. [`docs/SCENES/the-makers-mark.md`](../SCENES/the-makers-mark.md) - prologue occupancy, `mart_missing`, Henning visitor beat (project canon).
7. `content/maps/kalev_smithy.rrmap` - authoritative prop, anchor, transition, and terrain positions (project map).
8. Victoria and Albert Museum, **Chest** W.30-1926, 1200-1300 - portable household storage comparandum (cited via domestic-storage-furniture dossier).
9. Mendel Hausbuch I f. 120r / kitchen comparanda in [`history/reference/plates.csv`](../../history/reference/plates.csv) - hearth and workshop separation (public domain plates).
