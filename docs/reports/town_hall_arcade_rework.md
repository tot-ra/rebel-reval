# Town Hall arcade rework: structural gallery instead of decorative arches

Recorded: 2026-07-23  
Map: `market_civic_quarter`  
Building: `town_hall_mass` (primitive `town_hall_1343`)

## Problem

The arcade was drawn as arch bands and shadow panels laid on a closed facade, so
the bays read as painted decoration. The functional entrance door sat on that
same facade plane between the bays, and the ground-floor openings competed with
the generic house door and windows the shared facade pass added on top of them.

## Change

The bays are now an opening in the building, not a pattern on it:

- a pierced load-bearing arcade wall (`MapViewMeshBuilderPrimitives.arcade_wall_mesh`)
  with real jamb and soffit reveals in every bay;
- the solid mass is pulled back from the facade so a covered walk-through
  gallery fits behind the arcade, closed again by end walls and a vault;
- transverse arches spring from the arcade piers onto responds on the inner
  wall, which is the visible reason the storey above stands over an open walk;
- the council door stands at the back of that gallery, on the arcade axis,
  framed by a stone portal surround;
- one order of stone-framed lights, bay-aligned, replaces the loose row of
  small panes above the arcade, and the rear wall uses the same framed lights.

The recognizable arcade quotes the post-1404 rebuild for legibility. The hall
still has no upper council floor and no tower; see the Town Hall visual decision
in [`../HISTORICAL_AUDIT.md`](../HISTORICAL_AUDIT.md).

## Evidence

Captured with `tools/capture_town_hall_facade.gd` (rendering run, not headless):

- Before: [`images/view3d/town_hall/arcade_before.png`](./images/view3d/town_hall/arcade_before.png)
- After: [`images/view3d/town_hall/arcade_after.png`](./images/view3d/town_hall/arcade_after.png)
- Gallery and portal: [`images/view3d/town_hall/gallery_portal_after.png`](./images/view3d/town_hall/gallery_portal_after.png)

Covered by `tests/godot/test_market_prototype_maps.gd`:
`test_central_district_has_unique_period_building_models` asserts the arcade
wall, gallery floor, vault, transverse ribs and end walls exist and that the
mass stops short of the facade; `test_town_hall_exterior_door_is_attached_to_the_arcaded_facade`
asserts the door stands on the gallery back wall and on the portal axis.
