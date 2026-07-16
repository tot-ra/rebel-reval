# P0-033 comparison-room greybox

Recorded: 2026-07-16

## Scene

`scenes/comparison_room/comparison_room.tscn`

The scene is a focused greybox built from Godot primitive nodes (`ColorRect`, `CharacterBody2D`, `StaticBody2D`, `Area2D`, labels, and shape resources). It does not add final art assets and does not use the frozen current isometric, pixel-frame animation, or superseded HUD pipelines.

## Run from editor

Open `scenes/comparison_room/comparison_room.tscn` and press **F6**.

Manual controls:

- Move: WASD or arrow keys.
- Dialogue: stand near Aita and press `E` or `Enter`.
- Combat: stand near Henning and press `J` or `Space`.
- Reset actor state: `R`.

## Headless verification

```bash
godot --headless scenes/comparison_room/comparison_room.tscn
```

Expected output:

```text
P0-033 comparison room verification: PASS
 - movement: ok
 - collision: ok
 - ysort: ok
 - doorway: ok
 - foreground_fade: ok
 - npc_bodies: ok
 - dialogue: ok
 - combat: ok
```

## Verified result

Command run locally with Godot `4.7.1.stable.official.a13da4feb` on 2026-07-16:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless scenes/comparison_room/comparison_room.tscn
```

Result: exit code `0`, all P0-033 behavior checks passed.
