class_name MapClimbableProps
extends RefCounted

## Low outdoor props the player may step onto. The flat 2D logic plane stays
## authoritative for collision and navigation; this only lifts the derived 3D
## actor so crates, barrels, carts, and similar cargo read as climbable rather
## than as ground-clipped scenery. Wall-walk stairs/platforms remain owned by
## MapWallWalkAccess and take precedence when both apply.

## Stand heights match the prop mesh tops in MapViewMeshBuilderProps.
const STAND_HEIGHT_BY_KIND := {
	MapTypes.PROP_KIND_CARGO_CRATES: 0.62,
	MapTypes.PROP_KIND_BARRELS: 0.72,
	MapTypes.PROP_KIND_CART: 0.68,
	MapTypes.PROP_KIND_HAY_STACK: 0.78,
	MapTypes.PROP_KIND_TRADE_GOODS: 0.55,
	MapTypes.PROP_KIND_CHEST: 0.56,
}


static func is_climbable(prop: Dictionary) -> bool:
	if not prop.get("footprint") is Rect2:
		return false
	return STAND_HEIGHT_BY_KIND.has(prop.get("kind", &""))


static func stand_height(prop: Dictionary) -> float:
	if not is_climbable(prop):
		return 0.0
	return float(STAND_HEIGHT_BY_KIND[prop["kind"]])


static func elevation_at(definition: MapDefinition, logic_position: Vector2) -> float:
	if definition == null:
		return 0.0
	var best := 0.0
	for prop in definition.props:
		if not is_climbable(prop):
			continue
		var footprint: Rect2 = prop["footprint"]
		if not footprint.has_point(logic_position):
			continue
		best = maxf(best, stand_height(prop))
	return best
