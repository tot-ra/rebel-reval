# P0-035 projection and direction comparison room

Recorded: 2026-07-16

## Scope

This is a comparison spike, not a final-art scene. It preserves the P0-033 greybox content and deliberately changes only projection and movement direction policy:

| Variant | Scene | Gameplay projection | Input/facing directions |
|---|---|---|---:|
| Current prototype approach | `scenes/comparison_room/diamond_isometric_8_direction.tscn` | Diamond-isometric, including projected collision geometry | 8 (N, NE, E, SE, S, SW, W, NW) |
| Proposed approach | `scenes/comparison_room/orthogonal_4_direction.tscn` | Orthogonal flat gameplay plane | 4 (N, E, S, W) |

Both variants are configured from `scenes/comparison_room/comparison_room_variant.gd`. This keeps one authoritative definition for room topology and content instead of maintaining two scene copies that could drift.

The spike does not modify `scripts/player.gd`, `player.tscn`, action state, or runtime game state.

## Equivalent content contract

Both scenes use the same logical room specification:

- Navigation: six collision obstacles (five boundary sections plus one table), one walkable room, the same player spawn, one doorway/teleport target, Y-sort actors, and one foreground fade probe.
- Interaction: the same six named NPCs and the same authored Aita interaction, with a logical interaction range of 115 units.
- Combat: Henning is the combat target in both scenes; one attack performs the same exchange, reducing Kalev and Henning from 3 HP to 2 HP.

Positions are authored once in logical room coordinates. The diamond variant projects those coordinates and its collision polygons through a diamond transform. Interaction distance is measured after converting projected positions back to the shared logical plane, so projection does not silently change gameplay range.

## Manual inspection

Open either scene and press **F6**.

Controls:

- Move: WASD or arrow keys.
- Walk: hold `Shift` while moving.
- Interact with Aita: `E` or `Enter`.
- Attack Henning: `J` or `Space`.
- Reset actor state: `R`.

Objective manual checks for each scene:

1. Move through the room and collide with the table or boundary.
2. Cross the shared doorway threshold and confirm Kalev moves to its comparison marker without changing scenes.
3. Walk behind the labelled foreground area and confirm the occluder fades.
4. Approach Aita and trigger the authored dialogue box.
5. Approach Henning and attack once; both HP counters must change from 3 to 2.
6. Confirm the HUD identifies either an 8-direction or 4-direction model. In the orthogonal scene, simultaneous horizontal/vertical input resolves to one cardinal direction; in the diamond scene it resolves to a diagonal direction.

Primitive polygons, rectangles, and labels are intentional. Art quality is outside P0-035.

## Automated verification

Run both scene-level behavioral checks and then compare their content contracts:

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless scenes/comparison_room/diamond_isometric_8_direction.tscn
"$GODOT" --headless scenes/comparison_room/orthogonal_4_direction.tscn
"$GODOT" --headless --script scenes/comparison_room/verify_variants.gd
```

Each scene-level command moves a real `CharacterBody2D` through physics and verifies:

- the expected direction count (8 or 4),
- navigation movement and collision,
- Y-sort ordering condition,
- doorway state and destination,
- foreground fade state,
- six NPC physics bodies,
- Aita interaction state,
- the equivalent Henning/Kalev damage exchange.

The paired verifier independently loads both scene resources and requires distinct direction models but an identical content signature for obstacles/NPC roles, doorway, fade probe, interaction target, combat target, and damage amount.

## Verification record

Verified locally on 2026-07-16 with Godot `4.7.1.stable.official.a13da4feb`.

All three automated commands exited `0`:

```text
P0-035 diamond_isometric_8_direction verification: PASS
 - direction_model: ok (8 directions)
 - navigation: ok
 - collision: ok
 - ysort: ok
 - doorway: ok
 - foreground_fade: ok
 - npc_bodies: ok
 - interaction: ok
 - combat: ok

P0-035 orthogonal_4_direction verification: PASS
 - direction_model: ok (4 directions)
 - navigation: ok
 - collision: ok
 - ysort: ok
 - doorway: ok
 - foreground_fade: ok
 - npc_bodies: ok
 - interaction: ok
 - combat: ok

P0-035 paired content equivalence: PASS
 - variants: 2
 - direction_models: 8 and 4
 - equivalent_navigation_content: ok
 - equivalent_interaction_content: ok
 - equivalent_combat_content: ok
```

Both scene checks emitted the same content signature:

```text
walls=6;npcs=Mart:ambient,Aita:dialogue,Kaja:ambient,Henning:combat,Jürgen:ambient,Greybox Guard:ambient;door=775,125;fade=990,555;interaction=Aita;combat=Henning;hp_exchange=1
```

### Visual snapshots

Both snapshots were captured by the same 1600x900 project viewport with the Godot Compatibility renderer before any manual input:

- [Diamond-isometric / 8-direction snapshot](./images/p0_035_diamond_isometric_8_direction.png)
- [Orthogonal / 4-direction snapshot](./images/p0_035_orthogonal_4_direction.png)

Repeatable capture commands (these require a graphics renderer, not `--headless`, because Godot's headless dummy renderer has no viewport texture):

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --path . --script scenes/comparison_room/capture_variant.gd -- \
  res://scenes/comparison_room/diamond_isometric_8_direction.tscn \
  docs/reports/images/p0_035_diamond_isometric_8_direction.png
"$GODOT" --path . --script scenes/comparison_room/capture_variant.gd -- \
  res://scenes/comparison_room/orthogonal_4_direction.tscn \
  docs/reports/images/p0_035_orthogonal_4_direction.png
```

Conclusion: both variants contain equivalent navigation, interaction, and combat content. P0-035 can be marked complete. This result confirms functional equivalence only; visual-style selection and production/performance comparison remain P0-036 and P0-038.
