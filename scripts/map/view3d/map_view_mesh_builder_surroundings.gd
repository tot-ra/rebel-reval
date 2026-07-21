class_name MapViewMeshBuilderSurroundings
extends RefCounted

## Exterior landscape ring outside playable bounds.

const _NeighborRegistry := preload("res://scripts/map/map_neighbor_preview_registry.gd")
const _Buildings := preload("res://scripts/map/view3d/map_view_mesh_builder_buildings.gd")
const _Props := preload("res://scripts/map/view3d/map_view_mesh_builder_props.gd")
const NEIGHBOR_PREVIEW_DEPTH_CELLS := 32
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
		root.add_child(_neighbor_preview(definition, neighbor, transition, side))
		previewed_sides[side] = true

	# Always paint continuation ground for authored sides. Neighbor previews
	# overlay the near strip; skipping the apron left sky void past that strip
	# at max zoom-out.
	for side in MapDefinition.WORLD_SIDES:
		match sides.get(side):
			&"water":
				root.add_child(_water_continuation(definition, map_size, side))
			&"woodland":
				root.add_child(_woodland_apron(definition, map_size, side))
			&"town":
				root.add_child(_town_apron(definition, map_size, side))

	var tree_batches: Dictionary = {}
	var boulders: Array[Transform3D] = []
	var boulder_colors: Array[Color] = []

	var town_sides := definition.surroundings_town_sides
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
			var scale_range := MapViewTreeSpecies.scale_range(size_class)
			var tree_scale := scale_range.x + MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 1913) * (scale_range.y - scale_range.x)
			var yaw := MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 2003) * TAU
			var species := MapViewTreeSpecies.pick_species(
				MapViewTreeSpecies.MIXED_WEIGHTS,
				MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 1499)
			)
			var tree_transform := MapViewMeshBuilderPrimitives.placed(spot, tree_scale, Vector3.ZERO, yaw)
			MapViewMeshBuilderProps._push_tree_instance(
				tree_batches,
				species,
				tree_transform,
				MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 2111),
				MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 2221)
			)

	if not tree_batches.is_empty():
		MapViewMeshBuilderProps._emit_tree_batches(root, tree_batches)
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

	if not town_sides.is_empty():
		root.add_child(_town_silhouette(definition, map_size, previewed_sides, MapViewMeshBuilderConfig.GLACIS_CLEARANCE))
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


## Cobble apron for town continuation sides so background silhouettes sit on
## urban ground instead of the empty void past the authored terrain mesh.


static func _town_apron(_definition: MapDefinition, map_size: Vector2, side: StringName) -> MeshInstance3D:
	var apron := MeshInstance3D.new()
	apron.name = "TownApron_%s" % side
	var mesh := PlaneMesh.new()
	var depth := MapViewMeshBuilderConfig.SURROUNDINGS_TOWN_DEPTH
	mesh.size = _side_band_size(map_size, side, depth)
	mesh.material = MapViewMaterials.surroundings_town()
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


## Background house masses continuing the town past the playable bounds on the
## urban sides, so a walled-city district no longer reads as a forest clearing.


static func _town_silhouette(
	definition: MapDefinition,
	map_size: Vector2,
	previewed_sides: Dictionary = {},
	preview_depth_cells: float = 0.0
) -> Node3D:
	var bodies: Array[Transform3D] = []
	var body_colors: Array[Color] = []
	var roofs: Array[Transform3D] = []
	var roof_colors: Array[Color] = []
	var inner := Rect2(Vector2.ZERO, map_size).grow(MapViewMeshBuilderConfig.TOWN_BAND_INNER)
	var outer := MapViewMeshBuilderConfig.TOWN_BAND_OUTER
	var start_x := int(-outer / MapViewMeshBuilderConfig.TOWN_GRID_SPACING)
	var end_x := int((map_size.x + outer) / MapViewMeshBuilderConfig.TOWN_GRID_SPACING)
	var start_y := int(-outer / MapViewMeshBuilderConfig.TOWN_GRID_SPACING)
	var end_y := int((map_size.y + outer) / MapViewMeshBuilderConfig.TOWN_GRID_SPACING)
	for gy in range(start_y, end_y + 1):
		for gx in range(start_x, end_x + 1):
			var base := Vector2(gx, gy) * MapViewMeshBuilderConfig.TOWN_GRID_SPACING
			var jitter := Vector2(
				MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 3301) - 0.5,
				MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 3407) - 0.5
			) * MapViewMeshBuilderConfig.TOWN_GRID_SPACING * 0.55
			var spot := base + jitter
			if inner.has_point(spot):
				continue
			var side := _world_side(spot, map_size)
			if not definition.surroundings_town_sides.has(side):
				continue
			if previewed_sides.has(side) and _distance_outside(spot, map_size) < preview_depth_cells:
				continue
			if MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 3511) > MapViewMeshBuilderConfig.TOWN_KEEP_RATIO:
				continue
			var width := 2.6 + MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 3607) * 2.6
			var depth := 2.2 + MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 3701) * 2.0
			var body_height := 1.7 + MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 3803) * 1.3
			var yaw := (MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 3907) - 0.5) * 0.24
			var body_basis := Basis(Vector3.UP, yaw).scaled(Vector3(width, body_height, depth))
			bodies.append(Transform3D(body_basis, Vector3(spot.x, body_height * 0.5, spot.y)))
			var tone := 0.8 + MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 4001) * 0.3
			body_colors.append(Color(tone, tone * 0.97, tone * 0.9))
			var rise := depth * (0.42 + MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 4111) * 0.14)
			var roof_basis := Basis(Vector3.UP, yaw).scaled(Vector3(width + 0.25, rise, depth + 0.25))
			roofs.append(Transform3D(roof_basis, Vector3(spot.x, body_height, spot.y)))
			var warmth := 0.72 + MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 4211) * 0.4
			roof_colors.append(Color(warmth, warmth * 0.86, warmth * 0.8))

	var root := Node3D.new()
	root.name = "TownSilhouette"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3.ONE
	root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("TownBodies", body_mesh, bodies, body_colors, MapViewMaterials.role(&"plaster"), Vector3.ZERO))
	root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("TownRoofs", MapViewMeshBuilderPrimitives.unit_roof_prism(), roofs, roof_colors, MapViewMeshBuilderPrimitives.role_material(&"roof"), Vector3.ZERO))
	return root


## Unit triangular prism (1 x 1 base, ridge along x at y = 1) scaled per town
## silhouette instance.


## A preview renders the real terrain and structures from the adjoining map, but
## never its gameplay bodies or navigation. It is aligned by reciprocal spawn IDs,
## so changing either authored edge updates both views on the next load.
static func _neighbor_preview(
	definition: MapDefinition,
	neighbor: MapDefinition,
	transition: Dictionary,
	side: StringName
) -> Node3D:
	var root := Node3D.new()
	root.name = "Neighbor_%s" % side
	if neighbor.cell_size != definition.cell_size:
		return root
	var reciprocal := _reciprocal_transition(neighbor, transition.get("destination_spawn_id", &""))
	if reciprocal.is_empty():
		return root
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
		props.add_child(_Props.build_prop(prop, neighbor.cell_size))
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
	var depth := NEIGHBOR_PREVIEW_DEPTH_CELLS
	match side:
		&"west":
			return Rect2i(maxi(0, size.x - depth), 0, mini(depth, size.x), size.y)
		&"east":
			return Rect2i(0, 0, mini(depth, size.x), size.y)
		&"north":
			return Rect2i(0, maxi(0, size.y - depth), size.x, mini(depth, size.y))
		_:
			return Rect2i(0, 0, size.x, mini(depth, size.y))
