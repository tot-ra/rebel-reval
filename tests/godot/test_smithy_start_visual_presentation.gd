extends "res://tests/godot/test_case.gd"

## Guards the authored first frame in Kalev's smithy. The visual route must stay
## non-blocking so DoorNavigator can keep placing the player on the central floor.

const KalevSmithyDefinition := preload(
	"res://scripts/map/definitions/lower_town/kalev_smithy_definition.gd"
)
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapTypes := preload("res://scripts/map/map_types.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")

const START_RUNNER_CELLS := [Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6), Vector2i(13, 6)]


func test_smithy_start_visual_route_is_warm_and_non_blocking() -> void:
	var definition: MapDefinition = KalevSmithyDefinition.create()
	var grid: MapTerrainGrid = MapBuilder.build(definition)
	for cell: Vector2i in START_RUNNER_CELLS:
		assert_eq(grid.get_terrain(cell), MapTypes.TERRAIN_STRAW)
		assert_true(
			MapVerification.is_walkable_cell(definition, grid, cell),
			"Start runner cell %s must remain walkable" % str(cell)
		)
	assert_true(
		MapVerification.is_walkable_point(definition, grid, definition.player_spawn),
		"Visual dressing must not block Kalev's central new-game spawn"
	)

	var nook_candle := _prop_by_id(definition, &"start_nook_candle")
	assert_eq(nook_candle.get("kind"), MapTypes.PROP_KIND_CANDLE)
	assert_eq(nook_candle.get("style_variant"), MapTypes.LIGHTING_VARIANT_ARTISAN_TALLOW)
	assert_true(nook_candle.has("visual_offset_px"), "Nook candle must be wall-mounted")
	var forge_splint := _prop_by_id(definition, &"forge_wayfinding_splint")
	assert_eq(forge_splint.get("kind"), MapTypes.PROP_KIND_CANDLE)
	assert_eq(forge_splint.get("style_variant"), MapTypes.LIGHTING_VARIANT_PINE_SPLINT)
	assert_false(forge_splint.has("footprint"), "Forge splint must not occupy the central lane")


func _prop_by_id(definition: MapDefinition, prop_id: StringName) -> Dictionary:
	for prop: Dictionary in definition.props:
		if prop.get("id", &"") == prop_id:
			return prop
	push_error("Missing smithy start prop %s" % String(prop_id))
	return {}
