class_name MapViewMammalMeshes
extends RefCounted

## Cached low-poly reference geometry for the P0-118 mammal catalog. Meshes are
## static silhouettes only; runtime wander, tether, and flee behavior belong to
## P2-024 and P0-106.

const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const RADIAL_SEGMENTS := 6
const BODY_SEGMENTS := 8
const BODY_RINGS := 5

## Species the player meets at street range in Lower Town (P2-024). They carry
## facial features, paws, and a finer body tessellation than the rest of the
## reference catalog, which is only ever seen as a distant silhouette.
const DETAILED_SPECIES: Array[StringName] = [
	MammalSpecies.SPECIES_CAT,
	MammalSpecies.SPECIES_RAT,
]

static var _mesh_cache: Dictionary = {}


static func mesh_for(species: StringName, pose: StringName = &"") -> ArrayMesh:
	var resolved_pose := MammalSpecies.default_pose(species) if pose.is_empty() else pose
	if not MammalSpecies.is_known_species(species) or not MammalSpecies.is_known_pose(resolved_pose):
		return null
	var cache_key := "%s:%s" % [species, resolved_pose]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	var mesh := _build_mesh(species, resolved_pose)
	_mesh_cache[cache_key] = mesh
	return mesh


static func reset_cache() -> void:
	_mesh_cache.clear()


static func geometry_stats(species: StringName, pose: StringName = &"") -> Dictionary:
	var mesh := mesh_for(species, pose)
	if mesh == null or mesh.get_surface_count() == 0:
		return {}
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return {
		"vertices": vertices.size(),
		"triangles": vertices.size() / 3,
		"aabb": mesh.get_aabb(),
		"group": MammalSpecies.group_for(species),
		"pose": MammalSpecies.default_pose(species) if pose.is_empty() else pose,
	}


static func _build_mesh(species: StringName, pose: StringName) -> ArrayMesh:
	if species == MammalSpecies.SPECIES_DOG:
		return MapViewMammalMeshes._build_dog_mesh(species, pose)
	var group := MammalSpecies.group_for(species)
	if group == MammalSpecies.GROUP_BAT:
		return _build_bat_mesh(species, pose)
	if group == MammalSpecies.GROUP_SEAL:
		return _build_seal_mesh(species, pose)
	if group == MammalSpecies.GROUP_FOWL:
		return _build_fowl_mesh(species, pose)

	var geometry := MammalSpecies.geometry_for(species)
	var colors := MammalSpecies.colors_for(species)
	var body_dims: Vector3 = geometry["body"]
	var scale_factor := MammalSpecies.scale_m(species) / maxf(body_dims.x, 0.01)
	var body_radius := Vector3(body_dims.z, body_dims.y, body_dims.x) * scale_factor * 0.5
	var head_radius := float(geometry["head"]) * scale_factor
	var neck_length := float(geometry["neck"]) * scale_factor
	var leg_length := float(geometry["legs"]) * scale_factor
	var tail_length := float(geometry["tail"]) * scale_factor
	var ear_size := float(geometry.get("ears", 0.0)) * scale_factor
	var horn_length := float(geometry.get("horns", 0.0)) * scale_factor

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var body_pitch := 0.0
	var head_drop := 0.0
	var leg_scale := 1.0
	var body_drop := 0.0
	if pose == MammalSpecies.POSE_GRAZING:
		body_pitch = 0.22
		head_drop = body_radius.y * 0.72
	elif pose == MammalSpecies.POSE_RESTING:
		leg_scale = 0.42
		body_drop = body_radius.y * 0.28

	# The Lower Town street actors are seen up close, so they carry a rounder
	# body/head tessellation than the reference catalog silhouettes.
	var detailed := species in DETAILED_SPECIES
	var body_segments := 10 if detailed else BODY_SEGMENTS
	var body_rings := 6 if detailed else BODY_RINGS

	var body_center := Vector3(0.0, leg_length * leg_scale + body_radius.y * 0.92 - body_drop, 0.0)
	_append_ellipsoid(surface, body_center, body_radius, colors[0], body_segments, body_rings)
	if detailed:
		# Shoulder and haunch masses break the plain "loaf" ellipsoid.
		for hip_sign in [-1.0, 1.0]:
			_append_ellipsoid(
				surface,
				body_center + Vector3(0.0, -body_radius.y * 0.10, hip_sign * body_radius.z * 0.52),
				Vector3(body_radius.x * 1.06, body_radius.y * 0.78, body_radius.z * 0.30),
				colors[0].darkened(0.03),
				6,
				3
			)

	var neck_start := body_center + Vector3(0.0, body_radius.y * 0.18, -body_radius.z * 0.72)
	var neck_end := neck_start + Vector3(
		0.0,
		neck_length * 0.42 - head_drop,
		-neck_length * 0.86 - body_radius.z * 0.18 - body_radius.z * body_pitch
	)
	if neck_length > 0.01:
		_append_tapered_tube(
			surface,
			neck_start,
			neck_end,
			maxf(body_radius.x * 0.28, 0.008),
			maxf(head_radius * 0.62, 0.006),
			colors[0].darkened(0.04),
			RADIAL_SEGMENTS
		)
	else:
		neck_end = neck_start + Vector3(0.0, -head_drop, -body_radius.z * 0.42)

	var head_center := neck_end + Vector3(0.0, head_radius * 0.42, -head_radius * 0.62)
	_append_ellipsoid(
		surface,
		head_center,
		Vector3(head_radius * 0.92, head_radius, head_radius * 0.88),
		colors[1],
		9 if detailed else 7,
		5 if detailed else 4
	)
	_append_snout(surface, head_center, head_radius, colors[2], group, species)
	if ear_size > 0.01:
		_append_ears(surface, head_center, head_radius, ear_size, colors[1], group, species)
	if horn_length > 0.01:
		_append_horns(surface, head_center, head_radius, horn_length, colors[2])
	_append_face_details(surface, head_center, head_radius, colors, species)
	if species == MammalSpecies.SPECIES_CAT:
		_append_chest_patch(surface, body_center, body_radius, colors[2])

	# Cat and rat limbs are furred, not bone-white: the accent colour is reserved
	# for their paws.
	var leg_color := colors[0].darkened(0.14) if detailed else colors[2]
	_append_quadruped_legs(surface, body_center, body_radius, leg_length * leg_scale, leg_color, pose, species, false, colors[2])
	if tail_length > 0.01:
		_append_tail(surface, body_center, body_radius, tail_length, colors[1], group, pose, species)

	return _commit_mesh(surface, species)


static func _commit_mesh(surface: SurfaceTool, species: StringName) -> ArrayMesh:
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, MammalSpecies.surface_material_for(species))
	return mesh


static func _build_bat_mesh(species: StringName, pose: StringName) -> ArrayMesh:
	var geometry := MammalSpecies.geometry_for(species)


	var colors := MammalSpecies.colors_for(species)
	var scale_factor := MammalSpecies.scale_m(species) / maxf(float(geometry["body"].x), 0.01)
	var body_dims: Vector3 = geometry["body"]
	var wing_span := float(geometry.get("wing_span", 0.34)) * scale_factor
	var body_radius := Vector3(body_dims.z, body_dims.y, body_dims.x) * scale_factor * 0.5

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0.0, body_radius.y * 1.2, 0.0)
	_append_ellipsoid(surface, center, body_radius, colors[0], 6, 4)
	var head_center := center + Vector3(0.0, body_radius.y * 0.2, -body_radius.z * 0.9)
	_append_ellipsoid(surface, head_center, Vector3.ONE * body_radius.x * 0.72, colors[1], 5, 3)
	for side_sign in [-1.0, 1.0]:
		var shoulder := center + Vector3(side_sign * body_radius.x * 0.4, 0.0, 0.0)
		var tip := shoulder + Vector3(side_sign * wing_span * 0.5, -wing_span * 0.08, wing_span * 0.12)
		var rear := shoulder + Vector3(-side_sign * wing_span * 0.08, -wing_span * 0.04, -wing_span * 0.18)
		_append_quad(surface, shoulder, tip, rear, center, colors[1])
	if pose == MammalSpecies.POSE_RESTING:
		center.y -= body_radius.y * 0.35
	return _commit_mesh(surface, species)


static func _build_dog_mesh(species: StringName, pose: StringName) -> ArrayMesh:
	var geometry := MammalSpecies.geometry_for(species)
	var colors := MammalSpecies.colors_for(species)
	var scale_factor := MammalSpecies.scale_m(species) / maxf(float(geometry["body"].x), 0.01)
	var body_dims: Vector3 = geometry["body"]
	var body_radius := Vector3(body_dims.z, body_dims.y, body_dims.x) * scale_factor * 0.5
	var head_radius := float(geometry["head"]) * scale_factor
	var neck_length := float(geometry["neck"]) * scale_factor
	var leg_length := float(geometry["legs"]) * scale_factor
	var tail_length := float(geometry["tail"]) * scale_factor
	var ear_size := float(geometry.get("ears", 0.10)) * scale_factor

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	# A dog carries its weight between a deep chest and a compact, muscular rump.
	# Keeping these masses separate avoids the featureless capsule silhouette that
	# made the original street actor read as a toy or a fox-like quadruped.
	var body_center := Vector3(0.0, leg_length + body_radius.y * 0.92, 0.0)
	_append_ellipsoid(surface, body_center, body_radius, colors[0], 7, 4)
	_append_ellipsoid(
		surface,
		body_center + Vector3(0.0, body_radius.y * 0.06, -body_radius.z * 0.38),
		Vector3(body_radius.x * 1.04, body_radius.y * 1.02, body_radius.z * 0.54),
		colors[0].lightened(0.025),
		6,
		3
	)
	_append_ellipsoid(
		surface,
		body_center + Vector3(0.0, -body_radius.y * 0.02, body_radius.z * 0.38),
		Vector3(body_radius.x * 1.02, body_radius.y * 0.94, body_radius.z * 0.56),
		colors[1],
		6,
		3
	)

	var neck_start := body_center + Vector3(0.0, body_radius.y * 0.16, -body_radius.z * 0.70)
	var neck_end := neck_start + Vector3(
		0.0,
		neck_length * 0.86,
		-neck_length * 0.44 - body_radius.z * 0.12
	)
	_append_tapered_tube(
		surface,
		neck_start,
		neck_end,
		body_radius.x * 0.42,
		head_radius * 0.72,
		colors[0].darkened(0.04),
		6
	)
	# A light bib follows the front of the neck into the chest rather than sitting
	# as a perfectly flat decal, which gives the coat break a believable volume.
	_append_ellipsoid(
		surface,
		body_center + Vector3(0.0, body_radius.y * 0.02, -body_radius.z * 0.84),
		Vector3(body_radius.x * 0.52, body_radius.y * 0.64, body_radius.z * 0.10),
		colors[2],
		5,
		3
	)

	var head_center := neck_end + Vector3(0.0, head_radius * 0.12, -head_radius * 0.34)
	_append_ellipsoid(
		surface,
		head_center,
		Vector3(head_radius * 0.98, head_radius * 1.04, head_radius * 1.06),
		colors[1],
		9,
		5
	)
	# The lower jaw gives the long muzzle a stop and a visible mouth line instead
	# of leaving a single cone projected from a featureless head sphere.
	_append_ellipsoid(
		surface,
		head_center + Vector3(0.0, -head_radius * 0.19, -head_radius * 0.72),
		Vector3(head_radius * 0.52, head_radius * 0.25, head_radius * 0.48),
		colors[2].darkened(0.04),
		6,
		3
	)
	_append_snout(surface, head_center, head_radius, colors[2], MammalSpecies.GROUP_CANID, species)
	_append_ears(surface, head_center, head_radius, ear_size, colors[1], MammalSpecies.GROUP_CANID, species)
	_append_face_details(surface, head_center, head_radius, colors, species)
	_append_chest_patch(surface, body_center, body_radius, colors[2])

	# Four articulated legs establish shoulder and hip landmarks. The hind legs
	# bend back through the hock, while the forelegs stay nearly vertical under the
	# deep chest, which is much closer to a real standing dog than four straight rods.
	for side_sign: float in [-1.0, 1.0]:
		_append_dog_leg(surface, body_center, body_radius, leg_length, side_sign, true, colors[0], colors[2])
		_append_dog_leg(surface, body_center, body_radius, leg_length, side_sign, false, colors[1], colors[2])
	_append_tail(surface, body_center, body_radius, tail_length, colors[1], MammalSpecies.GROUP_CANID, pose, species)
	return _commit_mesh(surface, species)


static func _append_dog_leg(
	surface: SurfaceTool,
	body_center: Vector3,
	body_radius: Vector3,
	leg_length: float,
	side_sign: float,
	front_leg: bool,
	color: Color,
	paw_color: Color
) -> void:
	var z_offset := -body_radius.z * 0.36 if front_leg else body_radius.z * 0.36
	var top := body_center + Vector3(side_sign * body_radius.x * 0.43, -body_radius.y * 0.38, z_offset)
	var upper_radius := maxf(leg_length * 0.115, body_radius.x * 0.25)
	var lower_radius := upper_radius * 0.72
	var knee := top + Vector3(0.0, -leg_length * 0.43, leg_length * (0.025 if front_leg else 0.16))
	var ankle := knee + Vector3(0.0, -leg_length * 0.42, -leg_length * (0.06 if front_leg else 0.14))
	_append_tapered_tube(surface, top, knee, upper_radius, lower_radius, color, 5)
	_append_tapered_tube(surface, knee, ankle, lower_radius, lower_radius * 0.68, color.darkened(0.035), 5)
	var paw_length := maxf(leg_length * 0.28, body_radius.x * 0.62)
	var paw_center := ankle + Vector3(0.0, -upper_radius * 0.32, -paw_length * 0.28)
	_append_ellipsoid(
		surface,
		paw_center,
		Vector3(upper_radius * 1.05, upper_radius * 0.60, paw_length * 0.55),
		paw_color,
		4,
		2
	)


static func _build_seal_mesh(species: StringName, pose: StringName) -> ArrayMesh:
	var geometry := MammalSpecies.geometry_for(species)
	var colors := MammalSpecies.colors_for(species)
	var scale_factor := MammalSpecies.scale_m(species) / maxf(float(geometry["body"].x), 0.01)
	var body_dims: Vector3 = geometry["body"]
	var body_radius := Vector3(body_dims.z, body_dims.y, body_dims.x) * scale_factor * 0.5
	var flipper_length := float(geometry["legs"]) * scale_factor

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center_y := body_radius.y * 0.55
	if pose != MammalSpecies.POSE_STANDING:
		center_y -= body_radius.y * 0.18
	var center := Vector3(0.0, center_y, 0.0)
	_append_ellipsoid(surface, center, body_radius, colors[0], BODY_SEGMENTS, BODY_RINGS)
	var head_center := center + Vector3(0.0, body_radius.y * 0.08, -body_radius.z * 0.92)
	_append_ellipsoid(surface, head_center, Vector3(body_radius.x * 0.42, body_radius.y * 0.36, body_radius.z * 0.38), colors[1], 6, 4)
	for side_sign in [-1.0, 1.0]:
		var root := center + Vector3(side_sign * body_radius.x * 0.72, -body_radius.y * 0.18, body_radius.z * 0.12)
		var tip := root + Vector3(side_sign * flipper_length * 0.42, -flipper_length * 0.08, flipper_length * 0.62)
		_append_tapered_tube(surface, root, tip, flipper_length * 0.08, flipper_length * 0.04, colors[2], 5)
	var tail_root := center + Vector3(0.0, 0.0, body_radius.z * 0.82)
	var tail_tip := tail_root + Vector3(0.0, -body_radius.y * 0.12, float(geometry["tail"]) * scale_factor)
	_append_tapered_tube(surface, tail_root, tail_tip, body_radius.x * 0.22, body_radius.x * 0.08, colors[1], 5)
	return _commit_mesh(surface, species)


static func _build_fowl_mesh(species: StringName, pose: StringName) -> ArrayMesh:
	var geometry := MammalSpecies.geometry_for(species)
	var colors := MammalSpecies.colors_for(species)
	var scale_factor := MammalSpecies.scale_m(species) / maxf(float(geometry["body"].x), 0.01)
	var body_dims: Vector3 = geometry["body"]
	var body_radius := Vector3(body_dims.z, body_dims.y, body_dims.x) * scale_factor * 0.5
	var head_radius := float(geometry["head"]) * scale_factor
	var neck_length := float(geometry["neck"]) * scale_factor
	var leg_length := float(geometry["legs"]) * scale_factor

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grazing_drop := head_radius * 0.42 if pose == MammalSpecies.POSE_GRAZING else 0.0
	var body_center := Vector3(0.0, leg_length + body_radius.y * 0.88, 0.0)
	_append_ellipsoid(surface, body_center, body_radius, colors[0], BODY_SEGMENTS, BODY_RINGS)
	var neck_start := body_center + Vector3(0.0, body_radius.y * 0.22 - grazing_drop, -body_radius.z * 0.62)
	var neck_end := neck_start + Vector3(0.0, neck_length * 0.42 - grazing_drop, -neck_length * 0.72)
	_append_tapered_tube(surface, neck_start, neck_end, body_radius.x * 0.22, head_radius * 0.55, colors[0], 5)
	var head_center := neck_end + Vector3(0.0, head_radius * 0.28, -head_radius * 0.72)
	_append_ellipsoid(surface, head_center, Vector3.ONE * head_radius, colors[1], 6, 4)
	_append_beak(surface, head_center, head_radius, colors[2])
	_append_quadruped_legs(surface, body_center, body_radius, leg_length, colors[2], pose, &"", true)
	return _commit_mesh(surface, species)


static func _append_snout(
	surface: SurfaceTool,
	head_center: Vector3,
	head_radius: float,
	color: Color,
	group: StringName,
	species: StringName = &""
) -> void:
	var length := head_radius * (0.42 if group == MammalSpecies.GROUP_SWINE else 0.28)
	if group == MammalSpecies.GROUP_RODENT:
		length = head_radius * 0.52
	elif group == MammalSpecies.GROUP_FELID:
		length = head_radius * 0.20
	elif species == MammalSpecies.SPECIES_DOG:
		# A village dog reads by its long, defined muzzle; the generic canid nub
		# collapses into the head at street range.
		length = head_radius * 0.55
	var root := head_center + Vector3(0.0, -head_radius * 0.08, -head_radius * 0.82)
	var tip := root + Vector3(0.0, -length * 0.12, -length)
	var start_radius := head_radius * (0.30 if group == MammalSpecies.GROUP_RODENT else 0.24)
	var end_radius := head_radius * 0.08
	if species == MammalSpecies.SPECIES_DOG:
		start_radius = head_radius * 0.30
		end_radius = head_radius * 0.11
	_append_tapered_tube(surface, root, tip, start_radius, end_radius, color, 6)


static func _append_beak(surface: SurfaceTool, head_center: Vector3, head_radius: float, color: Color) -> void:
	var root := head_center + Vector3(0.0, -head_radius * 0.04, -head_radius * 0.78)
	var tip := root + Vector3(0.0, -head_radius * 0.08, -head_radius * 0.62)
	_append_tapered_tube(surface, root, tip, head_radius * 0.16, 0.002, color, 4)


static func _append_ears(
	surface: SurfaceTool,
	head_center: Vector3,
	head_radius: float,
	ear_size: float,
	color: Color,
	group: StringName,
	species: StringName = &""
) -> void:
	for side_sign in [-1.0, 1.0]:
		var base := head_center + Vector3(side_sign * head_radius * 0.62, head_radius * 0.42, -head_radius * 0.12)
		if group == MammalSpecies.GROUP_LAGOMORPH:
			var tip := base + Vector3(side_sign * ear_size * 0.08, ear_size, -ear_size * 0.12)
			_append_tapered_tube(surface, base, tip, ear_size * 0.10, ear_size * 0.04, color, 5)
		elif species == MammalSpecies.SPECIES_RAT:
			# Rats read by their round, dish-like ears, so they get real volume
			# instead of the generic cone every other mammal uses.
			var ear_center := base + Vector3(side_sign * ear_size * 0.08, ear_size * 0.34, 0.0)
			_append_ellipsoid(
				surface,
				ear_center,
				Vector3(ear_size * 0.42, ear_size * 0.48, ear_size * 0.15),
				color.lightened(0.08),
				5,
				2
			)
			_append_ellipsoid(
				surface,
				ear_center + Vector3(0.0, 0.0, -ear_size * 0.11),
				Vector3(ear_size * 0.24, ear_size * 0.29, ear_size * 0.05),
				Color("b98278"),
				4,
				2
			)
		elif species == MammalSpecies.SPECIES_CAT or species == MammalSpecies.SPECIES_DOG:
			# A flat triangle disappears when the animal is viewed from the side, so
			# the ear is a small closed pyramid with a pink inner face. Dog ears are
			# the same pricked spitz shape, only with a darker inner face.
			var inner_color := Color("c38f83") if species == MammalSpecies.SPECIES_CAT else Color("8a5a48")
			var apex := base + Vector3(side_sign * ear_size * 0.22, ear_size * 1.05, -ear_size * 0.06)
			var front := base + Vector3(side_sign * ear_size * 0.10, 0.0, -ear_size * 0.34)
			var back := base + Vector3(side_sign * ear_size * 0.10, 0.0, ear_size * 0.30)
			var outer := base + Vector3(side_sign * ear_size * 0.46, ear_size * 0.10, 0.0)
			_append_colored_triangle(surface, front, outer, apex, color)
			_append_colored_triangle(surface, outer, back, apex, color)
			_append_colored_triangle(surface, back, front, apex, inner_color)
			_append_colored_triangle(surface, front, back, outer, color.darkened(0.08))
		else:
			var tip := base + Vector3(side_sign * ear_size * 0.22, ear_size * 0.72, -ear_size * 0.08)
			_append_tapered_tube(surface, base, tip, ear_size * 0.14, ear_size * 0.06, color, 5)


static func _append_face_details(
	surface: SurfaceTool,
	head_center: Vector3,
	head_radius: float,
	colors: Array[Color],
	species: StringName
) -> void:
	if species not in [MammalSpecies.SPECIES_CAT, MammalSpecies.SPECIES_DOG, MammalSpecies.SPECIES_RAT]:
		return
	var is_cat := species == MammalSpecies.SPECIES_CAT
	var is_dog := species == MammalSpecies.SPECIES_DOG
	var muzzle_color := colors[2] if is_cat or is_dog else colors[1].lightened(0.12)
	# The dog muzzle is longer than the cat/rat snout, so its nose and muzzle
	# patches sit further forward.
	var muzzle_z := head_radius * (1.00 if is_dog else 0.91)
	var nose_z := head_radius * (1.36 if is_dog else 1.14)
	var nose_drop := head_radius * (0.15 if is_dog else 0.12)
	for side_sign in [-1.0, 1.0]:
		var muzzle_center := head_center + Vector3(
			side_sign * head_radius * 0.18,
			-head_radius * 0.16,
			-muzzle_z
		)
		_append_ellipsoid(
			surface,
			muzzle_center,
			Vector3(head_radius * 0.28, head_radius * 0.22, head_radius * 0.16),
			muzzle_color,
			4,
			2
		)
		var eye_center := head_center + Vector3(
			side_sign * head_radius * 0.48,
			head_radius * 0.16,
			-head_radius * 0.72
		)
		# Cats get the amber iris; dogs and rats keep the small black bead.
		_append_ellipsoid(
			surface,
			eye_center,
			Vector3(head_radius * 0.075, head_radius * 0.10, head_radius * 0.055),
			Color("c7a94d") if is_cat else Color("171512"),
			4,
			2
		)
		if is_cat:
			_append_ellipsoid(
				surface,
				eye_center + Vector3(0.0, 0.0, -head_radius * 0.048),
				Vector3(head_radius * 0.016, head_radius * 0.062, head_radius * 0.010),
				Color("171512"),
				3,
				2
			)
	var nose_center := head_center + Vector3(0.0, -nose_drop, -nose_z)
	# A dog nose is a wet black leather pad, not the pink rodent nose.
	var nose_color := Color("352927") if is_cat else Color("bc7e78")
	if is_dog:
		nose_color = Color("1b1512")
	_append_ellipsoid(
		surface,
		nose_center,
		Vector3(head_radius * 0.14, head_radius * 0.09, head_radius * 0.08),
		nose_color,
		4,
		2
	)
	if is_dog:
		# Dog whiskers are near-invisible at street range; skip them and keep the
		# triangle budget for the muzzle and tail instead.
		return
	for side_sign in [-1.0, 1.0]:
		for whisker_index in 2:
			var vertical_spread := (float(whisker_index) - 0.5) * head_radius * 0.16
			var whisker_root := nose_center + Vector3(
				side_sign * head_radius * 0.11,
				vertical_spread,
				head_radius * 0.015
			)
			var whisker_tip := whisker_root + Vector3(
				side_sign * head_radius * (0.42 + whisker_index * 0.06),
				vertical_spread * 0.25,
				-head_radius * (0.02 + whisker_index * 0.04)
			)
			_append_tapered_tube(
				surface,
				whisker_root,
				whisker_tip,
				head_radius * 0.009,
				head_radius * 0.003,
				Color("d6d0c4"),
				3
			)


static func _append_chest_patch(
	surface: SurfaceTool,
	body_center: Vector3,
	body_radius: Vector3,
	color: Color
) -> void:
	_append_ellipsoid(
		surface,
		body_center + Vector3(0.0, -body_radius.y * 0.08, -body_radius.z * 0.88),
		Vector3(body_radius.x * 0.42, body_radius.y * 0.52, body_radius.z * 0.06),
		color,
		4,
		2
	)


static func _append_horns(
	surface: SurfaceTool,
	head_center: Vector3,
	head_radius: float,
	horn_length: float,
	color: Color
) -> void:
	for side_sign in [-1.0, 1.0]:
		var base := head_center + Vector3(side_sign * head_radius * 0.34, head_radius * 0.62, -head_radius * 0.18)
		var tip := base + Vector3(side_sign * horn_length * 0.18, horn_length, horn_length * 0.08)
		_append_tapered_tube(surface, base, tip, horn_length * 0.05, horn_length * 0.02, color, 4)


static func _append_quadruped_legs(
	surface: SurfaceTool,
	body_center: Vector3,
	body_radius: Vector3,
	leg_length: float,
	color: Color,
	pose: StringName,
	species: StringName = &"",
	bird_like: bool = false,
	paw_color: Color = Color.WHITE
) -> void:
	if leg_length <= 0.01:
		return
	var offsets: Array[Vector3] = [
		Vector3(-body_radius.x * 0.42, 0.0, -body_radius.z * 0.34),
		Vector3(body_radius.x * 0.42, 0.0, -body_radius.z * 0.34),
		Vector3(-body_radius.x * 0.42, 0.0, body_radius.z * 0.34),
		Vector3(body_radius.x * 0.42, 0.0, body_radius.z * 0.34),
	]
	for offset: Vector3 in offsets:
		var top: Vector3 = body_center + offset + Vector3(0.0, -body_radius.y * 0.42, 0.0)
		var bend := leg_length * 0.18 if pose == MammalSpecies.POSE_RESTING else 0.0
		var bottom: Vector3 = top + Vector3(0.0, -leg_length + bend, bend * 0.4)
		# Short-legged animals need the body width as a floor for limb thickness,
		# otherwise the legs render as bare threads.
		var upper_radius := maxf(leg_length * 0.09, body_radius.x * 0.24) if species in DETAILED_SPECIES else leg_length * 0.06
		_append_tapered_tube(surface, top, bottom, upper_radius, upper_radius * 0.68, color, 5)
		if bird_like:
			for toe_index in 3:
				var spread := float(toe_index - 1) * leg_length * 0.12
				var toe_end: Vector3 = bottom + Vector3(spread, -leg_length * 0.02, -leg_length * 0.16)
				_append_tapered_tube(surface, bottom, toe_end, leg_length * 0.016, 0.002, color.darkened(0.06), 4)
		elif species in [MammalSpecies.SPECIES_CAT, MammalSpecies.SPECIES_RAT]:
			var paw_length := maxf(leg_length * 0.30, body_radius.x * 0.62)
			var paw_center := bottom + Vector3(0.0, -upper_radius * 0.35, -paw_length * 0.28)
			_append_ellipsoid(
				surface,
				paw_center,
				Vector3(upper_radius * 1.05, upper_radius * 0.62, paw_length * 0.55),
				paw_color,
				4,
				2
			)


static func _append_tail(
	surface: SurfaceTool,
	body_center: Vector3,
	body_radius: Vector3,
	tail_length: float,
	color: Color,
	group: StringName,
	pose: StringName = &"",
	species: StringName = &""
) -> void:
	var root := body_center + Vector3(0.0, 0.0, body_radius.z * 0.82)
	if species == MammalSpecies.SPECIES_RAT:
		# A segmented, ground-hugging taper reads as a rat tail instead of the old
		# rigid spike, especially when viewed from the isometric gameplay camera.
		var bend_side := body_radius.x * 0.46
		var first := root + Vector3(bend_side * 0.34, -body_radius.y * 0.38, tail_length * 0.34)
		var second := root + Vector3(bend_side, -body_radius.y * 0.50, tail_length * 0.70)
		var tip := root + Vector3(bend_side * 0.70, -body_radius.y * 0.52, tail_length)
		_append_tapered_tube(surface, root, first, body_radius.x * 0.30, body_radius.x * 0.21, color, 6)
		_append_tapered_tube(surface, first, second, body_radius.x * 0.21, body_radius.x * 0.13, color.lightened(0.05), 6)
		_append_tapered_tube(surface, second, tip, body_radius.x * 0.13, body_radius.x * 0.05, color.lightened(0.10), 6)
		return
	if species == MammalSpecies.SPECIES_CAT:
		var resting_drop := -body_radius.y * 0.52 if pose == MammalSpecies.POSE_RESTING else 0.0
		var first := root + Vector3(body_radius.x * 0.58, body_radius.y * 0.18 + resting_drop, tail_length * 0.34)
		var second := root + Vector3(body_radius.x * 0.86, body_radius.y * 0.58 + resting_drop, tail_length * 0.70)
		var tip := root + Vector3(body_radius.x * 0.54, body_radius.y * 0.92 + resting_drop, tail_length)
		_append_tapered_tube(surface, root, first, body_radius.x * 0.34, body_radius.x * 0.30, color, 6)
		_append_tapered_tube(surface, first, second, body_radius.x * 0.30, body_radius.x * 0.24, color, 6)
		_append_tapered_tube(surface, second, tip, body_radius.x * 0.24, body_radius.x * 0.14, color.lightened(0.04), 6)
		return
	var tip := root + Vector3(0.0, body_radius.y * 0.08, tail_length)
	if group == MammalSpecies.GROUP_MUSTELID:
		_append_tapered_tube(surface, root, tip, body_radius.x * 0.12, body_radius.x * 0.04, color, 5)
	else:
		_append_quad(
			surface,
			root + Vector3(-body_radius.x * 0.18, 0.0, 0.0),
			root + Vector3(body_radius.x * 0.18, 0.0, 0.0),
			tip + Vector3(body_radius.x * 0.10, 0.0, 0.0),
			tip + Vector3(-body_radius.x * 0.10, 0.0, 0.0),
			color
		)


static func _append_ellipsoid(
	surface: SurfaceTool,
	center: Vector3,
	radius: Vector3,
	color: Color,
	segments: int,
	rings: int
) -> void:
	for ring_index in rings:
		var latitude_a := -PI * 0.5 + PI * float(ring_index) / float(rings)
		var latitude_b := -PI * 0.5 + PI * float(ring_index + 1) / float(rings)
		for segment_index in segments:
			var longitude_a := TAU * float(segment_index) / float(segments)
			var longitude_b := TAU * float(segment_index + 1) / float(segments)
			var a := center + _ellipsoid_point(radius, latitude_a, longitude_a)
			var b := center + _ellipsoid_point(radius, latitude_a, longitude_b)
			var c := center + _ellipsoid_point(radius, latitude_b, longitude_b)
			var d := center + _ellipsoid_point(radius, latitude_b, longitude_a)
			_append_colored_triangle(surface, a, b, c, color)
			_append_colored_triangle(surface, a, c, d, color)


static func _ellipsoid_point(radius: Vector3, latitude: float, longitude: float) -> Vector3:
	var latitude_cos := cos(latitude)
	return Vector3(
		radius.x * latitude_cos * cos(longitude),
		radius.y * sin(latitude),
		radius.z * latitude_cos * sin(longitude)
	)


static func _append_tapered_tube(
	surface: SurfaceTool,
	start: Vector3,
	end: Vector3,
	start_radius: float,
	end_radius: float,
	color: Color,
	segments: int
) -> void:
	var direction := end - start
	if direction.length_squared() < 0.000001:
		return
	var axis := direction.normalized()
	var tangent := axis.cross(Vector3.UP)
	if tangent.length_squared() < 0.0001:
		tangent = axis.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := axis.cross(tangent).normalized()
	for segment_index in segments:
		var angle_a := TAU * float(segment_index) / float(segments)
		var angle_b := TAU * float(segment_index + 1) / float(segments)
		var radial_a := tangent * cos(angle_a) + bitangent * sin(angle_a)
		var radial_b := tangent * cos(angle_b) + bitangent * sin(angle_b)
		var a := start + radial_a * start_radius
		var b := start + radial_b * start_radius
		var c := end + radial_b * end_radius
		var d := end + radial_a * end_radius
		_append_colored_triangle(surface, a, b, c, color)
		_append_colored_triangle(surface, a, c, d, color.darkened(0.035))


static func _append_quad(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	color: Color
) -> void:
	_append_colored_triangle(surface, a, b, c, color)
	_append_colored_triangle(surface, a, c, d, color.darkened(0.025))


static func _append_colored_triangle(
	surface: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color: Color
) -> void:
	for vertex in [a, b, c]:
		surface.set_color(color)
		surface.add_vertex(vertex)
