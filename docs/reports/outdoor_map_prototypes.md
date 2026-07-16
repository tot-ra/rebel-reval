# Inactive outdoor map prototypes

Recorded: 2026-07-16  
Decision: `docs/adr/0005-inactive-outdoor-map-prototypes.md`  
Status: verified non-playable prototypes

## Scope result

No outdoor location was approved or activated as a playable area. The legacy `.tscn` shells retain their archive disposition. Every new definition is forced to `scope=prototype`, `active=false`, has no gameplay transition, and is absent from Start, `content/transitions/active_destinations.json`, and release traversal.

## Package matrix

| Package | Maps | Distinct layout landmarks |
|---|---|---|
| Coast/harbor | Reval harbor surroundings; Paldiski | Great Coast Gate, warehouse row, quay crane, twin piers; timber outpost hall, shipyard, long pier |
| Villages/monasteries | Harju village; Padise | split fields, village well, threshing barn; church, cloister, gatehouse, work yard |
| Castles | Haapsalu, Paide, Viljandi, Poide, Maasilinna, Karja | shared gate/curtain/keep/yard grammar plus a location-specific bishop castle, limestone tower, storehouse, chapel, coastal keep, or earthwork/palisade landmark |
| Wilderness/events | sacred grove; Pärnu; Pskov arrival; rebel kings camp; Saaremaa; Swedish outpost; Swedish arrival | ancient oak/stone/spring; bounded camp, barricade, shore, signal, or stockade compositions without army/fleet simulation |

Padise before/after is phase metadata on one definition, not duplicated geometry. Maasilinna is labelled as a post-uprising concept. Sacred-grove landmarks remain ambiguous physical traces and add no supernatural mechanics.

## Terrain vocabulary

The outdoor extension adds common material classes only: meadow, farm soil, straw, coast sand, mud, forest floor, bog, shallow/deep water, and castle paving. Existing grass, hay, dirt, sand, water, stone, and cobblestone remain reusable. Snow is excluded.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/capture_outdoor_maps.gd
python3 tools/verify_outdoor_prototypes.py
python3 -m unittest tests.python.test_verify_outdoor_prototypes -v
```

Results:

- 17 definitions validate and remain inactive.
- Full terrain coverage for every cell.
- At least three non-overlapping landmarks per map.
- Every structure collision equals its declared footprint.
- Stable `prototype_inspection` spawn and route avoid hard exclusions.
- Fingerprints reproduce across two builds.
- 17 procedural PNG captures at 1600 x 900 exist under `docs/reports/images/outdoor/`.
- Full Godot suite: 85 tests, 0 failures, 0 errors, no `SCRIPT ERROR`.
