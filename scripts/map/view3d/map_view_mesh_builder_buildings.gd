class_name MapViewMeshBuilderBuildings
extends RefCounted

## Building wall, roof, and facade mesh generation.

## Interior wall dressing is intentionally shallow: enough relief for warm
## directional light without narrowing navigation or changing collision.
const INTERIOR_WALL_RELIEF := 0.025
const INTERIOR_WALL_DRESSING_DEPTH := 0.075
const INTERIOR_WALL_SOOT_DEPTH := 0.03
const INTERIOR_WALL_PLINTH_HEIGHT := 0.48
const INTERIOR_WALL_RAIL_HEIGHT := 1.42
const INTERIOR_WALL_UPPER_RAIL_DROP := 0.18
const INTERIOR_WALL_TIMBER_WIDTH := 0.11
const INTERIOR_WALL_POST_SPACING := 2.25

static func build_building(building: Dictionary, cell_size: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Building_%s" % String(building["id"])
	var scale := MapViewBridge.world_scale(cell_size)
	var footprint: Rect2 = building["footprint"]
	var size := footprint.size * scale
	var kind: StringName = building.get("kind", MapTypes.BUILDING_KIND_HOUSE)
	var authored_height_px := float(building.get("wall_height", MapViewMeshBuilderConfig.DEFAULT_WALL_HEIGHT_PX.get(kind, 64.0)))
	var render_height_px := MapTypes.resolved_wall_height_px(building)
	var height := render_height_px * scale
	var center := footprint.get_center() * scale
	root.position = Vector3(center.x, 0.0, center.y)

	var wall_color := Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR))
	var fortification := kind == MapTypes.BUILDING_KIND_WALL and authored_height_px >= MapViewMeshBuilderConfig.BATTLEMENT_MIN_HEIGHT_PX
	var footprint_aspect := minf(size.x, size.y) / maxf(size.x, size.y)
	# `tower=true` in the map source forces the round-tower dressing for
	# large-footprint fortifications; the footprint heuristic stays as the
	# fallback for maps authored before the explicit flag existed.
	var tower := fortification and (
		bool(building.get("tower", false))
		or (
			size.x <= MapViewMeshBuilderConfig.TOWER_MAX_FOOTPRINT
			and size.y <= MapViewMeshBuilderConfig.TOWER_MAX_FOOTPRINT
			and footprint_aspect >= MapViewMeshBuilderConfig.TOWER_MIN_ASPECT
		)
	)

	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	if tower:
		# Tallinn-style round tower: limestone drum instead of a square prism.
		var drum := CylinderMesh.new()
		drum.top_radius = minf(size.x, size.y) * MapViewMeshBuilderConfig.TOWER_RADIUS_FACTOR
		drum.bottom_radius = drum.top_radius * 1.06
		drum.height = height
		drum.radial_segments = 18
		walls.mesh = drum
		walls.material_override = MapViewMaterials.wall_surface_for_size(
			&"limestone",
			wall_color.lightened(0.08),
			Vector3(TAU * drum.top_radius, height, TAU * drum.top_radius)
		)
	else:
		var wall_mesh := BoxMesh.new()
		var mesh_size := Vector3(size.x, height, size.y)
		if fortification:
			mesh_size = MapViewMeshBuilderBuildings.sealed_wall_size(mesh_size)
		wall_mesh.size = mesh_size
		walls.mesh = wall_mesh
		if kind == MapTypes.BUILDING_KIND_HOUSE:
			walls.material_override = house_wall_material(building, wall_color, wall_mesh.size)
		elif kind == MapTypes.BUILDING_KIND_WALL:
			walls.material_override = MapViewMaterials.wall_surface_triplanar(&"limestone", wall_color)
		elif kind == MapTypes.BUILDING_KIND_INTERIOR_WALL:
			walls.material_override = interior_wall_material(building, wall_color)
		else:
			walls.material_override = MapViewMaterials.wall_for_size(wall_color, wall_mesh.size)
	walls.position = Vector3(0.0, height * 0.5, 0.0)
	root.add_child(walls)

	if kind == MapTypes.BUILDING_KIND_HOUSE:
		var along_ridge_x := ridge_along_x(building, size)
		var roof := MeshInstance3D.new()
		roof.name = "Roof"
		roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(size, along_ridge_x)
		roof.position = Vector3(0.0, height, 0.0)
		roof.material_override = house_roof_material(building)
		root.add_child(roof)
		add_chimney(root, building, size, height, along_ridge_x)
		add_house_structure(root, building, size, height)
		add_house_facade(root, building, size, height)
		add_window_lights(root, building["id"])
	elif kind == MapTypes.BUILDING_KIND_INTERIOR_WALL:
		add_interior_wall_structure(root, building, size, height)
	elif tower:
		var radius := minf(size.x, size.y) * MapViewMeshBuilderConfig.TOWER_RADIUS_FACTOR
		# The stone overhang ring doubles as the flat cap the view contract
		# expects on every wall-kind building.
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
		add_tower_roof(root, radius, height)
		if authored_height_px >= MapViewMeshBuilderConfig.TOWER_MIN_HEIGHT_PX:
			add_tower_slits(root, radius, height)
	elif kind != MapTypes.BUILDING_KIND_INTERIOR_WALL:
		# Interior maps close with a shared ceiling shell; per-segment caps would
		# z-fight and still leave the room open to the sky in first-person.
		var cap := MeshInstance3D.new()
		cap.name = "Cap"
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(size.x + MapViewMeshBuilderConfig.CAP_OVERHANG * 2.0, MapViewMeshBuilderConfig.CAP_HEIGHT, size.y + MapViewMeshBuilderConfig.CAP_OVERHANG * 2.0)
		cap.mesh = cap_mesh
		cap.position = Vector3(0.0, height + MapViewMeshBuilderConfig.CAP_HEIGHT * 0.5, 0.0)
		if fortification:
			# Covered wall walks rest on a timber deck, not a stone coping slab.
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
			MapViewMeshBuilderBuildings.add_battlements(root, building, size, height)
			add_wall_walk_roof(root, size, height)
	return root
## Period interior treatment: lime plaster over a timber structure, with a local
## smoke wash in the forge bay. Object-space mapping keeps the finish consistent
## across north/south and east/west wall runs.
static func interior_wall_material(building: Dictionary, wall_color: Color) -> StandardMaterial3D:
	var family: StringName = building.get("wall_material", &"plaster")
	var material := MapViewMaterials.wall_surface_triplanar(&"plaster", wall_color)
	if family == &"smoked_plaster":
		material.roughness = 0.96
	return material


## A stone plinth protects lime plaster from damp and forge debris, while exposed
## oak posts and rails reveal the late-medieval craft dwelling's construction.
## This is view-only dressing and deliberately leaves map collision untouched.
static func add_interior_wall_structure(
	root: Node3D,
	building: Dictionary,
	size: Vector2,
	height: float
) -> void:
	var along_x := size.x >= size.y
	var run_length := size.x if along_x else size.y
	var wall_depth := size.y if along_x else size.x
	var face_offset := wall_depth * 0.5 + INTERIOR_WALL_RELIEF
	var plinth_height := minf(INTERIOR_WALL_PLINTH_HEIGHT, height * 0.22)
	var rail_height := minf(INTERIOR_WALL_RAIL_HEIGHT, height * 0.46)
	var upper_rail_y := maxf(height - INTERIOR_WALL_UPPER_RAIL_DROP, rail_height)
	var faces: Array[StringName] = []
	if along_x:
		faces.assign([&"south", &"north"])
	else:
		faces.assign([&"east", &"west"])
	for face in faces:
		facade_box(
			root,
			"StonePlinth_%s" % String(face),
			Vector3(run_length, plinth_height, INTERIOR_WALL_DRESSING_DEPTH),
			0.0,
			plinth_height * 0.5,
			face,
			face_offset,
			&"stone"
		)
		for rail in [
			["MidRail", rail_height],
			["UpperRail", upper_rail_y],
		]:
			facade_box(
				root,
				"%s_%s" % [rail[0], String(face)],
				Vector3(run_length, INTERIOR_WALL_TIMBER_WIDTH, INTERIOR_WALL_DRESSING_DEPTH),
				0.0,
				float(rail[1]),
				face,
				face_offset + 0.01,
				&"timber"
			)
		var post_count := maxi(2, ceili(run_length / INTERIOR_WALL_POST_SPACING) + 1)
		for index in post_count:
			var along := lerpf(-run_length * 0.5, run_length * 0.5, float(index) / float(post_count - 1))
			facade_box(
				root,
				"Post_%s_%02d" % [String(face), index],
				Vector3(INTERIOR_WALL_TIMBER_WIDTH, height, INTERIOR_WALL_DRESSING_DEPTH),
				along,
				height * 0.5,
				face,
				face_offset + 0.02,
				&"timber"
			)

	if StringName(building.get("wall_material", &"")) == &"smoked_plaster":
		add_forge_soot_wash(root, size, height, along_x, faces, face_offset)


## Smoke staining reads as one continuous band collected under the ceiling with
## a few streaks licking down the plaster - detached dark panels read as black
## windows from first-person. Low relief avoids z-fighting with lime plaster.
static func add_forge_soot_wash(
	root: Node3D,
	size: Vector2,
	height: float,
	along_x: bool,
	faces: Array[StringName],
	face_offset: float
) -> void:
	var run_length := size.x if along_x else size.y
	var band_height := clampf(height * 0.16, 0.35, 0.62)
	for face in faces:
		facade_box(
			root,
			"Soot_%s_00" % String(face),
			Vector3(run_length, band_height, INTERIOR_WALL_SOOT_DEPTH),
			0.0,
			height - band_height * 0.5,
			face,
			face_offset + 0.015,
			&"soot"
		)




## Visible construction material per house. Authors declare it per style via
## `wall_material`; undeclared houses fall back to a deterministic id-hash mix
## weighted for 1343 Reval, where the lower town was still mostly log-built,
## limestone belonged to wealthy merchants, and brick stayed rare.


static func house_style(building: Dictionary) -> StringName:
	match StringName(building.get("wall_material", &"")):
		&"plaster", &"timber":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER
		&"brick":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK
		&"plank":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_PLANK
		&"log":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_LOG
		&"limestone", &"stone":
			return MapViewMeshBuilderConfig.HOUSE_STYLE_STONE
	var roll := absi(String(building["id"]).hash()) % 10
	if roll < 4:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_LOG
	if roll < 6:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER
	if roll < 8:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_PLANK
	if roll < 9:
		return MapViewMeshBuilderConfig.HOUSE_STYLE_STONE
	return MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK




static func house_wall_material(building: Dictionary, wall_color: Color, size: Vector3) -> StandardMaterial3D:
	match house_style(building):
		MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER:
			return MapViewMaterials.wall_surface_for_size(&"plaster", wall_color.lerp(MapViewMeshBuilderConfig.PLASTER_TONE, 0.55), size)
		MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK:
			return MapViewMaterials.wall_surface_for_size(&"brick", wall_color.lerp(MapViewMeshBuilderConfig.BRICK_TONE, 0.6), size)
		MapViewMeshBuilderConfig.HOUSE_STYLE_LOG:
			return MapViewMaterials.wall_surface_for_size(&"log", wall_color.lerp(MapViewMeshBuilderConfig.LOG_TONE, 0.45), size)
		MapViewMeshBuilderConfig.HOUSE_STYLE_STONE:
			return MapViewMaterials.wall_surface_for_size(&"limestone", wall_color.lerp(MapViewMeshBuilderConfig.LIMESTONE_TONE, 0.5), size)
		_:
			return MapViewMaterials.wall_surface_for_size(&"plank", wall_color, size)


## Roof cover per house: declared `roof_material` wins; the fallback follows
## the wall material the way period fire practice did - ceramic tile caps stone
## and brick houses, most log dwellings carry thatch, the rest wooden shingle.


static func roof_style(building: Dictionary) -> StringName:
	match StringName(building.get("roof_material", &"")):
		&"tile":
			return MapViewMeshBuilderConfig.ROOF_STYLE_TILE
		&"shingle":
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE
		&"thatch", &"straw":
			return MapViewMeshBuilderConfig.ROOF_STYLE_THATCH
	match house_style(building):
		MapViewMeshBuilderConfig.HOUSE_STYLE_STONE, MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK:
			return MapViewMeshBuilderConfig.ROOF_STYLE_TILE
		MapViewMeshBuilderConfig.HOUSE_STYLE_LOG:
			if absi(String(building["id"]).hash() / 10) % 3 < 2:
				return MapViewMeshBuilderConfig.ROOF_STYLE_THATCH
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE
		_:
			return MapViewMeshBuilderConfig.ROOF_STYLE_SHINGLE


static func house_roof_material(building: Dictionary) -> StandardMaterial3D:
	var color := Color(building.get("roof_color", MapViewMeshBuilderConfig.DEFAULT_ROOF_COLOR))
	var style := roof_style(building)
	if style == MapViewMeshBuilderConfig.ROOF_STYLE_THATCH and not building.has("roof_material"):
		# Fallback thatch inherits tile-era dark browns; pull them toward straw.
		color = color.lerp(MapViewMeshBuilderConfig.THATCH_TONE, 0.55)
	return MapViewMaterials.roof_surface(style, color)


## Structural dressing that gives every house physical depth: a stone plinth,
## corner posts, and (for timber-frame houses) exposed beams with braces.


static func add_house_structure(root: Node3D, building: Dictionary, size: Vector2, height: float) -> void:
	var style := house_style(building)
	MapViewMeshBuilderPrimitives.box(
		root,
		"Plinth",
		Vector3(size.x + 0.12, MapViewMeshBuilderConfig.PLINTH_HEIGHT, size.y + 0.12),
		Vector3(0.0, MapViewMeshBuilderConfig.PLINTH_HEIGHT * 0.5, 0.0),
		&"stone"
	)
	# Masonry houses carry only the plinth; corner posts on log houses stand in
	# for the crossed log ends of Blockbau corners.
	if style == MapViewMeshBuilderConfig.HOUSE_STYLE_BRICK or style == MapViewMeshBuilderConfig.HOUSE_STYLE_STONE:
		return
	var half := size * 0.5
	var beam := MapViewMeshBuilderConfig.FRAME_BEAM_THICKNESS
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		MapViewMeshBuilderPrimitives.box(
			root,
			"CornerPost_%d_%d" % [int(corner.x), int(corner.y)],
			Vector3(beam, height, beam),
			Vector3(corner.x * half.x, height * 0.5, corner.y * half.y),
			&"timber"
		)
	if style != MapViewMeshBuilderConfig.HOUSE_STYLE_TIMBER:
		return
	# Horizontal beams at the sill, storey, and top plate on all facades, plus
	# diagonal braces flanking the storey line on the long facades.
	var beam_heights := [MapViewMeshBuilderConfig.PLINTH_HEIGHT + beam * 0.5, height * 0.55, height - beam * 0.5]
	for beam_y: float in beam_heights:
		MapViewMeshBuilderPrimitives.box(root, "BeamNS%d" % int(beam_y * 100.0), Vector3(size.x + beam, beam, beam), Vector3(0.0, beam_y, half.y), &"timber")
		MapViewMeshBuilderPrimitives.box(root, "BeamNS%dB" % int(beam_y * 100.0), Vector3(size.x + beam, beam, beam), Vector3(0.0, beam_y, -half.y), &"timber")
		MapViewMeshBuilderPrimitives.box(root, "BeamEW%d" % int(beam_y * 100.0), Vector3(beam, beam, size.y + beam), Vector3(half.x, beam_y, 0.0), &"timber")
		MapViewMeshBuilderPrimitives.box(root, "BeamEW%dB" % int(beam_y * 100.0), Vector3(beam, beam, size.y + beam), Vector3(-half.x, beam_y, 0.0), &"timber")
	var brace_length := (height * 0.55 - MapViewMeshBuilderConfig.PLINTH_HEIGHT) * 1.35
	var along_x := size.x >= size.y
	var brace_offset := (size.x if along_x else size.y) * 0.28
	for flip in [-1.0, 1.0]:
		var brace := MeshInstance3D.new()
		brace.name = "Brace%d" % int(flip)
		var brace_mesh := BoxMesh.new()
		brace_mesh.size = Vector3(brace_length, beam * 0.9, beam * 0.6)
		brace.mesh = brace_mesh
		var mid_y := (MapViewMeshBuilderConfig.PLINTH_HEIGHT + height * 0.55) * 0.5
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


static func add_tower_roof(root: Node3D, radius: float, height: float) -> void:
	var roof_radius := radius + 0.34
	var roof := MeshInstance3D.new()
	roof.name = "TowerRoof"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = roof_radius
	cone.height = roof_radius * MapViewMeshBuilderConfig.TOWER_ROOF_PITCH
	cone.radial_segments = 18
	roof.mesh = cone
	roof.position = Vector3(0.0, height + MapViewMeshBuilderConfig.CAP_HEIGHT * 2.0 + cone.height * 0.5, 0.0)
	roof.material_override = MapViewMaterials.roof(MapViewMeshBuilderConfig.TOWER_ROOF_COLOR)
	root.add_child(roof)
	var finial := MeshInstance3D.new()
	finial.name = "Finial"
	var knob := SphereMesh.new()
	knob.radius = 0.09
	knob.height = 0.18
	finial.mesh = knob
	finial.position = Vector3(0.0, height + MapViewMeshBuilderConfig.CAP_HEIGHT * 2.0 + cone.height + 0.06, 0.0)
	finial.material_override = MapViewMaterials.role(&"metal")
	root.add_child(finial)




static func add_tower_slits(root: Node3D, radius: float, height: float) -> void:
	var slit_center_y := height * 0.62
	var index := 0
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var outward := Vector3(sin(angle), 0.0, cos(angle))
		var frame_size := Vector3(
			MapViewMeshBuilderConfig.ARROW_SLIT_SIZE.x + MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_PAD.x * 2.0,
			MapViewMeshBuilderConfig.ARROW_SLIT_SIZE.y + MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_PAD.y * 2.0,
			MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_DEPTH
		)
		var frame := MeshInstance3D.new()
		frame.name = "SlitFrame%d" % index
		var frame_mesh := BoxMesh.new()
		frame_mesh.size = frame_size
		frame.mesh = frame_mesh
		frame.position = outward * (radius + MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_DEPTH * 0.5)
		frame.position.y = slit_center_y
		frame.rotation.y = angle
		frame.material_override = MapViewMaterials.wall_surface_for_size(
			&"brick",
			MapViewMeshBuilderConfig.BRICK_TONE,
			frame_size
		)
		root.add_child(frame)

		var slit := MeshInstance3D.new()
		slit.name = "Slit%d" % index
		var mesh := BoxMesh.new()
		mesh.size = MapViewMeshBuilderConfig.ARROW_SLIT_SIZE
		slit.mesh = mesh
		slit.position = outward * (radius + MapViewMeshBuilderConfig.ARROW_SLIT_FRAME_DEPTH + MapViewMeshBuilderConfig.ARROW_SLIT_SIZE.z * 0.5 - 0.01)
		slit.position.y = slit_center_y
		slit.rotation.y = angle
		# Deep void, not glazed house windows - arrow loops read as dark openings.
		slit.material_override = MapViewMaterials.role(&"ink")
		root.add_child(slit)
		index += 1


## Red saddle roof hovering over the wall walk on timber posts, with the
## battlements still reading underneath - the covered parapet look of the
## surviving Tallinn town wall.


static func add_wall_walk_roof(root: Node3D, size: Vector2, height: float) -> void:
	var along_x := size.x >= size.y
	var length := (size.x if along_x else size.y) + 0.3
	var span := (size.y if along_x else size.x) + 0.7
	var base_y := height + MapViewMeshBuilderConfig.CAP_HEIGHT + MapViewMeshBuilderConfig.WALL_WALK_ROOF_LIFT
	var roof := MeshInstance3D.new()
	roof.name = "WalkRoof"
	roof.mesh = MapViewMeshBuilderPrimitives.gabled_roof_mesh(
		Vector2(length, span) if along_x else Vector2(span, length),
		along_x
	)
	roof.position = Vector3(0.0, base_y, 0.0)
	roof.material_override = MapViewMaterials.roof(MapViewMeshBuilderConfig.WALL_ROOF_COLOR)
	root.add_child(roof)
	var post_count := maxi(2, int(length / 2.2))
	var post_height := MapViewMeshBuilderConfig.WALL_WALK_ROOF_LIFT + 0.1
	for post_index in post_count + 1:
		var along := (float(post_index) / float(post_count) - 0.5) * (length - 0.4)
		for side in [-1.0, 1.0]:
			var offset: float = side * (span * 0.5 - 0.35)
			var position := Vector3(along, height + MapViewMeshBuilderConfig.CAP_HEIGHT + post_height * 0.5, offset)
			if not along_x:
				position = Vector3(offset, position.y, along)
			MapViewMeshBuilderPrimitives.box(
				root,
				"RoofPost%d_%d" % [post_index, int(side)],
				Vector3(0.09, post_height, 0.09),
				position,
				&"timber"
			)
	return


## Ridge orientation: longest footprint axis unless the definition pins it via
## "ridge_axis" (&"x"/&"z") - Hanseatic houses turn the gable end to the street.


static func ridge_along_x(building: Dictionary, size: Vector2) -> bool:
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


static func add_house_facade(root: Node3D, building: Dictionary, size: Vector2, height: float) -> void:
	var declared: StringName = building.get("door_side", &"south")
	var side := declared if declared != &"none" else &"south"
	var along_x := side == &"north" or side == &"south"
	var facade_length := size.x if along_x else size.y
	var face_offset := (size.y if along_x else size.x) * 0.5
	var id_hash := String(building["id"]).hash()

	var door_height := minf(MapViewMeshBuilderConfig.HOUSE_DOOR_HEIGHT, height - 0.2)
	var door_along := (float(id_hash % 100) / 99.0 - 0.5) * maxf(facade_length - MapViewMeshBuilderConfig.HOUSE_DOOR_WIDTH - 1.2, 0.0) * 0.5
	if declared != &"none":
		facade_box(root, "Door", Vector3(MapViewMeshBuilderConfig.HOUSE_DOOR_WIDTH, door_height, MapViewMeshBuilderConfig.DOOR_THICKNESS), door_along, door_height * 0.5, side, face_offset, &"wood")
		facade_box(root, "DoorLintel", Vector3(MapViewMeshBuilderConfig.HOUSE_DOOR_WIDTH + 0.24, MapViewMeshBuilderConfig.DOOR_FRAME_THICKNESS, MapViewMeshBuilderConfig.DOOR_THICKNESS + 0.02), door_along, door_height + MapViewMeshBuilderConfig.DOOR_FRAME_THICKNESS * 0.5, side, face_offset, &"timber")
		facade_box(root, "DoorStep", Vector3(MapViewMeshBuilderConfig.HOUSE_DOOR_WIDTH + 0.2, 0.09, 0.34), door_along, 0.045, side, face_offset, &"stone")

	var window_count := clampi(int(facade_length / MapViewMeshBuilderConfig.HOUSE_WINDOW_SPACING), 1, 3)
	var window_sill := minf(MapViewMeshBuilderConfig.HOUSE_WINDOW_SILL, height - MapViewMeshBuilderConfig.HOUSE_WINDOW_SIZE.y - 0.15)
	var index := 0
	var faces: Array[StringName] = [side, opposite_side(side)]
	for face in faces:
		for window in window_count:
			var along := (float(window + 1) / float(window_count + 1) - 0.5) * facade_length
			# Keep the front windows clear of the door.
			if face == side and absf(along - door_along) < (MapViewMeshBuilderConfig.HOUSE_DOOR_WIDTH + MapViewMeshBuilderConfig.HOUSE_WINDOW_SIZE.x) * 0.62:
				continue
			add_house_window(root, index, along, window_sill, face, face_offset)
			index += 1


## Shuttered house window: outer timber frame, recessed glazed pane, inner
## mullions, plus lintel and sill so the opening reads as carpentry not paint.


static func add_house_window(root: Node3D, index: int, along: float, window_sill: float, face: StringName, face_offset: float) -> void:
	var w := MapViewMeshBuilderConfig.HOUSE_WINDOW_SIZE.x
	var h := MapViewMeshBuilderConfig.HOUSE_WINDOW_SIZE.y
	var fw := MapViewMeshBuilderConfig.HOUSE_WINDOW_FRAME
	var cy := window_sill + h * 0.5
	var glass_w := w - fw * 2.0
	var glass_h := h - fw * 2.0

	# Outer frame wraps the opening and sits proud of the wall.
	facade_box(root, "WindowFrameL%d" % index, Vector3(fw, h, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH), along - w * 0.5 + fw * 0.5, cy, face, face_offset, &"timber")
	facade_box(root, "WindowFrameR%d" % index, Vector3(fw, h, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH), along + w * 0.5 - fw * 0.5, cy, face, face_offset, &"timber")
	facade_box(root, "WindowFrameT%d" % index, Vector3(w, fw, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH), along, window_sill + h - fw * 0.5, face, face_offset, &"timber")
	facade_box(root, "WindowFrameB%d" % index, Vector3(w, fw, MapViewMeshBuilderConfig.HOUSE_WINDOW_OUTER_DEPTH), along, window_sill + fw * 0.5, face, face_offset, &"timber")

	# Glazed pane sits recessed between the outer frame and inner mullions.
	facade_box(root, "Window%d" % index, Vector3(glass_w, glass_h, MapViewMeshBuilderConfig.HOUSE_WINDOW_GLASS_DEPTH), along, cy, face, face_offset, &"window")

	# Inner cross mullions divide the pane like a simple leaded casement.
	facade_box(root, "WindowMullionV%d" % index, Vector3(MapViewMeshBuilderConfig.HOUSE_WINDOW_MULLION, glass_h, MapViewMeshBuilderConfig.HOUSE_WINDOW_MULLION_DEPTH), along, cy, face, face_offset, &"wood")
	facade_box(root, "WindowMullionH%d" % index, Vector3(glass_w, MapViewMeshBuilderConfig.HOUSE_WINDOW_MULLION, MapViewMeshBuilderConfig.HOUSE_WINDOW_MULLION_DEPTH), along, cy, face, face_offset, &"wood")

	facade_box(root, "WindowLintel%d" % index, Vector3(w + 0.18, 0.1, 0.09), along, window_sill + h + 0.05, face, face_offset, &"timber")
	facade_box(root, "WindowSill%d" % index, Vector3(w + 0.18, 0.08, 0.12), along, window_sill - 0.04, face, face_offset, &"timber")




static func opposite_side(side: StringName) -> StringName:
	match side:
		&"north":
			return &"south"
		&"south":
			return &"north"
		&"east":
			return &"west"
	return &"east"


## Places a box flush against the given facade, protruding MapViewMeshBuilderConfig.FACADE_RELIEF so it
## reads in the dimetric light.


static func facade_box(root: Node3D, name: String, box_size: Vector3, along: float, center_y: float, side: StringName, face_offset: float, role: StringName) -> void:
	var out := face_offset + box_size.z * 0.5 - MapViewMeshBuilderConfig.FACADE_RELIEF + 0.06
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
	MapViewMeshBuilderPrimitives.box(root, name, size, position, role)


## Crenellated parapet along the cap of tall fortification walls and towers.


static func add_battlements(root: Node3D, building: Dictionary, size: Vector2, height: float) -> void:
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
		var count := maxi(2, int(length / MapViewMeshBuilderConfig.MERLON_SPACING))
		for step in count + 1:
			var origin := from.lerp(to, float(step) / float(count))
			origin.y = height + MapViewMeshBuilderConfig.CAP_HEIGHT + MapViewMeshBuilderConfig.MERLON_SIZE.y * 0.5
			transforms.append(Transform3D(Basis.IDENTITY, origin))
			colors.append(Color.WHITE)
	var merlon_mesh := BoxMesh.new()
	merlon_mesh.size = MapViewMeshBuilderConfig.MERLON_SIZE
	var merlons := MapViewMeshBuilderPrimitives.multi_mesh(
		"Merlons",
		merlon_mesh,
		transforms,
		colors,
		MapViewMaterials.wall_surface(&"limestone", Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR)).lightened(0.12)),
		Vector3.ZERO
	)
	root.add_child(merlons)


## Resolves the authored interior shell height for window framing.


static func sealed_wall_size(size: Vector3) -> Vector3:
	if size.x <= size.z:
		return Vector3(size.x + MapViewMeshBuilderConfig.WALL_SEAL_OVERHANG * 2.0, size.y, size.z)
	return Vector3(size.x, size.y, size.z + MapViewMeshBuilderConfig.WALL_SEAL_OVERHANG * 2.0)


## District exits and gate passages render through view_landmarks instead of a
## second framed door floating in open ground.


static func add_chimney(root: Node3D, building: Dictionary, size: Vector2, wall_height: float, ridge_along_x: bool) -> void:
	var building_id: StringName = building["id"]
	var rise := ((size.y if ridge_along_x else size.x) * 0.5 + MapViewMeshBuilderConfig.ROOF_OVERHANG) * MapViewMeshBuilderConfig.ROOF_PITCH
	var along := ((size.x if ridge_along_x else size.y) * 0.5 - MapViewMeshBuilderConfig.CHIMNEY_SIZE) * 0.62
	if String(building_id).hash() % 2 == 0:
		along = -along
	var offset := Vector3(along, 0.0, 0.0) if ridge_along_x else Vector3(0.0, 0.0, along)
	var ridge_y := wall_height + rise
	var stack_bottom := ridge_y - MapViewMeshBuilderConfig.CHIMNEY_STACK_EMBED
	var stack_center_y := stack_bottom + MapViewMeshBuilderConfig.CHIMNEY_STACK_HEIGHT * 0.5
	var top := stack_bottom + MapViewMeshBuilderConfig.CHIMNEY_STACK_HEIGHT
	MapViewMeshBuilderPrimitives.add_chimney_stack(root, "Chimney", MapViewMeshBuilderConfig.CHIMNEY_SIZE, MapViewMeshBuilderConfig.CHIMNEY_STACK_HEIGHT, offset + Vector3(0.0, stack_center_y, 0.0))

	if ChimneySmoke3D.schedule_for(String(building_id).hash()) == ChimneySmoke3D.Schedule.NEVER:
		return
	var smoke: ChimneySmoke3D = MapViewMeshBuilderConfig.CHIMNEY_SMOKE_SCRIPT.new()
	smoke.position = offset + Vector3(0.0, top + 0.1, 0.0)
	smoke.configure(building_id)
	root.add_child(smoke)




static func add_window_lights(root: Node3D, building_id: StringName) -> void:
	var lights: BuildingWindowLights3D = MapViewMeshBuilderConfig.WINDOW_LIGHTS_SCRIPT.new()
	root.add_child(lights)
	lights.configure(building_id)


## Gabled roof over a rectangular footprint: ridge along the longer axis,
## rise proportional to the narrow span, small eave overhang.
