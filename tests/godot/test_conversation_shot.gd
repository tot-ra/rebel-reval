extends "res://tests/godot/test_case.gd"

## R-1888: the universal conversation camera sees the faces (it searches for an angle no drawn
## mesh blocks), cuts to the speaker over the listener's shoulder and hands the view back.

const ConversationShotScript := preload("res://scripts/prologue/conversation_shot.gd")
const ShotOcclusion := preload("res://scripts/prologue/shot_occlusion.gd")


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


## A 1.8 m capsule standing with its feet at `at`.
func _person(world: Node3D, at: Vector3, height: float = 1.8) -> Node3D:
	var person := Node3D.new()
	world.add_child(person)
	person.global_position = at
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = height
	capsule.radius = 0.25
	body.mesh = capsule
	person.add_child(body)
	body.position = Vector3.UP * height * 0.5
	return person


## A box mesh standing on the floor, centred at `center` (x/z) with `size`.
func _wall(world: Node3D, center: Vector3, size: Vector3) -> MeshInstance3D:
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	wall.mesh = box
	world.add_child(wall)
	wall.global_position = center + Vector3.UP * size.y * 0.5
	return wall


func _stage() -> Dictionary:
	var world := Node3D.new()
	_root().add_child(world)
	var gameplay := Camera3D.new()
	world.add_child(gameplay)
	gameplay.global_position = Vector3(1, 6, 8)
	gameplay.current = true
	var hero := _person(world, Vector3.ZERO, 1.6)
	var smith := _person(world, Vector3(2, 0, 0), 1.85)
	return {"world": world, "camera": gameplay, "hero": hero, "smith": smith}


func test_a_mesh_between_lens_and_face_blocks_the_ray() -> void:
	var world := Node3D.new()
	_root().add_child(world)
	var hero := _person(world, Vector3.ZERO)
	_wall(world, Vector3(0, 0, 2), Vector3(4, 3, 0.2))
	var occlusion := ShotOcclusion.new()
	occlusion.collect(world, Vector3.ZERO, 8.0, [hero])
	assert_eq(occlusion.occluder_count(), 1, "the subject's own mesh is ignored")
	assert_true(occlusion.blocked(Vector3(0, 1.5, 4), Vector3(0, 1.5, 0)), "the wall blocks")
	assert_false(occlusion.blocked(Vector3(0, 1.5, -4), Vector3(0, 1.5, 0)), "the other side is clear")
	# Bounds alone are not enough: a ray past the wall's end is clear.
	var past_end := occlusion.blocked(Vector3(3, 1.5, 4), Vector3(3, 1.5, 0))
	assert_false(past_end, "triangle test, not bounds")
	world.free()


func test_two_shot_turns_away_from_a_wall_that_hides_the_faces() -> void:
	var stage := _stage()
	var world: Node3D = stage["world"]
	# A wall right where the preferred angle (the gameplay camera's side, +z) would stand.
	_wall(world, Vector3(1, 0, 1.4), Vector3(9, 3, 0.2))
	var shot: Node = ConversationShotScript.new()
	world.add_child(shot)
	var subjects: Array[Node3D] = [stage["hero"], stage["smith"]]
	shot.frame_subjects(world, subjects, Vector3.ZERO, 0.0)
	assert_true(shot.camera != null and shot.camera.current, "the shot camera is current")
	assert_eq(shot.shot_kind, "two_shot")
	var eye: Vector3 = shot.camera.global_position
	var occlusion := ShotOcclusion.new()
	occlusion.collect(world, Vector3(1, 0, 0), 8.0, subjects)
	var faces: Array = [Vector3(0, 1.45, 0), Vector3(2, 1.7, 0)]
	assert_eq(occlusion.visible_count(eye, faces), 2, "both faces are seen past the wall")
	assert_true(eye.z < 1.4, "the camera did not stand behind the wall")
	shot.release()
	assert_true((stage["camera"] as Camera3D).current, "the gameplay camera is handed back")
	world.free()


func test_a_line_cuts_over_the_listeners_shoulder_after_the_opening_line() -> void:
	var stage := _stage()
	var world: Node3D = stage["world"]
	var hero: Node3D = stage["hero"]
	var smith: Node3D = stage["smith"]
	var shot: Node = ConversationShotScript.new()
	world.add_child(shot)
	var subjects: Array[Node3D] = [hero, smith]
	shot.frame_subjects(world, subjects, Vector3.ZERO, 0.0)
	var side: float = shot.call(&"_side_of", shot.camera.global_position)
	shot.cue_line(smith)
	assert_eq(shot.shot_kind, "two_shot", "the first line plays on the establishing shot")
	shot.cue_line(smith)
	assert_eq(shot.shot_kind, "shoulder")
	assert_true(shot.focused == smith)
	var eye: Vector3 = shot.camera.global_position
	var to_hero := eye.distance_to(hero.global_position)
	assert_true(to_hero < eye.distance_to(smith.global_position), "behind the boy")
	var forward: Vector3 = -shot.camera.global_basis.z
	assert_true(forward.dot((smith.global_position - eye).normalized()) > 0.9, "looking at the smith")
	assert_eq(shot.call(&"_side_of", eye), side, "the reverse shot keeps the screen side")
	# The reply: the boy, over the smith's shoulder, same side of the line.
	shot.focus(hero)
	var reverse: Vector3 = shot.camera.global_position
	assert_true(reverse.distance_to(smith.global_position) < reverse.distance_to(hero.global_position))
	assert_eq(shot.call(&"_side_of", reverse), side)
	shot.release()
	world.free()


func test_release_with_blend_cranes_back_to_the_gameplay_camera() -> void:
	var stage := _stage()
	var world: Node3D = stage["world"]
	var shot: Node = ConversationShotScript.new()
	world.add_child(shot)
	var subjects: Array[Node3D] = [stage["hero"], stage["smith"]]
	shot.frame_subjects(world, subjects, Vector3.ZERO, 0.0)
	var done := [false]
	shot.released.connect(func() -> void: done[0] = true)
	shot.release(1.0)
	assert_true(shot.is_releasing(), "the camera rises before the cut back")
	assert_false((stage["camera"] as Camera3D).current, "still on the shot camera while rising")
	# Ignored while rising: a line arriving now must not cut away from the crane.
	shot.focus(stage["smith"])
	assert_true(shot.focused == null)
	shot.release()
	assert_true(done[0], "released fires")
	assert_true((stage["camera"] as Camera3D).current)
	world.free()
