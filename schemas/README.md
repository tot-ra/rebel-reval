# Content JSON Schemas

This directory defines the first machine-readable content contract for Reval Rebel content records:

- `character.schema.json`
- `dialogue.schema.json`
- `bark.schema.json`
- `quest.schema.json`
- `item.schema.json`
- `commission.schema.json`
- `location.schema.json`
- `common.schema.json`

The schemas encode the P0 canon confidence labels (`attested`, `plausible composite`, `folklore`, `invented`), stable dotted IDs, editorial approval status, declarative conditions/effects, and ADR 0003's deterministic authored offline dialogue rule. Runtime LLM calls, free-text NPC chat, arbitrary GDScript in content, and non-deterministic bark selection are intentionally outside the schema contract.

Representative examples live in `content/examples/valid/`, records completing their cross-file references live in `content/examples/support/`, and seeded negative schema fixtures live in `content/examples/invalid/`. See `content/examples/README.md` for both schema-only and full semantic validation commands.

Run validation with:

```bash
python3 tools/validate_content_examples.py
```

Expected result: every valid example passes and every invalid example fails.
