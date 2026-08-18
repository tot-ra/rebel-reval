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
const TOWN_HALL_ARCADE_THICKNESS := 0.62
const TOWN_HALL_CORRIDOR_DEPTH := 1.5
## How far the door leaf stands off the gallery back wall, so the dark doorway
## void stays behind the leaf and the stone surround still frames it.
const TOWN_HALL_DOOR_RECESS := 0.16

static func house_style(building: Dictionary) -> StringName:
	return _Styles.house_style(building)


static func house_wall_material(
	building: Dictionary, wall_color: Color, size: Vector3
) -> StandardMaterial3D:
	return _Styles.house_wall_material(building, wall_color, size)


static func roof_style(building: Dictionary) -> StringName:
	return _Styles.roof_style(building)


static func house_roof_material(building: Dictionary) -> StandardMaterial3D:
	return _Styles.house_roof_material(building)


static func add_house_structure(
	root: Node3D, building: Dictionary, size: Vector2, height: float, along_ridge_x: bool
) -> void:
	_Structure.add_house_structure(root, building, size, height, along_ridge_x)


static func add_roof_trim(
	root: Node3D, building: Dictionary, size: Vector2, height: float, along_ridge_x: bool
) -> void:
	_RoofDressing.add_roof_trim(root, building, size, height, along_ridge_x)


## Ground-floor gallery carved out of the Town Hall mass: arcade wall thickness
## plus the walk-through corridor behind it. WHY: the arcade has to be a real
## covered passage with the civic door at its back, the way the rebuilt Raekoda
## reads, so the solid wall box is pulled back by this much on the facade side.
static func town_hall_gallery_inset(building: Dictionary, size: Vector2) -> float:
	if StringName(building.get("primitive", &"")) != &"town_hall_1343":
		return 0.0
	return minf(TOWN_HALL_ARCADE_THICKNESS + TOWN_HALL_CORRIDOR_DEPTH, size.y * 0.42)


## Facade openings authored by the primitive itself must not be doubled by the
## generic house door and window pass.
static func authors_own_facade(building: Dictionary) -> bool:
	return (
		StringName(building.get("primitive", &"")) == &"town_hall_1343"
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
	if not _ProductionModels.is_production_tier(building):
		return null
	return _ProductionModels.add_model(root, building, size, height)

static func add_historic_building_details(
	root: Node3D, building: Dictionary, size: Vector2, height: float, along_ridge_x: bool
) -> void:
	match StringName(building.get("primitive", &"")):
		&"town_hall_1343":
			_add_early_town_hall_details(root, building, size, height)
		&"holy_spirit_chapel_1343":
			_add_holy_spirit_chapel_details(root, size, height)
		&"stepped_gable_merchant":
			_add_stepped_merchant_gable(root, size, height, along_ridge_x)
		MapViewMonasticModels.ORATORY_PRIMITIVE:
			MapViewMonasticModels.add_oratory_details(root, building, size, height, along_ridge_x)


static func _add_early_town_hall_details(
	root: Node3D, building: Dictionary, size: Vector2, height: float
) -> void:
	# WHY: the rebuilt Raekoda is quoted as structure, not as ornament. The bays
	# are a real load-bearing arcade wall with a covered gallery behind it and the
	# council door at the back of that gallery, but the mass stays the low 1343
	# hall - one storey of tall lights over the arcade, no upper hall, no tower.
	var half_x := size.x * 0.5
	var facade_z := -size.y * 0.5
	var inset := town_hall_gallery_inset(building, size)
	var arcade_thickness := minf(TOWN_HALL_ARCADE_THICKNESS, inset * 0.5)
	var corridor_depth := inset - arcade_thickness
	var inner_wall_z := facade_z + inset
	var gallery_floor_y := MapViewMeshBuilderConfig.PLINTH_HEIGHT
	var wall_color := Color(building.get("wall_color", MapViewMeshBuilderConfig.DEFAULT_WALL_COLOR))

	var layout := _town_hall_arcade_layout(size, height)
	var openings: Array = layout["openings"]
	var portal: Dictionary = layout["portal"]
	var head_y: float = layout["head_y"]

	# WHY: house wall materials are cached and shared per building, and their
	# uv1_scale is derived from the size handed in. Always ask for the mass size
	# so the arcade cannot re-stripe the courses of the whole building.
	var wall_material := _Styles.house_wall_material(
		building, wall_color, Vector3(size.x, height, size.y)
	)
	var arcade := MeshInstance3D.new()
	arcade.name = "TownHallArcadeWall"
	arcade.mesh = MapViewMeshBuilderPrimitives.arcade_wall_mesh(
		size.x, height, arcade_thickness, openings
	)
	arcade.position = Vector3(0.0, 0.0, facade_z + arcade_thickness * 0.5)
	arcade.material_override = wall_material
	root.add_child(arcade)

	_add_town_hall_gallery(
		root,
		size,
		height,
		wall_material,
		facade_z + arcade_thickness,
		corridor_depth,
		gallery_floor_y,
		head_y,
		openings
	)
	_add_town_hall_arcade_dressing(root, openings, portal, facade_z, head_y, size)
	_add_town_hall_portal(root, portal, inner_wall_z, gallery_floor_y)
	_add_town_hall_upper_storey(root, size, height, facade_z, head_y, openings)

	for side_x: float in [-half_x + 0.55, half_x - 0.55]:
		MapViewMeshBuilderPrimitives.box(
			root,
			"TownHallCornerButtress%.0f" % side_x,
			Vector3(0.34, height * 0.92, 0.34),
			Vector3(side_x, height * 0.46, facade_z - 0.13),
			&"stone"
		)
	var step_count := 4
	for index in step_count:
		var step_width := size.y * (0.52 - float(index) * 0.085)
		var step_height := height + 0.18 + float(index) * 0.22
		for x_side: float in [-1.0, 1.0]:
			MapViewMeshBuilderPrimitives.box(
				root,
				"TownHallGableStep%02d_%s" % [index, "E" if x_side > 0.0 else "W"],
				Vector3(0.24, 0.20, maxf(0.32, step_width)),
				Vector3(x_side * (half_x + 0.05), step_height, 0.0),
				&"stone"
			)
	# Market stoop: the step up from the trampled square into the gallery.
	var dais_height := minf(0.2, gallery_floor_y * 0.8)
	MapViewMeshBuilderPrimitives.box(
		root,
		"TownHallMarketStoop",
		Vector3(size.x * 0.82, dais_height, 0.9),
		Vector3(0.0, dais_height * 0.5, facade_z - 0.45),
		&"stone"
	)


## Bay rhythm for the arcade. The portal bay sits on the building axis and the
## side bays share one pitch, so the facade reads as a single built order rather
## than a row of unrelated niches. The transition door is snapped to the same
## axis (see MapViewMeshBuilderLandmarks.build_transition_door).
static func _town_hall_arcade_layout(size: Vector2, height: float) -> Dictionary:
	var half_x := size.x * 0.5
	var corner_pier := 0.9
	var pier_width := 0.82
	var bay_pitch := 2.6
	var portal_half := minf(1.15, size.x * 0.06)
	var portal_spring := minf(1.85, height * 0.36)
	var portal := {
		"x": 0.0,
		"half_width": portal_half,
		"spring_y": portal_spring,
	}
	var openings: Array = [portal]

	var side_start := portal_half + pier_width
	var span := maxf(half_x - corner_pier - side_start, bay_pitch)
	var count := maxi(1, int(round(span / bay_pitch)))
	var pitch := span / float(count)
	var opening_half := clampf((pitch - pier_width) * 0.5, 0.5, 1.05)
	var side_spring := minf(portal_spring - 0.14, height * 0.33)
	for side: float in [-1.0, 1.0]:
		for index in count:
			(
				openings
				. append(
					{
						"x": side * (side_start + pitch * (float(index) + 0.5)),
						"half_width": opening_half,
						"spring_y": side_spring,
					}
				)
			)
	openings.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a["x"]) < float(b["x"])
	)

	var crown := 0.0
	for opening: Dictionary in openings:
		crown = maxf(crown, float(opening["spring_y"]) + float(opening["half_width"]))
	return {
		"openings": openings,
		"portal": portal,
		"head_y": minf(crown + 0.4, height - 1.5),
	}


## The walk-through gallery: raised floor, transverse arches springing from the
## arcade piers onto wall responds, and the ceiling that carries the wall above.
static func _add_town_hall_gallery(
	root: Node3D,
	size: Vector2,
	height: float,
	wall_material: StandardMaterial3D,
	gallery_front_z: float,
	corridor_depth: float,
	floor_y: float,
	head_y: float,
	openings: Array
) -> void:
	var half_x := size.x * 0.5
	var end_wall := 0.9
	var corridor_center_z := gallery_front_z + corridor_depth * 0.5
	var back_z := gallery_front_z + corridor_depth
	# The mass behind was pulled back to open the gallery, so the side walls of
	# that strip have to be rebuilt or the building would show a hollow flank.
	for side: float in [-1.0, 1.0]:
		var end_block := MeshInstance3D.new()
		end_block.name = "TownHallGalleryEndWall%s" % ("E" if side > 0.0 else "W")
		var block_mesh := BoxMesh.new()
		block_mesh.size = Vector3(end_wall, height, corridor_depth)
		end_block.mesh = block_mesh
		end_block.position = Vector3(
			side * (half_x - end_wall * 0.5), height * 0.5, corridor_center_z
		)
		end_block.material_override = wall_material
		root.add_child(end_block)

	var walk_width := size.x - end_wall * 2.0
	MapViewMeshBuilderPrimitives.box(
		root,
		"TownHallGalleryFloor",
		Vector3(walk_width, floor_y, corridor_depth),
		Vector3(0.0, floor_y * 0.5, corridor_center_z),
		&"stone"
	)
	MapViewMeshBuilderPrimitives.box(
		root,
		"TownHallGalleryVault",
		Vector3(walk_width, 0.22, corridor_depth),
		Vector3(0.0, head_y - 0.11, corridor_center_z),
		&"stone"
	)
	# WHY: the gallery is a covered walk and must sit in shade, otherwise the
	# bays keep reading as bright niches cut into a solid facade. A darkened
	# lining on the back wall carries that shadow at any time of day.
	var lining := MeshInstance3D.new()
	lining.name = "TownHallGalleryLining"
	var lining_mesh := BoxMesh.new()
	lining_mesh.size = Vector3(walk_width, head_y - floor_y, 0.08)
	lining.mesh = lining_mesh
	lining.position = Vector3(0.0, floor_y + (head_y - floor_y) * 0.5, back_z - 0.04)
	var lining_material := wall_material.duplicate() as StandardMaterial3D
	lining_material.albedo_color = wall_material.albedo_color.darkened(0.45)
	lining.material_override = lining_material
	root.add_child(lining)

	# Piers, responds and transverse arches: the visible reason the storey above
	# stands over an open walk.
	var rib_radius := corridor_depth * 0.5
	var rib_spring := minf(head_y - 0.3 - rib_radius, head_y * 0.6)
	for index in openings.size() - 1:
		var opening: Dictionary = openings[index]
		var next: Dictionary = openings[index + 1]
		var pier_x := (
			(
				float(opening["x"])
				+ float(opening["half_width"])
				+ float(next["x"])
				- float(next["half_width"])
			)
			* 0.5
		)
		MapViewMeshBuilderPrimitives.box(
			root,
			"TownHallGalleryRespond%02d" % index,
			Vector3(0.44, rib_spring, 0.2),
			Vector3(pier_x, rib_spring * 0.5, back_z - 0.1),
			&"stone"
		)
		var rib := MeshInstance3D.new()
		rib.name = "TownHallGalleryRib%02d" % index
		rib.mesh = MapViewMeshBuilderPrimitives.arch_band_mesh(rib_radius, 0.2, 0.36)
		rib.position = Vector3(pier_x, rib_spring, corridor_center_z)
		rib.rotation.y = PI * 0.5
		rib.material_override = MapViewMeshBuilderPrimitives.role_material(&"stone")
		root.add_child(rib)


## Outer face relief: impost blocks and archivolts around every opening.
static func _add_town_hall_arcade_dressing(
	root: Node3D, openings: Array, portal: Dictionary, facade_z: float, head_y: float, size: Vector2
) -> void:
	for index in openings.size():
		var opening: Dictionary = openings[index]
		var is_portal := is_equal_approx(float(opening["x"]), float(portal["x"]))
		var radius := float(opening["half_width"])
		var spring := float(opening["spring_y"])
		var voussoir := clampf(radius * 0.16, 0.14, 0.22)
		_add_arch_band(
			root,
			"TownHallPortalBayArch" if is_portal else "ArcadeArch%02d" % index,
			radius + voussoir,
			voussoir,
			Vector3(float(opening["x"]), spring, facade_z - 0.05),
			&"stone"
		)
		# Pier faces and imposts stay outside the opening: a block spanning the
		# void would read as a shop transom instead of an arcade.
		for side: float in [-1.0, 1.0]:
			var jamb_x := float(opening["x"]) + side * radius
			MapViewMeshBuilderPrimitives.box(
				root,
				"ArcadePier%02d%s" % [index, "R" if side > 0.0 else ""],
				Vector3(0.18, spring, 0.1),
				Vector3(jamb_x + side * (voussoir + 0.09), spring * 0.5, facade_z - 0.04),
				&"stone"
			)
			MapViewMeshBuilderPrimitives.box(
				root,
				"ArcadeImpost%02d%s" % [index, "R" if side > 0.0 else ""],
				Vector3(0.44, 0.12, 0.14),
				Vector3(jamb_x + side * 0.22, spring + 0.06, facade_z - 0.06),
				&"stone"
			)
	MapViewMeshBuilderPrimitives.box(
		root,
		"TownHallStringCourse",
		Vector3(size.x * 0.99, 0.16, 0.2),
		Vector3(0.0, head_y + 0.08, facade_z - 0.07),
		&"stone"
	)


## The council door stands at the back of the gallery, framed by a deep arched
## surround on the inner wall. The door leaf itself is the map transition door.
static func _add_town_hall_portal(
	root: Node3D, portal: Dictionary, inner_wall_z: float, floor_y: float
) -> void:
	var portal_x := float(portal["x"])
	var door_half := MapViewMeshBuilderConfig.DOOR_WIDTH * 0.5 + 0.18
	var door_head := floor_y + MapViewMeshBuilderConfig.DOOR_HEIGHT + 0.12
	# Depth order behind the arcade, from the wall outward: masonry tympanum,
	# then the transition door leaf (TOWN_HALL_DOOR_RECESS in front of the inner
	# wall), then the stone surround that frames both. The tympanum is masonry,
	# not void: a black arch head over the door reads as a hole in the building.
	_add_arch_panel(
		root,
		"TownHallPortalRecess",
		door_half * 2.0,
		door_head + door_half - floor_y,
		inner_wall_z - 0.05,
		&"stone"
	)
	var recess := root.get_node("TownHallPortalRecess") as Node3D
	recess.position.x = portal_x
	recess.position.y = floor_y
	for side: float in [-1.0, 1.0]:
		MapViewMeshBuilderPrimitives.box(
			root,
			"TownHallPortalJamb%s" % ("R" if side > 0.0 else "L"),
			Vector3(0.22, door_head - floor_y, 0.3),
			Vector3(
				portal_x + side * (door_half + 0.11),
				floor_y + (door_head - floor_y) * 0.5,
				inner_wall_z - 0.28
			),
			&"stone"
		)
	_add_arch_band(
		root,
		"TownHallPortalArch",
		door_half + 0.22,
		0.22,
		Vector3(portal_x, door_head, inner_wall_z - 0.28),
		&"stone"
	)
	MapViewMeshBuilderPrimitives.box(
		root,
		"TownHallPortalStep",
		Vector3(door_half * 2.6, 0.1, 0.46),
		Vector3(portal_x, floor_y + 0.05, inner_wall_z - 0.5),
		&"stone"
	)


## Single upper band of tall council lights over the arcade. Bay-aligned, so the
## facade reads as one order of arches carrying one order of windows.
static func _add_town_hall_upper_storey(
	root: Node3D, size: Vector2, height: float, facade_z: float, head_y: float, openings: Array
) -> void:
	var sill_y := head_y + 0.42
	var light_height := minf(height - sill_y - 0.42, 1.6)
	var index := 0
	for opening: Dictionary in openings:
		var x := float(opening["x"])
		if absf(x) > size.x * 0.5 - 1.1:
			continue
		# Kept name: the upper lights used to be authored as a clerestory row.
		_add_town_hall_light(
			root,
			"TownHallClerestory%02d" % index,
			index,
			x,
			sill_y,
			0.56,
			light_height,
			facade_z,
			-1.0
		)
		index += 1
	# Back wall onto the service lane: the same order of lights, lower and
	# plainer, so the hall is not a blank slab from the south.
	var rear_z := size.y * 0.5
	var rear_count := clampi(int(size.x / 3.2), 3, 6)
	var rear_height := minf(1.35, height * 0.32)
	for rear_index in rear_count:
		var x := (float(rear_index + 1) / float(rear_count + 1) - 0.5) * size.x
		_add_town_hall_light(
			root,
			"TownHallRearLancet%02d" % rear_index,
			index,
			x,
			height * 0.42,
			0.46,
			rear_height,
			rear_z,
			1.0
		)
		index += 1


## Stone-framed light: dark reveal, glazing, jambs, sill and hood mould. WHY:
## a bare tinted panel on the wall face reads as a sticker; the frame is what
## makes it read as an opening cut through masonry.
static func _add_town_hall_light(
	root: Node3D,
	hood_name: String,
	glass_index: int,
	x: float,
	sill_y: float,
	light_width: float,
	light_height: float,
	face_z: float,
	facing: float
) -> void:
	var reveal_name := "%sReveal" % hood_name
	_add_arch_panel(root, reveal_name, light_width, light_height, face_z + facing * 0.02, &"ink")
	var reveal := root.get_node(reveal_name) as Node3D
	reveal.position.x = x
	reveal.position.y = sill_y
	# Glass pane keeps the "Window<n>" name so the evening glow schedule lights
	# the council chamber like every other inhabited building.
	_add_arch_panel(
		root,
		"Window%d" % glass_index,
		light_width - 0.14,
		light_height - 0.12,
		face_z + facing * 0.06,
		&"window"
	)
	var pane := root.get_node("Window%d" % glass_index) as Node3D
	pane.position.x = x
	pane.position.y = sill_y + 0.06
	for side: float in [-1.0, 1.0]:
		MapViewMeshBuilderPrimitives.box(
			root,
			"%sJamb%s" % [hood_name, "R" if side > 0.0 else "L"],
			Vector3(0.16, light_height * 0.82, 0.14),
			Vector3(
				x + side * (light_width * 0.5 + 0.07),
				sill_y + light_height * 0.41,
				face_z + facing * 0.08
			),
			&"stone"
		)
	MapViewMeshBuilderPrimitives.box(
		root,
		"%sMullion" % hood_name,
		Vector3(0.06, light_height * 0.7, 0.1),
		Vector3(x, sill_y + light_height * 0.35, face_z + facing * 0.09),
		&"stone"
	)
	MapViewMeshBuilderPrimitives.box(
		root,
		"%sSill" % hood_name,
		Vector3(light_width + 0.32, 0.11, 0.16),
		Vector3(x, sill_y - 0.05, face_z + facing * 0.09),
		&"stone"
	)
	MapViewMeshBuilderPrimitives.box(
		root,
		hood_name,
		Vector3(light_width + 0.36, 0.1, 0.13),
		Vector3(x, sill_y + light_height + 0.14, face_z + facing * 0.08),
		&"stone"
	)


static func _add_arch_panel(
	root: Node3D, node_name: String, width: float, height: float, z: float, role: StringName
) -> void:
	var panel := MeshInstance3D.new()
	panel.name = node_name
	panel.mesh = MapViewMeshBuilderPrimitives.arched_panel_mesh(width, height)
	panel.position.z = z
	panel.material_override = MapViewMeshBuilderPrimitives.role_material(role)
	root.add_child(panel)


static func _add_arch_band(
	root: Node3D,
	node_name: String,
	radius: float,
	thickness: float,
	position: Vector3,
	role: StringName
) -> void:
	var band := MeshInstance3D.new()
	band.name = node_name
	band.mesh = MapViewMeshBuilderPrimitives.arch_band_mesh(radius, thickness)
	band.position = position
	band.material_override = MapViewMeshBuilderPrimitives.role_material(role)
	root.add_child(band)


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
