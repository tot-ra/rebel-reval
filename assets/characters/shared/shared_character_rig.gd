extends Node3D

class_name SharedCharacterRig

const CANONICAL_ANIMATIONS: Dictionary = {
	&"idle": &"Idle",
	&"walk": &"Walking_A",
	&"forge_strike": &"1H_Melee_Attack_Chop",
	&"hammer_attack": &"1H_Melee_Attack_Slice_Diagonal",
	&"guard": &"Blocking",
	&"hit": &"Hit_A",
	&"fall": &"Death_A",
}
const LOOPING_ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"guard"]
const VENDOR_EQUIPMENT_NAMES: Array[StringName] = [
	&"1H_Axe_Offhand",
	&"Barbarian_Round_Shield",
	&"1H_Axe",
	&"2H_Axe",
	&"Mug",
]
const RIGHT_HAND_BONE := &"hand.r"

@export var variant: CharacterVariant
@export var start_animation: StringName = &"idle"
@export_range(0.1, 5.0, 0.01) var visible_height_world: float = 2.0

var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _equipment_attachment: BoneAttachment3D

func _ready() -> void:
	_animation_player = _find_animation_player($Model)
	_skeleton = _find_skeleton($Model)
	_hide_vendor_equipment()
	_apply_variant()
	play_animation(start_animation)

func canonical_animation_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for canonical_name: StringName in CANONICAL_ANIMATIONS:
		names.append(canonical_name)
	return names

func source_animation_name(canonical_name: StringName) -> StringName:
	return CANONICAL_ANIMATIONS.get(canonical_name, &"") as StringName

func has_animation(canonical_name: StringName) -> bool:
	if _animation_player == null:
		return false
	var source_name := source_animation_name(canonical_name)
	return not source_name.is_empty() and _animation_player.has_animation(source_name)

func play_animation(canonical_name: StringName, blend_seconds: float = 0.12) -> bool:
	if not has_animation(canonical_name):
		push_warning("Unknown character animation: %s" % canonical_name)
		return false
	var source_name := source_animation_name(canonical_name)
	var animation := _animation_player.get_animation(source_name)
	if canonical_name in LOOPING_ANIMATIONS:
		animation.loop_mode = Animation.LOOP_LINEAR
	else:
		animation.loop_mode = Animation.LOOP_NONE
	_animation_player.play(source_name, blend_seconds)
	return true

func set_facing(logic_direction: Vector2) -> void:
	if logic_direction.is_zero_approx():
		return
	# Logic Y maps to world Z in the P0-052 bridge. The imported rig faces +Z.
	rotation.y = atan2(logic_direction.x, logic_direction.y)

func current_canonical_animation() -> StringName:
	if _animation_player == null:
		return &""
	var source_name := _animation_player.current_animation
	for canonical_name: StringName in CANONICAL_ANIMATIONS:
		if CANONICAL_ANIMATIONS[canonical_name] == source_name:
			return canonical_name
	return &""

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if _animation_player == null:
		errors.append("Rig has no AnimationPlayer")
	if _skeleton == null:
		errors.append("Rig has no Skeleton3D")
	elif _skeleton.find_bone(String(RIGHT_HAND_BONE)) < 0:
		errors.append("Rig has no %s equipment bone" % RIGHT_HAND_BONE)
	for canonical_name: StringName in CANONICAL_ANIMATIONS:
		if not has_animation(canonical_name):
			errors.append("Missing %s animation (%s)" % [
				canonical_name,
				source_animation_name(canonical_name),
			])
	if variant == null:
		errors.append("Rig has no CharacterVariant resource")
	return errors

func variant_id() -> StringName:
	if variant == null:
		return &""
	return variant.stable_id

func has_equipment() -> bool:
	return _equipment_attachment != null and _equipment_attachment.get_child_count() > 0

func skeleton() -> Skeleton3D:
	return _skeleton

func animation_player() -> AnimationPlayer:
	return _animation_player

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child: Node in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child: Node in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _hide_vendor_equipment() -> void:
	for node_name: StringName in VENDOR_EQUIPMENT_NAMES:
		var equipment_node := $Model.find_child(String(node_name), true, false) as Node3D
		if equipment_node != null:
			equipment_node.visible = false
	var cape := $Model.find_child("Barbarian_Cape", true, false) as Node3D
	if cape != null:
		cape.visible = variant != null and variant.show_cape
	var hat := $Model.find_child("Barbarian_Hat", true, false) as Node3D
	if hat != null:
		hat.visible = variant != null and variant.show_hat

func _apply_variant() -> void:
	if variant == null:
		return
	_tint_meshes($Model, variant.material_tint)
	if _skeleton == null or variant.equipment == null:
		return
	_equipment_attachment = BoneAttachment3D.new()
	_equipment_attachment.name = "EquipmentRightHand"
	_equipment_attachment.bone_name = String(RIGHT_HAND_BONE)
	_skeleton.add_child(_equipment_attachment)
	_equipment_attachment.add_child(variant.equipment.instantiate())

func _tint_meshes(root: Node, tint: Color) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			if source_material is BaseMaterial3D:
				var tinted_material := source_material.duplicate() as BaseMaterial3D
				tinted_material.albedo_color *= tint
				mesh_instance.set_surface_override_material(surface_index, tinted_material)
	for child: Node in root.get_children():
		_tint_meshes(child, tint)

