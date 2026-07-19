class_name MapViewMeshBuilderSurroundings
extends RefCounted

## Exterior landscape ring outside playable bounds.

static func build_surroundings(definition: MapDefinition) -> Node3D:
	var root := Node3D.new()
	root.name = "Surroundings"
	if definition.suppresses_exterior_surroundings():
		return root
	var sides: Dictionary = definition.resolved_surroundings_sides()
	if sides.is_empty():
		return root
	var map_size := Vector2(definition.size_cells)

	for side in MapDefinition.WORLD_SIDES:
		match sides.get(side):
			&"water":
				root.add_child(_water_continuation(definition, map_size, side))
			&"woodland":
				root.add_child(_woodland_apron(definition, map_size, side))
			&"town":
				root.add_child(_town_apron(definition, map_size, side))

	var trunks: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var spruces: Array[Transform3D] = []
	var spruce_colors: Array[Color] = []
	var leaves: Array[Transform3D] = []
	var leaf_colors: Array[Color] = []
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
			var tree_scale := 0.75 + MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 1907) * 0.7
			var yaw := MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 2003) * TAU
			trunks.append(MapViewMeshBuilderPrimitives.placed(spot, tree_scale, Vector3(0.0, 0.6 * tree_scale, 0.0), yaw))
			var bark := 0.85 + MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 2111) * 0.3
			trunk_colors.append(Color(bark, bark, bark))
			var tint := 0.8 + MapViewMeshBuilderPrimitives.hash01(gx, gy, definition.seed + 2221) * 0.4
			if kind_roll < 0.6:
				spruces.append(MapViewMeshBuilderPrimitives.placed(spot, tree_scale, Vector3(0.0, 0.4 * tree_scale, 0.0), yaw))
				spruce_colors.append(Color(tint * 0.9, tint, tint * 0.88))
			else:
				leaves.append(MapViewMeshBuilderPrimitives.placed(spot, tree_scale, Vector3(0.0, 1.5 * tree_scale, 0.0), yaw))
				leaf_colors.append(Color(tint * 0.96, tint, tint * 0.8))

	if not trunks.is_empty() or not spruces.is_empty() or not leaves.is_empty() or not boulders.is_empty():
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.09
		trunk_mesh.bottom_radius = 0.15
		trunk_mesh.height = 1.2
		trunk_mesh.radial_segments = 7
		root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("Trunks", trunk_mesh, trunks, trunk_colors, MapViewMaterials.bark(), Vector3.ZERO))
		root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("SpruceCanopies", MapViewMeshBuilderPrimitives.spruce_canopy_mesh(), spruces, spruce_colors, MapViewMaterials.canopy(&"spruce"), Vector3.ZERO))
		root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("LeafCanopies", MapViewMeshBuilderPrimitives.leaf_canopy_mesh(), leaves, leaf_colors, MapViewMaterials.canopy(&"leaf"), Vector3.ZERO))
		var boulder_mesh := SphereMesh.new()
		boulder_mesh.radius = 0.45
		boulder_mesh.height = 0.6
		boulder_mesh.radial_segments = 7
		boulder_mesh.rings = 4
		root.add_child(MapViewMeshBuilderPrimitives.multi_mesh("Boulders", boulder_mesh, boulders, boulder_colors, MapViewMaterials.role(&"stone"), Vector3.ZERO))

	if not town_sides.is_empty():
		root.add_child(_town_silhouette(definition, map_size))
	return root


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
	match side:
		&"north", &"south":
			return Vector2(map_size.x + MapViewMeshBuilderConfig.TREE_BAND_OUTER * 2.0, depth)
		_:
			return Vector2(depth, map_size.y + MapViewMeshBuilderConfig.TREE_BAND_OUTER * 2.0)




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


static func _town_silhouette(definition: MapDefinition, map_size: Vector2) -> Node3D:
	var bodies: Array[Transform3D] = []
	var body_colors: Array[Color] = []
	var roofs: Array[Transform3D] = []
	var roof_colors: Array[Color] = []
	var inner := Rect2(Vector2.ZERO, map_size).grow(MapViewMeshBuilderConfig.TOWN_BAND_INNER)
	var start_x := int(-MapViewMeshBuilderConfig.TREE_BAND_OUTER / MapViewMeshBuilderConfig.TOWN_GRID_SPACING)
	var end_x := int((map_size.x + MapViewMeshBuilderConfig.TREE_BAND_OUTER) / MapViewMeshBuilderConfig.TOWN_GRID_SPACING)
	var start_y := int(-MapViewMeshBuilderConfig.TREE_BAND_OUTER / MapViewMeshBuilderConfig.TOWN_GRID_SPACING)
	var end_y := int((map_size.y + MapViewMeshBuilderConfig.TREE_BAND_OUTER) / MapViewMeshBuilderConfig.TOWN_GRID_SPACING)
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
			if not definition.surroundings_town_sides.has(_world_side(spot, map_size)):
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
