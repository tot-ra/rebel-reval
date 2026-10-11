class_name SmithyHeldPropFactory
extends RefCounted

## Lightweight view-only held props for domestic activities. These are deliberately
## simple material silhouettes: gameplay inventory/equipment remains untouched.

const _Primitives := preload("res://scripts/map/view3d/map_view_mesh_builder_primitives.gd")


static func create(prop_id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "SmithyHeld_%s" % String(prop_id).replace(".", "_")
	root.set_meta(&"smithy_held_prop", prop_id)
	match prop_id:
		&"water_bucket":
			_Primitives.cylinder(root, "Bucket", 0.14, 0.24, Vector3(0.0, -0.12, 0.0), &"wood")
			var handle := MeshInstance3D.new()
			handle.name = "Handle"
			var handle_mesh := TorusMesh.new()
			handle_mesh.inner_radius = 0.145
			handle_mesh.outer_radius = 0.17
			handle.mesh = handle_mesh
			handle.rotation_degrees.x = 90.0
			handle.material_override = _Primitives.role_material(&"metal")
			root.add_child(handle)
		&"cooking_ladle":
			_Primitives.cylinder(root, "Handle", 0.018, 0.46, Vector3(0.0, 0.2, 0.0), &"wood")
			_Primitives.sphere(root, "Bowl", 0.07, Vector3(0.0, -0.055, 0.0), &"wood")
		&"prep_knife":
			_Primitives.box(root, "Handle", Vector3(0.05, 0.18, 0.04), Vector3(0.0, 0.05, 0.0), &"wood")
			_Primitives.box(root, "Blade", Vector3(0.025, 0.22, 0.075), Vector3(0.0, -0.15, 0.0), &"metal")
		&"broom":
			_Primitives.cylinder(root, "Handle", 0.025, 0.92, Vector3(0.0, 0.32, 0.0), &"wood")
			_Primitives.box(root, "Bristles", Vector3(0.24, 0.2, 0.1), Vector3(0.0, -0.25, 0.0), &"hay")
		&"kindling_bundle":
			for index in 4:
				_Primitives.cylinder(
					root,
					"Kindling%d" % index,
					0.025,
					0.42,
					Vector3((index - 1.5) * 0.045, 0.0, (index % 2) * 0.025),
					&"wood"
				)
		&"wash_cloth":
			_Primitives.box(root, "Cloth", Vector3(0.18, 0.24, 0.025), Vector3(0.0, -0.08, 0.0), &"plaster")
		&"bellows_handle":
			_Primitives.cylinder(root, "Handle", 0.035, 0.34, Vector3(0.0, 0.0, 0.0), &"wood")
		&"forge_hammer":
			var hammer_scene := load("res://assets/characters/shared/hammer.tscn") as PackedScene
			if hammer_scene != null:
				var hammer := hammer_scene.instantiate() as Node3D
				root.add_child(hammer)
		_:
			return null
	return root
