extends Node3D

class_name SharedCharacterRig

const CANONICAL_ANIMATIONS: Dictionary = {
	&"idle": &"Idle",
	&"walk": &"Walking_A",
	&"run": &"Running_B",
	&"forge_strike": &"1H_Melee_Attack_Chop",
	&"hammer_attack": &"1H_Melee_Attack_Slice_Diagonal",
	&"guard": &"Blocking",
	&"hit": &"Hit_A",
	&"fall": &"Death_A",
	&"talk_gesture": &"Interact",
	&"sit_down": &"Sit_Chair_Down",
	&"sit_idle": &"Sit_Chair_Idle",
	&"sit_up": &"Sit_Chair_StandUp",
}
const LOOPING_ANIMATIONS: Array[StringName] = [
	&"idle",
	&"walk",
	&"run",
	&"guard",
	&"sit_idle",
]

## Ground speed (world units/s) at which each locomotion cycle looks right at
## 1x playback; set_locomotion_speed stretches playback around these so feet
## track the ground instead of skating.
const LOCOMOTION_REFERENCE_SPEED: Dictionary = {
	&"walk": 2.6,
	&"run": 5.5,
}
const LOCOMOTION_SPEED_SCALE_MIN := 0.7
const LOCOMOTION_SPEED_SCALE_MAX := 1.5
const TURN_SMOOTHING := 10.0
const RIGHT_HAND_BONE := &"hand.r"

## Named bone-attachment points for rigid equipment (weapons, tools, props).
## Hands use the dedicated handslot grip bones so props sit in the palm.
const EQUIPMENT_SLOTS: Dictionary = {
	&"right_hand": &"handslot.r",
	&"left_hand": &"handslot.l",
	&"head": &"head",
	&"back": &"chest",
}

## Skinned garments authored against the shared skeleton by
## tools/generate_hero_body.py; they deform with the body.
const GARMENT_SCENES: Dictionary = {
	&"cape": preload("res://assets/characters/shared/hero_cape.glb"),
	&"hat": preload("res://assets/characters/shared/hero_hat.glb"),
}
## Uniform: the generated body is authored at adult proportions, so no
## anisotropic correction is needed — only normalization to the 2.0-unit
## visible height contract (2.0 / BODY_STATURE from the generator log).
const HEROIC_MODEL_SCALE := Vector3(1.1621, 1.1621, 1.1621)

## Per-scene override for non-hero bodies: a body scene generated from a
## different spec sets this to 2.0 / its own BODY_STATURE.
@export var model_scale: Vector3 = HEROIC_MODEL_SCALE
const OCCLUDED_SILHOUETTE_SHADER := preload("res://assets/characters/shared/occluded_silhouette.gdshader")
const HEAD_SCALE_MODIFIER := preload("res://assets/characters/shared/head_scale_modifier.gd")

static var _occluded_silhouette_material: ShaderMaterial

@export var variant: CharacterVariant
@export var start_animation: StringName = &"idle"
@export_range(0.1, 5.0, 0.01) var visible_height_world: float = 2.0

var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _slot_attachments: Dictionary = {}
var _garments: Dictionary = {}
var _occlusion_ghost := false

func _ready() -> void:
	# Apply the authored anisotropic normalization in code because inherited
	# imported-scene transforms can be reset to identity during instantiation.
	$Model.scale = model_scale
	_animation_player = _find_animation_player($Model)
	_skeleton = _find_skeleton($Model)
	_apply_variant()
	_install_head_scale()
	play_animation(start_animation)

## Adult proportions are baked into the generated heroic_humanoid.glb; the
## modifier stays neutral by default and exists as a per-variant fine-tune
## hook (slightly different head/limb builds without new meshes).
func _install_head_scale() -> void:
	if _skeleton == null:
		return
	var modifier := HEAD_SCALE_MODIFIER.new()
	modifier.name = "RealisticProportions"
	_skeleton.add_child(modifier)

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

## Frame-rate independent turn toward a logic direction; use instead of
## set_facing for continuous movement so direction changes read as a turn
## rather than a snap.
func face_toward(logic_direction: Vector2, delta: float) -> void:
	if logic_direction.is_zero_approx():
		return
	var target := atan2(logic_direction.x, logic_direction.y)
	var weight := 1.0 - exp(-TURN_SMOOTHING * delta)
	rotation.y = lerp_angle(rotation.y, target, weight)

## Matches locomotion playback rate to actual ground speed (world units/s).
## Non-locomotion animations always play at their authored rate.
func set_locomotion_speed(world_speed: float) -> void:
	if _animation_player == null:
		return
	var canonical := current_canonical_animation()
	if not LOCOMOTION_REFERENCE_SPEED.has(canonical):
		_animation_player.speed_scale = 1.0
		return
	var reference: float = LOCOMOTION_REFERENCE_SPEED[canonical]
	_animation_player.speed_scale = clampf(
		world_speed / reference,
		LOCOMOTION_SPEED_SCALE_MIN,
		LOCOMOTION_SPEED_SCALE_MAX
	)

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

## Shows a translucent silhouette wherever view geometry hides this rig so the
## character stays readable behind buildings. The overlay's inverted depth test
## only draws on occluded fragments; keeping it off while fully visible avoids
## ghost tint where the rig's own limbs overlap its body.
func set_occlusion_ghost(enabled: bool) -> void:
	if _occlusion_ghost == enabled:
		return
	_occlusion_ghost = enabled
	_apply_overlay(self, _silhouette_material() if enabled else null)

func occlusion_ghost_enabled() -> bool:
	return _occlusion_ghost

static func _silhouette_material() -> ShaderMaterial:
	if _occluded_silhouette_material == null:
		_occluded_silhouette_material = ShaderMaterial.new()
		_occluded_silhouette_material.shader = OCCLUDED_SILHOUETTE_SHADER
	return _occluded_silhouette_material

static func _apply_overlay(root: Node, overlay: Material) -> void:
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_overlay = overlay
	for child: Node in root.get_children():
		_apply_overlay(child, overlay)

func variant_id() -> StringName:
	if variant == null:
		return &""
	return variant.stable_id

func has_equipment() -> bool:
	return equipped(&"right_hand") != null

## Mounts a rigid prop scene on a named bone slot, replacing whatever the
## slot held. Returns the mounted instance, or null for an unknown slot.
func equip(slot: StringName, scene: PackedScene) -> Node3D:
	if _skeleton == null or not EQUIPMENT_SLOTS.has(slot) or scene == null:
		push_warning("Cannot equip on slot %s" % slot)
		return null
	unequip(slot)
	var attachment: BoneAttachment3D = _slot_attachments.get(slot)
	if attachment == null:
		attachment = BoneAttachment3D.new()
		attachment.name = "Slot_%s" % slot
		attachment.bone_name = String(EQUIPMENT_SLOTS[slot])
		_skeleton.add_child(attachment)
		_slot_attachments[slot] = attachment
	var instance := scene.instantiate() as Node3D
	attachment.add_child(instance)
	if _occlusion_ghost:
		_apply_overlay(instance, _silhouette_material())
	return instance

func unequip(slot: StringName) -> void:
	var attachment: BoneAttachment3D = _slot_attachments.get(slot)
	if attachment == null:
		return
	for child: Node in attachment.get_children():
		child.queue_free()

func equipped(slot: StringName) -> Node3D:
	var attachment: BoneAttachment3D = _slot_attachments.get(slot)
	if attachment == null:
		return null
	for child: Node in attachment.get_children():
		if not child.is_queued_for_deletion():
			return child as Node3D
	return null

## Mounts a skinned garment (a glb whose meshes are skinned to the shared
## skeleton) so it deforms with the body — clothes rather than props.
func equip_garment(garment_id: StringName, scene: PackedScene) -> bool:
	if _skeleton == null or scene == null:
		return false
	unequip_garment(garment_id)
	var source := scene.instantiate()
	var mounted: Array[MeshInstance3D] = []
	for found: Node in source.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		mesh_instance.get_parent().remove_child(mesh_instance)
		mesh_instance.name = "Garment_%s_%s" % [garment_id, mesh_instance.name]
		_skeleton.add_child(mesh_instance)
		mesh_instance.skeleton = NodePath("..")
		mesh_instance.transform = Transform3D.IDENTITY
		if _occlusion_ghost:
			_apply_overlay(mesh_instance, _silhouette_material())
		mounted.append(mesh_instance)
	source.free()
	if mounted.is_empty():
		return false
	_garments[garment_id] = mounted
	return true

func unequip_garment(garment_id: StringName) -> void:
	var mounted: Array = _garments.get(garment_id, [])
	for mesh_instance: MeshInstance3D in mounted:
		mesh_instance.queue_free()
	_garments.erase(garment_id)

func has_garment(garment_id: StringName) -> bool:
	return _garments.has(garment_id)

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

func _apply_variant() -> void:
	if variant == null:
		return
	_tint_meshes($Model, variant.material_tint)
	if _skeleton == null:
		return
	if variant.equipment != null:
		equip(&"right_hand", variant.equipment)
	if variant.show_cape:
		equip_garment(&"cape", GARMENT_SCENES[&"cape"])
	if variant.show_hat:
		equip_garment(&"hat", GARMENT_SCENES[&"hat"])

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

