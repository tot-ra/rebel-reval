# Demo content (D-002 / D-003)

Authored JSON for the MVP demo interaction loop. These records are schema-valid, deterministic, and engine-independent. Runtime wiring loads them through `ContentDB` and the demo scripts under `scripts/demo/`.

| ID | File | Used by |
|----|------|---------|
| `dialogue.demo.mart_street` | `dialogue.demo.mart_street.json` | D-002 via `DemoMartEncounter` / `DemoDialogueRunner` |
| `item.forge_hammer` | `item.forge_hammer.json` | D-003 forge-hammer pickup and bag overlay (`docs/INVENTORY_MECHANICS.md`) |

Support character records live in `content/examples/support/` so the demo corpus and the validated example corpus share one canon source. Validate the demo slice together with that support pack:

```bash
python3 tools/validate_content.py content/demo content/examples/support content/examples/valid
```

Expected result: exit code `0` with no diagnostics.
