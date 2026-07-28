class_name MapViewFishingNetModels
extends RefCounted

## Shared access to the authored fishing net rack. The rrmap still owns placement,
## footprint, collision, and navigation; this helper supplies visual geometry only.

const FISHING_NETS_SCENE_PATH := "res://assets/props/crafts/fishing_nets.glb"
const _ANIMATED_PARTS := {
	&"Netting": &"hemp",
	&"OutlineRope": &"hemp",
	&"Floats": &"float",
	&"Sinkers": &"sinker",
}


static func add_model(parent: Node3D) -> Node3D:
	var scene := load(FISHING_NETS_SCENE_PATH) as PackedScene
	assert(scene != null, "Fishing nets GLB must be imported before map assembly")
	var model := scene.instantiate() as Node3D
	assert(model != null, "Fishing nets GLB root must be Node3D")
	model.name = "FishingNetsModel"
	model.set_meta(&"production_fishing_nets_model", true)
	parent.add_child(model)
	_apply_wind_materials(model, parent)
	return model


static func _apply_wind_materials(model: Node3D, parent: Node3D) -> void:
	# WHY: each rack needs a small deterministic phase offset to prevent identical
	# synchronized motion, but materials still share the global weather uniforms.
	var phase := fposmod(float(String(parent.name).hash()) * 0.000173, TAU)
	for node_name: StringName in _ANIMATED_PARTS:
		var mesh := model.find_child(String(node_name), true, false) as MeshInstance3D
		assert(mesh != null, "Fishing nets GLB is missing animated part %s" % node_name)
		if mesh == null:
			continue
		var source: ShaderMaterial
		match _ANIMATED_PARTS[node_name] as StringName:
			&"float":
				source = MapViewMaterials.fishing_net_float()
			&"sinker":
				source = MapViewMaterials.fishing_net_sinker()
			_:
				source = MapViewMaterials.fishing_net_hemp()
		mesh.material_override = source
		mesh.set_instance_shader_parameter("motion_phase", phase)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin = 0.2
		mesh.set_meta(&"wind_animated", true)
