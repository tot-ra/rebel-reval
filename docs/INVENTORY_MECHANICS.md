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

Open the bag with **I**; close with **I**, **Esc**, or the overlay Close button. While open, movement is paused so the player can rearrange items. Move the grid selection with arrow keys or **WASD**; **Enter** or **Space** picks up or places the focused item (same as clicking a cell). The overlay shows exact burden (`kg`) and stowage (`cells`), short item labels on the grid, tooltips with full names, and a nine-socket worn-gear paper doll for head, back, body, arms, belt, legs, feet, and both hands. Visual styling follows the oak/brass/parchment HUD tokens in `InventoryUiTheme`; scalable chamfered brasswork and corner fittings give the satchel a richer late-medieval frame without resolution-specific texture assets.

## Relationship to other systems

| System | Role |
|--------|------|
| `GameState.bag` | Physical inventory for a session |
| `GameState.add_item` / `has_item` | Quest and content-rule ownership flags (unchanged) |
| P2-015 quest pouch | HUD strip (top-left) for at most three `visible_in_pouch` quest tools; separate from the bag grid |
| `content/*.json` `gameplay.carry` | Authored weight and grid footprint per item |
| `SessionState` autoload | Holds `GameState` and `ContentDB` across map transitions within a session |

Pickup wiring (D-003) should call `GameState.bag.try_add(item_id)` and, on success, `GameState.add_item(item_id)` so quest conditions and the bag stay aligned.

## Equipment placement (design)

Status: **implemented.** The inventory supports nine logical sockets (`head`, `back`, `body`, `arms`, `belt`, `legs`, `feet`, `left_hand`, `right_hand`). The current 3D rig mirrors the four rigid attachment sockets `right_hand`, `left_hand`, `head`, and `back`; the additional body sockets are UI/state-ready and need garment assets plus runtime rig wiring before they appear on the 3D character (see [`docs/CHARACTER_GENERATION.md`](CHARACTER_GENERATION.md)).

**Content**: item records gain an optional `gameplay.equip` block:

```json
"equip": {
  "slot": "right_hand",
  "scene": "res://assets/characters/shared/hammer.tscn"
}
```

or, for clothes, `"garment": "cape"` instead of `scene`. No `equip` block means the item is carry-only.

**Rules** (all state lives in `GameState`, mirroring the bag):

- `GameState.equipped` maps slot → item_id, persisted with the session like the bag.
- Equipping requires the item in the bag; on success it **leaves the grid** (frees cells) but its weight **still counts** toward the 28 kg cap — you carry what you wear.
- Equipping into an occupied slot returns the previous item to the bag first; if the grid cannot fit it, the swap is rejected with no partial mutation (same no-partial-mutation discipline as quest state).
- Unequip is the reverse: needs free grid space, else rejected.
- Quest/content ownership flags (`add_item`/`has_item`) are unaffected by equip state — an equipped hammer is still owned.

**UI**: the bag overlay places a nine-socket equipment paper doll (head, back, body, arms, belt, legs, feet, and both hands) beside the 8 x 5 packed-goods grid. Click an equipable item → "Equip" action; click an occupied socket → returns the item to the bag. Encumbrance meter unchanged.

**Visuals**: on any change to `GameState.equipped`, the player controller calls the matching `rig.equip/unequip/equip_garment` so the 3D view always reflects state; NPC variants keep using `CharacterVariant` defaults.

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
| `scripts/inventory/inventory_overlay_builder.gd` | Overlay node tree and chrome |
| `scripts/inventory/inventory_ornament_frame.gd` | Resolution-independent chamfered frame, fittings, and brass ornament |
| `scripts/inventory/equipment_silhouette.gd` | Anatomical paper doll, nine equipment sockets, and drag/drop hit zones |
| `scripts/inventory/inventory_ui_theme.gd` | Oak/brass/parchment style tokens |
| `scripts/inventory/quest_pouch_model.gd` | Resolve capped visible quest-tool ids from state + content |
| `scripts/inventory/quest_pouch_hud.gd` | Always-on three-slot quest-tool HUD |
| `scripts/inventory/quest_pouch_controller.gd` | Refresh HUD on item, equipment, and forged-record changes |
| `scripts/session/session_state.gd` | Session `GameState` and demo content load |
| `scripts/player.gd` | Applies encumbrance to walk/run speeds; blocks movement while bag is open |

## Verification

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_quest_pouch
godot --headless --path . --script tools/run_godot_tests.gd
python3 tools/validate_content.py content/demo content/demo/support content/examples/valid content/examples/support
```

Manual: run the game, press **I**, confirm seeded demo items, drag items by click-select then click destination, and walk with a heavy bag to feel slower movement.
