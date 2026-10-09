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
| Walk (slow) | `Shift` | unbound (rebind in Controls) |
| Spirit sight on / off (walk only while on, [`SYSTEMS/SPIRIT_SIGHT.md`](SYSTEMS/SPIRIT_SIGHT.md)) | `V` | Left stick click |
| Interact / continue | `E`, `Enter` | A |
| Attack (tap = next combo strike, hold = heavy) | left click (see above) | X |
| Guard | `F`, right click | Left shoulder |
| Roll (toward the held direction; none = back roll; with guard held, `A`/`D` = side roll keeping facing) | `Space` | Right trigger |
| Sidestep | `Q` | Right shoulder |
| Talk to yourself (short guard buff; nearby witnesses react, ADR 0033) | `T` | Left trigger |
| Dive (hold, while swimming in deep water) | `X`, `Ctrl` | B |
| Inventory | `I` | Y |
| Journal | `J` | Back |
| Camera view | `C` | Right stick click |
| Minimap | `N` | D-pad up |
| World map | `M` | D-pad down |
| Controls | `K` | Start |
| Back / close | `Esc` | B |
| Cast learned spell / reply slot 1-5 | `1` `2` `3` `4` `5` | X, Y, left shoulder, right shoulder, right stick click (or the cookbook, D-pad right) |
| Spell cookbook | `R` | D-pad right |
| Cast forged cookbook spell | `Enter` (cookbook only) | A (cookbook only) |

Left click never casts. It stays attack / interact / travel as described above. Number keys cast the learned recipes shown on the bottom-left spell bar (Fireball, Earth Tremor, Iron Skin in a new demo) **only in the spirit world** (during a spirit duel, [ADR 0033](adr/0033-teen-protagonist-and-spirit-dialogue-combat.md)); in the physical world they report "Magic answers only in the spirit world." and cost nothing. Gamepad face buttons stay combat verbs; open the cookbook to pick a spell with the mouse or focus.

Combat moves, combo timing, roll rules and cast gestures are specified in [`SYSTEMS/COMBAT_ANIMATION.md`](SYSTEMS/COMBAT_ANIMATION.md).

### Spirit duel

A spirit duel (the prologue confrontation, [`SYSTEMS/SPIRIT_DIALOGUE.md`](SYSTEMS/SPIRIT_DIALOGUE.md)) freezes the world and uses the same bindings, no separate scheme:

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Guard the telegraphed blow (hold; raise it inside the gold band to parry) | `F`, right click | Left shoulder |
| Dodge the telegraphed blow (once per blow) | `Q` | Right shoulder |
| Cast the reply in hotbar slot 1-5 | `1`..`5` | X, Y, left shoulder, right shoulder, right stick click |
| Cast the focused reply card | left click, `Enter` | A |
| Move the focus between reply cards | `Tab`, arrow keys | D-pad, left stick |
| Continue a spoken line / leave a finished duel | `E`, `Enter` | A |

The telegraph prompt and every card badge print the live binding, so a rebind shows up at once. During a telegraph a slot key that is also the guard or dodge button (by default the shoulders, slots 3 and 4) defends and does not cast. Settings -> Gameplay accessibility -> **Reply timer pressure** turns off the countdown ring on the reply window.

Bindings are stored per device and persist outside campaign save slots. Saved v1 bindings that still map `Space` to attack drop that default on load, because `Space` is the roll since bindings v2. Bindings v3 (R-1484) gives the left stick click to spirit sight: an untouched saved walk default on the left stick click is dropped on load, a deliberate custom walk binding is kept.

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
