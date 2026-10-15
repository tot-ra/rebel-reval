# Almshouse prologue content (SD-05, ADR 0033)

Prototype prologue records for the teen-protagonist opening ([`SPIRIT_DIALOGUE.md`](../../docs/SYSTEMS/SPIRIT_DIALOGUE.md)), played in the Holy Spirit almshouse sick-room of the seamless city (ADR 0052). Offline authored text.

| ID | File | Role |
|---|---|---|
| `dialogue.prologue.almshouse_quarrel` | `dialogue.prologue.almshouse_quarrel.json` | Matron and porter quarrel (observation mode, SD-06); not played by the opening any more, kept for tests and reuse |
| `dialogue.prologue.porter_confrontation` | `dialogue.prologue.porter_confrontation.json` | The hero's first own duel: every reply is a starter spell (`spell_id`) voiced by a short line, plus the physical option (`[Shove him away]`, sets `flag.prologue.struck_porter`, recorded as guilt by the opening, R-1335). Each ending sets its flag: `spared_porter`, `broke_porter`, `punished_by_porter`, `struck_porter`. `duel.topic` `rusted_key` (the key and the boy's place) holds 2-3 lines per element; on-topic replies carry `topic_tags` (R-1389, ADR 0038) |
| `dialogue.prologue.lambert_carried_in` | `dialogue.prologue.lambert_carried_in.json` | ADR 0052 beat 2: at dusk Gertrud has the wounded watchman laid on the sickbed, sends for Kalev and sets the boy at the bed. `entry_variants` open on her reaction to the porter ending (`matron_heard_struck`, `matron_heard_broke`, `matron_heard_punished`), then `matron_vespers` (R-1335 echo) |
| `dialogue.prologue.lambert_fear` | `dialogue.prologue.lambert_fear.json` | ADR 0052 beat 2: the healing duel with Lambert's fear (topic `the_flight`). Endings `resolved_calmed` (`flag.prologue.lambert_calmed`) and `resolved_frightened` (`flag.prologue.lambert_frightened`) |
| `dialogue.prologue.kalev_arrives` | `dialogue.prologue.kalev_arrives.json` | ADR 0052 beat 3: Kalev finds his mark on the spearhead (`flag.prologue.saw_makers_mark`), speaks the origin-of-iron charm (`plausible composite`, see its `source_notes`) and takes the apprentice (`flag.prologue.apprenticed`). `entry_variants` open on the healing duel's ending (`kalev_heard_screaming`, `kalev_found_quiet`), then `kalev_kneels` |
| `char.apprentice`, `char.almshouse_matron`, `char.almshouse_porter`, `char.watchman_lambert` | `character.*.json` | Cast records for the prologue |

Validate with the support pack and the example corpus:

```bash
python3 tools/validate_content.py content/prologue content/examples/support content/examples/valid
```
