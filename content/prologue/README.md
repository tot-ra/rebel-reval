# Almshouse prologue content (SD-05, ADR 0033)

Prototype prologue records for the teen-protagonist opening ([`SPIRIT_DIALOGUE.md`](../../docs/SYSTEMS/SPIRIT_DIALOGUE.md)). One location (the almshouse at the Holy Spirit parish), offline authored text, no map activation.

| ID | File | Role |
|---|---|---|
| `dialogue.prologue.almshouse_quarrel` | `dialogue.prologue.almshouse_quarrel.json` | Matron and porter quarrel (observation mode, SD-06); not played by the opening any more, kept for tests and reuse |
| `dialogue.prologue.porter_confrontation` | `dialogue.prologue.porter_confrontation.json` | The hero's first own duel: every reply is a starter spell (`spell_id`) voiced by a short line, plus the physical option (`[Shove him away]`, sets `flag.prologue.struck_porter`, recorded as guilt by the opening, R-1335). Each ending sets its flag: `spared_porter`, `broke_porter`, `punished_by_porter`, `struck_porter`. `duel.topic` `rusted_key` (the key and the boy's place) holds 2-3 lines per element; on-topic replies carry `topic_tags` (R-1389, ADR 0038) |
| `dialogue.prologue.kalev_arrives` | `dialogue.prologue.kalev_arrives.json` | Kalev takes the apprentice; sets `flag.prologue.apprenticed`. `entry_variants` open on Kalev's reaction to the duel ending (`kalev_heard_struck`, `kalev_heard_broke`, `kalev_heard_punished`), then `kalev_looks` (R-1335) |
| `char.apprentice`, `char.almshouse_matron`, `char.almshouse_porter` | `character.*.json` | Cast records for the prologue |

Validate with the support pack and the example corpus:

```bash
python3 tools/validate_content.py content/prologue content/examples/support content/examples/valid
```
