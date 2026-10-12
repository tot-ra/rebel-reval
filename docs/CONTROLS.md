# Controls

Player-facing control scheme for the gameplay maps. The in-game Controls screen
(`K` / gamepad Start) shows the same rules and lets every action be rebound per
device; this document is the design authority behind it.

Implementation: `scripts/map/map_click_input_controller.gd` (primary-click
routing), `scripts/player/player_primary_action.gd` (target resolution),
`scripts/player/player_action_input.gd` (action polling),
`scripts/map/view3d/map_view_runtime_camera.gd` (camera modes),
`scripts/settings/input_binding_settings.gd` (default bindings).

Status: implemented (task **R-1553** for the gamepad walk default and saved-binding regression). Scope: keyboard/mouse and gamepad input for the shipped actions. Out of scope: new actions and campaign-state changes.

## Principle

The camera decides who is pointing:

- **First-person and third-person** - the *character* points. The primary click
  acts on what the character faces, and locomotion belongs to the movement keys.
- **Top-down** - the *cursor* points. The primary click selects a place or a
  thing on the ground, so click-to-move lives here and only here.

Right mouse is defense in every mode, so an incoming blow is answered the same
way regardless of camera.

## Primary click (left mouse)

**Stance first (ADR 0047, R-1886).** The hero is peaceful by default: the weapon is sheathed
and the click never swings. `G` draws it. Peaceful, a click on a person (a census resident or
named NPC) is left to the crowd and opens a conversation when they are within 4 m, or a spirit
duel in spirit sight ([`SYSTEMS/DIALOGUE.md`](SYSTEMS/DIALOGUE.md#talk-to-anyone-r-1887)); the
lists below then apply with these changes: step 1 draws the weapon and strikes, and step 4
(open air) does nothing until the weapon is drawn.

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
| Walk (slow, hold) | `Shift` | D-pad left (hold) |
| Spirit sight on / off (walk only while on, [`SYSTEMS/SPIRIT_SIGHT.md`](SYSTEMS/SPIRIT_SIGHT.md)) | `V` | Left stick click |
| Interact / continue | `E`, `Enter` | A |
| Challenge (in spirit sight, on a person with a duel record; [`SYSTEMS/SPIRIT_SIGHT.md`](SYSTEMS/SPIRIT_SIGHT.md) "Entering a duel") | `E`, `Enter` | A |
| Talk to the person in reach (peaceful; [`SYSTEMS/DIALOGUE.md`](SYSTEMS/DIALOGUE.md#talk-to-anyone-r-1887)) | left click on them, `E` | A |
| Draw / sheathe weapon (peaceful by default, ADR 0047) | `G` | Share (or X draws, A on a person sheathes) |
| Attack (tap = next combo strike, hold = heavy; weapon drawn) | left click (see above) | X |
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

A spirit duel (the prologue confrontation, [`SYSTEMS/SPIRIT_DIALOGUE.md`](SYSTEMS/SPIRIT_DIALOGUE.md)) starts only from spirit sight: Challenge a duel-ready person in sight, or a scripted duel switches sight on first. After the duel the hero is still in spirit sight; press `V` / left stick click to leave it. The duel uses the same bindings, no separate scheme:

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

### Gamepad walk and saved settings (R-1553)

Hold D-pad left while moving the left stick to walk slowly; release it to return
to normal movement. Left stick click remains spirit sight and never shares the
walk default. D-pad left also opens the dialogue backlog while a dialogue owns
input; movement is blocked in that context. Both actions remain rebindable.

The `ui_shift` default lives in `InputBindingSettings.default_settings()` and is
read by `Player.is_walking()` (`scripts/player.gd`). Loading an older settings file
with an empty gamepad walk binding fills it with D-pad left; the retired v1/v2
left-stick walk default also falls back to D-pad left. Non-empty custom bindings
are preserved. The existing settings version stays at v3 because the loader
already fills missing or empty entries from current defaults. These settings
remain outside campaign saves.

Verification:

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_input_bindings,test_spirit_sight,test_act1_packaged_acceptance,test_act1_release_acceptance,test_bitter_brew_commission
```

The input tests cover press/release, separation from spirit sight, saved empty
bindings, custom bindings and round trips. The commission test verifies that the
bed stays locked before resolution and unlocks afterward (forge gate composition
was already repaired in commit `5fe4155f`). Physical controller ergonomics still
require a hands-on check; automated coverage uses synthetic input events.

## Camera

- `C` (gamepad: right stick click) cycles third-person, first-person, painted
  iso (seamless city only), top-down. Maps without painted iso skip it.
- The scroll wheel (or trackpad pinch/two-finger scroll) is one continuum:
  zooming in from third-person enters first-person, zooming out enters painted
  iso (city) and then the orthographic top-down overview.
- `PageUp` / `PageDown` rotate the view without the mouse.

### Painted iso view

Status: implemented (task **R-1744**). Scope: the seamless Reval city and the
regional site scenes that use `CityMapView`. Out of scope: district
`MapView3D` maps, wall cutaway, the start mode (third person stays the default).

A high telephoto camera that reads like the painted isometric references
(`docs/reports/images/city/painted_iso_compare.jpg`): a true perspective lens
with a 30 deg FOV, pitched 50 deg down, 42 m out by default.

- **Zoom:** the boom spans 30-45 m. Zooming out of third person at 12 m enters
  iso at 30 m; past 45 m it enters top-down; zooming in from top-down resumes
  iso at 45 m; below 30 m it returns to third person at 12 m.
- **Orbit:** right-drag horizontally or `PageUp` / `PageDown` yaw the view;
  right-drag vertically tilts only within 45-55 deg.
- **Follow:** the boom glides after the player (lerp weight 5, slower than the
  close follow's 8) and never pulls in toward walls.
- **Input:** iso is an overview like top-down: WASD and the left stick are
  screen-relative, the character keeps its own facing, and left click aims at
  the cursor (click-to-move, interact, attack) instead of the facing cone.
- **Roof cutaway:** city roofs (houses, wall-walk roofs) dither away around the
  sight line from the player's chest to the lens, within about 3 m of it and only
  in front of the player. Shadow passes keep the roof, so no sunlight leaks onto
  the street. Walls rely on the existing occlusion ghost silhouette.
- **Lens extras:** far depth of field is off (the player is past its start),
  the near plane is 0.5 m, and the city shadow range tightens to the telephoto
  frame.

Runtime entry points: `MapViewRuntimeCamera.CameraMode.PAINTED_ISO`
(`scripts/map/view3d/map_view_runtime_camera*.gd`), the view opt-in
`MapView3D.painted_iso_camera` (set by `CityMapView.create`), the hook
`MapView3D.update_camera_cutaway()`, `CityBuildingBuilder.set_roof_cutaway()`
and `scripts/city/city_roof_cutaway.gdshaderinc`. The camera mode is not saved.

Verify: `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_runtime_camera`;
captures with `tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_painted_iso.tscn`
(Raekoja plats and the forge street, third person and iso, plus a cutaway proof).

Limits: the iso frames read darker than the references because the ground and
roofs fill the frame (no sky) and Mobile has no auto exposure; site-kit roofs
(churches, the smithy) use their own materials and are not cut away.

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
