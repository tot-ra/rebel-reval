# Burgher house typology contract (P0-163)

Production authoring contract that turns
[`history/dossiers/architecture/burgher-house-plan.md`](../../history/dossiers/architecture/burgher-house-plan.md)
(R-003) into closed map/art keys. Downstream kits: **A-008**, **P2-063**–
**P2-067**, then **P0-102** / **P0-101**.

## Closed `house_tier` allowlist

| `house_tier` | Meaning | R-003 confidence | Storeys | Hoist / loading hatch | Hypocaust default |
|---|---|---|---|---|---|
| `merchant_stone` | Affluent stone or mixed street front, diele-dornse + cellars | attested typology; per-house material mix **plausible composite** | 2–3 | allowed (merchant only) | affluent houses **plausible composite** |
| `merchant_timber` | Ordinary timber or plastered-timber craft/merchant front on 7–11 m strip | attested wood/stone coexistence | 2 typical | allowed when hatch+winch authored; not default granary crane | usually no |
| `craft_boda` | Compact two-room workshop-dwelling (*boda*) | attested type; exact 1343 dims **unknown** | 1–2 | forbidden | forbidden |

Runtime constants live in `MapPropStyleVariants.HOUSE_TIERS`. Unknown values fail
compilation with the stable diagnostic `house_tier is unknown: <value>`.
Omitting `house_tier` remains legal until Lower Town wiring (**P2-067**) assigns
tiers; unset houses keep deterministic hash wall/roof styles.

## Ground-floor depth split

For merchant and craft front houses on strip plots (R-003 Brief ship decision 2;
**plausible composite**):

- **diele** (street-side workshop-shop hall): ~55–65% of footprint depth from street
- **dornse** (private rear room): ~35–45% of footprint depth toward yard
- Sequence: street → cellar neck / low terrace → diele → chimney-kitchen zone → dornse → rear yard gate

`craft_boda` uses the same street→workroom→sleeping-nook logic without a full
diele-dornse merchant volume.

## Massing and envelope rules

1. **Gable to street**, ridge perpendicular to the lane (Brief 1).
2. **Steep roof pitch** (~45° vernacular analogy) - Brief 1 / [12].
3. Frontage rhythm **7–11 m** from R-001 / R-003 strip plots.
4. **Rear yard** on merchant plots: budget **8–15 m** depth minimum where block
   depth allows (R-003 Production hooks; **attested** plot shell, depth band
   **plausible composite**).
5. Plot walls / fences ~3 m limestone or timber/wattle (Brief 10).

## 1343-safe windows, roofs, hoist

| Domain | Allowed | Rejected (tourist / late defaults) |
|---|---|---|
| Windows | Ground pointed-arch stone openings on stone fronts; smaller upper openings; hatches on storage floors; timber: smaller shuttered/glazed openings | Late-Gothic four-light stone crosses, rich blind niches, mouchettes, 15th-c. display facades as the ordinary default |
| Roofs | Tile on affluent stone/civic masses; shingle and thatch on ordinary timber and service buildings | Tiling every roof; contiguous shared roofing treated as universal in 1343 |
| Hoist | Protruding wooden hoisting beam + loading hatch + interior winch on merchant tiers only | Hoist/granary crane on `craft_boda`; modern restaurant crane theatre |

## Ward material bias (April 1343)

| Ward bias | Prefer | Roof band |
|---|---|---|
| Pikk / market merchant | More `merchant_stone` and stone cellars/rear houses; timber fronts still common | More tile on stone masses |
| Viru / craft edge | More `merchant_timber` and `craft_boda` | More shingle/thatch |
| *Boda* renters | `craft_boda` | Thatch/shingle |

Exact citywide wood-to-stone percentage remains **unknown** (R-003 / H04). Vary by
wealth and ward; do not skin every 1343 timber front with surviving 15th-c. Gothic
stone.

## Rejection rules (authoring)

Compilers reject unknown `house_tier` values. Human/map review must also reject:

1. Late-Gothic tourist facade defaults on ordinary Lower Town fabric.
2. Hoist hardware on `craft_boda`.
3. Hypocaust as default on craft *boda*.
4. Post-1400 four-light crosses / blind niche enrichment as the Spring 1343 default.
5. Peppersack modern restaurant interiors as 1343 prop licence.
6. Scaled-up ordinary-house variants used as churches, guild halls, or gates
   (exceptional landmarks stay on the separate landmark path).

## Parser / compiler wiring

- rrmap typed key: `house_tier=<name>` on `building` / house `style` blocks
  (`MapRrmapParserTokens.STYLE_NAME_KEYS`).
- Compiler allowlist: `MapBlueprintCompiler.BUILDING_OVERRIDE_KEYS` and
  `ALL_STYLE_KEYS`.
- Validation: `MapBlueprintCompilerExpandGeometry.append_building` via
  `MapPropStyleVariants.is_known_house_tier`.
- Compiled field copied onto `MapDefinition.buildings[]` for mesh-builder selection
  in **P2-067**.

## Verification

```bash
export GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- --filter=test_burgher_house_typology_contract
```
