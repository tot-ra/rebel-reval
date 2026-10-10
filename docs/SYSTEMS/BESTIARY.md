# Bestiary

Status: planned (task **R-1578**, epic **R-1577**). The roster, card format and validator are implemented; there are no creature cards yet and no runtime code reads the bestiary. Out of scope here: full cards (BST-2a/2b/3), concept art, 3D models, in-game spawning.

## What it is

One authoritative list of the beings the apprentice can meet, split by combat layer: `spirit` (spirit duel, [ADR 0033](../adr/0033-teen-protagonist-and-spirit-dialogue-combat.md)), `physical` (hybrid physical combat with guilt), `hybrid`, and `rejected`. Each kept entry has a stable `bst.<slug>` ID, a tier, a habitat and faction ties.

## Files

| Path | Role |
|---|---|
| [`docs/BESTIARY/README.md`](../BESTIARY/README.md) | Roster table and the keep/reject reasoning |
| [`docs/BESTIARY/TEMPLATE.md`](../BESTIARY/TEMPLATE.md) | Card format |
| `docs/BESTIARY/cards/<slug>.md` | One card per creature (none yet) |
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

## Limits

Eight physical and hybrid cards exist (BST-3); spirit cards are still planned. Archive image mapping follows the legacy README order and has not been reviewed visually. The layer of `kratt`, `libahunt` and `spirit_caller` as `hybrid` is a roster decision, not yet reflected in combat code.
