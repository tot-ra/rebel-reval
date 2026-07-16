# Content Examples

These files are schema fixtures for TODO P1-003, not final shipped content. They are intentionally small and representative:

- `valid/` contains one passing example for each schema type: character, dialogue, bark pool, quest, item, commission, and location.
- `support/` contains the additional referenced records that make `valid/` a complete semantic corpus without changing the representative P1-003 examples.
- `invalid/` contains one seeded failing example for each schema type so validation can prove negative cases are rejected.

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
