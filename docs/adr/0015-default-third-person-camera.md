# ADR 0015: Default over-the-shoulder third-person camera

**Recorded:** 2026-07-23
**Supersedes:** [ADR 0011](0011-optional-first-person-camera.md) (default camera and two-mode toggle)
**Amends:** [ADR 0012](0012-first-person-mouse-free-look.md) (third-person pitch rule)

## Status

Accepted

Amended 2026-07-25: third-person right-drag gains clamped vertical orbit; enclosed-interior occlusion ghost is disabled.

Amended 2026-07-25 (later): third-person mouse/trackpad scroll changes follow boom distance, clamps zoom-out, and crosses into first-person when zoomed in past the close threshold.

Amended 2026-07-25 (scroll continuum): zoom-out past the far boom threshold crosses into top-down; zoom-in past the close top-down size restores third-person at the max boom.

## Context

The game previously exposed two camera modes: a distant orthographic top-down view and an optional first-person inspection view. The orthographic mode was called "third-person" in parts of the implementation even though it did not place the camera behind the character. The desired default is now a Witcher-like camera behind the player, while the old top-down controls must remain available as a distinct third mode.

Camera-relative character facing also needs a clear mode contract. In close perspective views, turning the camera should turn the character and redefine keyboard forward/back movement. In top-down, rotating the camera must not turn the character, preserving the existing independent screen-relative controls.

Players also need vertical orbit on the default follow camera, and indoor play must not keep the occluded-actor silhouette stuck on because the boom clips perimeter walls or room ceilings.

Players also need scroll zoom on the follow boom: pull closer or push farther within authored limits, enter first-person when the boom would sit inside the character, and enter top-down when zoomed out past the far boom threshold.

## Decision

1. The gameplay camera has three explicit modes, cycled with `C` or the Quick access camera button: **third-person**, **first-person**, then **top-down**.
2. Third-person is the default. It uses a perspective camera placed behind and above the player on an orbit boom, with the character rig visible. Default boom distance is authored; scroll zoom changes that distance.
3. First-person keeps the existing eye-height perspective, hidden player rig, and right-drag pitch look.
4. Horizontal camera rotation in third-person and first-person immediately updates the player's authored facing. Keyboard movement remains projected from camera yaw, so forward/back and strafing follow the current view.
5. Top-down keeps the existing orthographic pitch, zoom, and screen-relative movement. Camera rotation re-projects movement but does not change authored character facing.
6. Close perspective modes show interior ceiling shells and nearby terrain micro detail. Top-down keeps the readability cutaway and orthographic zoom.
7. Vertical right-drag adjusts pitch in both perspective modes. Third-person uses a narrower authored clamp than first-person and repositions the orbit boom (not free flight). Top-down keeps its authored dimetric pitch.
8. The occluded-actor silhouette is for outdoor building/landmark masses. Enclosed interior maps (`suppresses_exterior_surroundings()`) keep the ghost off. Interior ceiling shells are presentation/solar only and are not actor occluders. Occlusion probes aim at the real camera position.
9. Mouse wheel, trackpad scroll, and pinch share one zoom polarity across modes. In third-person they scale boom distance between authored min/max. Zooming in past the min distance switches to first-person. Zooming out past the max distance switches to top-down. Zooming out from first-person restores third-person at the min boom. Zooming in past the close top-down ortho size restores third-person at the max boom. Top-down still clamps ortho size within its authored band when staying in that mode.

## Consequences

- `MapViewRuntimeCamera` owns an explicit camera-mode enum instead of inferring all behavior from a first-person boolean.
- Existing `set_first_person()` and `is_first_person()` APIs remain as compatibility helpers, while mode-aware callers can use the explicit camera-mode API.
- Camera-mode integration tests cover the full cycle, projection and placement, close/interior presentation, camera-relative facing, top-down independence, mouse pitch limits, third-person boom zoom / first-person and top-down flips, indoor ghost suppression, and Quick access activation.
- The default presentation in ADR 0007 and ADR 0011 is no longer fixed orthographic. The flat 2D logic plane and deterministic 3D view bridge remain unchanged.
