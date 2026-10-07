extends RefCounted

## Early Town Hall (Raekoda) as it stood in spring 1343, built on the primitive
## box mass. Sources: history/dossiers/topography/raekoja-plats-extents-1343.md
## and docs/HISTORICAL_AUDIT.md (H06). The hall is one storey of split grey
## limestone rubble with an attic storeroom under a tile roof. It has no arcade
## (1402-04), no upper council storey and no tower. Dressed stone is kept to the
## quoins, the portal and the window frames, the way local paekivi was laid.
##
## WHY the wear: the western core dates to the late 13th century, so in 1343 the
## hall is decades old. Rising damp, rain streaks under sills, eave soot, moss on
## the tiles and silvered shutters keep it from reading as a new build.
##
## The banners are the red field with a white cross: the Danish royal banner
## (Dannebrog, depicted in the Gelre Armorial) and the device Reval's own lesser
## arms derive from. Flying them on the council hall is a plausible game choice,
## labelled in docs/CANON.md.

const _BuildingMaterials := preload("res://scripts/map/view3d/map_view_building_materials.gd")

const PRIMITIVE := &"town_hall_1343"
## Pinned library stems. The hall's fabric is attested, so it is not rolled.
const WALL_STEM := "rubble_buff"
const ROOF_STEM := "tile_moss"
const TRIM_STEM := "ashlar_pale"
const TRIM_TINT := Color(0.96, 0.92, 0.84)
## Dressed faces are older and dirtier than the fresh-cut plate.
const TRIM_TONE := Color(0.72, 0.69, 0.63)
## Library tints only carry hue, so wear is applied as an explicit multiplier:
## paekivi dulls to a warm grey, and old tile loses its kiln orange to lichen,
## soot and dust.
const WALL_TONE := Color(0.9, 0.88, 0.84)
const ROOF_TONE := Color(0.74, 0.68, 0.62)
const GLASS_TINT := Color(0.17, 0.2, 0.18)
## Madder red and unbleached linen, both sun-faded.
const BANNER_RED := Color(0.55, 0.13, 0.1)
const BANNER_WHITE := Color(0.86, 0.82, 0.72)
const GRIME := Color(0.1, 0.09, 0.07)
## Keeps the overlay quads off the wall face without visible floating.
const DECAL_OFFSET := 0.015

static var _cache: Dictionary = {}


static func is_town_hall(building: Dictionary) -> bool:
	return StringName(building.get("primitive", &"")) == PRIMITIVE


static func wall_material(building: Dictionary, size: Vector3) -> StandardMaterial3D:
	var color := Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR))
	var material := _toned(
		_BuildingMaterials.library_surface_for_building(
			"town_hall_wall", building.get("id", &""), WALL_STEM, color
		),
		WALL_TONE
	)
	material.uv1_scale = _BuildingMaterials.library_box_uv_scale(WALL_STEM, size)
	return material


static func roof_material(building: Dictionary) -> StandardMaterial3D:
	var color := Color(building.get("roof_color", MapViewMeshBuilderConfig.DEFAULT_ROOF_COLOR))
	var material := _toned(
		_BuildingMaterials.library_surface_for_building(
			"town_hall_roof", building.get("id", &""), ROOF_STEM, color
		),
		ROOF_TONE
	)
	material.uv1_scale = _BuildingMaterials.library_world_uv_density(ROOF_STEM)
	return material


static func add_details(root: Node3D, building: Dictionary, size: Vector2, height: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = String(building.get("id", PRIMITIVE)).hash()
	var half_x := size.x * 0.5
	var half_z := size.y * 0.5
	var facade_z := -half_z
	var wall := wall_material(building, Vector3(size.x, height, size.y))

	_add_gables(root, size, height, wall)
	_add_plinth(root, size, wall)
	_add_quoins(root, size, height)
	_add_portal(root, facade_z)
	var glass_index := _add_market_windows(root, rng, half_x, height, facade_z)
	_add_rear_windows(root, rng, size, height, glass_index)
	_add_attic_hoist(root, size, height)
	_add_banners(root, size, height, facade_z)
	_add_weathering(root, rng, size, height)


## Stone gable ends. The generic roof closes its gables in tile at the verge,
## which on a limestone hall reads as a roof folded down the end wall. Each gable
## is a masonry prism from the wall line out past that tile face, sitting on a
## dressed gable course, with coping slabs along both rakes.
static func _add_gables(
	root: Node3D, size: Vector2, height: float, wall: StandardMaterial3D
) -> void:
	var half_x := size.x * 0.5
	var half_z := size.y * 0.5
	var overhang := MapViewMeshBuilderConfig.ROOF_OVERHANG
	var pitch := MapViewMeshBuilderConfig.ROOF_PITCH
	var eave_y := height + overhang * pitch
	var apex_y := height + (half_z + overhang) * pitch
	var gable_material := _triplanar(wall)
	var depth := overhang + 0.04
	for side: float in [-1.0, 1.0]:
		var suffix := "E" if side > 0.0 else "W"
		var inner_x := side * (half_x - 0.02)
		var outer_x := side * (half_x + depth)
		var outline: Array[Vector2] = [
			Vector2(-half_z, height),
			Vector2(half_z, height),
			Vector2(half_z, eave_y),
			Vector2(0.0, apex_y - 0.02),
			Vector2(-half_z, eave_y),
		]
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_normal(Vector3(side, 0.0, 0.0))
		for index in range(1, outline.size() - 1):
			for point: Vector2 in [outline[0], outline[index], outline[index + 1]]:
				surface.add_vertex(Vector3(outer_x, point.y, point.x))
		# Side faces between the wall line and the outer face.
		for index in outline.size():
			var a: Vector2 = outline[index]
			var b: Vector2 = outline[(index + 1) % outline.size()]
			var edge := b - a
			surface.set_normal(Vector3(0.0, -edge.x, edge.y).normalized())
			for point: Vector3 in [
				Vector3(inner_x, a.y, a.x),
				Vector3(outer_x, a.y, a.x),
				Vector3(outer_x, b.y, b.x),
				Vector3(inner_x, a.y, a.x),
				Vector3(outer_x, b.y, b.x),
				Vector3(inner_x, b.y, b.x),
			]:
				surface.add_vertex(point)
		var gable := MeshInstance3D.new()
		gable.name = "TownHallGable%s" % suffix
		gable.mesh = surface.commit()
		gable.material_override = gable_material
		root.add_child(gable)

		_stone(
			root,
			"TownHallGableCourse%s" % suffix,
			Vector3(depth + 0.06, 0.2, size.y + 0.1),
			Vector3(side * (half_x + depth * 0.5 - 0.01), height - 0.08, 0.0)
		)
		var rake_run := half_z + overhang
		var rake_length := sqrt(rake_run * rake_run + (apex_y - height) * (apex_y - height))
		var angle := atan2(apex_y - height, rake_run)
		for slope: float in [-1.0, 1.0]:
			var coping := _stone(
				root,
				"TownHallCoping%s%s" % [suffix, "S" if slope > 0.0 else "N"],
				Vector3(depth + 0.2, 0.16, rake_length),
				Vector3(
					side * (half_x + depth * 0.5),
					(height + apex_y) * 0.5 + 0.1,
					slope * rake_run * 0.5
				)
			)
			coping.rotation.x = slope * angle
		_stone(
			root,
			"TownHallApexStone%s" % suffix,
			Vector3(depth + 0.26, 0.34, 0.46),
			Vector3(side * (half_x + depth * 0.5), apex_y + 0.12, 0.0)
		)


## Rising-damp plinth of larger, darker footing stones around the whole hall.
static func _add_plinth(root: Node3D, size: Vector2, wall: StandardMaterial3D) -> void:
	var plinth_material := _triplanar(wall)
	plinth_material.albedo_color = wall.albedo_color.darkened(0.28)
	var plinth_height := 0.62
	var proud := 0.1
	var faces := {
		"N":
		[
			Vector3(size.x + proud * 2.0, plinth_height, proud),
			Vector3(0.0, 0.0, -size.y * 0.5 - proud * 0.5)
		],
		"S":
		[
			Vector3(size.x + proud * 2.0, plinth_height, proud),
			Vector3(0.0, 0.0, size.y * 0.5 + proud * 0.5)
		],
		"E": [Vector3(proud, plinth_height, size.y), Vector3(size.x * 0.5 + proud * 0.5, 0.0, 0.0)],
		"W":
		[Vector3(proud, plinth_height, size.y), Vector3(-size.x * 0.5 - proud * 0.5, 0.0, 0.0)],
	}
	for face: String in faces:
		var box_size: Vector3 = faces[face][0]
		var box := MeshInstance3D.new()
		box.name = "TownHallPlinth%s" % face
		var mesh := BoxMesh.new()
		mesh.size = box_size
		box.mesh = mesh
		box.position = faces[face][1] + Vector3(0.0, plinth_height * 0.5, 0.0)
		box.material_override = plinth_material
		root.add_child(box)


## Long-and-short dressed quoins. Only corners and openings were cut stone; the
## wall between them is split rubble.
static func _add_quoins(root: Node3D, size: Vector2, height: float) -> void:
	var course := 0.38
	var count := int((height - 0.62) / course)
	var corner_index := 0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for index in count:
				var long_on_x := index % 2 == 0
				var length_x := 0.78 if long_on_x else 0.42
				var length_z := 0.42 if long_on_x else 0.78
				var y := 0.62 + course * (float(index) + 0.5)
				_stone(
					root,
					"TownHallQuoin%d_%02d" % [corner_index, index],
					Vector3(length_x, course - 0.04, length_z),
					Vector3(
						sx * (size.x * 0.5 - length_x * 0.5 + 0.03),
						y,
						sz * (size.y * 0.5 - length_z * 0.5 + 0.03)
					)
				)
			corner_index += 1


## Round-headed council portal on the building axis. The leaf itself is the
## map transition door, which MapViewMeshBuilderLandmarks snaps to this axis.
static func _add_portal(root: Node3D, facade_z: float) -> void:
	var door_half := MapViewMeshBuilderConfig.DOOR_WIDTH * 0.5 + 0.12
	var door_head := MapViewMeshBuilderConfig.DOOR_HEIGHT + 0.04
	var reveal := 0.34
	for side: float in [-1.0, 1.0]:
		_stone(
			root,
			"TownHallPortalJamb%s" % ("R" if side > 0.0 else "L"),
			Vector3(reveal, door_head, 0.3),
			Vector3(side * (door_half + reveal * 0.5), door_head * 0.5, facade_z - 0.12)
		)
	# Plain masonry tympanum between the square door head and the arch.
	var tympanum := MeshInstance3D.new()
	tympanum.name = "TownHallPortalTympanum"
	tympanum.mesh = MapViewMeshBuilderPrimitives.arched_panel_mesh(
		door_half * 2.0, door_half + 0.02, 0.08
	)
	tympanum.position = Vector3(0.0, door_head, facade_z - 0.05)
	tympanum.material_override = _trim_material()
	root.add_child(tympanum)
	_stone(
		root,
		"TownHallPortalLintel",
		Vector3(door_half * 2.0, 0.22, 0.22),
		Vector3(0.0, door_head + 0.11, facade_z - 0.1)
	)
	var arch := MeshInstance3D.new()
	arch.name = "TownHallPortalArch"
	arch.mesh = MapViewMeshBuilderPrimitives.arch_band_mesh(door_half + reveal, reveal, 0.3)
	arch.position = Vector3(0.0, door_head, facade_z - 0.12)
	arch.material_override = _trim_material()
	root.add_child(arch)
	# Hollowed step: a century of boots has worn the centre down.
	_stone(
		root,
		"TownHallPortalStep",
		Vector3(door_half * 2.0 + reveal * 2.4, 0.12, 0.62),
		Vector3(0.0, 0.06, facade_z - 0.36)
	)
	var wear := _stone(
		root,
		"TownHallPortalStepWear",
		Vector3(door_half * 1.1, 0.02, 0.44),
		Vector3(0.0, 0.125, facade_z - 0.36)
	)
	wear.material_override = _grime_flat_material()


## Market-facing hall lights with open shutters, and below them the small
## barred cellar lights. Seven such openings from the 1322 building survive.
static func _add_market_windows(
	root: Node3D, rng: RandomNumberGenerator, half_x: float, height: float, facade_z: float
) -> int:
	var inner := 2.9
	var outer := half_x - 1.5
	var per_side := maxi(2, int((outer - inner) / 2.6))
	var pitch := (outer - inner) / float(per_side)
	var sill_y := minf(2.0, height * 0.36)
	var light_height := minf(1.7, height - sill_y - 1.1)
	var glass_index := 0
	var light_index := 0
	for side: float in [-1.0, 1.0]:
		for slot in per_side:
			var x := side * (inner + pitch * (float(slot) + 0.5))
			_add_light(
				root,
				"TownHallHallLight%02d" % light_index,
				glass_index,
				x,
				sill_y,
				0.86,
				light_height,
				facade_z,
				-1.0
			)
			_add_shutters(
				root,
				"TownHallHallLight%02d" % light_index,
				x,
				sill_y,
				0.86,
				light_height,
				facade_z,
				-1.0,
				rng
			)
			_add_sill_streaks(
				root, rng, "TownHallHallLight%02d" % light_index, x, sill_y, 0.86, facade_z, -1.0
			)
			_add_cellar_light(root, "TownHallCellarLight%02d" % light_index, x, facade_z)
			glass_index += 1
			light_index += 1
	return glass_index


static func _add_rear_windows(
	root: Node3D, rng: RandomNumberGenerator, size: Vector2, height: float, glass_index: int
) -> void:
	var rear_z := size.y * 0.5
	var count := clampi(int(size.x / 4.2), 3, 6)
	var light_height := minf(1.3, height * 0.26)
	for index in count:
		var x := (float(index + 1) / float(count + 1) - 0.5) * size.x
		var light_name := "TownHallRearLight%02d" % index
		_add_light(root, light_name, glass_index, x, height * 0.4, 0.62, light_height, rear_z, 1.0)
		_add_shutters(root, light_name, x, height * 0.4, 0.62, light_height, rear_z, 1.0, rng)
		_add_sill_streaks(root, rng, light_name, x, height * 0.4, 0.62, rear_z, 1.0)
		glass_index += 1


## Stone-framed round-headed light: dark reveal, leaded glass, jambs, mullion,
## sill. The pane keeps the "Window<n>" name so the evening glow schedule lights
## the council hall like every other inhabited building.
static func _add_light(
	root: Node3D,
	light_name: String,
	glass_index: int,
	x: float,
	sill_y: float,
	width: float,
	light_height: float,
	face_z: float,
	facing: float
) -> void:
	var reveal := MeshInstance3D.new()
	reveal.name = "%sReveal" % light_name
	reveal.mesh = MapViewMeshBuilderPrimitives.arched_panel_mesh(width, light_height)
	reveal.position = Vector3(x, sill_y, face_z + facing * 0.02)
	reveal.material_override = MapViewMeshBuilderPrimitives.role_material(&"ink")
	root.add_child(reveal)
	var pane := MeshInstance3D.new()
	pane.name = "Window%d" % glass_index
	pane.mesh = MapViewMeshBuilderPrimitives.arched_panel_mesh(width - 0.16, light_height - 0.14)
	pane.position = Vector3(x, sill_y + 0.06, face_z + facing * 0.04)
	pane.material_override = _glass_material()
	root.add_child(pane)
	for side: float in [-1.0, 1.0]:
		_stone(
			root,
			"%sJamb%s" % [light_name, "R" if side > 0.0 else "L"],
			Vector3(0.2, light_height * 0.8, 0.16),
			Vector3(
				x + side * (width * 0.5 + 0.08), sill_y + light_height * 0.4, face_z + facing * 0.07
			)
		)
	var arch := MeshInstance3D.new()
	arch.name = "%sArch" % light_name
	var radius := minf(width * 0.5, light_height * 0.58)
	arch.mesh = MapViewMeshBuilderPrimitives.arch_band_mesh(radius + 0.18, 0.18, 0.16)
	arch.position = Vector3(x, sill_y + light_height - radius, face_z + facing * 0.07)
	arch.material_override = _trim_material()
	root.add_child(arch)
	_stone(
		root,
		"%sMullion" % light_name,
		Vector3(0.07, light_height * 0.72, 0.1),
		Vector3(x, sill_y + light_height * 0.36, face_z + facing * 0.07)
	)
	_stone(
		root,
		"%sSill" % light_name,
		Vector3(width + 0.4, 0.12, 0.22),
		Vector3(x, sill_y - 0.06, face_z + facing * 0.11)
	)


## Board shutters, silvered with age. Most hang open against the wall; a few
## are still closed, so the row does not read as one stamped module.
static func _add_shutters(
	root: Node3D,
	light_name: String,
	x: float,
	sill_y: float,
	width: float,
	light_height: float,
	face_z: float,
	facing: float,
	rng: RandomNumberGenerator
) -> void:
	var leaf_width := width * 0.5 + 0.04
	var leaf_height := light_height * 0.78
	var closed := rng.randf() < 0.22
	var material := MapViewMaterials.hewn_timber(false, int(rng.randi() % 3))
	for side: float in [-1.0, 1.0]:
		var leaf := MeshInstance3D.new()
		leaf.name = "%sShutter%s" % [light_name, "R" if side > 0.0 else "L"]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(leaf_width, leaf_height, 0.05)
		leaf.mesh = mesh
		var offset := leaf_width * 0.5 if closed else width * 0.5 + 0.2 + leaf_width * 0.5
		leaf.position = Vector3(
			x + side * offset,
			sill_y + leaf_height * 0.5,
			face_z + facing * (0.2 if closed else 0.05)
		)
		# Open leaves hang a little off square on worn pintles.
		if not closed:
			leaf.rotation.y = side * facing * rng.randf_range(0.04, 0.2)
		leaf.material_override = material
		root.add_child(leaf)


static func _add_cellar_light(root: Node3D, light_name: String, x: float, facade_z: float) -> void:
	var opening := MeshInstance3D.new()
	opening.name = light_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.52, 0.3, 0.04)
	opening.mesh = mesh
	opening.position = Vector3(x, 0.36, facade_z - 0.12)
	opening.material_override = MapViewMeshBuilderPrimitives.role_material(&"ink")
	root.add_child(opening)
	for bar in 3:
		var rod := MeshInstance3D.new()
		rod.name = "%sBar%d" % [light_name, bar]
		var rod_mesh := BoxMesh.new()
		rod_mesh.size = Vector3(0.03, 0.32, 0.03)
		rod.mesh = rod_mesh
		rod.position = Vector3(x + (float(bar) - 1.0) * 0.15, 0.36, facade_z - 0.15)
		rod.material_override = MapViewMaterials.door_iron()
		root.add_child(rod)
	_stone(
		root, "%sLintel" % light_name, Vector3(0.74, 0.1, 0.12), Vector3(x, 0.56, facade_z - 0.15)
	)


## The attic was the town's storeroom: a gable loading door with a hoist beam,
## pulley block and rope on the east end, over the open lane. The west gable
## abuts its neighbour.
static func _add_attic_hoist(root: Node3D, size: Vector2, height: float) -> void:
	# The loft face is the outer plane of the gable prism (see _add_gables).
	var gable_x := size.x * 0.5 + MapViewMeshBuilderConfig.ROOF_OVERHANG + 0.06
	var door_bottom := height + 0.5
	var door_size := Vector3(0.06, 1.35, 1.0)
	var door := MeshInstance3D.new()
	door.name = "TownHallLoftDoor"
	var door_mesh := BoxMesh.new()
	door_mesh.size = door_size
	door.mesh = door_mesh
	door.position = Vector3(gable_x + 0.02, door_bottom + door_size.y * 0.5, 0.0)
	door.material_override = MapViewMaterials.door_wood(7)
	root.add_child(door)
	for side: float in [-1.0, 1.0]:
		_stone(
			root,
			"TownHallLoftJamb%s" % ("S" if side > 0.0 else "N"),
			Vector3(0.14, door_size.y + 0.1, 0.18),
			Vector3(gable_x + 0.06, door_bottom + door_size.y * 0.5, side * 0.59)
		)
	_stone(
		root,
		"TownHallLoftLintel",
		Vector3(0.18, 0.18, 1.36),
		Vector3(gable_x + 0.06, door_bottom + door_size.y + 0.1, 0.0)
	)
	_stone(
		root,
		"TownHallLoftSill",
		Vector3(0.24, 0.1, 1.3),
		Vector3(gable_x + 0.08, door_bottom - 0.04, 0.0)
	)
	var beam_y := door_bottom + door_size.y + 0.62
	var beam := MeshInstance3D.new()
	beam.name = "TownHallHoistBeam"
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(1.3, 0.2, 0.2)
	beam.mesh = beam_mesh
	beam.position = Vector3(gable_x + 0.55, beam_y, 0.0)
	beam.material_override = MapViewMaterials.hewn_timber(true, 1)
	root.add_child(beam)
	var block := MeshInstance3D.new()
	block.name = "TownHallHoistPulley"
	var block_mesh := CylinderMesh.new()
	block_mesh.top_radius = 0.11
	block_mesh.bottom_radius = 0.11
	block_mesh.height = 0.1
	block_mesh.radial_segments = 10
	block.mesh = block_mesh
	block.rotation.x = PI * 0.5
	block.position = Vector3(gable_x + 1.1, beam_y - 0.2, 0.0)
	block.material_override = MapViewMaterials.hewn_timber(true, 2)
	root.add_child(block)
	# R-1200: hemp rope and iron hook that swing in the world wind; the beam
	# runs along +X, the axis the hook bill is built on.
	var rope_length := beam_y - 0.2 - 1.3
	var rope := MapViewHoistRope.create(rope_length)
	rope.name = "TownHallHoistRope"
	rope.position = Vector3(gable_x + 1.2, beam_y - 0.2, 0.0)
	root.add_child(rope)


## Two banners hung flat on iron rods either side of the portal, facing the
## market, and a flag on a staff at the east gable apex.
static func _add_banners(root: Node3D, size: Vector2, height: float, facade_z: float) -> void:
	var banner_width := 1.05
	var banner_height := 1.45
	var top_y := height - 0.35
	for side: float in [-1.0, 1.0]:
		var suffix := "E" if side > 0.0 else "W"
		var x := side * 1.95
		var rod := MeshInstance3D.new()
		rod.name = "TownHallBannerRod%s" % suffix
		var rod_mesh := CylinderMesh.new()
		rod_mesh.top_radius = 0.025
		rod_mesh.bottom_radius = 0.025
		rod_mesh.height = banner_width + 0.3
		rod_mesh.radial_segments = 6
		rod.mesh = rod_mesh
		rod.rotation.z = PI * 0.5
		rod.position = Vector3(x, top_y, facade_z - 0.34)
		rod.material_override = MapViewMaterials.door_iron()
		root.add_child(rod)
		for end: float in [-1.0, 1.0]:
			var bracket := MeshInstance3D.new()
			bracket.name = "TownHallBannerBracket%s%s" % [suffix, "R" if end > 0.0 else "L"]
			var bracket_mesh := BoxMesh.new()
			bracket_mesh.size = Vector3(0.04, 0.05, 0.36)
			bracket.mesh = bracket_mesh
			bracket.position = Vector3(
				x + end * (banner_width * 0.5 + 0.08), top_y, facade_z - 0.17
			)
			bracket.material_override = MapViewMaterials.door_iron()
			root.add_child(bracket)
		var banner := MeshInstance3D.new()
		banner.name = "TownHallBanner%s" % suffix
		banner.mesh = _banner_mesh(banner_width, banner_height, false, int(side > 0.0))
		# The mesh hangs down from its top edge and faces -Z (the market).
		banner.position = Vector3(x - banner_width * 0.5, top_y - 0.03, facade_z - 0.34)
		# Pinned at the rod; the hem sways with the shared world wind.
		banner.material_override = MapViewMaterials.hanging_banner_cloth(null, true)
		banner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(banner)

	var apex_y := (
		height
		+ (
			(size.y * 0.5 + MapViewMeshBuilderConfig.ROOF_OVERHANG)
			* MapViewMeshBuilderConfig.ROOF_PITCH
		)
	)
	var staff_height := 3.2
	var staff_x := size.x * 0.5 + 0.02
	var staff := MeshInstance3D.new()
	staff.name = "TownHallFlagStaff"
	var staff_mesh := CylinderMesh.new()
	staff_mesh.top_radius = 0.035
	staff_mesh.bottom_radius = 0.05
	staff_mesh.height = staff_height
	staff_mesh.radial_segments = 8
	staff.mesh = staff_mesh
	staff.position = Vector3(staff_x, apex_y + 0.28 + staff_height * 0.5, 0.0)
	staff.material_override = MapViewMaterials.hewn_timber(false, 0)
	root.add_child(staff)
	var finial := MeshInstance3D.new()
	finial.name = "TownHallFlagFinial"
	var finial_mesh := SphereMesh.new()
	finial_mesh.radius = 0.07
	finial_mesh.height = 0.14
	finial.mesh = finial_mesh
	finial.position = Vector3(staff_x, apex_y + 0.28 + staff_height + 0.05, 0.0)
	finial.material_override = MapViewMaterials.door_iron()
	root.add_child(finial)
	var flag := MeshInstance3D.new()
	flag.name = "TownHallGableFlag"
	flag.mesh = _banner_mesh(1.5, 1.1, true, 2)
	# The hoist sits on the staff axis: the flag shader turns the cloth about
	# local Y to stream downwind, sags it in light air, and flutters the fly.
	flag.position = Vector3(staff_x, apex_y + 0.28 + staff_height - 0.1, 0.0)
	flag.material_override = MapViewMaterials.flag_cloth(true)
	root.add_child(flag)


## Red cloth with a centred white cross. Built on a grid whose lines fall on
## the cross edges, so per-cell colour gives crisp arms without a texture.
## `flying` leaves the cloth flat (the flag shader poses it in the live wind and
## needs UV.x = x / width); otherwise it hangs in soft vertical folds. Origin is
## the top-left (hoist) corner; the cloth runs +X and hangs -Y, facing -Z.
## UV runs u along the width and v down from the top edge.
static func _banner_mesh(
	width: float, cloth_height: float, flying: bool, variant: int
) -> ArrayMesh:
	var key := "banner:%.2f:%.2f:%s:%d" % [width, cloth_height, flying, variant]
	if _cache.has(key):
		return _cache[key]
	var cols := 16
	var rows := 12 if flying else 20
	# Two cells wide either side of the centre line.
	var cross_cols := [int(cols * 0.5) - 1, int(cols * 0.5)]
	var cross_rows := [int(rows * 0.5) - 1, int(rows * 0.5)]
	var phase := float(variant) * 1.7

	var points: Array = []
	for row in rows + 1:
		var line: Array[Vector3] = []
		for col in cols + 1:
			var u := float(col) / float(cols)
			var v := float(row) / float(rows)
			var p := Vector3(u * width, -v * cloth_height, 0.0)
			if not flying:
				# Folds deepen toward the free hem; the top edge stays on the rod.
				p.z = -sin(u * TAU * 2.0 + phase) * 0.045 * (0.3 + v)
				p.y -= sin(u * PI) * v * 0.05
			line.append(p)
		points.append(line)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in rows:
		for col in cols:
			var in_cross := col in cross_cols or row in cross_rows
			var color := BANNER_WHITE if in_cross else BANNER_RED
			# Grime and fading collect toward the hem and the fly edge.
			var v := (float(row) + 0.5) / float(rows)
			var u := (float(col) + 0.5) / float(cols)
			var wear := 0.18 * v + (0.12 * u if flying else 0.0)
			color = color.darkened(wear).lerp(Color(0.62, 0.58, 0.5), 0.12)
			surface.set_color(color)
			var a: Vector3 = points[row][col]
			var b: Vector3 = points[row][col + 1]
			var c: Vector3 = points[row + 1][col + 1]
			var d: Vector3 = points[row + 1][col]
			var u0 := float(col) / float(cols)
			var u1 := float(col + 1) / float(cols)
			var v0 := float(row) / float(rows)
			var v1 := float(row + 1) / float(rows)
			for corner: Array in [
				[a, u0, v0], [b, u1, v0], [c, u1, v1], [a, u0, v0], [c, u1, v1], [d, u0, v1]
			]:
				surface.set_uv(Vector2(corner[1], corner[2]))
				surface.add_vertex(corner[0])
	surface.generate_normals()
	var mesh := surface.commit()
	_cache[key] = mesh
	return mesh


## Staining overlays: rising damp above the plinth, soot and runoff under the
## eaves, and rain streaks below every sill. Lengths are seeded per building so
## the pattern is stable but irregular.
static func _add_weathering(
	root: Node3D, rng: RandomNumberGenerator, size: Vector2, height: float
) -> void:
	var half_x := size.x * 0.5
	var half_z := size.y * 0.5
	var faces := [
		["N", size.x, Vector3(0.0, 0.0, -half_z), PI],
		["S", size.x, Vector3(0.0, 0.0, half_z), 0.0],
		["E", size.y, Vector3(half_x, 0.0, 0.0), PI * 0.5],
		["W", size.y, Vector3(-half_x, 0.0, 0.0), -PI * 0.5],
	]
	for face: Array in faces:
		var face_name: String = face[0]
		var span: float = face[1]
		var origin: Vector3 = face[2]
		var yaw: float = face[3]
		var along := Vector3(cos(yaw), 0.0, -sin(yaw))
		var normal := Vector3(sin(yaw), 0.0, cos(yaw))
		var base := origin + normal * DECAL_OFFSET
		_decal(
			root,
			"TownHallDamp%s" % face_name,
			Vector2(span, 1.5),
			base + Vector3(0.0, 0.62 + 0.75, 0.0),
			yaw,
			0.5,
			false,
			false
		)
		var streak_count := int(span / 0.9)
		for index in streak_count:
			var width := rng.randf_range(0.25, 0.8)
			var length := rng.randf_range(0.5, 2.1)
			var t := (float(index) + rng.randf_range(0.2, 0.8)) / float(streak_count) - 0.5
			_decal(
				root,
				"TownHallEaveStreak%s%02d" % [face_name, index],
				Vector2(width, length),
				base + along * (t * span) + Vector3(0.0, height - length * 0.5, 0.0),
				yaw,
				rng.randf_range(0.2, 0.4),
				true
			)


static func _add_sill_streaks(
	root: Node3D,
	rng: RandomNumberGenerator,
	light_name: String,
	x: float,
	sill_y: float,
	width: float,
	face_z: float,
	facing: float
) -> void:
	var yaw := PI if facing < 0.0 else 0.0
	for index in 3:
		var length := rng.randf_range(0.5, 1.4)
		var streak_x := x + (float(index) - 1.0) * width * 0.34 + rng.randf_range(-0.06, 0.06)
		_decal(
			root,
			"%sStreak%d" % [light_name, index],
			Vector2(rng.randf_range(0.14, 0.3), length),
			Vector3(streak_x, sill_y - 0.12 - length * 0.5, face_z + facing * DECAL_OFFSET * 2.0),
			yaw,
			rng.randf_range(0.35, 0.6),
			true
		)


## One faded staining quad. `from_top` darkens at the top edge and fades down
## (runoff); otherwise it darkens at the bottom and fades up (rising damp).
static func _decal(
	root: Node3D,
	decal_name: String,
	quad_size: Vector2,
	center: Vector3,
	yaw: float,
	strength: float,
	from_top: bool,
	soft_sides: bool = true
) -> void:
	var quad := MeshInstance3D.new()
	quad.name = decal_name
	var mesh := QuadMesh.new()
	mesh.size = quad_size
	quad.mesh = mesh
	quad.position = center
	quad.rotation.y = yaw
	quad.material_override = _grime_material(snappedf(strength, 0.05), from_top, soft_sides)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(quad)


## Alpha mask baked per (strength, direction, edge) so every stain of that kind
## shares one material. Soft sides fade the stain across its width as well, so
## runoff reads as a streak instead of a translucent rectangle.
static func _grime_material(
	strength: float, from_top: bool, soft_sides: bool
) -> StandardMaterial3D:
	var key := "grime:%.2f:%s:%s" % [strength, from_top, soft_sides]
	if _cache.has(key):
		return _cache[key]
	var image := Image.create(16, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var v := float(y) / 63.0
		var fade := 1.0 - v if from_top else v
		fade = fade * fade
		for x in 16:
			var across := 1.0
			if soft_sides:
				across = pow(sin(PI * (float(x) + 0.5) / 16.0), 1.5)
			image.set_pixel(x, y, Color(GRIME, strength * fade * across))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	material.metallic_specular = 0.0
	material.cull_mode = BaseMaterial3D.CULL_BACK
	_cache[key] = material
	return material


static func _grime_flat_material() -> StandardMaterial3D:
	if _cache.has("grime_flat"):
		return _cache["grime_flat"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.34, 0.3)
	material.roughness = 1.0
	material.metallic_specular = 0.1
	_cache["grime_flat"] = material
	return material


## Dressed limestone for quoins and frames: the grey ashlar plate projected in
## object space, so small boxes keep the stone scale instead of one stretched
## texel band.
static func _trim_material() -> StandardMaterial3D:
	# No local cache: the entry lives in the AR-03 cache, so MapViewMaterials.reset()
	# and the anti-tiling toggle both reach it. Re-applying the settings is idempotent.
	var material := _toned(
		_BuildingMaterials.library_surface_for_building(
			"town_hall_trim", &"town_hall_trim", TRIM_STEM, TRIM_TINT
		),
		TRIM_TONE
	)
	material.uv1_triplanar = true
	material.uv1_scale = _BuildingMaterials.library_world_uv_density(TRIM_STEM)
	return material


## Scales the tint of a Town Hall-only library entry in place, once. Staying
## in the library cache keeps it under the anti-tiling quality toggle; the
## base-tint meta is scaled too, so the toggle keeps the same tone.
static func _toned(material: StandardMaterial3D, tone: Color) -> StandardMaterial3D:
	if material.has_meta(&"town_hall_toned"):
		return material
	material.set_meta(&"town_hall_toned", true)
	var base: Color = material.get_meta(&"ar03_base_tint", material.albedo_color)
	material.set_meta(&"ar03_base_tint", Color(base * tone, base.a))
	material.albedo_color = Color(material.albedo_color * tone, material.albedo_color.a)
	return material


## Box UVs stretch one plate across a long thin plinth or a pentagon, so those
## pieces reuse the wall stem projected at its real-world density.
static func _triplanar(wall: StandardMaterial3D) -> StandardMaterial3D:
	var material := wall.duplicate() as StandardMaterial3D
	material.uv1_triplanar = true
	material.uv1_scale = _BuildingMaterials.library_world_uv_density(WALL_STEM)
	return material


## Small leaded panes read dark and dull from outside, not as blue mirrors.
static func _glass_material() -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache["glass"]
	var material := StandardMaterial3D.new()
	material.albedo_color = GLASS_TINT
	material.roughness = 0.45
	material.metallic_specular = 0.3
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["glass"] = material
	return material


static func _stone(
	root: Node3D, node_name: String, box_size: Vector3, position: Vector3
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = _trim_material()
	root.add_child(instance)
	return instance
