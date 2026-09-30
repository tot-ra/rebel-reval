class_name MapViewMeshBuilderBuildingHouses
extends RefCounted

## Stable facade for house style, structure, roof, chimney, and civic-detail builders.

const _Styles := preload("res://scripts/map/view3d/map_view_mesh_builder_house_styles.gd")
const _RoofDressing := preload(
	"res://scripts/map/view3d/map_view_mesh_builder_house_roof_dressing.gd"
)
const _Structure := preload("res://scripts/map/view3d/map_view_mesh_builder_house_structure.gd")
const _Rural := preload("res://scripts/map/view3d/map_view_rural_dwelling_models.gd")
const _ProductionModels := preload("res://scripts/map/view3d/map_view_burgher_house_models.gd")
const _ProductionStone := preload(
	"res://scripts/map/view3d/map_view_burgher_house_stone_models.gd"
)
const _ProductionBoda := preload(
	"res://scripts/map/view3d/map_view_burgher_house_craft_boda_models.gd"
)
const _ServiceBuildings := preload("res://scripts/map/view3d/map_view_service_building_models.gd")
const _TownHall := preload("res://scripts/map/view3d/map_view_town_hall_model.gd")

static func house_style(building: Dictionary) -> StringName:
	return _Styles.house_style(building)


static func house_wall_material(
	building: Dictionary, wall_color: Color, size: Vector3
) -> StandardMaterial3D:
	if _TownHall.is_town_hall(building):
		return _TownHall.wall_material(building, size)
	return _Styles.house_wall_material(building, wall_color, size)


static func roof_style(building: Dictionary) -> StringName:
	return _Styles.roof_style(building)


static func house_roof_material(building: Dictionary) -> StandardMaterial3D:
	if _TownHall.is_town_hall(building):
		return _TownHall.roof_material(building)
	return _Styles.house_roof_material(building)


static func add_house_structure(
	root: Node3D, building: Dictionary, size: Vector2, height: float, along_ridge_x: bool
) -> void:
	_Structure.add_house_structure(root, building, size, height, along_ridge_x)


static func add_roof_trim(
	root: Node3D, building: Dictionary, size: Vector2, height: float, along_ridge_x: bool
) -> void:
	_RoofDressing.add_roof_trim(root, building, size, height, along_ridge_x)


## Buildings whose entrance portal is built on the mass axis, so the functional
## door must be snapped onto that axis rather than follow the approach trigger.
static func centres_entrance(building: Dictionary) -> bool:
	return _TownHall.is_town_hall(building)


## Facade openings authored by the primitive itself must not be doubled by the
## generic house door and window pass.
static func authors_own_facade(building: Dictionary) -> bool:
	return (
		_TownHall.is_town_hall(building)
		or _Rural.is_rural_1343(building)
		or MapViewMonasticModels.is_oratory(building)
	)


## Smoke cottages and early barn-dwellings use a flueless corner oven. A generic
## roof stack would turn the archaeological baseline into a later heated house.
static func allows_chimney(building: Dictionary) -> bool:
	# An oratory has no hearth, so a roof stack would misread it as a dwelling.
	return (
		not _Rural.is_smoke_heated(building)
		and (StringName(building.get("primitive", &"")) != _Rural.RURAL_BARN_PRIMITIVE)
		and not MapViewMonasticModels.is_oratory(building)
		and not MapViewMonasticModels.is_unheated_range(building)
	)


static func add_authored_facade(
	root: Node3D, building: Dictionary, size: Vector2, height: float
) -> void:
	if _Rural.is_rural_1343(building):
		_Rural.add_facade(root, building, size, height)
	elif MapViewMonasticModels.is_oratory(building):
		MapViewMonasticModels.add_oratory_facade(root, building, size, height)


static func add_production_model(
	root: Node3D, building: Dictionary, size: Vector2, height: float
) -> Node3D:
	if _ProductionModels.is_production_tier(building):
		return _ProductionModels.add_model(root, building, size, height)
	if _ProductionStone.is_production_tier(building):
		return _ProductionStone.add_model(root, building, size, height)
	if _ProductionBoda.is_production_tier(building):
		return _ProductionBoda.add_model(root, building, size, height)
	if _ServiceBuildings.is_service_building(building):
		return _ServiceBuildings.add_model(root, building, size)
	return null


## WB-07c (R-1006): every GLB add_production_model() may load for this building,
## so staged assembly can prefetch them off the main thread. It lists the whole
## tier, not the fitted variant: an extra kit load is cheap, a miss is not.
static func production_scene_paths(building: Dictionary) -> PackedStringArray:
	var variants: Array[Dictionary] = []
	if _ProductionModels.is_production_tier(building):
		variants = _ProductionModels.MERCHANT_TIMBER_VARIANTS
	elif _ProductionStone.is_production_tier(building):
		variants = _ProductionStone.MERCHANT_STONE_VARIANTS
	elif _ProductionBoda.is_production_tier(building):
		variants = _ProductionBoda.CRAFT_BODA_VARIANTS
	else:
		variants = _ServiceBuildings.variants_for(building)
	var paths := PackedStringArray()
	for variant in variants:
		paths.append(String(variant["path"]))
	return paths


## Every GLB and surface-variant plate the production models of `buildings` may
## load; the plates only when at least one building has a production model.
static func production_resource_paths(buildings: Array) -> PackedStringArray:
	var paths := PackedStringArray()
	for building: Dictionary in buildings:
		paths.append_array(production_scene_paths(building))
	if not paths.is_empty():
		paths.append_array(MapViewBurgherHouseSurfaceVariety.kit_texture_paths())
	return paths

static func add_historic_building_details(
	root: Node3D, building: Dictionary, size: Vector2, height: float, along_ridge_x: bool
) -> void:
	match StringName(building.get("primitive", &"")):
		_TownHall.PRIMITIVE:
			_TownHall.add_details(root, building, size, height)
		&"holy_spirit_chapel_1343":
			_add_holy_spirit_chapel_details(root, size, height)
		&"stepped_gable_merchant":
			_add_stepped_merchant_gable(root, size, height, along_ridge_x)
		MapViewMonasticModels.ORATORY_PRIMITIVE:
			MapViewMonasticModels.add_oratory_details(root, building, size, height, along_ridge_x)


static func _add_holy_spirit_chapel_details(root: Node3D, size: Vector2, height: float) -> void:
	var facade_z := size.y * 0.5 + 0.13
	var window_count := clampi(int(size.x / 2.7), 3, 6)
	for index in window_count:
		var x := (float(index + 1) / float(window_count + 1) - 0.5) * size.x
		var opening_height := minf(1.75, height * 0.42)
		MapViewMeshBuilderPrimitives.box(
			root,
			"Lancet%02d" % index,
			Vector3(0.42, opening_height, 0.06),
			Vector3(x, height * 0.52, facade_z),
			&"window"
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"LancetMullion%02d" % index,
			Vector3(0.055, opening_height, 0.09),
			Vector3(x, height * 0.52, facade_z + 0.04),
			&"stone"
		)
	var cote_x := -size.x * 0.24
	var cote_base := height + 0.2
	MapViewMeshBuilderPrimitives.box(
		root,
		"SanctusCote",
		Vector3(0.72, 1.1, 0.72),
		Vector3(cote_x, cote_base + 0.55, 0.0),
		&"stone"
	)
	var cote_roof := MeshInstance3D.new()
	cote_roof.name = "SanctusCoteRoof"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.62
	cone.height = 1.15
	cone.radial_segments = 4
	cote_roof.mesh = cone
	cote_roof.position = Vector3(cote_x, cote_base + 1.1 + cone.height * 0.5, 0.0)
	cote_roof.rotation.y = PI * 0.25
	cote_roof.material_override = MapViewMaterials.roof(Color8(82, 47, 38))
	root.add_child(cote_roof)


static func _add_stepped_merchant_gable(
	root: Node3D, size: Vector2, height: float, along_ridge_x: bool
) -> void:
	var front_side := &"south"
	var facade_width := size.x
	var face_offset := size.y * 0.5
	if along_ridge_x:
		front_side = &"east"
		facade_width = size.y
		face_offset = size.x * 0.5
	var step_widths := [0.78, 0.54, 0.30]
	for index in step_widths.size():
		var step_width := facade_width * float(step_widths[index])
		var step_height := 0.32 + float(index) * 0.18
		MapViewMeshBuilderBuildingFacade.facade_box(
			root,
			"GableStep%02d" % index,
			Vector3(step_width, step_height, 0.32),
			0.0,
			height + 0.18 + float(index) * 0.34,
			front_side,
			face_offset,
			&"stone"
		)
	MapViewMeshBuilderBuildingFacade.facade_box(
		root,
		"GablePinnacle",
		Vector3(0.22, 0.78, 0.28),
		0.0,
		height + 1.42,
		front_side,
		face_offset,
		&"stone"
	)


static func add_chimney(
	root: Node3D, building: Dictionary, size: Vector2, wall_height: float, ridge_along_x: bool
) -> void:
	if not allows_chimney(building):
		return
	var building_id: StringName = building["id"]
	var seed := String(building_id).hash()
	var chimney_size := MapViewMeshBuilderConfig.CHIMNEY_SIZE
	var chimney_half := chimney_size * 0.5
	var roof_style := _Styles.roof_style(building)
	var roof_overhang := MapViewMeshBuilderConfig.ROOF_OVERHANG
	var roof_pitch := MapViewMeshBuilderConfig.ROOF_PITCH
	if roof_style == MapViewMeshBuilderConfig.ROOF_STYLE_THATCH:
		roof_overhang = MapViewMeshBuilderConfig.THATCH_ROOF_OVERHANG
		roof_pitch = MapViewMeshBuilderConfig.THATCH_ROOF_PITCH
	var half_span := (size.y if ridge_along_x else size.x) * 0.5 + roof_overhang
	var rise := half_span * roof_pitch
	# Near one ridge end, fully on one slope face so the shaft pierces tiles
	# instead of balancing on the peak like a cube.
	var along := ((size.x if ridge_along_x else size.y) * 0.5 - chimney_size) * 0.62
	if seed % 2 == 0:
		along = -along
	var slope_side := 1.0 if (seed >> 1) % 2 == 0 else -1.0
	var across := slope_side * (chimney_half + MapViewMeshBuilderConfig.CHIMNEY_RIDGE_CLEARANCE)
	var offset := Vector3(along, 0.0, across) if ridge_along_x else Vector3(across, 0.0, along)
	# Embed from the downhill roof edge under the footprint so the whole stack
	# volume intersects the roof plane.
	var across_edge := minf(absf(across) + chimney_half, half_span)
	var roof_y_edge := wall_height + rise * (1.0 - across_edge / half_span)
	var stack_bottom := roof_y_edge - MapViewMeshBuilderConfig.CHIMNEY_STACK_EMBED
	var stack_height := MapViewMeshBuilderConfig.CHIMNEY_STACK_HEIGHT
	var stack_center_y := stack_bottom + stack_height * 0.5
	var top := stack_bottom + stack_height
	MapViewMeshBuilderPrimitives.add_chimney_stack(
		root, "Chimney", chimney_size, stack_height, offset + Vector3(0.0, stack_center_y, 0.0)
	)

	if ChimneySmoke3D.schedule_for(seed) == ChimneySmoke3D.Schedule.NEVER:
		return
	var smoke: ChimneySmoke3D = MapViewMeshBuilderConfig.CHIMNEY_SMOKE_SCRIPT.new()
	smoke.position = offset + Vector3(0.0, top + 0.1, 0.0)
	smoke.configure(building_id)
	root.add_child(smoke)


static func add_window_lights(root: Node3D, building: Dictionary) -> void:
	if _Rural.is_rural_1343(building):
		return
	var lights: BuildingWindowLights3D = MapViewMeshBuilderConfig.WINDOW_LIGHTS_SCRIPT.new()
	root.add_child(lights)
	lights.configure(building["id"])
