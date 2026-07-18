# Released Save Fixtures

These JSON files are the published save-slot compatibility corpus for P1-008. They are not player saves from `user://`; they are versioned fixtures that CI and headless tests must load without migration errors.

- `released/` contains one loadable envelope per named demo or compatibility checkpoint.
- `released_manifest.json` is the authoritative list exercised by `tests/godot/test_save_envelope.gd`.

Validate from the repository root:

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_save_envelope
```

Every manifest row must keep loading after game-state schema changes. When the envelope or game-state version changes, add a migration step in `scripts/save/save_envelope.gd`, update affected fixtures, and extend the tests.
