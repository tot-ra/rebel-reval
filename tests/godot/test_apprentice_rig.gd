extends "res://tests/godot/test_case.gd"

## ADR 0033: the playable hero is the 15-year-old orphan apprentice on the
## shared rig, and the player rig bootstrap spawns him instead of Kalev.

const APPRENTICE := preload("res://assets/characters/variants/apprentice.tscn")
const BOOTSTRAP := preload("res://scripts/map/view3d/map_view_runtime_bootstrap.gd")
const WORLD_HOST := preload("res://scripts/world/world_host.gd")
const OUTFITS_PATH := "res://assets/characters/realistic/apprentice/outfits.json"

var rig: SharedCharacterRig


func before_each() -> void:
	super.before_each()
	rig = APPRENTICE.instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)


func after_each() -> void:
	SharedCharacterRig._detach_render_geometry(rig)
	rig.free()
	super.after_each()


func test_keeps_shared_rig_and_every_clip() -> void:
	assert_eq(rig.validation_errors(), [])
	assert_eq(rig.skeleton().get_bone_count(), 71)
	assert_true(rig.skeleton().find_bone("handslot.r") >= 0)
	assert_true(rig.animation_player().get_animation_list().size() >= 76)
	for motion: StringName in [&"idle", &"walk", &"run", &"hammer_attack", &"guard"]:
		assert_true(rig.play_animation(motion, 0.0), "missing %s" % motion)


func test_variant_is_the_apprentice() -> void:
	assert_eq(rig.variant_id(), &"char.apprentice")


func test_is_smaller_than_the_master_smith() -> void:
	var apprentice := _body_height(rig)
	var kalev := load("res://assets/characters/kalev/kalev.tscn").instantiate() as SharedCharacterRig
	(Engine.get_main_loop() as SceneTree).root.add_child(kalev)
	var master := _body_height(kalev)
	SharedCharacterRig._detach_render_geometry(kalev)
	kalev.free()
	assert_true(apprentice > 0.0 and apprentice < master * 0.95, "apprentice %.2f vs Kalev %.2f" % [apprentice, master])


func test_named_outfits_cover_the_prologue_and_the_forge() -> void:
	var outfits: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTFITS_PATH))
	for outfit: String in ["almshouse", "work", "street", "travel"]:
		assert_true(outfits.has(outfit), "missing outfit %s" % outfit)
	assert_false(outfits["almshouse"].has("boots"), "almshouse orphan is unshod")


func test_player_rig_scenes_spawn_the_apprentice() -> void:
	assert_eq(BOOTSTRAP.PLAYER_RIG_SCENE.resource_path, APPRENTICE.resource_path)
	assert_eq(WORLD_HOST.PLAYER_RIG_SCENE_PATH, APPRENTICE.resource_path)


func _body_height(node: SharedCharacterRig) -> float:
	var top := -INF
	var bottom := INF
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null or not mesh.name.begins_with("Anatomy_"):
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		top = maxf(top, box.end.y)
		bottom = minf(bottom, box.position.y)
	return top - bottom
