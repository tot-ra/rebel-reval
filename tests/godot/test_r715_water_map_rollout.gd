extends "res://tests/godot/test_case.gd"

const MapAudit := preload("res://scripts/map/map_audit_registry.gd")
const MapBuilder := preload("res://scripts/map/map_builder.gd")
const MapVerification := preload("res://scripts/map/map_verification.gd")
const MapView := preload("res://scripts/map/view3d/map_view_3d.gd")
const MapViewMaterials := preload("res://scripts/map/view3d/map_view_materials.gd")
const MapTypesContract := preload("res://scripts/map/map_types.gd")

const EXPECTED_WATER_MAP_IDS: Array[StringName] = [
	&"smithy_courtyard",
	&"lower_town_slice",
	&"south_quarter",
	&"viru_gate_foreland",
	&"reval_harbor_north",
	&"reval_harbor_east",
	&"prototype.paldiski_coastal_outpost",
	&"prototype.sacred_grove",
	&"prototype.saaremaa",
	&"prototype.swedish_arrival",
	&"world.sacred_grove",
	&"world.padise",
	&"world.saaremaa",
]


func test_every_water_map_builds_shared_view_water_and_preserves_walkability() -> void:
	var covered: Array[StringName] = []
	for definition: MapDefinition in MapAudit.all():
		if definition.map_id.is_empty():
			continue
		var grid := MapBuilder.build(definition)
		if grid.size_cells != definition.size_cells:
			continue
		var water_ids := _water_ids(grid)
		if water_ids.is_empty():
			continue
		covered.append(definition.map_id)
		var grid_fingerprint_before := grid.fingerprint()
		var walkability_before := _walkability_signature(definition, grid)
		var view := MapView.create(definition, grid)
		assert_true(view != null, "%s must create a 3D view" % definition.map_id)
		if view == null:
			continue
		_assert_single_shared_presenters(view, definition.map_id)
		for terrain_id: StringName in water_ids:
			_assert_water_surface(view, terrain_id, definition.map_id)
		assert_eq(
			grid.fingerprint(),
			grid_fingerprint_before,
			"%s view build must not mutate the terrain fingerprint" % definition.map_id,
		)
		assert_eq(
			_walkability_signature(definition, grid),
			walkability_before,
			"%s view build must not mutate gameplay walkability" % definition.map_id,
		)
		_free_view(view)
	covered.sort()
	var expected: Array[StringName] = EXPECTED_WATER_MAP_IDS.duplicate()
	expected.sort()
	assert_eq(covered, expected, "every inventoried water map must receive rollout coverage")


func test_water_rollout_uses_the_closed_shared_material_catalog() -> void:
	assert_eq(
		MapViewMaterials.WATER_TERRAINS,
		MapTypesContract.WATER_TERRAINS,
		"rollout must use the closed MapTypes water vocabulary",
	)
	for terrain_id: StringName in MapTypesContract.WATER_TERRAINS:
		var material := MapViewMaterials.water_surface(terrain_id)
		assert_true(material is ShaderMaterial, "%s needs the approved shader material" % terrain_id)
		if material is ShaderMaterial:
			assert_true(
				(material as ShaderMaterial).shader != null,
				"%s needs the shared water shader" % terrain_id,
			)


func _assert_single_shared_presenters(view: MapView, map_id: StringName) -> void:
	var environments := view.find_children("*", "WorldEnvironment", true, false)
	assert_eq(
		environments.size(),
		1,
		"%s must keep one shared WorldEnvironment" % map_id,
	)
	assert_eq(
		view.find_children("ViewEnvironment", "WorldEnvironment", true, false).size(),
		1,
		"%s must use the MapView3D environment owner" % map_id,
	)
	assert_eq(
		view.find_children("SkyWeather", "SkyWeather3D", true, false).size(),
		1,
		"%s must keep one shared SkyWeather3D presenter" % map_id,
	)


func _assert_water_surface(view: MapView, terrain_id: StringName, map_id: StringName) -> void:
	var surface := view.get_node_or_null("Terrain/Terrain_%s" % String(terrain_id)) as MeshInstance3D
	assert_true(
		surface != null,
		"%s must build a visible surface for %s" % [map_id, terrain_id],
	)
	if surface == null:
		return
	assert_true(
		surface.mesh != null and surface.mesh.get_surface_count() > 0,
		"%s %s surface must contain geometry" % [map_id, terrain_id],
	)
	var material := surface.material_override as ShaderMaterial
	var approved := MapViewMaterials.water_surface(terrain_id)
	assert_eq(
		material,
		approved,
		"%s %s surface must use the shared approved material" % [map_id, terrain_id],
	)


func _water_ids(grid: MapTerrainGrid) -> Array[StringName]:
	var result: Array[StringName] = []
	for terrain_id: StringName in MapTypesContract.WATER_TERRAINS:
		if grid.used_terrain_ids().has(terrain_id):
			result.append(terrain_id)
	return result


func _walkability_signature(definition: MapDefinition, grid: MapTerrainGrid) -> String:
	var blocked := MapVerification.blocked_cells(definition)
	var cells := PackedByteArray()
	cells.resize(definition.size_cells.x * definition.size_cells.y)
	for y in definition.size_cells.y:
		for x in definition.size_cells.x:
			var cell := Vector2i(x, y)
			var walkable := not MapTypesContract.WATER_TERRAINS.has(grid.get_terrain(cell))
			walkable = walkable and not blocked.has(cell)
			cells[y * definition.size_cells.x + x] = 1 if walkable else 0
	return cells.hex_encode()


func _free_view(view: MapView) -> void:
	if not is_instance_valid(view):
		return
	MapView._strip_geometry_materials(view)
	view.free()
