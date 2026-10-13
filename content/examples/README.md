# Content Examples

These files are schema fixtures for TODO P1-003, not final shipped content. They are intentionally small and representative:

- `valid/` contains one passing example for each schema type: character, dialogue, bark pool, quest, item, commission, location, and the P7-010 magic spell/rite/grant records.
- `support/` contains the additional referenced records that make `valid/` a complete semantic corpus without changing the representative P1-003 examples.
- `invalid/` contains one seeded failing example for each schema type so validation can prove negative cases are rejected, including a runtime-invented magic combination.

Spirit-duel word spells (`spirit_spell`, ADR 0048) have no `valid/` example: `ContentDB` maps the `spell.` prefix to pagan magic, so a `spell.word.*` record here would break every test that loads this corpus. The real catalogue in [`content/spirit_spells/`](../spirit_spells/README.md) is their valid corpus; `invalid/spell.word.three_lights.json` is the negative fixture.

The examples use the approved P0 canon and character brief data where possible. Dialogue and barks follow ADR 0003: authored offline strings, deterministic local selection, no runtime LLM dependency, and no free-text NPC chat.

Validate schema fixtures from the repository root:

```bash
python3 tools/validate_content_examples.py
```

Validate the complete example corpus for schemas, references, reachability, duplicate IDs, allowlisted conditions/effects, and `res://` assets:

```bash
python3 tools/validate_content.py content/examples/valid content/examples/support
```

Run the validator test suite:

```bash
python3 -m unittest tests.python.test_validate_content -v
```
