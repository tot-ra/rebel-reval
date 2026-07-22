class_name MapViewMeshBuilderSurroundings
extends RefCounted

## Exterior landscape ring outside playable bounds.

const _NeighborRegistry := preload("res://scripts/map/map_neighbor_preview_registry.gd")
const _Buildings := preload("res://scripts/map/view3d/map_view_mesh_builder_buildings.gd")
const _PropModels := preload("res://scripts/map/view3d/map_view_mesh_builder_prop_models.gd")
const _Scatter := preload("res://scripts/map/view3d/map_view_mesh_builder_scatter.gd")
## At max zoom-out the rotated orthographic ground footprint reaches about 66
## cells past an edge on a 16:9 viewport. Keep a generous margin for wider
## viewports so every visible urban structure comes from the authored neighbor.
const NEIGHBOR_VISIBLE_DEPTH_CELLS := 96
const NEIGHBOR_GROUND_Y := -0.025

static func build_surroundings(definition: MapDefinition) -> Node3D:
	var root := Node3D.new()
	root.name = "Surroundings"
	if definition.suppresses_exterior_surroundings():
		return root
	var sides: Dictionary = definition.resolved_surroundings_sides()
	if sides.is_empty():
		return root
	var map_size := Vector2(definition.size_cells)
	var previewed_sides: Dictionary = {}
	for transition in definition.transitions:
		if transition.get("transition_visual", MapTypes.TRANSITION_VISUAL_DOOR) != MapTypes.TRANSITION_VISUAL_GROUND:
			continue
		var side := _transition_side(definition, transition)
		if side.is_empty() or previewed_sides.has(side):
			continue
		var neighbor := _NeighborRegistry.create_definition(transition.get("destination_scene_id", &""))
		if neighbor == null:
			continue
		var preview := _neighbor_preview(definition, neighbor, transition, side)
		if preview == null:
			continue
		root.add_child(preview)
		previewed_sides[side] = true

	# Natural and water backdrops may extend beyond authored maps. Urban sides do
	# not receive any filler: their visible continuation must come from a neighbor.
	for side in MapDefinition.WORLD_SIDES:
		match sides.get(side):
			&"water":
				root.add_child(_water_continuation(definition, map_size, side))
			&"woodland":
				root.add_child(_woodland_apron(definition, map_size, side))

	var tree_batches: Dictionary = {}
	var boulders: Array[Transform3D] = []
	var boulder_colors: Array[Color] = []

	var inner := Rect2(Vector2.ZERO, map_size).grow(MapViewMeshBuilderConfig.TREE_BAND_INNER)
	var start_x := int(-MapViewMeshBuilderConfig.TREE_BAND_OUTER / MapViewMeshBuilderConfig.TREE_GRID_SPACING)
	var end_x := int((map_size.x + MapViewMeshBuilderConfig.TREE_BAND_OUTER) / MapViewMeshBuilderConfig.TREE_GRID_SPACING)
	var start_y := int(-MapViewMeshBuilderConfig.TREE_BAND_OUTER / MapViewMeshBuilderConfig.TREE_GRID_SPACING)
	var end_y := int((map_size.y + MapViewMeshBuilderConfig.TREE_BAND_OUTER) / MapViewMeshBuilderConfig.TREE_GRID_SPACING)
	for gy in range(start_y, end_y + 1):
		for gx in range(start_x, end_x + 1):
			var base := Vector2(gx, gy) * MapViewMeshBuilderConfig.TREE_GRID_SPACING
			var jitter := Vector2(
				MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 601) - 0.5,
				MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 907) - 0.5
			) * MapViewMeshBuilderConfig.TREE_GRID_SPACING * 0.9
			var spot := base + jitter
			if inner.has_point(spot):
				continue
			var side := _world_side(spot, map_size)
			if previewed_sides.has(side):
				continue
			if sides.get(side) != &"woodland":
				continue
			if _distance_outside(spot, map_size) < MapViewMeshBuilderConfig.GLACIS_CLEARANCE:
				continue
			var keep := MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 1201)
			if keep > MapViewMeshBuilderConfig.TREE_KEEP_RATIO:
				continue
			var kind_roll := MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 1499)
			if kind_roll < 0.06:
				var boulder_scale := 0.5 + MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 1601) * 0.9
				boulders.append(MapViewMeshBuilderPrimitives.placed(spot, boulder_scale, Vector3(0.0, 0.16 * boulder_scale, 0.0), MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 1733) * TAU))
				var gray := 0.85 + MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 1801) * 0.25
				boulder_colors.append(Color(gray, gray, gray))
				continue
			var size_class := MapViewTreeSpecies.pick_size(
				MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 1907)
			)
			var scale_vec := MapViewTreeSpecies.instance_scale(
				size_class,
				MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 1913)
			)
			var yaw := MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 2003) * TAU
			var species := MapViewTreeSpecies.pick_species(
				MapViewTreeSpecies.MIXED_WEIGHTS,
				MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 1499)
			)
			var tree_transform := Transform3D(
				Basis(Vector3.UP, yaw).scaled(scale_vec),
				Vector3(spot.x, 0.0, spot.y)
			)
			_Scatter._push_tree_instance(
				tree_batches,
				species,
				tree_transform,
				MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 2111),
				MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 2221)
			)

	if not tree_batches.is_empty():
		_Scatter._emit_tree_batches(root, tree_batches)
		# Stable names expected by mesh/wind regression tests.
		_alias_tree_layer(root, "Trees_Spruce", "SpruceCanopies")
		_alias_tree_layer(root, "Trees_Broad", "LeafCanopies")
		_alias_tree_layer(root, "TreeTrunks", "Trunks")

	if not boulders.is_empty():
		var boulder_mesh := SphereMesh.new()
		boulder_mesh.radius = 0.45
		boulder_mesh.height = 0.6
		boulder_mesh.radial_segments = 7
		boulder_mesh.rings = 4
		root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("Boulders", boulder_mesh, boulders, boulder_colors, MapViewMaterials.natural_rock(), Vector3.ZERO))
	return root


static func _alias_tree_layer(root: Node3D, from_name: String, to_name: String) -> void:
	var node := root.get_node_or_null(from_name)
	if node != null:
		node.name = to_name


## Meadow apron strip for one explicit woodland side.


static func _woodland_apron(_definition: MapDefinition, map_size: Vector2, side: StringName) -> MeshInstance3D:
	var apron := MeshInstance3D.new()
	apron.name = "WoodlandApron_%s" % side
	var mesh := PlaneMesh.new()
	var depth := MapViewMeshBuilderConfig.SURROUNDINGS_WOODLAND_DEPTH
	mesh.size = _side_band_size(map_size, side, depth)
	mesh.material = MapViewMaterials.surroundings_ground()
	apron.mesh = mesh
	apron.position = _edge_band_center(map_size, side, depth * 0.5, -MapViewMeshBuilderConfig.WATER_RECESS - 0.04)
	return apron


## Shallow then deep animated water past one map edge so harbours read as open sea.


static func _water_continuation(_definition: MapDefinition, map_size: Vector2, side: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "Water_%s" % side
	var shallow_depth := MapViewMeshBuilderConfig.SURROUNDINGS_WATER_SHALLOW_DEPTH
	var deep_depth := MapViewMeshBuilderConfig.SURROUNDINGS_WATER_DEEP_DEPTH
	var y := -MapViewMeshBuilderConfig.WATER_RECESS
	root.add_child(_surroundings_water_plane(
		"Shallow",
		_side_band_size(map_size, side, shallow_depth),
		_edge_band_center(map_size, side, shallow_depth * 0.5, y),
		MapTypes.TERRAIN_SHALLOW_WATER
	))
	root.add_child(_surroundings_water_plane(
		"Deep",
		_side_band_size(map_size, side, deep_depth),
		_edge_band_center(map_size, side, shallow_depth + deep_depth * 0.5, y),
		MapTypes.TERRAIN_DEEP_WATER
	))
	return root




static func _surroundings_water_plane(
	plane_name: String,
	size: Vector2,
	center: Vector3,
	terrain_id: StringName
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = plane_name
	var mesh := PlaneMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = center
	instance.material_override = MapViewMaterials.water_surface(terrain_id)
	return instance




static func _side_band_size(map_size: Vector2, side: StringName, depth: float) -> Vector2:
	# Lateral overhang matches continuation depth so 45-degree corners stay
	# covered when the gameplay camera looks diagonally past a map edge.
	var overhang := maxf(depth, MapViewMeshBuilderConfig.TREE_BAND_OUTER)
	match side:
		&"north", &"south":
			return Vector2(map_size.x + overhang * 2.0, depth)
		_:
			return Vector2(depth, map_size.y + overhang * 2.0)




static func _edge_band_center(map_size: Vector2, side: StringName, outward: float, height: float) -> Vector3:
	match side:
		&"north":
			return Vector3(map_size.x * 0.5, height, -outward)
		&"south":
			return Vector3(map_size.x * 0.5, height, map_size.y + outward)
		&"west":
			return Vector3(-outward, height, map_size.y * 0.5)
		_:
			return Vector3(map_size.x + outward, height, map_size.y * 0.5)


## Which side of the map bounds a surroundings spot falls on.


static func _world_side(spot: Vector2, map_size: Vector2) -> StringName:
	var west := -spot.x
	var east := spot.x - map_size.x
	var north := -spot.y
	var south := spot.y - map_size.y
	var best := maxf(maxf(west, east), maxf(north, south))
	if best == east:
		return &"east"
	if best == west:
		return &"west"
	if best == north:
		return &"north"
	return &"south"




static func _distance_outside(spot: Vector2, map_size: Vector2) -> float:
	return maxf(
		maxf(-spot.x, spot.x - map_size.x),
		maxf(-spot.y, spot.y - map_size.y)
	)




## A preview renders the complete visible terrain and structures from the
## adjoining map, but never its gameplay bodies or navigation. It is aligned by
## reciprocal spawn IDs, so changing either authored district updates the seam on
## next load. WHY: the old shallow strip exposed procedural filler houses at
## normal zoom; the preview now covers the maximum gameplay camera footprint.
static func _neighbor_preview(
	definition: MapDefinition,
	neighbor: MapDefinition,
	transition: Dictionary,
	side: StringName
) -> Node3D:
	if neighbor.cell_size != definition.cell_size:
		return null
	var reciprocal := _reciprocal_transition(neighbor, transition.get("destination_spawn_id", &""))
	if reciprocal.is_empty():
		return null
	var root := Node3D.new()
	root.name = "Neighbor_%s" % side
	var offset := _neighbor_offset(definition, neighbor, transition, reciprocal, side)
	var bounds := _neighbor_strip(neighbor.size_cells, side)
	var grid := MapBuilder.build(neighbor)
	var surfaces: Dictionary = {}
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var terrain := grid.get_terrain(Vector2i(x, y))
			if not surfaces.has(terrain):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surfaces[terrain] = surface
			_add_preview_quad(surfaces[terrain], Vector2(x, y) + offset, terrain)
	for terrain in surfaces:
		var instance := MeshInstance3D.new()
		instance.name = "Terrain_%s" % String(terrain)
		instance.mesh = (surfaces[terrain] as SurfaceTool).commit()
		instance.material_override = MapViewMaterials.water_surface(terrain) if MapTypes.WATER_TERRAINS.has(terrain) else MapViewMaterials.terrain(terrain, neighbor.seed)
		root.add_child(instance)
	var source_world_bounds := neighbor.cell_rect_to_world_rect(bounds)
	var offset_px := offset * float(neighbor.cell_size)
	var buildings := Node3D.new()
	buildings.name = "Buildings"
	root.add_child(buildings)
	for source in neighbor.buildings:
		if not source_world_bounds.intersects(source["footprint"]):
			continue
		var building: Dictionary = source.duplicate(true)
		building["footprint"] = Rect2(source["footprint"].position + offset_px, source["footprint"].size)
		buildings.add_child(_Buildings.build_building(building, neighbor.cell_size))
	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	for source in neighbor.props:
		if not source_world_bounds.has_point(source["position"]):
			continue
		var prop: Dictionary = source.duplicate(true)
		prop["position"] = source["position"] + offset_px
		if prop.has("footprint"):
			prop["footprint"] = Rect2(prop["footprint"].position + offset_px, prop["footprint"].size)
		props.add_child(_PropModels.build_prop(prop, neighbor.cell_size))
	return root


static func _add_preview_quad(surface: SurfaceTool, cell: Vector2, terrain: StringName) -> void:
	var y := -MapViewMeshBuilderConfig.WATER_RECESS if MapTypes.WATER_TERRAINS.has(terrain) else NEIGHBOR_GROUND_Y
	var points := [cell, cell + Vector2.RIGHT, cell + Vector2.ONE, cell + Vector2.DOWN]
	for index in [0, 2, 1, 0, 3, 2]:
		var point: Vector2 = points[index]
		surface.set_normal(Vector3.UP)
		surface.set_uv(point / MapViewMaterials.TERRAIN_TEXTURE_WORLD_SIZE)
		surface.add_vertex(Vector3(point.x, y, point.y))


static func _transition_side(definition: MapDefinition, transition: Dictionary) -> StringName:
	var rect: Rect2 = transition["rect"]
	var world := definition.world_size()
	var distances := {
		&"west": rect.position.x,
		&"east": world.x - rect.end.x,
		&"north": rect.position.y,
		&"south": world.y - rect.end.y,
	}
	var nearest: StringName = &"west"
	for side: StringName in distances:
		if float(distances[side]) < float(distances[nearest]):
			nearest = side
	# Authored transitions may sit a short approach inside the terrain edge so the
	# camera can show road beyond a city gate. They still describe that edge.
	var max_approach := float(definition.cell_size * 12)
	return nearest if float(distances[nearest]) <= max_approach else &""


static func _reciprocal_transition(neighbor: MapDefinition, spawn_id: StringName) -> Dictionary:
	for transition in neighbor.transitions:
		if transition.get("spawn_id", &"") == spawn_id:
			return transition
	return {}


static func _neighbor_offset(
	definition: MapDefinition,
	neighbor: MapDefinition,
	transition: Dictionary,
	reciprocal: Dictionary,
	side: StringName
) -> Vector2:
	var scale := 1.0 / float(definition.cell_size)
	var current_center: Vector2 = transition["rect"].get_center() * scale
	var neighbor_center: Vector2 = reciprocal["rect"].get_center() * scale
	match side:
		&"west":
			return Vector2(-neighbor.size_cells.x, current_center.y - neighbor_center.y)
		&"east":
			return Vector2(definition.size_cells.x, current_center.y - neighbor_center.y)
		&"north":
			return Vector2(current_center.x - neighbor_center.x, -neighbor.size_cells.y)
		_:
			return Vector2(current_center.x - neighbor_center.x, definition.size_cells.y)


static func _neighbor_strip(size: Vector2i, side: StringName) -> Rect2i:
	var depth := NEIGHBOR_VISIBLE_DEPTH_CELLS
	match side:
		&"west":
			return Rect2i(maxi(0, size.x - depth), 0, mini(depth, size.x), size.y)
		&"east":
			return Rect2i(0, 0, mini(depth, size.x), size.y)
		&"north":
			return Rect2i(0, maxi(0, size.y - depth), size.x, mini(depth, size.y))
		_:
			return Rect2i(0, 0, size.x, mini(depth, size.y))
