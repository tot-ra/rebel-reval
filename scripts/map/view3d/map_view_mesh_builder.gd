class_name MapViewMeshBuilder
extends RefCounted

const TRANSITION_MARKER_SCRIPT := preload("res://scripts/map/view3d/transition_marker_3d.gd")

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
const TRANSITION_MARKER_HEIGHT := 0.035
const TRANSITION_MARKER_COLOR := Color(0.55, 0.78, 0.48, 0.3)

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

## Gentle rolling ground relief. Heights flatten to zero around buildings,
## transitions, water, and the map border so gameplay-relevant geometry keeps
## sitting on level pads and the logic plane's flat collision stays honest.
const HEIGHT_BROAD_AMPLITUDE := 0.38
const HEIGHT_FINE_AMPLITUDE := 0.09
const HEIGHT_BROAD_PERIOD := 9.0
const HEIGHT_FINE_PERIOD := 3.1
## Each logic cell becomes a 3 x 3 visual patch (18 triangles). Gameplay stays
## on the original grid while relief and surface borders gain finer curvature.
const TERRAIN_SUBDIVISIONS := 3
## Shared grid vertices shift laterally up to this much so terrain borders
## (road edges, shorelines) curve organically instead of running cell-straight.
const EDGE_JITTER := 0.26
## Terrain identity is sampled through a smooth offset at sub-cell centers.
## This visually rounds rectangle-authored roads and banks while the immutable
## terrain grid continues to own gameplay semantics.
const VISUAL_EDGE_WARP := 0.38
const FLATTEN_START := 0.3
const FLATTEN_END := 2.4
const BORDER_FLATTEN_CELLS := 2.5
const WATER_FLATTEN_CELLS := 3

## House construction families: visible building material per dwelling.
const HOUSE_STYLE_TIMBER := &"timber_frame"
const HOUSE_STYLE_BRICK := &"brick"
const HOUSE_STYLE_PLANK := &"plank"
const PLASTER_TONE := Color(0.87, 0.81, 0.67)
const BRICK_TONE := Color(0.64, 0.36, 0.25)
const FRAME_BEAM_THICKNESS := 0.11
const PLINTH_HEIGHT := 0.24

## Tallinn town-wall dressing: round limestone towers wear tall conical
## red-tile roofs, and wall walks carry a red saddle roof on timber posts.
const TOWER_MAX_FOOTPRINT := 5.2
const TOWER_MIN_ASPECT := 0.65
const TOWER_RADIUS_FACTOR := 0.48
const TOWER_ROOF_COLOR := Color8(158, 64, 44)
const WALL_ROOF_COLOR := Color8(150, 66, 48)
const TOWER_ROOF_PITCH := 1.45
const WALL_WALK_ROOF_LIFT := 0.75

const CHIMNEY_SIZE := 0.5
const SMOKE_LIFETIME := 6.0
const SMOKE_AMOUNT := 28

## House facades: every house gets a street door and shuttered windows so the
## dwellings read as inhabited from the dimetric camera.
const HOUSE_DOOR_WIDTH := 0.95
const HOUSE_DOOR_HEIGHT := 2.1
const HOUSE_WINDOW_SIZE := Vector2(0.6, 0.75)
const HOUSE_WINDOW_SILL := 1.15
const HOUSE_WINDOW_SPACING := 2.1
const FACADE_RELIEF := 0.05

## Fortification dressing: town-wall segments and towers above this height get
## battlements; towers additionally get arrow slits.
const BATTLEMENT_MIN_HEIGHT_PX := 160.0
const TOWER_MIN_HEIGHT_PX := 220.0
const MERLON_SIZE := Vector3(0.42, 0.5, 0.3)
const MERLON_SPACING := 0.95
const ARROW_SLIT_SIZE := Vector3(0.14, 0.7, 0.08)

## Gate arch landmark: view-only mass bridging a walkable gate passage.
const GATE_ARCH_CLEARANCE := 3.2

## Background town silhouette on `surroundings_town_sides`.
const TOWN_GRID_SPACING := 6.5
const TOWN_KEEP_RATIO := 0.6
const TOWN_BAND_INNER := 2.5
const GLACIS_CLEARANCE := 6.0

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


## Deterministic per-map height field shared by the terrain mesh, scatter,
## trees, and actor sync so everything sits on the same rolling ground.
static var _height_fields: Dictionary = {}


## Precomputes flatten rectangles, water cells, and shared jittered/heightened
## grid vertices for a definition. Idempotent per map id.
static func ensure_height_field(definition: MapDefinition, grid: MapTerrainGrid) -> Dictionary:
	var key := String(definition.map_id)
	if _height_fields.has(key):
		return _height_fields[key]
	var scale := MapViewBridge.world_scale(definition.cell_size)
	var rects: Array[Rect2] = []
	for building in definition.buildings:
		var footprint: Rect2 = building["footprint"]
		rects.append(Rect2(footprint.position * scale, footprint.size * scale).grow(0.75))
	for transition in definition.transitions:
		var rect: Rect2 = transition["rect"]
		rects.append(Rect2(rect.position * scale, rect.size * scale).grow(0.5))
	for landmark in definition.view_landmarks:
		var rect: Rect2 = landmark["rect"]
		rects.append(Rect2(rect.position * scale, rect.size * scale).grow(0.75))
	var water := {}
	for y in grid.size_cells.y:
		for x in grid.size_cells.x:
			if MapViewMaterials.WATER_TERRAINS.has(grid.get_terrain(Vector2i(x, y))):
				water[Vector2i(x, y)] = true
	var field := {
		"seed": definition.seed,
		"size": grid.size_cells,
		"rects": rects,
		"water": water,
	}
	_height_fields[key] = field
	_bake_vertices(field)
	return field


## Ground height (world units) of the visible terrain at a world XZ position.
## Zero when the map has no baked height field or outside the playable bounds.
static func ground_height(definition: MapDefinition, world_xz: Vector2) -> float:
	var field: Dictionary = _height_fields.get(String(definition.map_id), {})
	if field.is_empty():
		return 0.0
	return _field_height(field, world_xz)


static func _field_height(field: Dictionary, position: Vector2) -> float:
	var size: Vector2i = field["size"]
	if position.x < 0.0 or position.y < 0.0 or position.x > float(size.x) or position.y > float(size.y):
		return 0.0
	var cell := Vector2i(floori(position.x), floori(position.y))
	if field["water"].has(cell):
		return -WATER_RECESS
	var noise_seed: int = field["seed"]
	var broad := _value_noise(position / HEIGHT_BROAD_PERIOD, noise_seed + 7717)
	var fine := _value_noise(position / HEIGHT_FINE_PERIOD, noise_seed + 8317)
	var height := broad * HEIGHT_BROAD_AMPLITUDE + fine * HEIGHT_FINE_AMPLITUDE
	return height * minf(_pad_factor(field, position), _water_factor(field, position))


## Smooth value noise in [0, 1] over an integer lattice.
static func _value_noise(p: Vector2, noise_seed: int) -> float:
	var xi := floori(p.x)
	var yi := floori(p.y)
	var fx := p.x - float(xi)
	var fy := p.y - float(yi)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _hash01(xi, yi, noise_seed)
	var b := _hash01(xi + 1, yi, noise_seed)
	var c := _hash01(xi, yi + 1, noise_seed)
	var d := _hash01(xi + 1, yi + 1, noise_seed)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## 0 on building/transition pads and at the map border, easing to 1 beyond
## FLATTEN_END so level gameplay pads blend into the rolling ground.
static func _pad_factor(field: Dictionary, position: Vector2) -> float:
	var size: Vector2i = field["size"]
	var border := minf(
		minf(position.x, float(size.x) - position.x),
		minf(position.y, float(size.y) - position.y)
	)
	var factor := clampf(border / BORDER_FLATTEN_CELLS, 0.0, 1.0)
	for rect: Rect2 in field["rects"]:
		var dx := maxf(maxf(rect.position.x - position.x, position.x - rect.end.x), 0.0)
		var dy := maxf(maxf(rect.position.y - position.y, position.y - rect.end.y), 0.0)
		var distance := Vector2(dx, dy).length()
		factor = minf(factor, smoothstep(FLATTEN_START, FLATTEN_END, distance))
	return factor


static func _water_factor(field: Dictionary, position: Vector2) -> float:
	var cell := Vector2i(floori(position.x), floori(position.y))
	var water: Dictionary = field["water"]
	if water.is_empty():
		return 1.0
	var nearest := float(WATER_FLATTEN_CELLS + 1)
	for oy in range(-WATER_FLATTEN_CELLS, WATER_FLATTEN_CELLS + 1):
		for ox in range(-WATER_FLATTEN_CELLS, WATER_FLATTEN_CELLS + 1):
			if water.has(cell + Vector2i(ox, oy)):
				nearest = minf(nearest, maxf(absf(float(ox)), absf(float(oy))))
	return smoothstep(0.6, float(WATER_FLATTEN_CELLS), nearest)


## Shared sub-cell vertex positions and normals: lateral jitter bends terrain
## borders while neighboring patches reuse identical vertices, keeping the
## ground watertight. Vertices touching water drop to the recess depth.
static func _bake_vertices(field: Dictionary) -> void:
	var size: Vector2i = field["size"]
	var noise_seed: int = field["seed"]
	var columns := size.x * TERRAIN_SUBDIVISIONS + 1
	var rows := size.y * TERRAIN_SUBDIVISIONS + 1
	var positions := PackedVector3Array()
	positions.resize(columns * rows)
	for vy in rows:
		for vx in columns:
			var base := Vector2(vx, vy) / float(TERRAIN_SUBDIVISIONS)
			var jitter_scale := _pad_factor(field, base)
			var jitter := Vector2(
				_hash01(vx, vy, noise_seed + 8887) - 0.5,
				_hash01(vx, vy, noise_seed + 9973) - 0.5
			) * EDGE_JITTER * jitter_scale
			if vx == 0 or vy == 0 or vx == columns - 1 or vy == rows - 1:
				jitter = Vector2.ZERO
			var spot := base + jitter
			var height := -WATER_RECESS if _subvertex_touches_water(field, vx, vy) else _field_height(field, spot)
			positions[vy * columns + vx] = Vector3(spot.x, height, spot.y)
	var normals := PackedVector3Array()
	normals.resize(columns * rows)
	for vy in rows:
		for vx in columns:
			var left := positions[vy * columns + maxi(vx - 1, 0)].y
			var right := positions[vy * columns + mini(vx + 1, columns - 1)].y
			var up := positions[maxi(vy - 1, 0) * columns + vx].y
			var down := positions[mini(vy + 1, rows - 1) * columns + vx].y
			normals[vy * columns + vx] = Vector3(left - right, 2.0, up - down).normalized()
	field["positions"] = positions
	field["normals"] = normals
	field["vertex_columns"] = columns


## Sample each side of a subvertex so shoreline vertices are shared by the
## recessed water and its bank while interior water vertices stay level.
static func _subvertex_touches_water(field: Dictionary, vx: int, vy: int) -> bool:
	var water: Dictionary = field["water"]
	var size: Vector2i = field["size"]
	var base := Vector2(vx, vy) / float(TERRAIN_SUBDIVISIONS)
	for nudge: Vector2 in [Vector2(-0.001, -0.001), Vector2(0.001, -0.001), Vector2(-0.001, 0.001), Vector2(0.001, 0.001)]:
		var sample: Vector2 = base + nudge
		if sample.x < 0.0 or sample.y < 0.0 or sample.x >= size.x or sample.y >= size.y:
			continue
		var cell := Vector2i(floori(sample.x), floori(sample.y))
		if water.has(cell):
			return true
	return false


## One MeshInstance3D per used terrain: every cell of that terrain becomes a
## textured ground quad over the shared jittered height vertices. Water-family
## cells sit slightly recessed under an animated surface so shorelines read in
## the dimetric view without touching walkability.
static func build_terrain(definition: MapDefinition, grid: MapTerrainGrid) -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"
	var field := ensure_height_field(definition, grid)
	for terrain_id in grid.used_terrain_ids():
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var water := MapViewMaterials.WATER_TERRAINS.has(terrain_id)
		for y in grid.size_cells.y:
			for x in grid.size_cells.x:
				if grid.get_terrain(Vector2i(x, y)) != terrain_id:
					continue
				var tone := 1.0 if water else _cell_tone(x, y, definition.seed)
				_add_cell_quad(surface, field, grid, terrain_id, x, y, definition.seed, tone)
		var instance := MeshInstance3D.new()
		instance.name = "Terrain_%s" % String(terrain_id)
		if water:
			surface.generate_tangents()
		instance.mesh = surface.commit()
		if water:
			instance.material_override = MapViewMaterials.water_surface(terrain_id)
		else:
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

	var wall_color := Color(building.get("wall_color", DEFAULT_WALL_COLOR))
	var fortification := kind == MapTypes.BUILDING_KIND_WALL and height_px >= BATTLEMENT_MIN_HEIGHT_PX
	var footprint_aspect := minf(size.x, size.y) / maxf(size.x, size.y)
	var tower := (
		fortification
		and size.x <= TOWER_MAX_FOOTPRINT
		and size.y <= TOWER_MAX_FOOTPRINT
		and footprint_aspect >= TOWER_MIN_ASPECT
	)

	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	if tower:
		# Tallinn-style round tower: limestone drum instead of a square prism.
		var drum := CylinderMesh.new()
		drum.top_radius = minf(size.x, size.y) * TOWER_RADIUS_FACTOR
		drum.bottom_radius = drum.top_radius * 1.06
		drum.height = height
		drum.radial_segments = 18
		walls.mesh = drum
		walls.material_override = MapViewMaterials.wall_surface(&"limestone", wall_color.lightened(0.08))
	else:
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(size.x, height, size.y)
		walls.mesh = wall_mesh
		if kind == MapTypes.BUILDING_KIND_HOUSE:
			walls.material_override = _house_wall_material(building, wall_color)
		elif kind == MapTypes.BUILDING_KIND_WALL:
			walls.material_override = MapViewMaterials.wall_surface(&"limestone", wall_color)
		else:
			walls.material_override = MapViewMaterials.wall(wall_color)
	walls.position = Vector3(0.0, height * 0.5, 0.0)
	root.add_child(walls)

	if kind == MapTypes.BUILDING_KIND_HOUSE:
		var ridge_along_x := _ridge_along_x(building, size)
		var roof := MeshInstance3D.new()
		roof.name = "Roof"
		roof.mesh = _gabled_roof_mesh(size, ridge_along_x)
		roof.position = Vector3(0.0, height, 0.0)
		roof.material_override = MapViewMaterials.roof(building.get("roof_color", DEFAULT_ROOF_COLOR))
		root.add_child(roof)
		_add_chimney(root, building, size, height, ridge_along_x)
		_add_house_structure(root, building, size, height)
		_add_house_facade(root, building, size, height)
	elif tower:
		var radius := minf(size.x, size.y) * TOWER_RADIUS_FACTOR
		# The stone overhang ring doubles as the flat cap the view contract
		# expects on every wall-kind building.
		var cap := MeshInstance3D.new()
		cap.name = "Cap"
		var ring := CylinderMesh.new()
		ring.top_radius = radius + 0.22
		ring.bottom_radius = radius + 0.22
		ring.height = CAP_HEIGHT * 2.0
		ring.radial_segments = 18
		cap.mesh = ring
		cap.position = Vector3(0.0, height + CAP_HEIGHT, 0.0)
		cap.material_override = MapViewMaterials.wall_surface(&"limestone", wall_color.lightened(0.16))
		root.add_child(cap)
		_add_tower_roof(root, radius, height)
		if height_px >= TOWER_MIN_HEIGHT_PX:
			_add_tower_slits(root, radius, height)
	else:
		var cap := MeshInstance3D.new()
		cap.name = "Cap"
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(size.x + CAP_OVERHANG * 2.0, CAP_HEIGHT, size.y + CAP_OVERHANG * 2.0)
		cap.mesh = cap_mesh
		cap.position = Vector3(0.0, height + CAP_HEIGHT * 0.5, 0.0)
		cap.material_override = MapViewMaterials.wall_surface(
			&"limestone" if kind == MapTypes.BUILDING_KIND_WALL else &"plaster",
			wall_color.lightened(0.12)
		)
		root.add_child(cap)
		if fortification:
			_add_battlements(root, building, size, height)
			_add_wall_walk_roof(root, size, height)
	return root


## Visible construction material per house, deterministic from the id: most are
## plastered timber frame, the rest brick or plank, so facades stop reading as
## flat painted boxes.
static func _house_style(building: Dictionary) -> StringName:
	var roll := absi(String(building["id"]).hash()) % 10
	if roll < 4:
		return HOUSE_STYLE_TIMBER
	if roll < 7:
		return HOUSE_STYLE_BRICK
	return HOUSE_STYLE_PLANK


static func _house_wall_material(building: Dictionary, wall_color: Color) -> StandardMaterial3D:
	match _house_style(building):
		HOUSE_STYLE_TIMBER:
			return MapViewMaterials.wall_surface(&"plaster", wall_color.lerp(PLASTER_TONE, 0.55))
		HOUSE_STYLE_BRICK:
			return MapViewMaterials.wall_surface(&"brick", wall_color.lerp(BRICK_TONE, 0.6))
		_:
			return MapViewMaterials.wall_surface(&"plank", wall_color)


## Structural dressing that gives every house physical depth: a stone plinth,
## corner posts, and (for timber-frame houses) exposed beams with braces.
static func _add_house_structure(root: Node3D, building: Dictionary, size: Vector2, height: float) -> void:
	var style := _house_style(building)
	_box(
		root,
		"Plinth",
		Vector3(size.x + 0.12, PLINTH_HEIGHT, size.y + 0.12),
		Vector3(0.0, PLINTH_HEIGHT * 0.5, 0.0),
		&"stone"
	)
	if style == HOUSE_STYLE_BRICK:
		return
	var half := size * 0.5
	var beam := FRAME_BEAM_THICKNESS
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		_box(
			root,
			"CornerPost_%d_%d" % [int(corner.x), int(corner.y)],
			Vector3(beam, height, beam),
			Vector3(corner.x * half.x, height * 0.5, corner.y * half.y),
			&"timber"
		)
	if style != HOUSE_STYLE_TIMBER:
		return
	# Horizontal beams at the sill, storey, and top plate on all facades, plus
	# diagonal braces flanking the storey line on the long facades.
	var beam_heights := [PLINTH_HEIGHT + beam * 0.5, height * 0.55, height - beam * 0.5]
	for beam_y: float in beam_heights:
		_box(root, "BeamNS%d" % int(beam_y * 100.0), Vector3(size.x + beam, beam, beam), Vector3(0.0, beam_y, half.y), &"timber")
		_box(root, "BeamNS%dB" % int(beam_y * 100.0), Vector3(size.x + beam, beam, beam), Vector3(0.0, beam_y, -half.y), &"timber")
		_box(root, "BeamEW%d" % int(beam_y * 100.0), Vector3(beam, beam, size.y + beam), Vector3(half.x, beam_y, 0.0), &"timber")
		_box(root, "BeamEW%dB" % int(beam_y * 100.0), Vector3(beam, beam, size.y + beam), Vector3(-half.x, beam_y, 0.0), &"timber")
	var brace_length := (height * 0.55 - PLINTH_HEIGHT) * 1.35
	var along_x := size.x >= size.y
	var brace_offset := (size.x if along_x else size.y) * 0.28
	for flip in [-1.0, 1.0]:
		var brace := MeshInstance3D.new()
		brace.name = "Brace%d" % int(flip)
		var brace_mesh := BoxMesh.new()
		brace_mesh.size = Vector3(brace_length, beam * 0.9, beam * 0.6)
		brace.mesh = brace_mesh
		var mid_y := (PLINTH_HEIGHT + height * 0.55) * 0.5
		if along_x:
			brace.position = Vector3(flip * brace_offset, mid_y, half.y)
			brace.rotation.z = flip * 0.7
		else:
			brace.position = Vector3(half.x, mid_y, flip * brace_offset)
			brace.rotation.y = PI * 0.5
			brace.rotation.z = flip * 0.7
		brace.material_override = MapViewMaterials.role(&"timber")
		root.add_child(brace)


## Tall conical red-tile roof with a finial: the signature silhouette of the
## Tallinn town-wall towers.
static func _add_tower_roof(root: Node3D, radius: float, height: float) -> void:
	var roof_radius := radius + 0.34
	var roof := MeshInstance3D.new()
	roof.name = "TowerRoof"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = roof_radius
	cone.height = roof_radius * TOWER_ROOF_PITCH
	cone.radial_segments = 18
	roof.mesh = cone
	roof.position = Vector3(0.0, height + CAP_HEIGHT * 2.0 + cone.height * 0.5, 0.0)
	roof.material_override = MapViewMaterials.roof(TOWER_ROOF_COLOR)
	root.add_child(roof)
	var finial := MeshInstance3D.new()
	finial.name = "Finial"
	var knob := SphereMesh.new()
	knob.radius = 0.09
	knob.height = 0.18
	finial.mesh = knob
	finial.position = Vector3(0.0, height + CAP_HEIGHT * 2.0 + cone.height + 0.06, 0.0)
	finial.material_override = MapViewMaterials.role(&"metal")
	root.add_child(finial)


static func _add_tower_slits(root: Node3D, radius: float, height: float) -> void:
	var index := 0
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var slit := MeshInstance3D.new()
		slit.name = "Slit%d" % index
		var mesh := BoxMesh.new()
		mesh.size = ARROW_SLIT_SIZE
		slit.mesh = mesh
		slit.position = Vector3(sin(angle) * radius, height * 0.62, cos(angle) * radius)
		slit.rotation.y = angle
		slit.material_override = MapViewMaterials.role(&"window")
		root.add_child(slit)
		index += 1


## Red saddle roof hovering over the wall walk on timber posts, with the
## battlements still reading underneath - the covered parapet look of the
## surviving Tallinn town wall.
static func _add_wall_walk_roof(root: Node3D, size: Vector2, height: float) -> void:
	var along_x := size.x >= size.y
	var length := (size.x if along_x else size.y) + 0.3
	var span := (size.y if along_x else size.x) + 0.7
	var base_y := height + CAP_HEIGHT + WALL_WALK_ROOF_LIFT
	var roof := MeshInstance3D.new()
	roof.name = "WalkRoof"
	roof.mesh = _gabled_roof_mesh(
		Vector2(length, span) if along_x else Vector2(span, length),
		along_x
	)
	roof.position = Vector3(0.0, base_y, 0.0)
	roof.material_override = MapViewMaterials.roof(WALL_ROOF_COLOR)
	root.add_child(roof)
	var post_count := maxi(2, int(length / 2.2))
	var post_height := WALL_WALK_ROOF_LIFT + 0.1
	for post_index in post_count + 1:
		var along := (float(post_index) / float(post_count) - 0.5) * (length - 0.4)
		for side in [-1.0, 1.0]:
			var offset: float = side * (span * 0.5 - 0.35)
			var position := Vector3(along, height + CAP_HEIGHT + post_height * 0.5, offset)
			if not along_x:
				position = Vector3(offset, position.y, along)
			_box(
				root,
				"RoofPost%d_%d" % [post_index, int(side)],
				Vector3(0.09, post_height, 0.09),
				position,
				&"timber"
			)
	return


## Ridge orientation: longest footprint axis unless the definition pins it via
## "ridge_axis" (&"x"/&"z") - Hanseatic houses turn the gable end to the street.
static func _ridge_along_x(building: Dictionary, size: Vector2) -> bool:
	match building.get("ridge_axis", &""):
		&"x":
			return true
		&"z":
			return false
	return size.x >= size.y


## Street door plus shuttered windows on the "door_side" facade (&"south"
## default) and matching windows on the opposite face. A house whose entry is
## already a framed transition door declares door_side &"none" to keep windows
## without doubling the door.
static func _add_house_facade(root: Node3D, building: Dictionary, size: Vector2, height: float) -> void:
	var declared: StringName = building.get("door_side", &"south")
	var side := declared if declared != &"none" else &"south"
	var along_x := side == &"north" or side == &"south"
	var facade_length := size.x if along_x else size.y
	var face_offset := (size.y if along_x else size.x) * 0.5
	var id_hash := String(building["id"]).hash()

	var door_height := minf(HOUSE_DOOR_HEIGHT, height - 0.2)
	var door_along := (float(id_hash % 100) / 99.0 - 0.5) * maxf(facade_length - HOUSE_DOOR_WIDTH - 1.2, 0.0) * 0.5
	if declared != &"none":
		_facade_box(root, "Door", Vector3(HOUSE_DOOR_WIDTH, door_height, DOOR_THICKNESS), door_along, door_height * 0.5, side, face_offset, &"wood")
		_facade_box(root, "DoorLintel", Vector3(HOUSE_DOOR_WIDTH + 0.24, DOOR_FRAME_THICKNESS, DOOR_THICKNESS + 0.02), door_along, door_height + DOOR_FRAME_THICKNESS * 0.5, side, face_offset, &"timber")
		_facade_box(root, "DoorStep", Vector3(HOUSE_DOOR_WIDTH + 0.2, 0.09, 0.34), door_along, 0.045, side, face_offset, &"stone")

	var window_count := clampi(int(facade_length / HOUSE_WINDOW_SPACING), 1, 3)
	var window_sill := minf(HOUSE_WINDOW_SILL, height - HOUSE_WINDOW_SIZE.y - 0.15)
	var index := 0
	var faces: Array[StringName] = [side, _opposite_side(side)]
	for face in faces:
		for window in window_count:
			var along := (float(window + 1) / float(window_count + 1) - 0.5) * facade_length
			# Keep the front windows clear of the door.
			if face == side and absf(along - door_along) < (HOUSE_DOOR_WIDTH + HOUSE_WINDOW_SIZE.x) * 0.62:
				continue
			_facade_box(root, "Window%d" % index, Vector3(HOUSE_WINDOW_SIZE.x, HOUSE_WINDOW_SIZE.y, 0.06), along, window_sill + HOUSE_WINDOW_SIZE.y * 0.5, face, face_offset, &"window")
			_facade_box(root, "WindowLintel%d" % index, Vector3(HOUSE_WINDOW_SIZE.x + 0.18, 0.1, 0.09), along, window_sill + HOUSE_WINDOW_SIZE.y + 0.05, face, face_offset, &"timber")
			_facade_box(root, "WindowSill%d" % index, Vector3(HOUSE_WINDOW_SIZE.x + 0.18, 0.08, 0.12), along, window_sill - 0.04, face, face_offset, &"timber")
			index += 1


static func _opposite_side(side: StringName) -> StringName:
	match side:
		&"north":
			return &"south"
		&"south":
			return &"north"
		&"east":
			return &"west"
	return &"east"


## Places a box flush against the given facade, protruding FACADE_RELIEF so it
## reads in the dimetric light.
static func _facade_box(root: Node3D, name: String, box_size: Vector3, along: float, center_y: float, side: StringName, face_offset: float, role: StringName) -> void:
	var out := face_offset + box_size.z * 0.5 - FACADE_RELIEF + 0.06
	var position := Vector3.ZERO
	var size := box_size
	match side:
		&"south":
			position = Vector3(along, center_y, out)
		&"north":
			position = Vector3(along, center_y, -out)
		&"east":
			position = Vector3(out, center_y, along)
			size = Vector3(box_size.z, box_size.y, box_size.x)
		&"west":
			position = Vector3(-out, center_y, along)
			size = Vector3(box_size.z, box_size.y, box_size.x)
	_box(root, name, size, position, role)


## Crenellated parapet along the cap of tall fortification walls and towers.
static func _add_battlements(root: Node3D, building: Dictionary, size: Vector2, height: float) -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var half := size * 0.5
	var tower := size.x <= 3.4 and size.y <= 3.4
	var edges: Array = []
	if tower or size.x >= size.y:
		edges.append([Vector3(-half.x, 0.0, -half.y), Vector3(half.x, 0.0, -half.y)])
		edges.append([Vector3(-half.x, 0.0, half.y), Vector3(half.x, 0.0, half.y)])
	if tower or size.y > size.x:
		edges.append([Vector3(-half.x, 0.0, -half.y), Vector3(-half.x, 0.0, half.y)])
		edges.append([Vector3(half.x, 0.0, -half.y), Vector3(half.x, 0.0, half.y)])
	for edge in edges:
		var from: Vector3 = edge[0]
		var to: Vector3 = edge[1]
		var length := from.distance_to(to)
		var count := maxi(2, int(length / MERLON_SPACING))
		for step in count + 1:
			var origin := from.lerp(to, float(step) / float(count))
			origin.y = height + CAP_HEIGHT + MERLON_SIZE.y * 0.5
			transforms.append(Transform3D(Basis.IDENTITY, origin))
			colors.append(Color.WHITE)
	var merlon_mesh := BoxMesh.new()
	merlon_mesh.size = MERLON_SIZE
	var merlons := _multi_mesh(
		"Merlons",
		merlon_mesh,
		transforms,
		colors,
		MapViewMaterials.wall_surface(&"limestone", Color(building.get("wall_color", DEFAULT_WALL_COLOR)).lightened(0.12)),
		Vector3.ZERO
	)
	root.add_child(merlons)


## View-only landmark geometry over walkable openings (never collides).
static func build_landmark(landmark: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Landmark_%s" % String(landmark["id"])
	var scale := MapViewBridge.world_scale(cell_size)
	var rect: Rect2 = landmark["rect"]
	var size := rect.size * scale
	var center := rect.get_center() * scale
	root.position = Vector3(center.x, 0.0, center.y)
	match landmark.get("kind", &""):
		&"gate_arch":
			var color := Color(landmark.get("wall_color", DEFAULT_WALL_COLOR))
			var top := float(landmark.get("top_px", 256.0)) * scale
			var span_height := maxf(top - GATE_ARCH_CLEARANCE, 0.6)
			var bridge := MeshInstance3D.new()
			bridge.name = "Bridge"
			var bridge_mesh := BoxMesh.new()
			bridge_mesh.size = Vector3(size.x, span_height, size.y)
			bridge.mesh = bridge_mesh
			bridge.position = Vector3(0.0, GATE_ARCH_CLEARANCE + span_height * 0.5, 0.0)
			bridge.material_override = MapViewMaterials.wall_surface(&"limestone", color)
			root.add_child(bridge)
			_add_battlements(root, {"id": landmark["id"], "wall_color": color}, size, top - CAP_HEIGHT)
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


## A low translucent patch makes district exits readable without looking like
## ordinary terrain. Runtime proximity raises its opacity for a gentle focus cue.
static func build_transition_marker(transition: Dictionary, cell_size: int) -> Node3D:
	var root := TRANSITION_MARKER_SCRIPT.new() as Node3D
	root.name = "Marker_%s" % String(transition["id"])
	root.set_meta("transition_id", transition["id"])
	var rect: Rect2 = transition["rect"]
	var scale := MapViewBridge.world_scale(cell_size)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Surface"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(rect.size.x * scale, TRANSITION_MARKER_HEIGHT, rect.size.y * scale)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = TRANSITION_MARKER_HEIGHT * 0.5
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = TRANSITION_MARKER_COLOR
	mesh_instance.material_override = material
	root.position = Vector3(rect.get_center().x * scale, 0.0, rect.get_center().y * scale)
	root.add_child(mesh_instance)
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


## Decorative ground clutter per terrain family: wind-swaying grass blade
## tufts on green cells, pebbles on worked ground. Deterministic from the map
## seed, skips building footprints, and stays under knee height so it never
## suggests collision.
static func build_scatter(definition: MapDefinition, grid: MapTerrainGrid) -> Node3D:
	var root := Node3D.new()
	root.name = "Scatter"
	var blocked := _building_cell_rects(definition)
	var field := ensure_height_field(definition, grid)

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
				var count := 2 + int(_hash01(x, y, definition.seed + 511) * 2.0)
				for tuft_index in count:
					tufts.append(_scatter_transform(field, x, y, definition.seed + 31 * (tuft_index + 1), 0.7, 1.4))
					var green := 0.86 + _hash01(x + tuft_index, y, definition.seed + 77) * 0.28
					tuft_colors.append(Color(green * 0.94, green, green * 0.8))
			elif roll < SCATTER_TUFT_CHANCE.get(terrain, 0.0) + SCATTER_STONE_CHANCE.get(terrain, 0.0):
				stones.append(_scatter_transform(field, x, y, definition.seed + 913, 0.6, 1.6))
				var gray := 0.8 + _hash01(x, y, definition.seed + 154) * 0.35
				stone_colors.append(Color(gray, gray, gray * 0.97))

	root.add_child(_multi_mesh("Tufts", _grass_tuft_mesh(), tufts, tuft_colors, MapViewMaterials.grass_blades(), Vector3.ZERO))

	var stone_mesh := SphereMesh.new()
	stone_mesh.radius = 0.09
	stone_mesh.height = 0.11
	stone_mesh.radial_segments = 8
	stone_mesh.rings = 4
	root.add_child(_multi_mesh("Stones", stone_mesh, stones, stone_colors, MapViewMaterials.role(&"stone"), Vector3(0.0, 0.03, 0.0)))
	return root


## A handful of tapered blades leaning out from a shared root: reads as a real
## grass clump instead of a cone, and gives the wind shader tips to move.
## UV.y runs root (0) to tip (1) for both sway weight and shading.
static func _grass_tuft_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade_count := 7
	for blade in blade_count:
		var yaw := TAU * float(blade) / float(blade_count) + _hash01(blade, 3, 17) * 0.9
		var lean := 0.10 + _hash01(blade, 7, 29) * 0.22
		var blade_height := 0.26 + _hash01(blade, 11, 41) * 0.24
		var half_width := 0.020 + _hash01(blade, 13, 53) * 0.012
		var direction := Vector3(sin(yaw), 0.0, cos(yaw))
		var side := Vector3(cos(yaw), 0.0, -sin(yaw))
		var root_center := direction * 0.03
		var tip := root_center + direction * lean + Vector3(0.0, blade_height, 0.0)
		var mid := root_center + direction * lean * 0.45 + Vector3(0.0, blade_height * 0.55, 0.0)
		var normal := Vector3.UP.cross(side).normalized() + Vector3(0.0, 0.4, 0.0)
		normal = normal.normalized()
		var quad := [
			[root_center - side * half_width, Vector2(0.0, 0.0)],
			[root_center + side * half_width, Vector2(1.0, 0.0)],
			[mid + side * half_width * 0.55, Vector2(1.0, 0.55)],
			[mid - side * half_width * 0.55, Vector2(0.0, 0.55)],
		]
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(normal)
			surface.set_uv(quad[index][1])
			surface.add_vertex(quad[index][0])
		var tip_triangle := [
			[mid - side * half_width * 0.55, Vector2(0.0, 0.55)],
			[mid + side * half_width * 0.55, Vector2(1.0, 0.55)],
			[tip, Vector2(0.5, 1.0)],
		]
		for point in tip_triangle:
			surface.set_normal(normal)
			surface.set_uv(point[1])
			surface.add_vertex(point[0])
	return surface.commit()


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
	# Below WATER_RECESS: the apron spans under the playable map too, so it must
	# sit deeper than recessed water cells or moats render invisible.
	apron.position = Vector3(map_size.x * 0.5, -WATER_RECESS - 0.04, map_size.y * 0.5)
	root.add_child(apron)

	var trunks: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var spruces: Array[Transform3D] = []
	var spruce_colors: Array[Color] = []
	var leaves: Array[Transform3D] = []
	var leaf_colors: Array[Color] = []
	var boulders: Array[Transform3D] = []
	var boulder_colors: Array[Color] = []

	var town_sides := definition.surroundings_town_sides
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
			if not town_sides.is_empty():
				# Town keeps going on urban sides; open sides keep a cleared
				# glacis strip before the treeline starts.
				if town_sides.has(_world_side(spot, map_size)):
					continue
				if _distance_outside(spot, map_size) < GLACIS_CLEARANCE:
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
			trunks.append(_placed(spot, tree_scale, Vector3(0.0, 0.6 * tree_scale, 0.0), yaw))
			var bark := 0.85 + _hash01(gx, gy, definition.seed + 2111) * 0.3
			trunk_colors.append(Color(bark, bark, bark))
			var tint := 0.8 + _hash01(gx, gy, definition.seed + 2221) * 0.4
			if kind_roll < 0.6:
				spruces.append(_placed(spot, tree_scale, Vector3(0.0, 0.4 * tree_scale, 0.0), yaw))
				spruce_colors.append(Color(tint * 0.9, tint, tint * 0.88))
			else:
				leaves.append(_placed(spot, tree_scale, Vector3(0.0, 1.5 * tree_scale, 0.0), yaw))
				leaf_colors.append(Color(tint * 0.96, tint, tint * 0.8))

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.09
	trunk_mesh.bottom_radius = 0.15
	trunk_mesh.height = 1.2
	trunk_mesh.radial_segments = 7
	root.add_child(_multi_mesh("Trunks", trunk_mesh, trunks, trunk_colors, MapViewMaterials.bark(), Vector3.ZERO))

	root.add_child(_multi_mesh("SpruceCanopies", _spruce_canopy_mesh(), spruces, spruce_colors, MapViewMaterials.canopy(&"spruce"), Vector3.ZERO))
	root.add_child(_multi_mesh("LeafCanopies", _leaf_canopy_mesh(), leaves, leaf_colors, MapViewMaterials.canopy(&"leaf"), Vector3.ZERO))

	var boulder_mesh := SphereMesh.new()
	boulder_mesh.radius = 0.45
	boulder_mesh.height = 0.6
	boulder_mesh.radial_segments = 7
	boulder_mesh.rings = 4
	root.add_child(_multi_mesh("Boulders", boulder_mesh, boulders, boulder_colors, MapViewMaterials.role(&"stone"), Vector3.ZERO))
	if not town_sides.is_empty():
		root.add_child(_town_silhouette(definition, map_size))
	return root


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
	var inner := Rect2(Vector2.ZERO, map_size).grow(TOWN_BAND_INNER)
	var start_x := int(-TREE_BAND_OUTER / TOWN_GRID_SPACING)
	var end_x := int((map_size.x + TREE_BAND_OUTER) / TOWN_GRID_SPACING)
	var start_y := int(-TREE_BAND_OUTER / TOWN_GRID_SPACING)
	var end_y := int((map_size.y + TREE_BAND_OUTER) / TOWN_GRID_SPACING)
	for gy in range(start_y, end_y + 1):
		for gx in range(start_x, end_x + 1):
			var base := Vector2(gx, gy) * TOWN_GRID_SPACING
			var jitter := Vector2(
				_hash01(gx, gy, definition.seed + 3301) - 0.5,
				_hash01(gx, gy, definition.seed + 3407) - 0.5
			) * TOWN_GRID_SPACING * 0.55
			var spot := base + jitter
			if inner.has_point(spot):
				continue
			if not definition.surroundings_town_sides.has(_world_side(spot, map_size)):
				continue
			if _hash01(gx, gy, definition.seed + 3511) > TOWN_KEEP_RATIO:
				continue
			var width := 2.6 + _hash01(gx, gy, definition.seed + 3607) * 2.6
			var depth := 2.2 + _hash01(gx, gy, definition.seed + 3701) * 2.0
			var body_height := 1.7 + _hash01(gx, gy, definition.seed + 3803) * 1.3
			var yaw := (_hash01(gx, gy, definition.seed + 3907) - 0.5) * 0.24
			var body_basis := Basis(Vector3.UP, yaw).scaled(Vector3(width, body_height, depth))
			bodies.append(Transform3D(body_basis, Vector3(spot.x, body_height * 0.5, spot.y)))
			var tone := 0.8 + _hash01(gx, gy, definition.seed + 4001) * 0.3
			body_colors.append(Color(tone, tone * 0.97, tone * 0.9))
			var rise := depth * (0.42 + _hash01(gx, gy, definition.seed + 4111) * 0.14)
			var roof_basis := Basis(Vector3.UP, yaw).scaled(Vector3(width + 0.25, rise, depth + 0.25))
			roofs.append(Transform3D(roof_basis, Vector3(spot.x, body_height, spot.y)))
			var warmth := 0.72 + _hash01(gx, gy, definition.seed + 4211) * 0.4
			roof_colors.append(Color(warmth, warmth * 0.86, warmth * 0.8))

	var root := Node3D.new()
	root.name = "TownSilhouette"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3.ONE
	root.add_child(_multi_mesh("TownBodies", body_mesh, bodies, body_colors, MapViewMaterials.role(&"plaster"), Vector3.ZERO))
	root.add_child(_multi_mesh("TownRoofs", _unit_roof_prism(), roofs, roof_colors, _role_material(&"roof"), Vector3.ZERO))
	return root


## Unit triangular prism (1 x 1 base, ridge along x at y = 1) scaled per town
## silhouette instance.
static func _unit_roof_prism() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.5, 0.0, -0.5)
	var b := Vector3(0.5, 0.0, -0.5)
	var c := Vector3(0.5, 0.0, 0.5)
	var d := Vector3(-0.5, 0.0, 0.5)
	var r0 := Vector3(-0.5, 1.0, 0.0)
	var r1 := Vector3(0.5, 1.0, 0.0)
	_add_roof_quad(surface, a, b, r1, r0, Vector3(0.0, 0.5, -1.0).normalized())
	_add_roof_quad(surface, r0, r1, c, d, Vector3(0.0, 0.5, 1.0).normalized())
	_add_roof_triangle(surface, a, r0, d, Vector3.LEFT)
	_add_roof_triangle(surface, b, c, r1, Vector3.RIGHT)
	return surface.commit()


static func _placed(spot: Vector2, scale: float, lift: Vector3, yaw: float) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	return Transform3D(basis, Vector3(spot.x, 0.0, spot.y) + lift)


## Three stacked, slightly offset cone tiers with a small top spike: a spruce
## silhouette with layered skirts instead of a single flat cone. Local y spans
## 0 (skirt) to about 2.9 (tip).
static func _spruce_canopy_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := [
		[0.95, 0.0, 1.2],
		[0.74, 0.7, 1.1],
		[0.52, 1.4, 1.0],
		[0.28, 2.1, 0.8],
	]
	for tier_index in tiers.size():
		var tier: Array = tiers[tier_index]
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = tier[0]
		cone.height = tier[2]
		cone.radial_segments = 9
		cone.rings = 1
		var offset := Vector3(
			(_hash01(tier_index, 1, 97) - 0.5) * 0.12,
			float(tier[1]) + float(tier[2]) * 0.5,
			(_hash01(tier_index, 5, 131) - 0.5) * 0.12
		)
		surface.append_from(cone, 0, Transform3D(Basis.IDENTITY, offset))
	return surface.commit()


## Broadleaf canopy: several overlapping lobes merged into one lumpy crown
## centered near the local origin, replacing the single smooth sphere.
static func _leaf_canopy_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lobes := [
		[Vector3(0.0, 0.1, 0.0), 0.72],
		[Vector3(0.42, -0.08, 0.14), 0.5],
		[Vector3(-0.38, -0.02, 0.3), 0.54],
		[Vector3(0.08, 0.42, -0.3), 0.5],
		[Vector3(-0.12, 0.34, 0.34), 0.46],
		[Vector3(0.16, -0.18, -0.4), 0.48],
	]
	for lobe: Array in lobes:
		var sphere := SphereMesh.new()
		sphere.radius = lobe[1]
		sphere.height = float(lobe[1]) * 1.8
		sphere.radial_segments = 10
		sphere.rings = 6
		surface.append_from(sphere, 0, Transform3D(Basis.IDENTITY, lobe[0]))
	return surface.commit()


static func _scatter_transform(field: Dictionary, x: int, y: int, noise_seed: int, scale_min: float, scale_max: float) -> Transform3D:
	var offset := Vector2(
		_hash01(x, y, noise_seed + 7) * 0.9 + 0.05,
		_hash01(x, y, noise_seed + 13) * 0.9 + 0.05
	)
	var scale := scale_min + _hash01(x, y, noise_seed + 29) * (scale_max - scale_min)
	var yaw := _hash01(x, y, noise_seed + 41) * TAU
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	var spot := Vector2(float(x) + offset.x, float(y) + offset.y)
	return Transform3D(basis, Vector3(spot.x, _field_height(field, spot), spot.y))


static func _multi_mesh(
	name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	colors: Array[Color],
	material: Material,
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


## Emits the subpatches visually assigned to one terrain. Every subpatch is
## still emitted exactly once, but its identity comes from a smoothly warped
## lookup so a grid-authored corner does not have to render as a square corner.
static func _add_cell_quad(
	surface: SurfaceTool,
	field: Dictionary,
	grid: MapTerrainGrid,
	terrain_id: StringName,
	x: int,
	y: int,
	noise_seed: int,
	tone: float = 1.0
) -> void:
	var columns: int = field["vertex_columns"]
	var positions: PackedVector3Array = field["positions"]
	var normals: PackedVector3Array = field["normals"]
	var origin_x := x * TERRAIN_SUBDIVISIONS
	var origin_y := y * TERRAIN_SUBDIVISIONS
	for patch_y in TERRAIN_SUBDIVISIONS:
		for patch_x in TERRAIN_SUBDIVISIONS:
			if _visual_patch_terrain(grid, x, y, patch_x, patch_y, noise_seed) != terrain_id:
				continue
			var vertex_x := origin_x + patch_x
			var vertex_y := origin_y + patch_y
			var indices := [
				vertex_y * columns + vertex_x,
				vertex_y * columns + vertex_x + 1,
				(vertex_y + 1) * columns + vertex_x + 1,
				(vertex_y + 1) * columns + vertex_x,
			]
			for index in [0, 1, 2, 0, 2, 3]:
				var vertex := positions[indices[index]]
				surface.set_normal(normals[indices[index]])
				surface.set_uv(Vector2(vertex.x, vertex.z) / MapViewMaterials.TERRAIN_TEXTURE_WORLD_SIZE)
				surface.set_color(Color(tone, tone, tone))
				surface.add_vertex(vertex)


## Smoothly displaces only the visual material lookup. Geometry, collision,
## navigation, height pads, and deterministic definition fingerprints remain
## tied to the authored logic cell.
static func _visual_patch_terrain(
	grid: MapTerrainGrid,
	x: int,
	y: int,
	patch_x: int,
	patch_y: int,
	noise_seed: int
) -> StringName:
	var center := Vector2(
		float(x) + (float(patch_x) + 0.5) / float(TERRAIN_SUBDIVISIONS),
		float(y) + (float(patch_y) + 0.5) / float(TERRAIN_SUBDIVISIONS)
	)
	var warp := Vector2(
		_value_noise(center / 2.4, noise_seed + 12101) - 0.5,
		_value_noise(center / 2.4, noise_seed + 12703) - 0.5
	) * VISUAL_EDGE_WARP * 2.0
	var sample := center + warp
	sample.x = clampf(sample.x, 0.0, float(grid.size_cells.x) - 0.001)
	sample.y = clampf(sample.y, 0.0, float(grid.size_cells.y) - 0.001)
	return grid.get_terrain(Vector2i(floori(sample.x), floori(sample.y)))


## Every house earns a stone chimney near one ridge end with a slow smoke
## plume: deterministic per building id, view-only, and the cheapest signal
## that somebody actually lives here.
static func _add_chimney(root: Node3D, building: Dictionary, size: Vector2, wall_height: float, ridge_along_x: bool) -> void:
	var rise := ((size.y if ridge_along_x else size.x) * 0.5 + ROOF_OVERHANG) * ROOF_PITCH
	var along := ((size.x if ridge_along_x else size.y) * 0.5 - CHIMNEY_SIZE) * 0.62
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
static func _gabled_roof_mesh(base: Vector2, ridge_along_x: bool = true) -> ArrayMesh:
	var half_w := base.x * 0.5 + ROOF_OVERHANG
	var half_d := base.y * 0.5 + ROOF_OVERHANG
	var narrow := half_d if ridge_along_x else half_w
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
