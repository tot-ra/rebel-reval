extends SharedCharacterRig
## Realistic MPFB-based human (ADR 0022). Proportions, skin and grooming are
## baked into the imported body; clothes are CharacterWearable layers.

## Wearables equipped on spawn, before any variant wearables.
@export var default_outfit: Array[CharacterWearable] = []


func _ready() -> void:
	super._ready()
	for wearable: CharacterWearable in default_outfit:
		if not equip_wearable(wearable):
			push_error("%s could not equip default wearable %s" % [name, wearable.stable_id])
	# Default outfit can add skinned meshes after the shared _ready walk.
	enable_authored_vertex_color_albedo($Model)


func equip_garment(garment_id: StringName, scene: PackedScene) -> bool:
	if not super.equip_garment(garment_id, scene):
		return false
	for mesh_instance: MeshInstance3D in _garments.get(garment_id, []):
		enable_authored_vertex_color_albedo(mesh_instance)
	return true


## Legacy show_cape/show_hat flags mount garments fitted to the retired
## procedural hero; realistic bodies dress only through fitted wearables.
func _apply_variant() -> void:
	if variant == null:
		return
	_apply_material_stack($Model, variant.material_tint)
	if skeleton() == null:
		return
	if variant.equipment != null:
		equip(&"right_hand", variant.equipment)
	for wearable: CharacterWearable in variant.wearables:
		equip_wearable(wearable)


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
