# ADR 0012: First-person mouse free look

**Recorded:** 2026-07-21
**Amends:** [ADR 0011](0011-optional-first-person-camera.md) (decision 4)

## Status

Accepted

## Context

ADR 0011 shipped first-person inspection with the existing horizontal camera orbit only. Players could turn left and right but could not inspect ceilings, upper floors, or nearby ground without leaving first-person mode. This made the eye-level view too restrictive for its stated purpose of inspecting interiors and sky detail.

## Decision

1. First-person mode supports mouse free look while the right mouse button is held. Horizontal drag changes yaw and vertical drag changes pitch.
2. Pitch is clamped to -80 through 80 degrees so the camera cannot cross a vertical pole and invert yaw or screen-relative movement.
3. Third-person keeps the authored dimetric pitch. Vertical drag has no effect outside first-person mode.
4. The persistent Quick access help and camera tooltip document the right-drag control.
5. First-person movement remains projected from camera yaw only. Looking up or down does not add vertical player movement.

## Consequences

- ADR 0011 decision 4 is amended to allow player-controlled free look only in first-person mode. Its fixed orthographic default and third-person readability rules remain unchanged.
- Interior and exterior geometry can be inspected above and below eye level, so first-person scene reviews should include ceiling and ground-facing angles.
- Headless camera tests cover two-axis drag, pitch limits, and the unchanged third-person pitch.
