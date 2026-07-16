extends RefCounted

class_name CharacterScale

# P0-037 integration contract for P0-052. The camera value preserves the
# carried-forward 64 px target at the reference 1600 x 900 viewport.
const VISIBLE_HEIGHT_WORLD := 2.0
const TARGET_VISIBLE_HEIGHT_PX := 64.0
const REFERENCE_VIEWPORT_HEIGHT_PX := 900.0
const GAMEPLAY_ORTHOGRAPHIC_SIZE := (
	VISIBLE_HEIGHT_WORLD * REFERENCE_VIEWPORT_HEIGHT_PX / TARGET_VISIBLE_HEIGHT_PX
)

static func projected_height_px(
	orthographic_size: float = GAMEPLAY_ORTHOGRAPHIC_SIZE,
	viewport_height_px: float = REFERENCE_VIEWPORT_HEIGHT_PX,
) -> float:
	return VISIBLE_HEIGHT_WORLD * viewport_height_px / orthographic_size

