# Almshouse prologue content (SD-05, ADR 0033)

Prototype prologue records for the teen-protagonist opening ([`SPIRIT_DIALOGUE.md`](../../docs/SYSTEMS/SPIRIT_DIALOGUE.md)). One location (the almshouse at the Holy Spirit parish), offline authored text, no map activation.

| ID | File | Role |
|---|---|---|
| `dialogue.prologue.almshouse_quarrel` | `dialogue.prologue.almshouse_quarrel.json` | Matron and porter quarrel (observation mode, SD-06); not played by the opening any more, kept for tests and reuse |
| `dialogue.prologue.porter_confrontation` | `dialogue.prologue.porter_confrontation.json` | The hero's first own duel: every reply is a starter spell (`spell_id`) voiced by a short line, plus the physical option (`[Shove him away]`, sets `flag.prologue.struck_porter` for the guilt hook, SD-07) |
| `dialogue.prologue.kalev_arrives` | `dialogue.prologue.kalev_arrives.json` | Kalev takes the apprentice (starts at Kalev's first line); sets `flag.prologue.apprenticed` |
| `char.apprentice`, `char.almshouse_matron`, `char.almshouse_porter` | `character.*.json` | Cast records for the prologue |

Validate with the support pack and the example corpus:

```bash
python3 tools/validate_content.py content/prologue content/examples/support content/examples/valid
```
