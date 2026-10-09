# Settings, input bindings, and accessibility

Status: implemented (tasks **P1-013** dialogue settings, **P1-028** input bindings, **P3-007** gameplay accessibility). Scope: player preferences stored outside save slots, the in-game settings screen, rebinding, and audio volume. The control scheme itself is in [`CONTROLS.md`](../CONTROLS.md).

## Player-facing behavior

- **Esc** opens the Settings overlay during play when no other modal is open (`GameSettingsController` on the player scene). Sections:
  - **Audio**: music volume, sound effects volume.
  - **Dialogue accessibility**: text size, text speed, high contrast, subtitle background, subtitles, bark subtitles, voice playback, always translate foreign speech (shows lines in languages the hero does not yet understand in full), reduced motion.
  - **Gameplay accessibility**: guard input `hold` / `toggle`, screen shake, reduced flashing (scales lightning flashes to 25%), enhanced focus contrast (thicker UI focus borders), reply timer pressure, spirit sight grade intensity (0-100 %, task **R-1484**; scales only the look of spirit sight, never its walk-only limits).
- **Quick menu → Controls** opens `ControlsOverlay`, which lists every action with its keyboard/mouse and gamepad binding and allows rebinding and restoring defaults.
- Settings apply immediately and persist across sessions and save slots.

## Rebindable actions

Movement (up/down/left/right, walk, spirit sight), interact/continue, confirm, back/close, dialogue backlog, attack, guard, sidestep, roll, spell cookbook, cast learned spell 1–5, remove forged element, cast forged cookbook spell, inventory, journal, camera view, minimap, map, controls. Each action keeps separate keyboard/mouse and gamepad bindings (`InputBindingSettings.ACTION_DEFINITIONS`).

## Runtime pieces

| Piece | File | Role |
|---|---|---|
| `UserSettings` (autoload) | `scripts/settings/user_settings.gd` | Owns the four settings models; `apply_*` persists and emits `dialogue_settings_changed`, `gameplay_accessibility_changed`, `input_bindings_changed`, `audio_settings_changed`. `rebind_action`, `restore_default_input_bindings`. |
| `UserSettingsStore` | `scripts/settings/user_settings_store.gd` | JSON file under `user://settings/` (format version 4, migrates v1). |
| `DialogueSettings` | `scripts/settings/dialogue_settings.gd` | Text and subtitle preferences ([`DIALOGUE.md`](./DIALOGUE.md)). |
| `GameplayAccessibilitySettings` | `scripts/settings/gameplay_accessibility_settings.gd` | Guard mode, screen shake, reduced flashing, focus contrast, `reply_timer_pressure`, `spirit_sight_intensity`. Read by combat input, `map_view_runtime_camera_shake.gd`, `sky_weather_3d.gd`, `UiFocusTheme`, `SpiritArenaHost`. |
| `InputBindingSettings` | `scripts/settings/input_binding_settings.gd` | Serializes and applies `InputMap`. `BINDINGS_VERSION` 2 moved Space from attack to roll and drops untouched v1 defaults on load; 3 moved the left stick click from walk to spirit sight the same way. |
| `AudioSettings`, `AudioBusService` | `scripts/settings/` | Linear volumes routed to the `Music`, `SFX`, and `Voice` buses. |
| `GameSettingsOverlay`, `GameSettingsController` | `scripts/ui/` | The settings screen and its Esc entry point. |
| `ControlsOverlay` | `scripts/ui/controls_overlay.gd` | Binding list and rebinding UI. |

**Reply timer pressure** (task **R-1333**, default on) drives the countdown ring on a spirit duel's reply window. It is never a timeout: when it runs out the hero hesitates once for 6 composure, clamped so it cannot break composure, and the replies stay open. Off hides the ring and stops the timer entirely (`SpiritDuel.reply_pressure_enabled`, see [`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md)). The duel's reply cards also honour the dialogue settings: the cast caption types at the dialogue text speed and appears at once under reduced motion or instant text.

Accessibility acceptance data: `docs/data/accessibility_checklist.json`.

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_game_settings_overlay
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_dialogue_settings
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_input_binding
```

## Limits

- `DialogueSettings.locale`, `pseudo_localization`, and `AudioSettings.voice_volume` are stored and honored but have no control in the settings screen yet.
