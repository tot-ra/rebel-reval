# Bestiary

Status: planned (task **R-1578**, epic **R-1577**). The roster, card format and validator are implemented; cards exist for every kept creature (36 in total, the latest `bst.hiie_hirv` in task **R-1757**; spirit and hybrid cards written from folklore and the legacy notes) and no runtime code reads the bestiary. Out of scope here: full cards (BST-2a/2b/3), concept art, 3D models, in-game spawning.

## What it is

One authoritative list of the beings the apprentice can meet, split by combat layer: `spirit` (spirit duel, [ADR 0033](../adr/0033-teen-protagonist-and-spirit-dialogue-combat.md)), `physical` (hybrid physical combat with guilt), `hybrid`, and `rejected`. Each kept entry has a stable `bst.<slug>` ID, a tier, a habitat and faction ties.

## Files

| Path | Role |
|---|---|
| [`docs/BESTIARY/README.md`](../BESTIARY/README.md) | Roster table and the keep/reject reasoning |
| [`docs/BESTIARY/TEMPLATE.md`](../BESTIARY/TEMPLATE.md) | Card format |
| `docs/BESTIARY/cards/<slug>.md` | One card per kept creature |
| [`docs/BESTIARY/inspiration/`](../BESTIARY/inspiration/) | Legacy pixel-art sketches kept only as inspiration (`.gdignore`d, not runtime art); roster Images column refers to these |
| [`assets/bestiary/README.md`](../../assets/bestiary/README.md) | Legacy archived list, points to the roster |
| `tools/validate_bestiary_cards.py` | Validator |
| `tests/python/test_validate_bestiary_cards.py` | Validator tests |

## Verify

```bash
python3 tools/validate_bestiary_cards.py
python3 -m unittest tests.python.test_validate_bestiary_cards -v
```

The validator checks the roster (unique `bst.` IDs, layer and tier enums, a reason on every row, a card link that exists and carries the same ID, rejected rows with no card) and every card (section order, field table, ID, layer, tier agreeing with the roster).

## Work plan

- BST-2a / BST-2b: spirit cards, in tier order.
- BST-3: physical adversary cards (done, task **R-1581**: street thug, saboteur, brute, road bandit, Black Cloak fighter, spirit-caller, Vanapagan cultist, wolf; bear and boar stay backlog).
- Later: concept art, 3D models, an `EnemyArchetype` link for physical entries.

## Meshy model pilot (Kratt)

Status: experiment for task **R-1585** (BST-6), not installed. It tests whether Meshy AI image-to-3D can stand in for a hand-built Blender creature.

- Input: the card's concept art `docs/BESTIARY/inspiration/kratt_concept.jpg`. Tool: `meshy_generate_3d` (image-to-3D, textured, PBR), about 100 s and 30 credits per run.
- Output in `generated/meshy/kratt_v1/`: `kratt_meshy_40k.glb` (40k triangles, 1.8 m tall, feet at origin, 1024 base colour, metallic-roughness and normal maps, 1.8 MB), Meshy previews, and `kratt_raw_vs_40k.jpg` (raw render next to the decimated one, front and back). `record.json` holds the Meshy task IDs, settings, SHA-256 of the gitignored 30-70 MB raw downloads, and the decimation steps.
- Result: the silhouette, straw, pitchfork, rope and the amber chest knot match the concept from every side, and decimating 2.1M to 40k triangles shows no visible loss. Meshy copies the concept's mistakes, though. The concept draws a skull face, but the card asks for a hollow head with no face or mouth. A scythe-blade hand is missing too. Fix the concept image first, then rerun.
- Not done: no rig or clips, no spirit material, no Godot import (`generated/meshy/.gdignore`), no `assets/SOURCES.csv` row. These come with the R-1585 install.

## Limits

Eight physical and hybrid cards exist (BST-3); every kept spirit row has a card (22, including `bst.hinged`, `bst.virmalised` and `bst.hiie_hirv`). Archive image mapping follows the legacy README order and has not been reviewed visually. The layer of `kratt`, `libahunt` and `spirit_caller` as `hybrid` is a roster decision, not yet reflected in combat code.
