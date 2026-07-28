class_name MapPropRenderer
extends RefCounted

## Public 2D prop-rendering facade. It owns shared node setup and delegates
## visual details to focused renderers so unrelated prop families stay isolated.

const Draw := preload("res://scripts/map/map_prop_draw.gd")
const Industrial := preload("res://scripts/map/map_prop_renderer_industrial.gd")
const Heraldry := preload("res://scripts/map/map_prop_renderer_heraldry.gd")
const Nature := preload("res://scripts/map/map_prop_renderer_nature.gd")
const Harbor := preload("res://scripts/map/map_prop_renderer_harbor.gd")
const Life := preload("res://scripts/map/map_prop_renderer_life.gd")


static func create_prop(
	prop: Dictionary,
	target: StringName = MapVisualStyle.TARGET_CLEAN_PAINTED,
	time_of_day: StringName = MapVisualStyle.TIME_DAY
) -> Node2D:
	var root := Node2D.new()
	root.name = "Prop_%s" % String(prop["id"])
	root.position = prop["position"]
	if prop.has("visual_offset_px"):
		root.position += prop["visual_offset_px"] as Vector2
	root.set_meta("y_sort_anchor", prop["position"])
	root.set_meta("visual_target", target)

	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	if prop["kind"] in MapTypes.BOAT_PROP_KINDS:
		shadow.visible = false
	shadow.polygon = Draw.ellipse(Vector2(0, 2) + MapVisualStyle.shadow_offset(target) * 0.35, Vector2(26, 9), 16)
	shadow.color = Color(MapVisualStyle.role_color(&"ink", target, time_of_day), MapVisualStyle.shadow_alpha(target, time_of_day))
	shadow.z_index = -2
	root.add_child(shadow)

	match prop["kind"] as StringName:
		MapTypes.PROP_KIND_ANVIL: Industrial.draw_anvil(root, target, time_of_day)
		MapTypes.PROP_KIND_HAY_STACK: Industrial.draw_hay_stack(root, prop, target, time_of_day)
		MapTypes.PROP_KIND_CART: Industrial.draw_cart(root, target, time_of_day)
		MapTypes.PROP_KIND_WELL: Industrial.draw_well(root, target, time_of_day)
		MapTypes.PROP_KIND_BARRELS: Harbor.draw_barrels(root, target, time_of_day)
		MapTypes.PROP_KIND_FURNACE: Industrial.draw_furnace(root, target, time_of_day)
		MapTypes.PROP_KIND_BELLOWS: Industrial.draw_bellows(root, target, time_of_day)
		MapTypes.PROP_KIND_LEDGER: Industrial.draw_ledger(root, target, time_of_day)
		MapTypes.PROP_KIND_BED: Industrial.draw_bed(root, target, time_of_day)
		MapTypes.PROP_KIND_CHEST: Industrial.draw_chest(root, target, time_of_day)
		MapTypes.PROP_KIND_TABLE: Industrial.draw_table(root, target, time_of_day)
		MapTypes.PROP_KIND_SHELF: Industrial.draw_shelf(root, target, time_of_day)
		MapTypes.PROP_KIND_QUENCH: Industrial.draw_quench(root, target, time_of_day)
		MapTypes.PROP_KIND_STAIRS: Industrial.draw_stairs(root, target, time_of_day)
		MapTypes.PROP_KIND_STALL: Industrial.draw_stall(root, target, time_of_day)
		MapTypes.PROP_KIND_HEARTH: Industrial.draw_hearth(root, target, time_of_day)
		MapTypes.PROP_KIND_CHAIR: Industrial.draw_chair(root, target, time_of_day)
		MapTypes.PROP_KIND_CANDLE: Industrial.draw_candle(root, target, time_of_day)
		MapTypes.PROP_KIND_BUSH: Nature.draw_bush(root, target, time_of_day)
		MapTypes.PROP_KIND_TREE: Nature.draw_tree(root, prop, target, time_of_day)
		MapTypes.PROP_KIND_FISHING_BOAT: Harbor.draw_fishing_boat(root, target, time_of_day)
		MapTypes.PROP_KIND_MERCHANT_BOAT: Harbor.draw_merchant_boat(root, target, time_of_day)
		MapTypes.PROP_KIND_CARGO_CRATES: Harbor.draw_cargo_crates(root, target, time_of_day)
		MapTypes.PROP_KIND_TRADE_GOODS: Harbor.draw_trade_goods(root, target, time_of_day)
		MapTypes.PROP_KIND_TIMBER_FENCE: Nature.draw_timber_fence(root, prop, target, time_of_day)
		MapTypes.PROP_KIND_CATTLE: Nature.draw_cattle(root, target, time_of_day)
		MapTypes.PROP_KIND_SHEEP: Nature.draw_sheep(root, target, time_of_day)
		MapTypes.PROP_KIND_HORSE: Nature.draw_horse(root, target, time_of_day)
		MapTypes.PROP_KIND_BANNER: Heraldry.draw_banner(root, prop, target, time_of_day)
		_:
			if prop["kind"] in MapTypes.DISTRICT_LIFE_PROP_KINDS:
				Life.draw_district_life_prop(root, prop["kind"], target, time_of_day)
			elif prop["kind"] in MapTypes.RURAL_LIFE_PROP_KINDS:
				Life.draw_rural_life_prop(root, prop["kind"], target, time_of_day)
			else:
				Draw.add_rect(root, "Marker", Vector2(-8, -8), Vector2(16, 16), Color.MAGENTA, target, time_of_day)
	if prop["kind"] in MapTypes.BOAT_PROP_KINDS and _has_tall_footprint(prop):
		root.rotation = PI * 0.5
	return root


static func _has_tall_footprint(prop: Dictionary) -> bool:
	var footprint: Variant = prop.get("footprint")
	return footprint is Rect2 and footprint.size.y > footprint.size.x
