class_name MapViewMeshBuilder
extends RefCounted

## Converts immutable MapDefinition data into 3D view geometry (P0-052).
## View only: no collision shapes, physics bodies, or navigation are generated
## here - the logic plane keeps owning all gameplay geometry. All sizes are in
## world units where one logic cell equals one unit (MapViewBridge).

const WATER_RECESS := 0.08
const ROOF_PITCH := 0.9
const ROOF_OVERHANG := 0.15
const CAP_HEIGHT := 0.12
const CAP_OVERHANG := 0.05
## Doorways must read taller than the frozen 2.0-unit character.
const DOOR_WIDTH := 1.5
const DOOR_HEIGHT := 2.5
const DOOR_THICKNESS := 0.14
const DOOR_FRAME_THICKNESS := 0.16

## Fallback wall heights in logic pixels when a building omits wall_height.
## Houses carry a full storey plus loft over the 2.0-unit character; freestanding
## walls stay chest-high so courtyards read open.
const DEFAULT_WALL_HEIGHT_PX := {
	MapTypes.BUILDING_KIND_HOUSE: 112.0,
	MapTypes.BUILDING_KIND_WALL: 64.0,
	MapTypes.BUILDING_KIND_INTERIOR_WALL: 72.0,
	MapTypes.BUILDING_KIND_INTERIOR_BLOCK: 56.0,
}

const DEFAULT_WALL_COLOR := Color(0.46, 0.44, 0.40)
const DEFAULT_ROOF_COLOR := Color(0.24, 0.20, 0.16)

## Per-cell ground tone variation so large terrain fields stop reading as one
## flat tint: fine per-cell jitter plus a broader patch drift, both deterministic.
const TERRAIN_JITTER := 0.07
const TERRAIN_PATCH_STRENGTH := 0.06
const TERRAIN_PATCH_CELLS := 5

const CHIMNEY_SIZE := 0.5
const SMOKE_LIFETIME := 6.0
const SMOKE_AMOUNT := 28

## View-only landscape ring past the playable bounds: warm meadow apron with a
## scattered treeline instead of a hard void.
const SURROUNDINGS_SIZE_WORLD := 512.0
const SURROUNDINGS_COLOR := Color8(74, 88, 60)
const TREE_BAND_INNER := 1.5
const TREE_BAND_OUTER := 18.0
const TREE_GRID_SPACING := 3.0
const TREE_KEEP_RATIO := 0.5

## Ground scatter (grass tufts, pebbles) is decorative only; it never implies
## collision, so every piece stays well under knee height.
const SCATTER_TUFT_CHANCE := {
	MapTypes.TERRAIN_GRASS: 0.85,
	MapTypes.TERRAIN_MEADOW: 0.9,
	MapTypes.TERRAIN_FOREST_FLOOR: 0.6,
	MapTypes.TERRAIN_BOG: 0.4,
	MapTypes.TERRAIN_HAY: 0.35,
	MapTypes.TERRAIN_STRAW: 0.3,
}
const SCATTER_STONE_CHANCE := {
	MapTypes.TERRAIN_DIRT: 0.12,
	MapTypes.TERRAIN_COBBLESTONE: 0.06,
	MapTypes.TERRAIN_MUD: 0.1,
	MapTypes.TERRAIN_SAND: 0.08,
	MapTypes.TERRAIN_COAST_SAND: 0.1,
	MapTypes.TERRAIN_GRASS: 0.05,
}


## One MeshInstance3D per used terrain: every cell of that terrain becomes a
## textured ground quad. Water-family cells sit slightly recessed so shorelines
## read in the dimetric view without touching walkability.
static func build_terrain(definition: MapDefinition, grid: MapTerrainGrid) -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"
	for terrain_id in grid.used_terrain_ids():
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var water := MapViewMaterials.WATER_TERRAINS.has(terrain_id)
		var height := -WATER_RECESS if water else 0.0
		for y in grid.size_cells.y:
			for x in grid.size_cells.x:
				if grid.get_terrain(Vector2i(x, y)) != terrain_id:
					continue
				var tone := 1.0 if water else _cell_tone(x, y, definition.seed)
				_add_ground_quad(surface, x, y, height, tone)
		var instance := MeshInstance3D.new()
		instance.name = "Terrain_%s" % String(terrain_id)
		instance.mesh = surface.commit()
		instance.material_override = MapViewMaterials.terrain(terrain_id, definition.seed)
		root.add_child(instance)
	return root


## Deterministic per-cell brightness: fine jitter over a broad patch drift.
static func _cell_tone(x: int, y: int, noise_seed: int) -> float:
	var fine := _hash01(x, y, noise_seed)
	var patch := _hash01(
		floori(float(x) / TERRAIN_PATCH_CELLS),
		floori(float(y) / TERRAIN_PATCH_CELLS),
		noise_seed + 977
	)
	var tone := 1.0
	tone += (fine * 2.0 - 1.0) * TERRAIN_JITTER
	tone += (patch * 2.0 - 1.0) * TERRAIN_PATCH_STRENGTH
	return clampf(tone, 0.75, 1.2)


static func _hash01(x: int, y: int, noise_seed: int) -> float:
	var hashed := ((x * 374761393) + (y * 668265263) + noise_seed * 69069) & 0x7fffffff
	hashed = (hashed ^ (hashed >> 13)) * 1274126177 & 0x7fffffff
	return float(hashed % 100000) / 99999.0


## Building footprint plus per-kind height rules become a wall prism; houses
## get a gabled roof, walls and interior masses get a flat stone cap.
static func build_building(building: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_%s" % String(building["id"])
	var scale := MapViewBridge.world_scale(cell_size)
	var footprint: Rect2 = building["footprint"]
	var size := footprint.size * scale
	var kind: StringName = building.get("kind", MapTypes.BUILDING_KIND_HOUSE)
	var height_px := float(building.get("wall_height", DEFAULT_WALL_HEIGHT_PX.get(kind, 64.0)))
	var height := height_px * scale
	var center := footprint.get_center() * scale
	root.position = Vector3(center.x, 0.0, center.y)

	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(size.x, height, size.y)
	walls.mesh = wall_mesh
	walls.position = Vector3(0.0, height * 0.5, 0.0)
	walls.material_override = MapViewMaterials.wall(building.get("wall_color", DEFAULT_WALL_COLOR))
	root.add_child(walls)

	if kind == MapTypes.BUILDING_KIND_HOUSE:
		var roof := MeshInstance3D.new()
		roof.name = "Roof"
		roof.mesh = _gabled_roof_mesh(size)
		roof.position = Vector3(0.0, height, 0.0)
		roof.material_override = MapViewMaterials.roof(building.get("roof_color", DEFAULT_ROOF_COLOR))
		root.add_child(roof)
		_add_chimney(root, building, size, height)
	else:
		var cap := MeshInstance3D.new()
		cap.name = "Cap"
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(size.x + CAP_OVERHANG * 2.0, CAP_HEIGHT, size.y + CAP_OVERHANG * 2.0)
		cap.mesh = cap_mesh
		cap.position = Vector3(0.0, height + CAP_HEIGHT * 0.5, 0.0)
		cap.material_override = MapViewMaterials.wall(
			Color(building.get("wall_color", DEFAULT_WALL_COLOR)).lightened(0.12)
		)
		root.add_child(cap)
	return root


## Functional transitions get a view-only framed door at the edge of their
## trigger rectangle. The trigger can stay generously sized for navigation;
## the visible door remains at the frozen character scale.
static func build_transition_door(transition: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Door_%s" % String(transition["id"])
	root.set_meta("transition_id", transition["id"])

	var scale := MapViewBridge.world_scale(cell_size)
	var rect: Rect2 = transition["rect"]
	var horizontal_wall := rect.size.x >= rect.size.y
	var center := rect.get_center() * scale
	if horizontal_wall:
		# Transition rectangles begin at the wall boundary and extend into the
		# walkable approach, so use the leading edge rather than the center.
		center.y = rect.position.y * scale
	else:
		center.x = rect.position.x * scale
	root.position = Vector3(center.x, 0.0, center.y)
	if not horizontal_wall:
		root.rotation.y = PI * 0.5

	_box(
		root,
		"Panel",
		Vector3(DOOR_WIDTH, DOOR_HEIGHT, DOOR_THICKNESS),
		Vector3(0.0, DOOR_HEIGHT * 0.5, 0.0),
		&"wood"
	)
	var frame_height := DOOR_HEIGHT + DOOR_FRAME_THICKNESS
	var frame_x := DOOR_WIDTH * 0.5 + DOOR_FRAME_THICKNESS * 0.5
	_box(root, "FrameLeft", Vector3(DOOR_FRAME_THICKNESS, frame_height, 0.22), Vector3(-frame_x, frame_height * 0.5, 0.0), &"timber")
	_box(root, "FrameRight", Vector3(DOOR_FRAME_THICKNESS, frame_height, 0.22), Vector3(frame_x, frame_height * 0.5, 0.0), &"timber")
	_box(root, "Lintel", Vector3(DOOR_WIDTH + DOOR_FRAME_THICKNESS * 2.0, DOOR_FRAME_THICKNESS, 0.22), Vector3(0.0, frame_height, 0.0), &"timber")
	_box(root, "Threshold", Vector3(DOOR_WIDTH + 0.18, 0.08, 0.28), Vector3(0.0, 0.04, 0.0), &"stone")
	for plank_index in 3:
		var plank_x := -DOOR_WIDTH * 0.25 + float(plank_index) * DOOR_WIDTH * 0.25
		_box(root, "Plank%d" % plank_index, Vector3(0.025, DOOR_HEIGHT - 0.12, 0.018), Vector3(plank_x, DOOR_HEIGHT * 0.5, DOOR_THICKNESS * 0.5 + 0.01), &"timber")
	_sphere(root, "Handle", 0.055, Vector3(DOOR_WIDTH * 0.3, DOOR_HEIGHT * 0.52, DOOR_THICKNESS * 0.5 + 0.06), &"metal")
	return root


## Parametric primitive assembly per prop kind, anchored at the shared
## definition position so the logic plane and the view agree on placement.
static func build_prop(prop: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Prop_%s" % String(prop["id"])
	root.position = MapViewBridge.logic_to_world(prop["position"], cell_size)

	match prop["kind"] as StringName:
		MapTypes.PROP_KIND_ANVIL:
			_box(root, "Base", Vector3(0.9, 0.22, 0.5), Vector3(0.0, 0.11, 0.0), &"wood")
			_box(root, "Body", Vector3(0.65, 0.3, 0.32), Vector3(0.0, 0.37, 0.0), &"metal")
			_box(root, "Face", Vector3(1.05, 0.14, 0.34), Vector3(0.0, 0.59, 0.0), &"metal")
		MapTypes.PROP_KIND_HAY_STACK:
			_sphere(root, "Mound", 0.85, Vector3(0.0, 0.42, 0.0), &"hay", Vector3(1.0, 0.62, 1.0))
			_sphere(root, "Crown", 0.5, Vector3(0.1, 0.78, -0.05), &"hay", Vector3(1.0, 0.6, 1.0))
		MapTypes.PROP_KIND_CART:
			_box(root, "Bed", Vector3(1.6, 0.16, 0.9), Vector3(0.0, 0.6, 0.0), &"wood")
			_cylinder(root, "WheelLeft", 0.34, 0.1, Vector3(-0.45, 0.34, 0.5), &"wood", true)
			_cylinder(root, "WheelRight", 0.34, 0.1, Vector3(-0.45, 0.34, -0.5), &"wood", true)
			_box(root, "Handle", Vector3(0.9, 0.08, 0.5), Vector3(1.1, 0.62, 0.0), &"wood")
		MapTypes.PROP_KIND_WELL:
			_cylinder(root, "Ring", 0.55, 0.5, Vector3(0.0, 0.25, 0.0), &"stone")
			_cylinder(root, "Water", 0.42, 0.06, Vector3(0.0, 0.49, 0.0), &"water_highlight")
			_box(root, "PostLeft", Vector3(0.1, 1.0, 0.1), Vector3(-0.5, 0.75, 0.0), &"wood")
			_box(root, "PostRight", Vector3(0.1, 1.0, 0.1), Vector3(0.5, 0.75, 0.0), &"wood")
			_box(root, "RoofBeam", Vector3(1.3, 0.1, 0.5), Vector3(0.0, 1.3, 0.0), &"roof")
		MapTypes.PROP_KIND_BARRELS:
			_cylinder(root, "BarrelA", 0.28, 0.62, Vector3(-0.24, 0.31, 0.05), &"wood")
			_cylinder(root, "BarrelB", 0.28, 0.62, Vector3(0.3, 0.31, -0.14), &"wood")
		MapTypes.PROP_KIND_FURNACE:
			_box(root, "Mass", Vector3(1.0, 1.1, 0.9), Vector3(0.0, 0.55, 0.0), &"stone")
			_box(root, "Mouth", Vector3(0.42, 0.36, 0.08), Vector3(0.0, 0.35, 0.48), &"ember")
			_box(root, "Chimney", Vector3(0.26, 0.6, 0.26), Vector3(0.2, 1.4, -0.15), &"stone")
		MapTypes.PROP_KIND_LEDGER:
			_box(root, "Stand", Vector3(0.16, 0.9, 0.16), Vector3(0.0, 0.45, 0.0), &"wood")
			_box(root, "Book", Vector3(0.52, 0.08, 0.42), Vector3(0.0, 0.95, 0.0), &"plaster")
		MapTypes.PROP_KIND_BED:
			_box(root, "Frame", Vector3(1.4, 0.34, 0.8), Vector3(0.0, 0.17, 0.0), &"wood")
			_box(root, "Mattress", Vector3(1.3, 0.14, 0.7), Vector3(0.0, 0.41, 0.0), &"plaster")
			_box(root, "Pillow", Vector3(0.3, 0.12, 0.5), Vector3(-0.48, 0.52, 0.0), &"hay")
		MapTypes.PROP_KIND_CHEST:
			_box(root, "Box", Vector3(0.7, 0.42, 0.46), Vector3(0.0, 0.21, 0.0), &"wood")
			_box(root, "Lid", Vector3(0.72, 0.14, 0.48), Vector3(0.0, 0.49, 0.0), &"timber")
		MapTypes.PROP_KIND_TABLE:
			_box(root, "Top", Vector3(1.1, 0.08, 0.7), Vector3(0.0, 0.56, 0.0), &"wood")
			_box(root, "LegsLeft", Vector3(0.1, 0.52, 0.6), Vector3(-0.45, 0.26, 0.0), &"timber")
			_box(root, "LegsRight", Vector3(0.1, 0.52, 0.6), Vector3(0.45, 0.26, 0.0), &"timber")
		MapTypes.PROP_KIND_SHELF:
			_box(root, "Frame", Vector3(0.9, 1.4, 0.3), Vector3(0.0, 0.7, 0.0), &"timber")
			for level in 3:
				_box(root, "Board%d" % level, Vector3(0.82, 0.06, 0.26), Vector3(0.0, 0.35 + 0.4 * level, 0.0), &"wood")
		MapTypes.PROP_KIND_QUENCH:
			_cylinder(root, "Bucket", 0.3, 0.46, Vector3(0.0, 0.23, 0.0), &"wood")
			_cylinder(root, "Water", 0.24, 0.05, Vector3(0.0, 0.44, 0.0), &"water_highlight")
		MapTypes.PROP_KIND_STAIRS:
			for step in 3:
				_box(
					root,
					"Step%d" % step,
					Vector3(1.0, 0.2, 0.4),
					Vector3(0.0, 0.1 + 0.2 * step, -0.35 * step),
					&"stone"
				)
		MapTypes.PROP_KIND_STALL:
			_box(root, "Counter", Vector3(1.4, 0.8, 0.6), Vector3(0.0, 0.4, 0.0), &"wood")
			_box(root, "PostLeft", Vector3(0.08, 1.5, 0.08), Vector3(-0.65, 0.75, -0.4), &"timber")
			_box(root, "PostRight", Vector3(0.08, 1.5, 0.08), Vector3(0.65, 0.75, -0.4), &"timber")
			_box(root, "Canopy", Vector3(1.6, 0.08, 1.1), Vector3(0.0, 1.55, -0.1), &"hay")
		MapTypes.PROP_KIND_HEARTH:
			_box(root, "Base", Vector3(1.0, 0.4, 1.0), Vector3(0.0, 0.2, 0.0), &"stone")
			_box(root, "Fire", Vector3(0.5, 0.22, 0.5), Vector3(0.0, 0.5, 0.0), &"ember")
		_:
			_box(root, "Marker", Vector3(0.5, 0.5, 0.5), Vector3(0.0, 0.25, 0.0), &"ink")
	return root


## Decorative ground clutter per terrain family: grass tufts on green cells,
## pebbles on worked ground. Deterministic from the map seed, skips building
## footprints, and stays under knee height so it never suggests collision.
static func build_scatter(definition: MapDefinition, grid: MapTerrainGrid) -> Node3D:
	var root := Node3D.new()
	root.name = "Scatter"
	var blocked := _building_cell_rects(definition)

	var tufts: Array[Transform3D] = []
	var tuft_colors: Array[Color] = []
	var stones: Array[Transform3D] = []
	var stone_colors: Array[Color] = []
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			var cell := Vector2i(x, y)
			if _cell_blocked(cell, blocked):
				continue
			var terrain := grid.get_terrain(cell)
			var roll := _hash01(x, y, definition.seed + 4242)
			if roll < SCATTER_TUFT_CHANCE.get(terrain, 0.0):
				var count := 1 + int(_hash01(x, y, definition.seed + 511) * 2.0)
				for tuft_index in count:
					tufts.append(_scatter_transform(x, y, definition.seed + 31 * (tuft_index + 1), 0.7, 1.5))
					var green := 0.86 + _hash01(x + tuft_index, y, definition.seed + 77) * 0.28
					tuft_colors.append(Color(green * 0.94, green, green * 0.8))
			elif roll < SCATTER_TUFT_CHANCE.get(terrain, 0.0) + SCATTER_STONE_CHANCE.get(terrain, 0.0):
				stones.append(_scatter_transform(x, y, definition.seed + 913, 0.6, 1.6))
				var gray := 0.8 + _hash01(x, y, definition.seed + 154) * 0.35
				stone_colors.append(Color(gray, gray, gray * 0.97))

	var tuft_mesh := CylinderMesh.new()
	tuft_mesh.top_radius = 0.0
	tuft_mesh.bottom_radius = 0.09
	tuft_mesh.height = 0.26
	tuft_mesh.radial_segments = 5
	tuft_mesh.rings = 1
	root.add_child(_multi_mesh("Tufts", tuft_mesh, tufts, tuft_colors, MapViewMaterials.foliage_tuft(), Vector3(0.0, 0.13, 0.0)))

	var stone_mesh := SphereMesh.new()
	stone_mesh.radius = 0.09
	stone_mesh.height = 0.11
	stone_mesh.radial_segments = 6
	stone_mesh.rings = 3
	root.add_child(_multi_mesh("Stones", stone_mesh, stones, stone_colors, MapViewMaterials.role(&"stone"), Vector3(0.0, 0.03, 0.0)))
	return root


## Landscape ring outside the playable rectangle: a warm meadow apron plane and
## a deterministic treeline (spruce and broadleaf) with a few boulders, so map
## edges read as countryside instead of a void. Everything is unreachable and
## purely view-side.
static func build_surroundings(definition: MapDefinition) -> Node3D:
	var root := Node3D.new()
	root.name = "Surroundings"
	var map_size := Vector2(definition.size_cells)

	var apron := MeshInstance3D.new()
	apron.name = "Apron"
	var apron_mesh := PlaneMesh.new()
	apron_mesh.size = Vector2(SURROUNDINGS_SIZE_WORLD, SURROUNDINGS_SIZE_WORLD)
	apron_mesh.material = MapViewMaterials.surroundings_ground()
	apron.mesh = apron_mesh
	apron.position = Vector3(map_size.x * 0.5, -0.04, map_size.y * 0.5)
	root.add_child(apron)

	var trunks: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var spruces: Array[Transform3D] = []
	var spruce_colors: Array[Color] = []
	var leaves: Array[Transform3D] = []
	var leaf_colors: Array[Color] = []
	var boulders: Array[Transform3D] = []
	var boulder_colors: Array[Color] = []

	var inner := Rect2(Vector2.ZERO, map_size).grow(TREE_BAND_INNER)
	var start_x := int(-TREE_BAND_OUTER / TREE_GRID_SPACING)
	var end_x := int((map_size.x + TREE_BAND_OUTER) / TREE_GRID_SPACING)
	var start_y := int(-TREE_BAND_OUTER / TREE_GRID_SPACING)
	var end_y := int((map_size.y + TREE_BAND_OUTER) / TREE_GRID_SPACING)
	for gy in range(start_y, end_y + 1):
		for gx in range(start_x, end_x + 1):
			var base := Vector2(gx, gy) * TREE_GRID_SPACING
			var jitter := Vector2(
				_hash01(gx, gy, definition.seed + 601) - 0.5,
				_hash01(gx, gy, definition.seed + 907) - 0.5
			) * TREE_GRID_SPACING * 0.9
			var spot := base + jitter
			if inner.has_point(spot):
				continue
			var keep := _hash01(gx, gy, definition.seed + 1201)
			if keep > TREE_KEEP_RATIO:
				continue
			var kind_roll := _hash01(gx, gy, definition.seed + 1499)
			if kind_roll < 0.06:
				var boulder_scale := 0.5 + _hash01(gx, gy, definition.seed + 1601) * 0.9
				boulders.append(_placed(spot, boulder_scale, Vector3(0.0, 0.16 * boulder_scale, 0.0), _hash01(gx, gy, definition.seed + 1733) * TAU))
				var gray := 0.85 + _hash01(gx, gy, definition.seed + 1801) * 0.25
				boulder_colors.append(Color(gray, gray, gray))
				continue
			var tree_scale := 0.75 + _hash01(gx, gy, definition.seed + 1907) * 0.7
			var yaw := _hash01(gx, gy, definition.seed + 2003) * TAU
			trunks.append(_placed(spot, tree_scale, Vector3(0.0, 0.5 * tree_scale, 0.0), yaw))
			var bark := 0.85 + _hash01(gx, gy, definition.seed + 2111) * 0.3
			trunk_colors.append(Color(bark, bark, bark))
			var tint := 0.8 + _hash01(gx, gy, definition.seed + 2221) * 0.4
			if kind_roll < 0.6:
				spruces.append(_placed(spot, tree_scale, Vector3(0.0, (0.9 + 1.1) * tree_scale, 0.0), yaw))
				spruce_colors.append(Color(tint * 0.9, tint, tint * 0.88))
			else:
				leaves.append(_placed(spot, tree_scale, Vector3(0.0, (0.9 + 0.75) * tree_scale, 0.0), yaw))
				leaf_colors.append(Color(tint * 0.96, tint, tint * 0.8))

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.11
	trunk_mesh.bottom_radius = 0.16
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	root.add_child(_multi_mesh("Trunks", trunk_mesh, trunks, trunk_colors, MapViewMaterials.bark(), Vector3.ZERO))

	var spruce_mesh := CylinderMesh.new()
	spruce_mesh.top_radius = 0.0
	spruce_mesh.bottom_radius = 0.85
	spruce_mesh.height = 2.2
	spruce_mesh.radial_segments = 7
	root.add_child(_multi_mesh("SpruceCanopies", spruce_mesh, spruces, spruce_colors, MapViewMaterials.foliage_spruce(), Vector3.ZERO))

	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 0.85
	leaf_mesh.height = 1.5
	leaf_mesh.radial_segments = 8
	leaf_mesh.rings = 4
	root.add_child(_multi_mesh("LeafCanopies", leaf_mesh, leaves, leaf_colors, MapViewMaterials.foliage_leaf(), Vector3.ZERO))

	var boulder_mesh := SphereMesh.new()
	boulder_mesh.radius = 0.45
	boulder_mesh.height = 0.6
	boulder_mesh.radial_segments = 7
	boulder_mesh.rings = 4
	root.add_child(_multi_mesh("Boulders", boulder_mesh, boulders, boulder_colors, MapViewMaterials.role(&"stone"), Vector3.ZERO))
	return root


static func _placed(spot: Vector2, scale: float, lift: Vector3, yaw: float) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	return Transform3D(basis, Vector3(spot.x, 0.0, spot.y) + lift)


static func _scatter_transform(x: int, y: int, noise_seed: int, scale_min: float, scale_max: float) -> Transform3D:
	var offset := Vector2(
		_hash01(x, y, noise_seed + 7) * 0.9 + 0.05,
		_hash01(x, y, noise_seed + 13) * 0.9 + 0.05
	)
	var scale := scale_min + _hash01(x, y, noise_seed + 29) * (scale_max - scale_min)
	var yaw := _hash01(x, y, noise_seed + 41) * TAU
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	return Transform3D(basis, Vector3(float(x) + offset.x, 0.0, float(y) + offset.y))


static func _multi_mesh(
	name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	colors: Array[Color],
	material: StandardMaterial3D,
	mesh_lift: Vector3
) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = name
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in transforms.size():
		var transform := transforms[index]
		transform.origin += mesh_lift * transform.basis.get_scale().y
		multi.set_instance_transform(index, transform)
		multi.set_instance_color(index, colors[index])
	instance.multimesh = multi
	instance.material_override = material
	return instance


static func _building_cell_rects(definition: MapDefinition) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var scale := MapViewBridge.world_scale(definition.cell_size)
	for building in definition.buildings:
		var footprint: Rect2 = building["footprint"]
		rects.append(Rect2(footprint.position * scale, footprint.size * scale))
	return rects


static func _cell_blocked(cell: Vector2i, rects: Array[Rect2]) -> bool:
	var center := Vector2(cell) + Vector2(0.5, 0.5)
	for rect in rects:
		if rect.grow(0.5).has_point(center):
			return true
	return false


static func _add_ground_quad(surface: SurfaceTool, x: int, y: int, height: float, tone: float = 1.0) -> void:
	var x0 := float(x)
	var x1 := float(x + 1)
	var z0 := float(y)
	var z1 := float(y + 1)
	var corners := [
		Vector3(x0, height, z0),
		Vector3(x1, height, z0),
		Vector3(x1, height, z1),
		Vector3(x0, height, z1),
	]
	var uvs := [
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	]
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_normal(Vector3.UP)
		surface.set_uv(uvs[index])
		surface.set_color(Color(tone, tone, tone))
		surface.add_vertex(corners[index])


## Every house earns a stone chimney near one ridge end with a slow smoke
## plume: deterministic per building id, view-only, and the cheapest signal
## that somebody actually lives here.
static func _add_chimney(root: Node3D, building: Dictionary, size: Vector2, wall_height: float) -> void:
	var ridge_along_x := size.x >= size.y
	var rise := (minf(size.x, size.y) * 0.5 + ROOF_OVERHANG) * ROOF_PITCH
	var along := (maxf(size.x, size.y) * 0.5 - CHIMNEY_SIZE) * 0.62
	if String(building["id"]).hash() % 2 == 0:
		along = -along
	var offset := Vector3(along, 0.0, 0.0) if ridge_along_x else Vector3(0.0, 0.0, along)
	var top := wall_height + rise + 0.55
	var stack := MeshInstance3D.new()
	stack.name = "Chimney"
	var stack_mesh := BoxMesh.new()
	stack_mesh.size = Vector3(CHIMNEY_SIZE, top - wall_height + 0.9, CHIMNEY_SIZE)
	stack.mesh = stack_mesh
	stack.position = offset + Vector3(0.0, (top + wall_height - 0.9) * 0.5, 0.0)
	stack.material_override = MapViewMaterials.role(&"stone")
	root.add_child(stack)

	var smoke := GPUParticles3D.new()
	smoke.name = "ChimneySmoke"
	smoke.position = offset + Vector3(0.0, top + 0.1, 0.0)
	smoke.amount = SMOKE_AMOUNT
	smoke.lifetime = SMOKE_LIFETIME
	smoke.preprocess = SMOKE_LIFETIME
	smoke.local_coords = true
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.35, 1.0, 0.1)
	process.spread = 16.0
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 0.55
	process.gravity = Vector3(0.14, 0.26, 0.0)
	process.scale_min = 0.8
	process.scale_max = 1.4
	process.angle_min = -180.0
	process.angle_max = 180.0
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(1.0, 1.0))
	var curve_texture := CurveTexture.new()
	curve_texture.curve = scale_curve
	process.scale_curve = curve_texture
	var alpha_ramp := Gradient.new()
	alpha_ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.32))
	alpha_ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = alpha_ramp
	process.color_ramp = ramp_texture
	smoke.process_material = process
	var puff := QuadMesh.new()
	puff.size = Vector2(1.0, 1.0)
	puff.material = MapViewMaterials.smoke()
	smoke.draw_pass_1 = puff
	root.add_child(smoke)


## Gabled roof over a rectangular footprint: ridge along the longer axis,
## rise proportional to the narrow span, small eave overhang.
static func _gabled_roof_mesh(base: Vector2) -> ArrayMesh:
	var half_w := base.x * 0.5 + ROOF_OVERHANG
	var half_d := base.y * 0.5 + ROOF_OVERHANG
	var ridge_along_x := base.x >= base.y
	var narrow := minf(half_w, half_d)
	var rise := narrow * ROOF_PITCH

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if ridge_along_x:
		var a := Vector3(-half_w, 0.0, -half_d)
		var b := Vector3(half_w, 0.0, -half_d)
		var c := Vector3(half_w, 0.0, half_d)
		var d := Vector3(-half_w, 0.0, half_d)
		var r0 := Vector3(-half_w, rise, 0.0)
		var r1 := Vector3(half_w, rise, 0.0)
		var north := Vector3(0.0, half_d, -rise).normalized()
		var south := Vector3(0.0, half_d, rise).normalized()
		_add_roof_quad(surface, a, b, r1, r0, north)
		_add_roof_quad(surface, r0, r1, c, d, south)
		_add_roof_triangle(surface, a, r0, d, Vector3.LEFT)
		_add_roof_triangle(surface, b, c, r1, Vector3.RIGHT)
	else:
		var a := Vector3(-half_w, 0.0, -half_d)
		var b := Vector3(half_w, 0.0, -half_d)
		var c := Vector3(half_w, 0.0, half_d)
		var d := Vector3(-half_w, 0.0, half_d)
		var r0 := Vector3(0.0, rise, -half_d)
		var r1 := Vector3(0.0, rise, half_d)
		var west := Vector3(-rise, half_w, 0.0).normalized()
		var east := Vector3(rise, half_w, 0.0).normalized()
		_add_roof_quad(surface, a, r0, r1, d, west)
		_add_roof_quad(surface, r0, b, c, r1, east)
		_add_roof_triangle(surface, a, b, r0, Vector3.FORWARD)
		_add_roof_triangle(surface, d, r1, c, Vector3.BACK)
	return surface.commit()


static func _add_roof_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(vertex.x + vertex.z, vertex.y))
		surface.add_vertex(vertex)


static func _add_roof_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	for vertex in [a, b, c]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(vertex.x + vertex.z, vertex.y))
		surface.add_vertex(vertex)


static func _box(parent: Node3D, name: String, size: Vector3, position: Vector3, role: StringName) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _role_material(role)
	parent.add_child(instance)


static func _cylinder(
	parent: Node3D,
	name: String,
	radius: float,
	height: float,
	position: Vector3,
	role: StringName,
	side_axis: bool = false
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position
	if side_axis:
		instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	instance.material_override = _role_material(role)
	parent.add_child(instance)


static func _sphere(
	parent: Node3D,
	name: String,
	radius: float,
	position: Vector3,
	role: StringName,
	scale: Vector3 = Vector3.ONE
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	instance.mesh = mesh
	instance.position = position
	instance.scale = scale
	instance.material_override = _role_material(role)
	parent.add_child(instance)


static func _role_material(role: StringName) -> StandardMaterial3D:
	match role:
		&"roof":
			return MapViewMaterials.roof(MapVisualStyle.role_color(&"roof", MapVisualStyle.TARGET_CLEAN_PAINTED, MapVisualStyle.TIME_DAY))
		_:
			return MapViewMaterials.role(role)
