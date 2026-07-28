class_name MapClimbableProps
extends RefCounted

const _HayMeshes := preload("res://scripts/map/view3d/map_view_hay_meshes.gd")

## Low outdoor props the player may step onto. The flat 2D logic plane stays
## authoritative for collision and navigation; this only lifts the derived 3D
## actor so crates, barrels, carts, and similar cargo read as climbable rather
## than as ground-clipped scenery. Wall-walk stairs/platforms remain owned by
## MapWallWalkAccess and take precedence when both apply.

## Variant-aware props use their authored model top while every other climbable
## kind retains the established mesh-builder height.
const STAND_HEIGHT_BY_KIND := {
	MapTypes.PROP_KIND_CARGO_CRATES: 0.62,
	MapTypes.PROP_KIND_BARRELS: 0.72,
	MapTypes.PROP_KIND_CART: 0.68,
	MapTypes.PROP_KIND_HAY_STACK: 0.78,
	MapTypes.PROP_KIND_TRADE_GOODS: 0.55,
}
const CHEST_STAND_HEIGHT_BY_VARIANT := {
	MapPropStyleVariants.CHEST_PLAIN_COFFER: 0.45,
	MapPropStyleVariants.CHEST_BURGHER: 0.61,
	MapPropStyleVariants.CHEST_MERCHANT_STRONGBOX: 0.70,
}
const DEFAULT_CHEST_STAND_HEIGHT := 0.61


static func is_climbable(prop: Dictionary) -> bool:
	if not prop.get("footprint") is Rect2:
		return false
	var kind: StringName = prop.get("kind", &"")
	return kind == MapTypes.PROP_KIND_CHEST or STAND_HEIGHT_BY_KIND.has(kind)


static func stand_height(prop: Dictionary) -> float:
	if not is_climbable(prop):
		return 0.0
	match prop.get("kind", &"") as StringName:
		MapTypes.PROP_KIND_CHEST:
			var variant := StringName(prop.get("style_variant", &""))
			return float(CHEST_STAND_HEIGHT_BY_VARIANT.get(variant, DEFAULT_CHEST_STAND_HEIGHT))
		MapTypes.PROP_KIND_HAY_STACK:
			# The broad shoulder, not the loose crown tip, is the believable footing.
			var size_variant := StringName(prop.get("style_variant", _HayMeshes.DEFAULT_SIZE))
			return STAND_HEIGHT_BY_KIND[MapTypes.PROP_KIND_HAY_STACK] * _HayMeshes.size_scale(size_variant).y
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
