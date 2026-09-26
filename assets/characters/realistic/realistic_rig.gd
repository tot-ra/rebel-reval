extends SharedCharacterRig
## Realistic MPFB-based human (ADR 0022). Proportions, skin and grooming are
## baked into the imported body; clothes are CharacterWearable layers.

## Wearables equipped on spawn, before any variant wearables.
@export var default_outfit: Array[CharacterWearable] = []


func _ready() -> void:
	super._ready()
	_prepare_groom_materials($Model)
	for wearable: CharacterWearable in default_outfit:
		if not equip_wearable(wearable):
			push_error("%s could not equip default wearable %s" % [name, wearable.stable_id])


func equip_garment(garment_id: StringName, scene: PackedScene) -> bool:
	if not super.equip_garment(garment_id, scene):
		return false
	for mesh_instance: MeshInstance3D in _garments.get(garment_id, []):
		_prepare_groom_materials(mesh_instance)
	return true


## Fur shells (beard, scalp) encode strand length in vertex-colour alpha; glTF
## import leaves vertex colour unused unless the material opts in.
static func _prepare_groom_materials(root: Node) -> void:
	for found: Node in root.find_children("*", "MeshInstance3D", true, false) + [root]:
		var mesh_instance := found as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface) as BaseMaterial3D
			if material == null:
				continue
			var material_name := material.resource_name
			if material_name.ends_with("_fur_cutout"):
				material = material.duplicate() as BaseMaterial3D
				material.vertex_color_use_as_albedo = true
				mesh_instance.set_surface_override_material(surface, material)


func _install_proportion_modifiers() -> void:
	pass


func _configure_lod0_visibility() -> void:
	pass


func _install_distance_lods() -> void:
	pass


func consume_foot_plant() -> StringName:
	if not LOCOMOTION_REFERENCE_SPEED.has(current_canonical_animation()):
		_planted_foot = &""
		return &""
	var player := animation_player()
	if player == null or player.current_animation_length <= 0.0:
		return &""
	# The shared authored walk/run cycles keep both foot bones at nearly the same
	# height while the legs exchange load, so the half-cycle is the contact
	# authority (same contract as the retired kalev_fresh body).
	var phase := fposmod(player.current_animation_position / player.current_animation_length, 1.0)
	var planted := RIGHT_FOOT_BONE if phase < 0.5 else LEFT_FOOT_BONE
	if planted == _planted_foot:
		return &""
	_planted_foot = planted
	return planted
