class_name ProceduralChickenModel
extends RefCounted

## Builds a compact, texture-free farm chicken from Godot primitive meshes.
## Articulated pivots keep the silhouette readable while allowing runtime clips
## to animate the head, wings, tail, body, and legs without an imported rig.

const IDLE_ANIMATION := &"Idle"
const WALK_ANIMATION := &"Walk"

const FEATHER_BROWN := Color("#76513a")
const FEATHER_DARK := Color("#332b26")
const FEATHER_CREAM := Color("#c7ad83")
const SKIN_RED := Color("#a62d32")
const BEAK_GOLD := Color("#d99a35")
const LEG_GOLD := Color("#b77b32")
const EYE_DARK := Color("#171311")


static func create() -> Node3D:
	var model := Node3D.new()
	model.name = "Model"
	model.set_meta(&"procedural_animal_model", true)

	var rig := Node3D.new()
	rig.name = "Rig"
	model.add_child(rig)

	var body_pivot := Node3D.new()
	body_pivot.name = "BodyPivot"
	body_pivot.position = Vector3(0.0, 0.285, 0.015)
	rig.add_child(body_pivot)
	_add_grounded_sphere(
		body_pivot, "AnimalMesh", Vector3(0.0, -0.08, 0.0),
		Vector3(0.19, 0.16, 0.245), FEATHER_BROWN
	)
	_add_sphere(
		body_pivot, "Breast", Vector3(0.0, 0.015, -0.145),
		Vector3(0.155, 0.145, 0.16), FEATHER_CREAM
	)

	var neck_pivot := Node3D.new()
	neck_pivot.name = "NeckPivot"
	neck_pivot.position = Vector3(0.0, 0.075, -0.185)
	body_pivot.add_child(neck_pivot)
	_add_sphere(neck_pivot, "Neck", Vector3(0.0, 0.035, -0.005), Vector3(0.115, 0.15, 0.12), FEATHER_CREAM)
	_add_sphere(neck_pivot, "Head", Vector3(0.0, 0.145, -0.055), Vector3(0.1, 0.095, 0.11), FEATHER_CREAM)
	_add_beak(neck_pivot)
	_add_face_details(neck_pivot)

	_add_wing(body_pivot, "WingLeft", -1.0)
	_add_wing(body_pivot, "WingRight", 1.0)
	_add_tail(body_pivot)
	_add_leg(rig, "LegLeft", -0.072)
	_add_leg(rig, "LegRight", 0.072)

	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	var library := AnimationLibrary.new()
	library.add_animation(IDLE_ANIMATION, _build_idle_animation())
	library.add_animation(WALK_ANIMATION, _build_walk_animation())
	player.add_animation_library(&"", library)
	return model


static func _add_wing(parent: Node3D, wing_name: String, side: float) -> void:
	var pivot := Node3D.new()
	pivot.name = wing_name
	pivot.position = Vector3(side * 0.145, 0.025, -0.005)
	pivot.rotation.z = side * deg_to_rad(8.0)
	parent.add_child(pivot)
	_add_sphere(
		pivot, "Feathers", Vector3(side * 0.025, -0.015, 0.025),
		Vector3(0.035, 0.105, 0.17), FEATHER_DARK
	)
	_add_sphere(
		pivot, "Coverts", Vector3(side * 0.03, 0.035, -0.02),
		Vector3(0.025, 0.075, 0.115), FEATHER_BROWN
	)


static func _add_tail(parent: Node3D) -> void:
	var pivot := Node3D.new()
	pivot.name = "TailPivot"
	pivot.position = Vector3(0.0, 0.07, 0.205)
	pivot.rotation.x = deg_to_rad(56.0)
	parent.add_child(pivot)
	for feather_index in 5:
		var side := float(feather_index - 2)
		_add_capsule(
			pivot,
			"TailFeather%d" % feather_index,
			Vector3(side * 0.025, 0.085 + absf(side) * 0.008, 0.0),
			Vector3(0.025, 0.12 - absf(side) * 0.008, 0.018),
			FEATHER_DARK if feather_index % 2 == 0 else FEATHER_BROWN,
			Vector3(0.0, 0.0, side * deg_to_rad(10.0))
		)


static func _add_leg(parent: Node3D, leg_name: String, x: float) -> void:
	var pivot := Node3D.new()
	pivot.name = leg_name
	pivot.position = Vector3(x, 0.19, 0.045)
	parent.add_child(pivot)
	_add_cylinder(pivot, "Shank", Vector3(0.0, -0.095, 0.0), 0.012, 0.19, LEG_GOLD)
	_add_segment(pivot, "ForwardToe", Vector3(0.0, -0.19, -0.002), Vector3(0.0, -0.19, -0.075), 0.008, LEG_GOLD)
	_add_segment(pivot, "OuterToe", Vector3(0.0, -0.19, -0.006), Vector3(signf(x) * 0.045, -0.19, -0.055), 0.007, LEG_GOLD)
	_add_segment(pivot, "BackToe", Vector3(0.0, -0.19, 0.002), Vector3(0.0, -0.185, 0.045), 0.007, LEG_GOLD)


static func _add_beak(parent: Node3D) -> void:
	var beak := _add_cone(
		parent, "Beak", Vector3(0.0, 0.14, -0.16), 0.038, 0.105, BEAK_GOLD
	)
	beak.rotation.x = -PI * 0.5


static func _add_face_details(parent: Node3D) -> void:
	for side: float in [-1.0, 1.0]:
		_add_sphere(
			parent, "EyeLeft" if side < 0.0 else "EyeRight",
			Vector3(side * 0.075, 0.178, -0.095), Vector3(0.014, 0.014, 0.01), EYE_DARK
		)
	for comb_index in 3:
		_add_sphere(
			parent, "Comb%d" % comb_index,
			Vector3(0.0, 0.236 + float(comb_index % 2) * 0.009, -0.06 + comb_index * 0.035),
			Vector3(0.025, 0.038, 0.025), SKIN_RED
		)
	_add_sphere(parent, "Wattle", Vector3(0.0, 0.095, -0.13), Vector3(0.027, 0.045, 0.024), SKIN_RED)


static func _build_idle_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 2.4
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_rotation_track(animation, "Rig/BodyPivot", Vector3.ZERO, Vector3(0.0, 0.0, deg_to_rad(1.5)), 1.2)
	_add_rotation_track(animation, "Rig/BodyPivot/NeckPivot", Vector3.ZERO, Vector3(deg_to_rad(7.0), 0.0, 0.0), 0.75)
	_add_rotation_track(animation, "Rig/BodyPivot/TailPivot", Vector3(deg_to_rad(56.0), 0.0, 0.0), Vector3(deg_to_rad(56.0), deg_to_rad(8.0), 0.0), 1.2)
	_add_rotation_track(animation, "Rig/BodyPivot/WingLeft", Vector3(0.0, 0.0, -deg_to_rad(8.0)), Vector3(0.0, 0.0, -deg_to_rad(11.0)), 1.2)
	_add_rotation_track(animation, "Rig/BodyPivot/WingRight", Vector3(0.0, 0.0, deg_to_rad(8.0)), Vector3(0.0, 0.0, deg_to_rad(11.0)), 1.2)
	return animation


static func _build_walk_animation() -> Animation:
	var animation := Animation.new()
	animation.length = 0.52
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_rotation_track(animation, "Rig/LegLeft", Vector3(-deg_to_rad(24.0), 0.0, 0.0), Vector3(deg_to_rad(24.0), 0.0, 0.0), 0.26)
	_add_rotation_track(animation, "Rig/LegRight", Vector3(deg_to_rad(24.0), 0.0, 0.0), Vector3(-deg_to_rad(24.0), 0.0, 0.0), 0.26)
	_add_rotation_track(animation, "Rig/BodyPivot", Vector3(0.0, 0.0, -deg_to_rad(4.0)), Vector3(0.0, 0.0, deg_to_rad(4.0)), 0.26)
	_add_rotation_track(animation, "Rig/BodyPivot/NeckPivot", Vector3(-deg_to_rad(9.0), 0.0, 0.0), Vector3(deg_to_rad(8.0), 0.0, 0.0), 0.26)
	_add_rotation_track(animation, "Rig/BodyPivot/TailPivot", Vector3(deg_to_rad(56.0), -deg_to_rad(7.0), 0.0), Vector3(deg_to_rad(56.0), deg_to_rad(7.0), 0.0), 0.26)
	_add_position_track(animation, "Rig/BodyPivot", Vector3(0.0, 0.285, 0.015), Vector3(0.0, 0.297, 0.015), 0.13)
	return animation


static func _add_rotation_track(
	animation: Animation, node_path: String, first: Vector3, second: Vector3, midpoint: float
) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(node_path + ":rotation"))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	animation.track_insert_key(track, 0.0, first)
	animation.track_insert_key(track, midpoint, second)
	animation.track_insert_key(track, animation.length, first)


static func _add_position_track(
	animation: Animation, node_path: String, first: Vector3, second: Vector3, midpoint: float
) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(node_path + ":position"))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	animation.track_insert_key(track, 0.0, first)
	animation.track_insert_key(track, midpoint, second)
	animation.track_insert_key(track, midpoint * 2.0, first)
	animation.track_insert_key(track, midpoint * 3.0, second)
	animation.track_insert_key(track, animation.length, first)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	return material


static func _add_sphere(
	parent: Node3D, node_name: String, position: Vector3, scale: Vector3, color: Color
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _material(color)
	return _add_mesh(parent, node_name, mesh, position, scale)


static func _add_capsule(
	parent: Node3D, node_name: String, position: Vector3, scale: Vector3, color: Color,
	rotation: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 4
	mesh.material = _material(color)
	var instance := _add_mesh(parent, node_name, mesh, position, scale)
	instance.rotation = rotation
	return instance


static func _add_cylinder(
	parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, color: Color
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = _material(color)
	return _add_mesh(parent, node_name, mesh, position, Vector3.ONE)


static func _add_grounded_sphere(
	parent: Node3D, node_name: String, position: Vector3, scale: Vector3, color: Color
) -> MeshInstance3D:
	var source := SphereMesh.new()
	source.radius = 0.5
	source.height = 1.0
	source.radial_segments = 16
	source.rings = 8
	var arrays := source.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex_index in vertices.size():
		vertices[vertex_index].y += 0.5
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material(color))
	return _add_mesh(parent, node_name, mesh, position, scale)


static func _add_cone(
	parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, color: Color
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = _material(color)
	return _add_mesh(parent, node_name, mesh, position, Vector3.ONE)


static func _add_segment(
	parent: Node3D, node_name: String, start: Vector3, finish: Vector3, radius: float, color: Color
) -> MeshInstance3D:
	var direction := finish - start
	var segment := _add_cylinder(parent, node_name, (start + finish) * 0.5, radius, direction.length(), color)
	segment.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return segment


static func _add_mesh(
	parent: Node3D, node_name: String, mesh: Mesh, position: Vector3, scale: Vector3
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.scale = scale
	parent.add_child(instance)
	return instance
