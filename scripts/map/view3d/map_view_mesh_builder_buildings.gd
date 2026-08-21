class_name MapViewMeshBuilderBuildings
extends RefCounted

## Building wall, roof, and facade mesh generation.
## Implementation is split across focused modules; this class keeps the public
## API stable for callers and tests.

const _Registry := preload("res://scripts/map/view3d/map_view_mesh_builder_building_registry.gd")
const _Churches := preload("res://scripts/map/view3d/map_view_mesh_builder_churches.gd")
const ST_MARYS_ID := &"cathedral_silhouette"
const ST_MARYS_PRIMITIVE := &"st_marys_construction_1343"


static func build_building(
	building: Dictionary,
	cell_size: int,
	entrances: Array[Dictionary] = [],
	map_bounds: Rect2 = Rect2()
) -> Node3D:
	if _Registry.is_exceptional(building):
		return build_exceptional_building(building, cell_size, entrances, map_bounds)

	# Oak-ring / treeline footprints must not render as house boxes. Sacred Grove
	# and similar outdoor rings are authored as house+tree_line for collision
	# envelopes, then dressed as real oak instances in the 3D view.
	if StringName(building.get("primitive", &"")) == &"tree_line":
		return _build_tree_line(building, cell_size)

	var root := Node3D.new()
	root.name = "Building_%s" % String(building["id"])
	root.set_meta(&"renderer_boundary", &"ordinary")
	var scale := MapViewBridge.world_scale(cell_size)
	var footprint: Rect2 = building["footprint"]
	var size := footprint.size * scale
	var kind: StringName = building.get("kind", MapTypes.BUILDING_KIND_HOUSE)
	var authored_height_px := float(
		building.get("wall_height", MapViewMeshBuilderConfig.DEFAULT_WALL_HEIGHT_PX.get(kind, 64.0))
	)
	var render_height_px := MapTypes.resolved_wall_height_px(building)
	var height := render_height_px * scale
	var center := footprint.get_center() * scale
	root.position = Vector3(center.x, 0.0, center.y)

	var wall_color := Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR))
	var fortification := (
		kind == MapTypes.BUILDING_KIND_WALL
		and authored_height_px >= MapViewMeshBuilderConfig.BATTLEMENT_MIN_HEIGHT_PX
	)
	var footprint_aspect := minf(size.x, size.y) / maxf(size.x, size.y)
	var explicitly_completed_tower := bool(building.get("tower", false))
	var explicitly_round_tower := bool(building.get("round_tower", false))
	var inferred_tower := (
		not building.has("tower")
		and not building.has("round_tower")
		and size.x <= MapViewMeshBuilderConfig.TOWER_MAX_FOOTPRINT
		and size.y <= MapViewMeshBuilderConfig.TOWER_MAX_FOOTPRINT
		and footprint_aspect >= MapViewMeshBuilderConfig.TOWER_MIN_ASPECT
	)
	# WHY: tower tracks completion in the 1343 historical snapshot (door, slits,
	# fighting stage). round_tower keeps the Tallinn circular drum and always
	# wears the conical red-tile roof silhouette; incomplete stubs stay doorless.
	var round_tower := (
		fortification and (explicitly_completed_tower or explicitly_round_tower or inferred_tower)
	)

	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	if round_tower:
		var drum := CylinderMesh.new()
		drum.top_radius = minf(size.x, size.y) * MapViewMeshBuilderConfig.TOWER_RADIUS_FACTOR
		drum.bottom_radius = drum.top_radius * 1.06
		var tower_passage := MapWallWalkAccess.has_tower_passage(building)
		var passage_floor_y := minf(height, MapViewMeshBuilderConfig.WALL_WALK_PASSAGE_FLOOR_HEIGHT)
		drum.height = passage_floor_y if tower_passage else height
		drum.radial_segments = 24
		walls.mesh = drum
		walls.material_override = MapViewMaterials.wall_surface_for_size(
			&"limestone",
			wall_color.lightened(0.08),
			Vector3(TAU * drum.top_radius, drum.height, TAU * drum.top_radius)
		)
		walls.position = Vector3(0.0, drum.height * 0.5, 0.0)
		if tower_passage:
			MapViewMeshBuilderBuildingFortification.add_tower_wall_walk_passage(
				root,
				drum.top_radius,
				passage_floor_y,
				height,
				MapWallWalkAccess.passage_axis(building),
				wall_color
			)
	else:
		var wall_mesh := BoxMesh.new()
		var mesh_size := Vector3(size.x, height, size.y)
		if fortification:
			mesh_size = MapViewMeshBuilderBuildingFortification.sealed_wall_size(mesh_size)
		# WHY: a primitive with an open ground-floor gallery cannot be a single
		# solid box. The mass is pulled back from the facade and the strip it
		# vacates is rebuilt as arcade wall, end walls, and vault by the
		# primitive's own detail pass.
		var gallery_inset := MapViewMeshBuilderBuildingHouses.town_hall_gallery_inset(
			building, size
		)
		mesh_size.z -= gallery_inset
		wall_mesh.size = mesh_size
		walls.mesh = wall_mesh
		if kind == MapTypes.BUILDING_KIND_HOUSE:
			walls.material_override = MapViewMeshBuilderBuildingHouses.house_wall_material(
				building, wall_color, wall_mesh.size
			)
		elif kind == MapTypes.BUILDING_KIND_WALL:
			walls.material_override = MapViewMaterials.wall_surface_triplanar(
				&"limestone", wall_color
			)
		elif kind == MapTypes.BUILDING_KIND_INTERIOR_WALL:
			walls.material_override = (
				MapViewMeshBuilderBuildingInteriorWalls
				. interior_wall_material(building, wall_color, wall_mesh.size)
			)
		else:
			walls.material_override = MapViewMaterials.wall_for_size(wall_color, wall_mesh.size)
		walls.position = Vector3(0.0, height * 0.5, gallery_inset * 0.5)
	root.add_child(walls)

	if kind == MapTypes.BUILDING_KIND_HOUSE:
		var along_ridge_x := MapViewMeshBuilderBuildingFacade.ridge_along_x(building, size)
		var roof_style := MapViewMeshBuilderBuildingHouses.roof_style(building)
		var roof_overhang := MapViewMeshBuilderConfig.ROOF_OVERHANG
		var roof_pitch := MapViewMeshBuilderConfig.ROOF_PITCH
		if roof_style == MapViewMeshBuilderConfig.ROOF_STYLE_THATCH:
			roof_overhang = MapViewMeshBuilderConfig.THATCH_ROOF_OVERHANG
			roof_pitch = MapViewMeshBuilderConfig.THATCH_ROOF_PITCH
		var roof := MeshInstance3D.new()
		roof.name = "Roof"
		roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(
			size,
			along_ridge_x,
			roof_overhang,
			roof_style != MapViewMeshBuilderConfig.ROOF_STYLE_THATCH,
			roof_pitch
		)
		roof.position = Vector3(0.0, height, 0.0)
		roof.material_override = MapViewMeshBuilderBuildingHouses.house_roof_material(building)
		root.add_child(roof)
		MapViewMeshBuilderBuildingHouses.add_chimney(root, building, size, height, along_ridge_x)
		MapViewMeshBuilderBuildingHouses.add_house_structure(
			root, building, size, height, along_ridge_x
		)
		if not MapViewMeshBuilderBuildingHouses.authors_own_facade(building):
			MapViewMeshBuilderBuildingFacade.add_house_facade(
				root, building, size, height, cell_size, entrances
			)
		else:
			MapViewMeshBuilderBuildingHouses.add_authored_facade(root, building, size, height)
		MapViewMeshBuilderBuildingHouses.add_historic_building_details(
			root, building, size, height, along_ridge_x
		)
		MapViewMeshBuilderBuildingHouses.add_production_model(root, building, size, height)
		MapViewMeshBuilderBuildingHouses.add_window_lights(root, building)
	elif kind == MapTypes.BUILDING_KIND_INTERIOR_WALL:
		MapViewMeshBuilderBuildingInteriorWalls.add_interior_wall_structure(
			root, building, size, height
		)
	elif round_tower:
		var radius := minf(size.x, size.y) * MapViewMeshBuilderConfig.TOWER_RADIUS_FACTOR
		var cap := MeshInstance3D.new()
		cap.name = "Cap"
		var ring := CylinderMesh.new()
		ring.top_radius = radius + 0.22
		ring.bottom_radius = radius + 0.22
		ring.height = MapViewMeshBuilderConfig.CAP_HEIGHT * 2.0
		ring.radial_segments = 18
		cap.mesh = ring
		cap.position = Vector3(0.0, height + MapViewMeshBuilderConfig.CAP_HEIGHT, 0.0)
		cap.material_override = MapViewMaterials.wall_surface_for_size(
			&"limestone",
			wall_color.lightened(0.16),
			Vector3(TAU * ring.top_radius, ring.height, TAU * ring.top_radius)
		)
		root.add_child(cap)
		# Conical red-tile roof is the Tallinn skyline for every circular drum,
		# including incomplete tower=false stubs that still read as wall towers.
		MapViewMeshBuilderBuildingFortification.add_tower_roof(root, radius, height, building)
		if explicitly_completed_tower:
			MapViewMeshBuilderBuildingFortification.add_tower_door(
				root, radius, height, StringName(building.get("door_side", &""))
			)
			if authored_height_px >= MapViewMeshBuilderConfig.TOWER_MIN_HEIGHT_PX:
				MapViewMeshBuilderBuildingFortification.add_tower_slits(root, radius, height)
	elif kind != MapTypes.BUILDING_KIND_INTERIOR_WALL:
		var cap := MeshInstance3D.new()
		cap.name = "Cap"
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(
			size.x + MapViewMeshBuilderConfig.CAP_OVERHANG * 2.0,
			MapViewMeshBuilderConfig.CAP_HEIGHT,
			size.y + MapViewMeshBuilderConfig.CAP_OVERHANG * 2.0
		)
		cap.mesh = cap_mesh
		cap.position = Vector3(0.0, height + MapViewMeshBuilderConfig.CAP_HEIGHT * 0.5, 0.0)
		if fortification:
			cap.material_override = MapViewMaterials.wall_surface_for_size(
				&"plank",
				wall_color.lerp(MapViewMeshBuilderConfig.WALL_WALK_TIMBER_TONE, 0.72),
				cap_mesh.size
			)
		else:
			cap.material_override = MapViewMaterials.wall_surface_for_size(
				&"limestone" if kind == MapTypes.BUILDING_KIND_WALL else &"plaster",
				wall_color.lightened(0.12),
				cap_mesh.size
			)
		root.add_child(cap)
		if fortification:
			MapViewMeshBuilderBuildingFortification.add_base_arcades(
				root, building, size, map_bounds
			)
			MapViewMeshBuilderBuildingFortification.add_battlements(root, building, size, height)
			MapViewMeshBuilderBuildingFortification.add_wall_walk_roof(root, size, height)
	return root


static func is_st_marys_construction(building: Dictionary) -> bool:
	return (
		StringName(String(building.get("id", ""))) == ST_MARYS_ID
		and StringName(String(building.get("primitive", ""))) == ST_MARYS_PRIMITIVE
	)


static func build_st_marys_construction(building: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_%s" % String(building["id"])
	root.set_meta(&"renderer_boundary", &"exceptional")
	root.set_meta(&"exceptional_category", &"church")
	root.set_meta(&"church_renderer", ST_MARYS_PRIMITIVE)
	root.set_meta(&"construction_phase", &"early_1330s_gothic_enlargement")

	var scale := MapViewBridge.world_scale(cell_size)
	var footprint: Rect2 = building["footprint"]
	var size := footprint.size * scale
	var height := MapTypes.resolved_wall_height_px(building) * scale
	var center := footprint.get_center() * scale
	root.position = Vector3(center.x, 0.0, center.y)

	# WHY: the east end remained usable while the 1330s three-aisle nave was being
	# enlarged. Separate masses keep the roofed choir and vestry visually distinct
	# from the deliberately open, unfinished nave.
	var choir_length := size.x * 0.34
	var nave_length := size.x - choir_length
	var choir_x := size.x * 0.5 - choir_length * 0.5
	var nave_x := -size.x * 0.5 + nave_length * 0.5
	var choir_height := height * 0.88
	var wall_color := Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR))
	_add_limestone_mass(
		root,
		"StandingChoir",
		Vector3(choir_length, choir_height, size.y * 0.72),
		Vector3(choir_x, choir_height * 0.5, 0.0),
		wall_color
	)
	var choir_roof := MeshInstance3D.new()
	choir_roof.name = "StandingChoirRoof"
	choir_roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(
		Vector2(choir_length, size.y * 0.72), true, 0.18, true, 0.68
	)
	choir_roof.position = Vector3(choir_x, choir_height, 0.0)
	choir_roof.material_override = MapViewMaterials.roof_surface_for_building(
		ST_MARYS_ID,
		&"tile",
		Color(building.get("roof_color", MapViewMeshBuilderConfig.DEFAULT_ROOF_COLOR))
	)
	root.add_child(choir_roof)

	var vestry_size := Vector3(choir_length * 0.62, height * 0.52, size.y * 0.3)
	_add_limestone_mass(
		root,
		"StandingVestry",
		vestry_size,
		Vector3(choir_x + choir_length * 0.05, vestry_size.y * 0.5, -size.y * 0.5 + vestry_size.z * 0.45),
		wall_color.darkened(0.04)
	)

	_add_open_three_aisle_nave(root, nave_x, nave_length, size.y, height, wall_color)
	_add_nave_scaffolding(root, nave_x, nave_length, size.y, height)
	_add_masons_yard(root, nave_x, nave_length, size.y)
	return root


static func _add_limestone_mass(
	root: Node3D, node_name: String, mass_size: Vector3, position: Vector3, color: Color
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = mass_size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = MapViewMaterials.wall_surface_for_building(
		ST_MARYS_ID, &"limestone", color, mass_size
	)
	root.add_child(instance)


static func _add_open_three_aisle_nave(
	root: Node3D,
	nave_x: float,
	nave_length: float,
	nave_width: float,
	height: float,
	wall_color: Color
) -> void:
	var nave := Node3D.new()
	nave.name = "OpenNave"
	root.add_child(nave)
	var aisle_offset := nave_width * 0.24
	var bay_count := 5
	var pier_height := height * 0.66
	for bay_index in bay_count:
		var bay_x := nave_x - nave_length * 0.42 + nave_length * 0.84 * float(bay_index) / float(bay_count - 1)
		for side: float in [-1.0, 1.0]:
			_add_limestone_mass(
				nave,
				"RectangularPier_%s_%02d" % ["N" if side < 0.0 else "S", bay_index],
				Vector3(0.5, pier_height, 0.5),
				Vector3(bay_x, pier_height * 0.5, side * aisle_offset),
				wall_color.lightened(0.03)
			)
	# Low unfinished aisle walls disclose the open sky and construction phase at
	# gameplay scale instead of reading as a completed basilica shell.
	for side: float in [-1.0, 1.0]:
		_add_limestone_mass(
			nave,
			"UnfinishedAisleWall_%s" % ("N" if side < 0.0 else "S"),
			Vector3(nave_length * 0.92, height * 0.2, 0.38),
			Vector3(nave_x, height * 0.1, side * (nave_width * 0.5 - 0.19)),
			wall_color.darkened(0.02)
		)


static func _add_nave_scaffolding(
	root: Node3D, nave_x: float, nave_length: float, nave_width: float, height: float
) -> void:
	var scaffold := Node3D.new()
	scaffold.name = "NaveScaffolding"
	root.add_child(scaffold)
	var scaffold_y := height * 0.52
	for frame_index in 4:
		var frame_x := nave_x - nave_length * 0.38 + nave_length * 0.76 * float(frame_index) / 3.0
		for side: float in [-1.0, 1.0]:
			var frame_z := side * (nave_width * 0.5 + 0.18)
			MapViewMeshBuilderPrimitives.box(
				scaffold,
				"Post_%s_%02d" % ["N" if side < 0.0 else "S", frame_index],
				Vector3(0.14, height * 0.76, 0.14),
				Vector3(frame_x, height * 0.38, frame_z),
				&"timber"
			)
			MapViewMeshBuilderPrimitives.box(
				scaffold,
				"Platform_%s_%02d" % ["N" if side < 0.0 else "S", frame_index],
				Vector3(nave_length * 0.23, 0.14, 0.58),
				Vector3(frame_x, scaffold_y, frame_z),
				&"timber"
			)
	for side: float in [-1.0, 1.0]:
		MapViewMeshBuilderPrimitives.box(
			scaffold,
			"TopRail_%s" % ("N" if side < 0.0 else "S"),
			Vector3(nave_length * 0.94, 0.12, 0.12),
			Vector3(nave_x, height * 0.75, side * (nave_width * 0.5 + 0.18)),
			&"timber"
		)


static func _add_masons_yard(
	root: Node3D, nave_x: float, nave_length: float, nave_width: float
) -> void:
	var yard := Node3D.new()
	yard.name = "MasonsYard"
	root.add_child(yard)
	var yard_z := nave_width * 0.5 + 0.75
	MapViewMeshBuilderPrimitives.box(
		yard,
		"MasonBench",
		Vector3(2.2, 0.55, 0.68),
		Vector3(nave_x - nave_length * 0.18, 0.55, yard_z),
		&"timber"
	)
	for stone_index in 5:
		var row := stone_index / 3
		var column := stone_index % 3
		MapViewMeshBuilderPrimitives.box(
			yard,
			"CutStone_%02d" % stone_index,
			Vector3(0.58, 0.34 + float(row) * 0.08, 0.5),
			Vector3(nave_x + nave_length * 0.1 + float(column) * 0.66, 0.17, yard_z + float(row) * 0.58),
			&"stone"
		)




## Specialized handoff for authored landmarks and institutions. It intentionally
## owns only the landmark mass and dressing, never the ordinary house kit.
static func build_exceptional_building(
	building: Dictionary,
	cell_size: int,
	_entrances: Array[Dictionary] = [],
	_map_bounds: Rect2 = Rect2()
) -> Node3D:
	var category := _Registry.exceptional_category(building)
	if category == &"monastic_precinct":
		return MapViewMonasticModels.build_st_michaels_precinct(building, cell_size)
	if is_st_marys_construction(building):
		return build_st_marys_construction(building, cell_size)
	if _Churches.is_st_catherines_church(building):
		return _Churches.build_st_catherines_church(building, cell_size)
	var root := Node3D.new()
	root.name = "Building_%s" % String(building["id"])
	root.set_meta(&"renderer_boundary", &"exceptional")
	root.set_meta(&"exceptional_category", category)
	var scale := MapViewBridge.world_scale(cell_size)
	var footprint: Rect2 = building["footprint"]
	var size := footprint.size * scale
	var authored_height_px := float(
		building.get(
			"wall_height",
			MapViewMeshBuilderConfig.DEFAULT_WALL_HEIGHT_PX[MapTypes.BUILDING_KIND_HOUSE]
		)
	)
	var height := MapTypes.resolved_wall_height_px(building) * scale
	var center := footprint.get_center() * scale
	root.position = Vector3(center.x, 0.0, center.y)
	var wall_color := Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR))
	var gallery_inset := MapViewMeshBuilderBuildingHouses.town_hall_gallery_inset(building, size)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(size.x, height, maxf(size.y - gallery_inset, 0.25))
	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	walls.mesh = wall_mesh
	walls.position = Vector3(0.0, height * 0.5, gallery_inset * 0.5)
	walls.material_override = MapViewMeshBuilderBuildingHouses.house_wall_material(
		building, wall_color, wall_mesh.size
	)
	root.add_child(walls)

	# Existing primitive detail passes remain the source of truth for period-specific
	# church and civic features, but they are now downstream of this boundary.
	MapViewMeshBuilderBuildingHouses.add_historic_building_details(
		root, building, size, height, MapViewMeshBuilderBuildingFacade.ridge_along_x(building, size)
	)
	if category == &"gatehouse":
		var cap := MeshInstance3D.new()
		cap.name = "LandmarkCap"
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(
			size.x + MapViewMeshBuilderConfig.CAP_OVERHANG * 2.0,
			MapViewMeshBuilderConfig.CAP_HEIGHT,
			size.y + MapViewMeshBuilderConfig.CAP_OVERHANG * 2.0
		)
		cap.mesh = cap_mesh
		cap.position = Vector3(0.0, height + MapViewMeshBuilderConfig.CAP_HEIGHT * 0.5, 0.0)
		cap.material_override = MapViewMaterials.wall_surface_for_size(
			&"limestone", wall_color.lightened(0.12), cap_mesh.size
		)
		root.add_child(cap)
	else:
		var roof := MeshInstance3D.new()
		roof.name = "LandmarkRoof"
		var along_ridge_x := MapViewMeshBuilderBuildingFacade.ridge_along_x(building, size)
		roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(
			size,
			along_ridge_x,
			MapViewMeshBuilderConfig.ROOF_OVERHANG,
			true,
			MapViewMeshBuilderConfig.ROOF_PITCH
		)
		roof.position = Vector3(0.0, height, 0.0)
		roof.material_override = MapViewMeshBuilderBuildingHouses.house_roof_material(building)
		root.add_child(roof)
	if category != &"gatehouse":
		MapViewMeshBuilderBuildingHouses.add_window_lights(root, building)
	return root


## Places large oaks along a thin footprint so grove rings read as trees, not walls.
static func _build_tree_line(building: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_%s" % String(building["id"])
	var scale := MapViewBridge.world_scale(cell_size)
	var footprint: Rect2 = building["footprint"]
	var size := footprint.size * scale
	var center := footprint.get_center() * scale
	root.position = Vector3(center.x, 0.0, center.y)
	root.set_meta(&"tree_line", true)

	var along_x := size.x >= size.y
	var length := maxf(size.x if along_x else size.y, 1.0)
	# ~2.6 world units between trunks keeps crowns touching without merging into a hedge.
	var spacing := 2.6
	var count := maxi(2, int(round(length / spacing)) + 1)
	var wood_mesh := MapViewMeshBuilderPrimitives.tree_wood_mesh(MapViewTreeSpecies.SPECIES_OAK)
	var canopy_mesh := MapViewMeshBuilderPrimitives.tree_canopy_mesh(MapViewTreeSpecies.SPECIES_OAK)
	var bark := MapViewMaterials.bark(
		MapViewTreeSpecies.bark_kind_for(MapViewTreeSpecies.SPECIES_OAK)
	)
	var canopy_mat := MapViewMaterials.canopy(
		MapViewTreeSpecies.canopy_material_kind(MapViewTreeSpecies.SPECIES_OAK)
	)
	for index in count:
		var t := float(index) / float(count - 1)
		var along := lerpf(-length * 0.5, length * 0.5, t)
		var tree := Node3D.new()
		tree.name = "Oak%02d" % index
		tree.position = Vector3(along, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, along)
		# Deterministic size mix so the ring feels planted rather than cloned.
		var size_roll := MapViewMeshBuilderMath.hash01(index, String(building["id"]).hash(), 7741)
		var tree_scale := MapViewTreeSpecies.instance_scale(
			MapViewTreeSpecies.SIZE_LARGE, size_roll
		)
		tree.rotation.y = size_roll * TAU
		root.add_child(tree)

		var trunk := MeshInstance3D.new()
		trunk.name = "Trunk"
		trunk.mesh = wood_mesh
		trunk.scale = tree_scale
		trunk.material_override = bark
		tree.add_child(trunk)

		var canopy := MeshInstance3D.new()
		canopy.name = "Canopy"
		canopy.mesh = canopy_mesh
		canopy.scale = tree_scale
		canopy.material_override = canopy_mat
		tree.add_child(canopy)
		tree.set_meta(&"tree_species", MapViewTreeSpecies.SPECIES_OAK)
		tree.set_meta(&"tree_size", MapViewTreeSpecies.SIZE_LARGE)
	return root


static func facade_box(
	root: Node3D,
	name: String,
	box_size: Vector3,
	along: float,
	center_y: float,
	side: StringName,
	face_offset: float,
	role: StringName
) -> void:
	MapViewMeshBuilderBuildingFacade.facade_box(
		root, name, box_size, along, center_y, side, face_offset, role
	)


static func add_battlements(
	root: Node3D, building: Dictionary, size: Vector2, height: float
) -> void:
	MapViewMeshBuilderBuildingFortification.add_battlements(root, building, size, height)


static func sealed_wall_size(size: Vector3) -> Vector3:
	return MapViewMeshBuilderBuildingFortification.sealed_wall_size(size)
