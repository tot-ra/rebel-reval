# ADR 0011: Optional first-person camera for interior inspection

**Reference:** TODO P0-059  
**Recorded:** 2026-07-20  
**Amends:** [ADR 0007](0007-ai-generated-isometric-presentation.md) (camera rule 3)

## Status

Accepted

## Context

ADR 0007 freezes the gameplay presentation on a fixed orthographic dimetric camera. The 3D view layer later added an optional first-person perspective toggle (`C`) so players can inspect interiors, ceilings, and sky detail at eye height. The toggle shipped without an ADR note or a mouse-accessible discoverability entry point, which blocked demo packaging (D-004) and conflicted with the repository discoverability policy in `TODO.md`.

Maintainers confirmed on 2026-07-20 that first-person mode is a **release feature**, not a developer-only inspection tool.

## Decision

1. **Default gameplay remains the fixed orthographic dimetric camera** from ADR 0007. First-person mode is an optional alternate view; it does not replace the authored isometric presentation for combat, navigation, or slice readability.
2. **Players toggle first-person with `C` or the Quick access "Camera [C]" button.** The shortcut and the visible button must stay in sync. The passive gameplay-help strip documents the shortcut; the Quick access menu provides the required mouse entry point.
3. **First-person enables interior ceiling shells and sky visibility** already implemented in `MapView3D` and `MapViewRuntimeCamera`. Returning to third-person restores the top-down readability defaults (hidden ceiling shell, orthographic zoom).
4. **No free camera rotation in release builds.** Yaw follows the existing gameplay orbit; wheel zoom applies only in third-person orthographic mode.

## Alternatives

- **Developer-only inspection tool excluded from release UI.** Rejected per maintainer direction; players should discover and use the mode in packaged builds.
- **Always-on first-person or player-controlled orbit camera.** Rejected. It breaks the ADR 0007 readability bar and raises art/collision scope for every exterior scene.

## Consequences

- ADR 0007 rule 3 is amended: the slice keeps a fixed orthographic dimetric default, with an optional first-person toggle for inspection. P0-040 may still freeze orthographic size, pitch, and grade parameters; first-person FOV and eye height are documented beside those constants in `MapViewRuntimeCamera`.
- Quick access, gameplay help, and headless tests must cover both keyboard and mouse activation.
- Future camera features (photo mode, free look) require a new ADR and TODO entry; they are out of scope for this amendment.
