extends "res://tests/godot/test_case.gd"

const Models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const PennedFauna := preload("res://scripts/map/view3d/map_view_penned_fauna.gd")
const UrbanFauna := preload("res://scripts/map/view3d/map_view_urban_fauna.gd")


func test_production_models_load_with_mesh_material_and_ground_contact() -> void:
	for species: StringName in [MammalSpecies.SPECIES_CHICKEN, MammalSpecies.SPECIES_DUCK, MammalSpecies.SPECIES_GOOSE, &"goat", MammalSpecies.SPECIES_COW, MammalSpecies.SPECIES_PIG, MammalSpecies.SPECIES_SHEEP, MammalSpecies.SPECIES_HORSE]:
		var host := Node3D.new()
		var model := Models.add_model(host, species)
		assert_true(model != null, "%s needs an imported production model" % species)
		assert_true(model.get_meta(&"production_animal_model", false))
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		assert_true(meshes.size() >= 1, "%s GLB needs render geometry" % species)
		var mesh_instance := model.find_child("AnimalMesh", true, false) as MeshInstance3D
		if mesh_instance == null:
			mesh_instance = meshes[0] as MeshInstance3D
		assert_true(mesh_instance.mesh.get_surface_count() >= 1)
		assert_true(mesh_instance.mesh.surface_get_material(0) != null, "%s needs portable PBR material" % species)
		var aabb := mesh_instance.get_aabb()
		assert_true(absf(aabb.position.y) < 0.001, "%s feet must touch Y=0" % species)
		host.free()


func test_static_fowl_models_receive_a_distance_synced_procedural_gait() -> void:
	for species: StringName in Models.PROCEDURAL_FOWL:
		var host := Node3D.new()
		var model := Models.add_model(host, species)
		assert_true(model != null)
		assert_true(host.has_meta(Models.PROCEDURAL_GAIT_MODEL_META), "%s needs a gait pivot" % species)
		var pivot := host.get_meta(Models.PROCEDURAL_GAIT_MODEL_META) as Node3D
		assert_true(pivot != null)
		assert_eq(model.get_parent(), pivot)
		Models.sync_animation(host, host.position - Vector3(0.08, 0.0, 0.0), 0.1)
		assert_true(absf(pivot.rotation.x) > 0.0001 or absf(pivot.rotation.z) > 0.0001)
		assert_true(pivot.position.y > 0.0, "%s walk should lift the body between planted steps" % species)
		for _idle_step in 12:
			Models.sync_animation(host, host.position, 0.1)
		assert_true(is_zero_approx(pivot.position.y))
		assert_true(is_zero_approx(pivot.rotation.x))
		assert_true(is_zero_approx(pivot.rotation.z))
		host.free()


func test_domestic_goose_uses_the_detailed_authored_greylag_model() -> void:
	assert_eq(
		Models.MODEL_PATHS[MammalSpecies.SPECIES_GOOSE],
		"res://assets/birds/greylag_goose/standing.glb"
	)
	var host := Node3D.new()
	var model := Models.add_model(host, MammalSpecies.SPECIES_GOOSE)
	assert_true(model != null)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() >= 1)
	var goose_mesh := meshes[0] as MeshInstance3D
	assert_true(goose_mesh.mesh.get_surface_count() >= 7, "Goose needs distinct feather, bill, eye, leg, and foot materials")
	assert_true(goose_mesh.get_aabb().size.y >= 0.75, "Goose needs its authored long-neck silhouette")
	host.free()


func test_pig_has_realistic_rigged_body_and_locomotion_clips() -> void:
	var host := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var model := Models.add_model(host, MammalSpecies.SPECIES_PIG)
	assert_true(model != null)
	var mesh := model.find_child("AnimalMesh", true, false) as MeshInstance3D
	assert_true(mesh != null)
	var aabb := mesh.get_aabb()
	assert_true(aabb.size.x >= 1.30, "Pig must keep a low, long landrace silhouette")
	assert_true(aabb.size.x < 1.50, "Pig must not inherit an inflated scan/helper bound")
	assert_true(aabb.size.y >= 0.70, "Pig legs and back must retain plausible standing height")
	assert_true(aabb.size.y < 0.85, "Pig must retain a low landrace body profile")
	assert_true(aabb.size.z >= 0.45, "Pig chest must retain believable load-bearing width")
	assert_true(aabb.size.z < 0.55, "Pig must not become an over-wide generic blob")
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	assert_true(skeletons.size() >= 1, "Pig needs an imported skeleton")
	var skeleton := skeletons[0] as Skeleton3D
	for bone_name: StringName in [&"FrontLeftLeg", &"FrontRightLeg", &"BackLeftLeg", &"BackRightLeg"]:
		assert_true(skeleton.find_bone(bone_name) >= 0, "%s needs four authored weight-bearing leg bones" % bone_name)
	assert_true(mesh.mesh.get_surface_count() == 1, "Pig body must remain one portable production surface")
	var eye_left := model.find_child("EyeLeft", true, false) as Node3D
	var eye_right := model.find_child("EyeRight", true, false) as Node3D
	assert_true(eye_left != null)
	assert_true(eye_right != null)
	assert_true(eye_left.global_position.x < -0.40, "Pig eyes must sit on the head side of the body")
	assert_true(eye_right.global_position.x < -0.40, "Pig eyes must sit on the head side of the body")
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert_true(players.size() >= 1, "Pig needs imported skeletal animation")
	var player := players[0] as AnimationPlayer
	assert_true(player.has_animation(Models.IDLE_ANIMATION))
	assert_true(player.has_animation(Models.WALK_ANIMATION))
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	Models.sync_animation(host, host.position - Vector3(0.1, 0.0, 0.0), 0.1)
	assert_eq(player.current_animation, Models.WALK_ANIMATION)
	host.free()


func test_cattle_has_broad_rigged_body_eyes_tail_and_locomotion_clips() -> void:
	var host := Node3D.new()
	var model := Models.add_model(host, MammalSpecies.SPECIES_COW)
	assert_true(model != null)
	var mesh := model.find_child("AnimalMesh", true, false) as MeshInstance3D
	assert_true(mesh != null)
	var aabb := mesh.get_aabb()
	assert_true(aabb.size.z >= 1.0, "Cattle must keep a broad, readable body silhouette")
	assert_true(model.find_child("EyeLeft", true, false) != null, "Cattle needs a visible left eye")
	assert_true(model.find_child("EyeRight", true, false) != null, "Cattle needs a visible right eye")
	assert_true(model.find_child("TailTuft", true, false) != null, "Cattle needs an articulated tail")
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert_true(players.size() >= 1, "Cattle needs imported skeletal animation")
	var player := players[0] as AnimationPlayer
	assert_true(player != null, "Cattle needs imported skeletal animation")
	assert_true(player.has_animation(Models.IDLE_ANIMATION), "Idle must animate tail, head, and blinking eyes")
	assert_true(player.has_animation(Models.WALK_ANIMATION), "Walk must animate legs and tail")
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	Models.sync_animation(host, host.position - Vector3(0.1, 0.0, 0.0), 0.1)
	assert_eq(player.current_animation, Models.WALK_ANIMATION)
	Models.sync_animation(host, host.position, 0.1)
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	host.free()


func test_sheep_has_rigged_body_tail_and_locomotion_clips() -> void:
	var host := Node3D.new()
	var model := Models.add_model(host, MammalSpecies.SPECIES_SHEEP)
	assert_true(model != null)
	var mesh := model.find_child("AnimalMesh", true, false) as MeshInstance3D
	assert_true(mesh != null)
	var aabb := mesh.get_aabb()
	assert_true(aabb.size.z >= 0.45, "Sheep must keep a compact fleece silhouette")
	assert_true(model.find_child("TailTuft", true, false) != null, "Sheep needs an articulated tail")
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert_true(players.size() >= 1, "Sheep needs imported skeletal animation")
	var player := players[0] as AnimationPlayer
	assert_true(player.has_animation(Models.IDLE_ANIMATION))
	assert_true(player.has_animation(Models.WALK_ANIMATION))
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	Models.sync_animation(host, host.position - Vector3(0.1, 0.0, 0.0), 0.1)
	assert_eq(player.current_animation, Models.WALK_ANIMATION)
	Models.sync_animation(host, host.position, 0.1)
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	host.free()


func test_pack_horse_has_tall_rigged_body_tail_and_locomotion_clips() -> void:
	var host := Node3D.new()
	var model := Models.add_model(host, MammalSpecies.SPECIES_HORSE)
	assert_true(model != null)
	var mesh := model.find_child("AnimalMesh", true, false) as MeshInstance3D
	assert_true(mesh != null)
	var aabb := mesh.get_aabb()
	assert_true(aabb.size.y >= 1.2, "Pack horse must keep a tall readable silhouette")
	assert_true(model.find_child("TailTuft", true, false) != null, "Pack horse needs an articulated tail")
	var players := model.find_children("*", "AnimationPlayer", true, false)
	assert_true(players.size() >= 1, "Pack horse needs imported skeletal animation")
	var player := players[0] as AnimationPlayer
	assert_true(player.has_animation(Models.IDLE_ANIMATION))
	assert_true(player.has_animation(Models.WALK_ANIMATION))
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	Models.sync_animation(host, host.position - Vector3(0.1, 0.0, 0.0), 0.1)
	assert_eq(player.current_animation, Models.WALK_ANIMATION)
	Models.sync_animation(host, host.position, 0.1)
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	host.free()


func test_pack_horse_walk_keeps_four_hooves_at_ground_contact() -> void:
	var host := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var model := Models.add_model(host, MammalSpecies.SPECIES_HORSE)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var walk := player.get_animation(Models.WALK_ANIMATION)
	assert_true(walk != null, "Pack horse must expose the imported Walk clip")
	assert_eq(Models.horse_hoof_contact_points(skeleton).size(), Models.HORSE_LEG_BONES.size())

	# Sample start, both diagonal transitions, and the loop endpoint.
	for phase in 5:
		player.seek(walk.length * float(phase) / 4.0, true)
		skeleton.force_update_all_bone_transforms()
		var contacts := Models.horse_hoof_contact_points(skeleton)
		for bone_name: StringName in Models.HORSE_LEG_BONES:
			var contact := contacts[bone_name] as Vector3
			assert_true(
				contact.y >= Models.HORSE_GROUND_MIN_Y and contact.y <= Models.HORSE_GROUND_MAX_Y,
				"%s hoof leaves the ground envelope at Walk phase %d: %s" % [bone_name, phase, contact]
			)

	host.free()


func test_medieval_livestock_carry_normal_and_roughness_maps() -> void:
	for species: StringName in [
		MammalSpecies.SPECIES_COW,
		MammalSpecies.SPECIES_PIG,
		MammalSpecies.SPECIES_SHEEP,
		MammalSpecies.SPECIES_HORSE,
	]:
		var host := Node3D.new()
		var model := Models.add_model(host, species)
		assert_true(model != null, "%s production model must load" % species)
		var mesh_instance := model.find_child("AnimalMesh", true, false) as MeshInstance3D
		assert_true(mesh_instance != null, "%s needs AnimalMesh" % species)
		_assert_livestock_pbr_material(mesh_instance.mesh.surface_get_material(0), species)
		host.free()


func _assert_livestock_pbr_material(material: Material, label: String) -> void:
	assert_true(material is StandardMaterial3D, "%s must import as StandardMaterial3D" % label)
	var std := material as StandardMaterial3D
	assert_ne(
		std.shading_mode,
		BaseMaterial3D.SHADING_MODE_UNSHADED,
		"%s must react to scene lighting" % label
	)
	assert_true(std.normal_enabled and std.normal_texture != null, "%s needs hide/wool normal map" % label)
	assert_true(
		std.roughness_texture != null or (std.roughness > 0.05 and std.roughness < 1.0),
		"%s needs authored roughness response" % label
	)


func test_static_livestock_props_use_production_models() -> void:
	for kind: StringName in [MapTypes.PROP_KIND_CATTLE, MapTypes.PROP_KIND_SHEEP, MapTypes.PROP_KIND_HORSE]:
		var prop := MapViewMeshBuilder.build_prop({"id": kind, "kind": kind, "position": Vector2.ZERO}, MapTypes.DEFAULT_CELL_SIZE)
		assert_true((prop.get_node("Model") as Node3D).get_meta(&"production_animal_model", false))
		prop.free()


func test_ambient_livestock_actors_share_production_models_without_collision() -> void:
	var penned := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(penned)
	penned.configure(&"north_quarter", MammalSpecies.CONTEXT_MARKET, 32)
	for actor in penned.get_children():
		assert_true((actor.get_node("Model") as Node3D).get_meta(&"production_animal_model", false))
		assert_false(penned.actor_has_collision(actor))
	penned.queue_free()

	var urban := UrbanFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(urban)
	urban.configure(&"south_quarter", MammalSpecies.CONTEXT_TOOMPEA, 32)
	for actor in urban.get_children():
		if actor.get_meta(&"species", &"") == MammalSpecies.SPECIES_HORSE:
			assert_true((actor.get_node("Model") as Node3D).get_meta(&"production_animal_model", false))
		assert_false(urban.actor_has_collision(actor))
	urban.queue_free()
