# Inventory mechanics

Status: **prototype** - grid bag overlay for the demo and vertical-slice foundation. Replaces the D-003 "minimal inventory display" shortcut and feeds the later P2-015 quest pouch (separate, capped quest-item strip).

## Player-facing model

Kalev carries one **bag** with two independent limits:

| Limit | Default | Player sees |
|-------|---------|-------------|
| **Volume** | 8 x 5 grid (40 cells) | Filled cells in the bag overlay |
| **Weight** | 28 kg | Weight meter; also slows movement |

Items occupy rectangular footprints on the grid (`grid_width` x `grid_height`). Small light items (evidence shards, supplies) use 1x1 cells and weigh under 0.5 kg. Tools and weapons use larger footprints and more weight. A forge hammer is 2x2 and 4.5 kg.

**Encumbrance:** movement speed scales linearly from 100% at empty load to 65% at the weight cap. Volume does not slow the player directly, but a full grid blocks new pickups.

Open the bag with **I**; close with **I** or **Esc**. While open, movement is paused so the player can rearrange items.

## Relationship to other systems

| System | Role |
|--------|------|
| `GameState.bag` | Physical inventory for a session |
| `GameState.add_item` / `has_item` | Quest and content-rule ownership flags (unchanged) |
| P2-015 quest pouch | Future HUD strip for at most three visible quest tools; not the bag |
| `content/*.json` `gameplay.carry` | Authored weight and grid footprint per item |
| `SessionState` autoload | Holds `GameState` and `ContentDB` across map transitions within a session |

Pickup wiring (D-003) should call `GameState.bag.try_add(item_id)` and, on success, `GameState.add_item(item_id)` so quest conditions and the bag stay aligned.

## Content authoring

Optional `gameplay.carry` block on item records:

```json
"carry": {
  "weight_g": 1100,
  "grid_width": 1,
  "grid_height": 2
}
```

When omitted, category defaults apply (see `ItemCarryProfile.DEFAULTS_BY_CATEGORY`).

Stackable items (`gameplay.stackable: true`) share one grid cell and stack up to 20 units; each unit adds full item weight.

## Implementation map

| File | Responsibility |
|------|----------------|
| `scripts/state/inventory_bag.gd` | Placement, limits, encumbrance multiplier |
| `scripts/state/item_carry_profile.gd` | Resolve carry stats from content or defaults |
| `scripts/inventory/inventory_overlay.gd` | Bag UI (grid, meters, move-by-click) |
| `scripts/inventory/inventory_controller.gd` | `toggle_inventory` input on the player |
| `scripts/session/session_state.gd` | Session `GameState` and demo content load |
| `scripts/player.gd` | Applies encumbrance to walk/run speeds; blocks movement while bag is open |

## Verification

```bash
godot --headless --path . --script tools/run_godot_tests.gd
python3 tools/validate_content.py content/demo content/demo/support content/examples/valid content/examples/support
```

Manual: run the game, press **I**, confirm seeded demo items, drag items by click-select then click destination, and walk with a heavy bag to feel slower movement.
