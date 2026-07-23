# ADR 0015: Default over-the-shoulder third-person camera

**Recorded:** 2026-07-23
**Supersedes:** [ADR 0011](0011-optional-first-person-camera.md) (default camera and two-mode toggle)
**Amends:** [ADR 0012](0012-first-person-mouse-free-look.md) (third-person pitch rule)

## Status

Accepted

## Context

The game previously exposed two camera modes: a distant orthographic top-down view and an optional first-person inspection view. The orthographic mode was called "third-person" in parts of the implementation even though it did not place the camera behind the character. The desired default is now a Witcher-like camera behind the player, while the old top-down controls must remain available as a distinct third mode.

Camera-relative character facing also needs a clear mode contract. In close perspective views, turning the camera should turn the character and redefine keyboard forward/back movement. In top-down, rotating the camera must not turn the character, preserving the existing independent screen-relative controls.

## Decision

1. The gameplay camera has three explicit modes, cycled with `C` or the Quick access camera button: **third-person**, **first-person**, then **top-down**.
2. Third-person is the default. It uses a perspective camera placed behind and above the player at a fixed follow distance, with the character rig visible.
3. First-person keeps the existing eye-height perspective, hidden player rig, and right-drag pitch look.
4. Horizontal camera rotation in third-person and first-person immediately updates the player's authored facing. Keyboard movement remains projected from camera yaw, so forward/back and strafing follow the current view.
5. Top-down keeps the existing orthographic pitch, zoom, and screen-relative movement. Camera rotation re-projects movement but does not change authored character facing.
6. Close perspective modes show interior ceiling shells and nearby terrain micro detail. Top-down keeps the readability cutaway and orthographic-only zoom.
7. Vertical right-drag remains first-person-only. Third-person uses a fixed authored pitch so it stays a predictable follow camera rather than a free-flying orbit.

## Consequences

- `MapViewRuntimeCamera` owns an explicit camera-mode enum instead of inferring all behavior from a first-person boolean.
- Existing `set_first_person()` and `is_first_person()` APIs remain as compatibility helpers, while mode-aware callers can use the explicit camera-mode API.
- Camera-mode integration tests cover the full cycle, projection and placement, close/interior presentation, camera-relative facing, top-down independence, mouse pitch limits, and Quick access activation.
- The default presentation in ADR 0007 and ADR 0011 is no longer fixed orthographic. The flat 2D logic plane and deterministic 3D view bridge remain unchanged.
