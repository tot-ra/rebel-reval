# Quest packages (P4-018 / P1-038)

Agent-authorable quest bundles combine a quest record, optional dialogue/support
files, a branch map, and stable landmark or map-anchor bindings.

Each package directory contains:

- `package.json` - manifest with `type: quest_package`
- `quest.json` - schema-valid quest record
- `branch_map.json` - declared traversal branches for generated tests
- optional dialogue/support JSON referenced by the manifest

Validate a package corpus and emit branch-traversal Godot tests:

```bash
python3 tools/verify_quest_packages.py content/packages/act1_south_quarter_probe
python3 tools/generate_quest_package_tests.py --check
python3 tools/validate_content.py \
  content/packages/act1_south_quarter_probe/content \
  content/examples/support
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_quest_package_act1_south_quarter_probe
```
