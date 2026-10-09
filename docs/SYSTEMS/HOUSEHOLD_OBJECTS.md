# Household objects

Status: data implemented, runtime planned (task **R-1367**, HOMEOBJ-1, parent R-1366). Scope: a closed vocabulary of household needs and the objects that serve them per wealth tier. Out of scope: art for the new objects, player verbs, and any layout code that reads the table (later HOMEOBJ tasks).

## What exists

- `content/objects/_household_needs.json`: 14 needs (sleep, eat, drink, wash, warmth, light, cook, clothe, store, work, faith, safety, money, child), each with `poor`, `mid` and `rich` lists. At most 3 distinct catalog objects per need and tier. `count_per_resident` is a quota (fractions such as 0.25 mean one shared fixture per four residents). Counts are authoring estimates, not historical claims.
- `schemas/household_needs.schema.json`: structure of that table.
- 13 new `planned` catalog records (no model, no icon): blanket_wool, bolster_straw, chamber_pot, kirtle_wool, wall_peg_rail, pot_crane, ladle_wood, tinderbox, hatchet, dagger_belt, root_veg_basket, spindle_distaff, crucifix_wall. Mass, size and price are estimates. The other seven TOP-20 objects (tunic_wool, leather_boots, sword_cruciform, coin_purse, iron_key, ale_tankard, sack_grain) already existed.
- `ContentDB` skips JSON files whose name starts with `_`, since they are authoring tables and not typed records.

## TOP-20 by need served

1 blanket_wool (sleep), 2 bolster_straw (sleep), 3 chamber_pot (wash), 4 tunic_wool (clothe), 5 kirtle_wool (clothe), 6 leather_boots (clothe), 7 wall_peg_rail (store), 8 pot_crane (cook), 9 ladle_wood (cook), 10 tinderbox (light), 11 hatchet (warmth, safety), 12 dagger_belt (safety), 13 sword_cruciform (safety), 14 coin_purse (money), 15 iron_key (store), 16 ale_tankard (drink), 17 sack_grain (eat), 18 root_veg_basket (eat), 19 spindle_distaff (work), 20 crucifix_wall (faith).

Follow-ups, each its own task: cradle, shears and needle kit, wax tablet, saint figure, protective charm, crossbow, spear_watch, wall_torch, hanging lantern, cheese, apple, honey, smoked fish models.

## Verification

```bash
python3 tools/validate_object_catalog.py
python3 -m unittest tests.python.test_object_catalog -v
```

`HouseholdNeedsTests` covers unknown and duplicate ids, missing need or tier, empty or over-full lists, bad counts and malformed files.

## Limits

- `HouseholdLayout` does not read the table yet.
- The catalog validator and test suite had pre-existing failures before this task (missing preview images, missing legacy equipment GLBs: 124 problems). This task adds none.
