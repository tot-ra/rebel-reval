extends CatRig
## Preserve forge routines and the SharedCharacterRig-facing API.
const CLIPS := {&"idle": &"Idle", &"walk": &"Walk", &"sleep": &"Sleep", &"lick": &"Groom", &"stretch": &"Stretch"}

func has_animation(canonical_name: StringName) -> bool:
	return _animation_player != null and _animation_player.has_animation(CLIPS.get(canonical_name, &""))

func play_animation(canonical_name: StringName, blend_seconds: float = 0.12) -> bool:
	if not has_animation(canonical_name):
		return false
	var clip: StringName = CLIPS[canonical_name]
	_current_canonical_animation = canonical_name
	if _animation_player.current_animation != clip:
		_animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if canonical_name in LOOPING_CAT_ANIMATIONS else Animation.LOOP_NONE
		_animation_player.play(clip, blend_seconds)
	return true

func current_canonical_animation() -> StringName:
	return _current_canonical_animation

func _snap_model_to_ground() -> void:
	play_animation(&"idle", 0.0)
	_animation_player.seek(0.0, true)
	var min_y := _measure_mesh_min_y()
	if min_y != INF:
		$Model.position.y -= min_y - GROUND_SNAP_EPSILON

func view_glyph_height() -> float:
	return 0.68

func apply_coat(variant_seed: int) -> StringName:
	var coat := CatCoatVariants.coat_for_seed(variant_seed)
	var colors := {&"tabby_brown": Color("805b40"), &"tabby_grey": Color("797d80"), &"black": Color("34363d"), &"ginger": Color("b97844"), &"white_black": Color("c4c1b6")}
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.mesh = mesh.mesh.duplicate()
		for surface: int in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null or source.resource_name not in ["ginger", "stripe", "forge_cat_coat"]:
				continue
			var fur := source.duplicate() as StandardMaterial3D
			if source.resource_name == "forge_cat_coat":
				# Tint the textured tabby surface; retain its fur and facial detail.
				var tints := {&"tabby_brown": Color(0.90, 0.76, 0.62), &"tabby_grey": Color(0.80, 0.83, 0.86), &"black": Color(0.22, 0.23, 0.25), &"ginger": Color(1.0, 0.72, 0.45), &"white_black": Color.WHITE}
				fur.albedo_color = tints[coat]
			else:
				fur.albedo_color = colors[coat] if source.resource_name == "ginger" else (colors[coat] as Color).darkened(0.35)
			mesh.mesh.surface_set_material(surface, fur)
	scale = Vector3.ONE * CatCoatVariants.scale_for_seed(variant_seed)
	set_meta(&"cat_coat", coat)
	return coat
