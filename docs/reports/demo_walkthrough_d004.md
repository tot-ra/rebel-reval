# Demo walkthrough (D-004)

Captured proof that the packaged demo loop completes without debug intervention:
Start -> forge move -> Lower Town Mart talk -> forge spearhead pickup into the bag.

## How to reproduce

```bash
tools/verify_packaged_demo.sh
# or capture frames only:
godot --path . res://tools/capture_demo_walkthrough_host.tscn
```

## Frame sequence

| Step | Capture | What it shows |
|------|---------|---------------|
| 1 | ![forge start](images/demo_walkthrough/01_forge_start.png) | Main-menu Start lands at `smithy_start` |
| 2 | ![forge move](images/demo_walkthrough/02_forge_move.png) | Player can move in the forge |
| 3 | ![lower town](images/demo_walkthrough/03_lower_town_arrive.png) | Courtyard door reaches Lower Town |
| 4 | ![mart talk](images/demo_walkthrough/04_mart_talk.png) | Talk to Mart opens demo dialogue |
| 5 | ![mart done](images/demo_walkthrough/05_mart_done.png) | Conversation completes and sets `flag.demo_mart_spoken` |
| 6 | ![pickup](images/demo_walkthrough/06_spearhead_pickup.png) | Anvil spearhead is taken into the bag |

## Automated checks

- Headless flow: `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_demo_walkthrough`
- Packaged macOS build: `tools/verify_packaged_demo.sh` exports `build/rr.dmg`, extracts `build/Reval Rebel.app`, and confirms the binary launches.

Release builds omit the debug inspector (`OS.is_debug_build()` is false), so this loop matches packaged play without debug presets.
