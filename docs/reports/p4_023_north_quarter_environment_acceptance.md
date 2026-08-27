# P4-023 North Quarter environment acceptance

**Map:** `north_quarter`
**Status:** environment composition delivered; activation remains blocked
**Historical target:** Spring 1343 Reval

The district now enforces the P0-072/P1-036 composition card instead of skipping it. The map remains `active=false`, and the activation manifest remains `implementation_delivered=false` until P4-023f signed day/night captures, population/activity profiles, seam evidence, and gameplay evidence are accepted.

## Implemented environment contract

- Pikk remains the narrow cobbled market-to-port spine; Lai and work lanes remain earth routes.
- Merchant property closes use rubble/local limestone without creating a blanket cobblestone field.
- Dense front and rear property ranges fill inherited map-scale voids while preserving Pikk/Lai, merchant courts, patrol points, transitions, livestock courts, and the extramural road.
- Material styles remain mixed across timber, plank, plaster, limestone, shingle, thatch, and tile.
- The Coastal Gate keeps the conservative 1343 single completed tower, timber-leaf opening, low curtain profile, and excludes Fat Margaret and later barbicans.
- Relief continues to fall toward the harbour while the gate sits on a raised sill.

## Measured P1-036 result

The focused `MapCompositionAudit` result is clean with:

- built density: `46.04%` (target `45-60%`)
- stone surface: `30.67%` (target `30-45%`)
- earth surface: `48.88%` (target `35-50%`)
- grass surface: `20.45%` (target `15-25%`)
- cobblestone: `2.85%` (cap `5%`)
- maximum material-style share: `31.75%` (cap `35%`)
- largest unexplained empty region: `7,419` cells (cap `12,000`)
- elevation range: `1.49` (minimum `0.3`)

Intentional route, yard, and verge space is declared in `docs/data/north_quarter_authoring_contract.json`; exclusions do not change density or surface measurements.

## Remaining activation gates

Signed day/night captures and visual review remain owned by P4-023f. Population/activity profiles, reciprocal monastery-wall evidence, and gameplay loop/interaction evidence also remain blocked. This handoff therefore does not activate either North Quarter or Monastery Quarter.
