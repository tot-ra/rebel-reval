# Merchant cart and road-transport contract (P0-164)

Production authoring contract that turns
[`history/dossiers/economy/merchant-cart-and-transport-1340s.md`](../../history/dossiers/economy/merchant-cart-and-transport-1340s.md)
(R-068) and the R-069 toll gap in
[`reval-cart-tolls-and-fuhr-rent-1340s.md`](../../history/dossiers/economy/reval-cart-tolls-and-fuhr-rent-1340s.md)
into closed map/art/dev keys. Downstream kits: **A-010**, **A-004**, **P2-068**–
**P2-070**, **P4-037**, **P4-038**.

## Closed `vehicle_class` allowlist

| `vehicle_class` | Meaning | R-068 confidence | Default corridor use | Draught |
|---|---|---|---|---|
| `cart_2w` | Two-wheel horse *Karren* - open front, lattice/wicker sides, hinged rear gate | plausible composite; track ~1.3 m from Tallinn rut find **plausible composite** | **Default** urban supply on lanes, forum, harbour approach | single horse in shafts |
| `wagon_4w` | Four-wheel freight wagon for timber/stone/bulk | plausible composite | Harbour margin and wall yards only - not alley default | 2–4 horses |
| `barrow` | Hand / sack barrow | plausible composite | Forum throat and shop diele | human porter |
| `sledge` | Winter / mud-season runners | plausible composite | Harju winter road and mud bypass - not late-April cobble default | horse |

Runtime constants live in `MapPropStyleVariants.VEHICLE_CLASSES`.
`DEFAULT_URBAN_VEHICLE_CLASS` is `cart_2w`. Unknown values fail compilation with
the stable diagnostic `vehicle_class is unknown: <value>`. Omitting
`vehicle_class` remains legal until kit wiring (**P2-068**) assigns classes;
unset `cart` / `farm_cart` props keep the legacy wooden_cart mesh.

## Metric and systems constants

| Key | Value | Source / confidence |
|---|---|---|
| `wheel_rut_spacing` | **1.3 m** (`WHEEL_RUT_SPACING_M`) | Tallinn cart-path wheelbase 1.26–1.40 m **attested** find; 1343 application **plausible composite** (R-068) |
| `cart_path_width_min` | **2.5 m** (`CART_PATH_WIDTH_MIN_M`) on Vanaturg forum throat | R-068 map hook **plausible composite** |
| `cart_toll_pfennig` | **null** (`cart_toll_pfennig()` / `CART_TOLL_ATTESTED = false`) | R-069 **gap**: no AWB/council *Wagenzoll* / *Radsteuer* / *Fuhrpacht* line 1340–1343 |
| `carter_hire_schilling` | 4–12 band (systems **P4-037**) | R-069 **plausible composite** |
| `load_kg` cap | 250–350 for `cart_2w` (systems **P4-037**) | R-068 **plausible composite** |

## Corridor allowlist

| Corridor id | Role | April 1343 note |
|---|---|---|
| `vanaturg_throat` | Cart queue, barrel roll | Active pre-siege; congested after 23 Apr |
| `pikk_lai_delivery` | Shop / smith stock delivery | Single-cart width - no twin passing |
| `harbour_margin` | Barrel and timber bulk; optional `wagon_4w` | Lighter-to-cart may continue under siege |
| `viru_apron` | Inbound Harju grain queue | Mark stallable post–23 Apr |
| `harju_road` | Manor corvée grain / livestock | Rebel countryside - unsafe late April |

Back lanes under **3 m** clear width must not stage twin-cart passing (R-001 /
R-068). Tag cobbled lanes that carry wheeled traffic with `wheel_rut_spacing`
contract spacing in corridor authoring (**P2-069**).

## April 1343 load bands

| Direction | Loads | Confidence |
|---|---|---|
| Inbound | Grain sacks, beer barrels, salt kegs, iron-bar bundles, charcoal sacks | R-068 / trade season **plausible composite** |
| Outbound | Hemp/flax bales, hides, empty barrels | same |
| Post–23 Apr | Inland grain/charcoal carts **stall**; harbour lighter-to-cart may continue | R-068 / R-069 **plausible composite** |

## Rejection rules (authoring)

Compilers reject unknown `vehicle_class` values. Human/map review must also reject:

1. War-wagon / Hussite missile-platform silhouettes as supply traffic.
2. Ox teams as the default urban burgher draught (horse only for town supply).
3. Invented **gate toll booths** or pfennig-per-wheel UI (R-069 gap).
4. Municipal **dung-cart livery** as an attested 1343 Reval roster (parallel AWB gap).
5. Coach springs, rubber tyres, Conestoga covers, Victorian spring carts.
6. `wagon_4w` as the default alley / forum vehicle (harbour or wall yard only).

## Parser / compiler wiring

- rrmap typed key: `vehicle_class=<name>` on `prop` / cart `style` blocks
  (`MapRrmapParserTokens.STYLE_NAME_KEYS`).
- Compiler allowlist: `MapBlueprintCompiler.PROP_OVERRIDE_KEYS` and
  `ALL_STYLE_KEYS`.
- Validation: `MapBlueprintCompilerExpand._expand_prop` via
  `MapPropStyleVariants.is_known_vehicle_class`.
- Compiled field copied onto `MapDefinition.props[]` for mesh-builder selection
  in **P2-068** / **P2-070**.

## Verification

```bash
export GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_merchant_cart_transport_contract
```
