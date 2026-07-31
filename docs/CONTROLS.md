# Controls

Player-facing control scheme for the gameplay maps. The in-game Controls screen
(`K` / gamepad Start) shows the same rules and lets every action be rebound per
device; this document is the design authority behind it.

Implementation: `scripts/map/map_click_input_controller.gd` (primary-click
routing), `scripts/player/player_primary_action.gd` (target resolution),
`scripts/player/player_action_input.gd` (action polling),
`scripts/map/view3d/map_view_runtime_camera.gd` (camera modes),
`scripts/settings/input_binding_settings.gd` (default bindings).

## Principle

The camera decides who is pointing:

- **First-person and third-person** - the *character* points. The primary click
  acts on what the character faces, and locomotion belongs to the movement keys.
- **Top-down** - the *cursor* points. The primary click selects a place or a
  thing on the ground, so click-to-move lives here and only here.

Right mouse is defense in every mode, so an incoming blow is answered the same
way regardless of camera.

## Primary click (left mouse)

### First-person / third-person

Resolved in this order against the character's facing:

1. **Hostile in front** (a live actor in the `combat_damageable` group, inside
   the aggression cone, within `PlayerPrimaryAction.HOSTILE_SCAN_PX`) - attack.
   Hostiles slightly outside weapon reach still resolve as an attack: swinging is
   the honest answer to an enemy closing in.
2. **Loose item under the cursor** - pick up (the pointer is visible in both
   perspective modes, so hovering an item is an explicit aim).
3. **Neutral or quest-giving target in front** - interact: dialogue for people,
   pickup for items and bodies, use for doors, chests, and workstations. Only
   targets the character is already in interaction range of qualify.
4. **Nothing in front** - attack (a swing at open air), never a move order.

A foe standing behind or beside the character does not steal a click aimed at a
prompt in front: hostile targeting uses a tighter cone than interaction.

Techniques with a charged attack swing on button release, so holding the primary
button charges instead of repeating the swing.

### Top-down

1. **Loose item under the cursor** - pick up.
2. **Interactable under the cursor** - interact when in range, otherwise walk up
   to it and interact on arrival.
3. **Hostile under the cursor** - attack when already within reach, otherwise
   close the distance first.
4. **Ground** - move there (click-to-move).

### Everywhere

- While the bag is open, locomotion is blocked but a selected item can still be
  dropped into the world with the primary click.
- Focusable HUD widgets and modal overlays keep ownership of their own clicks.

## Secondary click (right mouse)

- **Guard / defense.** Hold or toggle depending on the gameplay setting
  (`UserSettings.gameplay.guard_uses_hold`).
- **Camera orbit while dragging.** Horizontal drag yaws the view in every mode;
  vertical drag pitches the perspective cameras. Guarding and re-aiming the
  camera therefore share the button by design: a defended character can still
  look around.

## Keyboard and gamepad defaults

| Action | Keyboard / mouse | Gamepad |
| --- | --- | --- |
| Move | `W` `A` `S` `D` / arrows | Left stick |
| Walk (slow) | `Shift` | Left stick click |
| Interact / continue | `E`, `Enter` | A |
| Attack | `Space`, left click (see above) | X |
| Guard | `F`, right click | Left shoulder |
| Dodge | `Q` | Right shoulder |
| Inventory | `I` | Y |
| Journal | `J` | Back |
| Camera view | `C` | Right stick click |
| Minimap | `N` | D-pad up |
| World map | `M` | D-pad down |
| Controls | `K` | Start |
| Back / close | `Esc` | B |

Bindings are stored per device and persist outside campaign save slots.

## Camera

- `C` cycles third-person, first-person, top-down.
- The scroll wheel (or trackpad pinch/two-finger scroll) is one continuum:
  zooming in from third-person enters first-person, zooming out enters the
  orthographic top-down overview.
- `PageUp` / `PageDown` rotate the view without the mouse.

## Rationale

Click-to-move in a mounted camera fought the character's own aim: the player saw
a target ahead and got a walk order. Attack was keyboard-only, which made the
mouse feel inert during combat while the same button moved the character in every
mode. Binding the primary click to intent (aggression vs. interaction) and
keeping ground movement exclusive to the top-down camera makes each mode answer
what the player is actually pointing at.

## Related documents

- [Gameplay loop](GAMEPLAY.md)
- [Combat and night operations](SYSTEMS/COMBAT_NIGHT.md)
- [Game pillars](GAME-PILLARS.md)
