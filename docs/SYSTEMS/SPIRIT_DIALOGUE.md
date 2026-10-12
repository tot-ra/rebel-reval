# Spirit dialogue combat

Status: partial (SW-1, R-1348; reflection panel and first explorable Hingepuu hub are implemented). Scope: the current Hingepuu visit loop over the active city scene. Out of scope: a full spirit-world map, phantom encounters, authored open-world duels, rites, and comprehensive spirit combat; see the SW task chain.

Canon labels: Hingepuu, spirit world, creatures, and guilt rites are `folklore` / `invented` per [`docs/CANON.md`](../CANON.md). The hero's perception is never given a clinical diagnosis.

## Player behavior

Press **H** to enter or leave Hingepuu (when entered from the city player). Move with **WASD**, arrow keys, or the left stick. **E / gamepad A** interacts with the central tree mark; **Esc** returns. The symbolic tree has three visible marks. The central mark opens the existing reflection panel when available; other marks currently provide a placeholder response. Leaving restores the exact city player transform because the player and city scene remain resident underneath the overlay.

## Runtime and persistence

- `scripts/reflection/hingepuu_hub.gd` draws and controls the minimal explorable hub as a `CanvasLayer` overlay.
- `scripts/reflection/reflection_controller.gd` owns the hub and bridges the central mark to `ReflectionModel` / `ReflectionOverlay`.
- The hub stores the return position and active-visit bit in `GameState`'s existing `location_states` dictionary, which is already serialized by `GameStatePersistence` and `SaveService`. `restore_after_load` resumes the visit without replacing the saved return point.
- The hub blocks city movement through `modal_input_overlay` while active. Inputs use existing `ui_left/right/up/down`, `interact`, and `ui_cancel` mappings. `interact` already includes keyboard and gamepad A.

## Verification and limits

Run `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_hingepuu_hub,test_reflection_overlay,test_save_service`.
The current host is a lightweight symbolic illustration rather than a dedicated streamed location or detailed art environment. Enter/exit is exposed by `ReflectionController.enter_hingepuu()` and `leave_hingepuu()`; an in-world access prompt/anchor, world-tree art, dedicated hub save-slot location, and integrated return-after-process-restart scene restoration remain follow-up work. No visual capture is accepted as historical reference.
