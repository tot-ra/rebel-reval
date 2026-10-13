# Spirit spells (R-1913, ADR 0048)

Catalogue of the psychological word spells of the spirit duel: one record per spell, id `spell.word.<slug>`, type `spirit_spell` ([`schemas/spirit_spell.schema.json`](../../schemas/spirit_spell.schema.json)). Design and rules: [`SPIRIT_DIALOGUE.md`](../../docs/SYSTEMS/SPIRIT_DIALOGUE.md#psychological-spells-and-willpower-planned). Loaded read-only by `SpiritSpellCatalog` (`scripts/combat/spirit_spell_catalog.gd`); nothing reads it in play until SPL-2 (R-1914) and SPL-4 (R-1916).

Each record has `element`, `light_vector` (one or two `aspect.*` lights with a signed delta -2..+2, never 0), willpower `cost` 1..3, `kind` (`lowering` / `raising` / `mixed`, must agree with the delta signs), `starter`, optional `guilt` weights (`church` / `folk` / `civic`) and `lines` keyed `answer.<move kind>`, `topic.<topic id>`, `weak` or `default` (required). The element must be guarded by one of the spell's lights (awareness guards none). The five starters are today's word spells, one per slot element (fear, shame, duty, love, faith), each its own light at -2 for 1 willpower.

All numbers are prototype values (ADR 0048 decision 4). Lines are authored offline; SPL-5 (R-1917) adds the `answer.*` and `topic.*` contexts.

```bash
python3 tools/validate_content.py content/spirit_spells
```
