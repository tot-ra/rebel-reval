extends "res://tests/godot/test_case.gd"

const Models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const PennedFauna := preload("res://scripts/map/view3d/map_view_penned_fauna.gd")
const UrbanFauna := preload("res://scripts/map/view3d/map_view_urban_fauna.gd")


func test_production_models_load_with_mesh_material_and_ground_contact() -> void:
	for species: StringName in [
		MammalSpecies.SPECIES_CHICKEN,
		MammalSpecies.SPECIES_DUCK,
		MammalSpecies.SPECIES_GOOSE,
		&"goat",
		MammalSpecies.SPECIES_COW,
		MammalSpecies.SPECIES_PIG,
		MammalSpecies.SPECIES_SHEEP,
		MammalSpecies.SPECIES_HORSE,
	]:
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
		assert_true(
			mesh_instance.mesh.surface_get_material(0) != null,
			"%s needs portable PBR material" % species
		)
		var aabb := _bounds(model)
		assert_true(
			absf(aabb.position.y) < 0.035, "%s feet must touch Y=0: %s" % [species, aabb.position.y]
		)
		host.free()


func test_imported_domestic_fowl_use_skeletal_locomotion_clips() -> void:
	for species: StringName in [
		MammalSpecies.SPECIES_DUCK,
		MammalSpecies.SPECIES_GOOSE,
	]:
		var host := Node3D.new()
		var model := Models.add_model(host, species)
		assert_true(model != null)
		assert_false(
			host.has_meta(Models.PROCEDURAL_GAIT_MODEL_META),
			"%s must use skeletal gait clips instead of the procedural pivot" % species
		)
		var skeletons := model.find_children("*", "Skeleton3D", true, false)
		assert_true(skeletons.size() >= 1, "%s needs an imported skeleton" % species)
		var skeleton := skeletons[0] as Skeleton3D
		var legs: Array = (
			[&"Leg.L", &"Leg.R"]
			if species == MammalSpecies.SPECIES_DUCK
			else [&"FrontLeftLeg", &"FrontRightLeg", &"BackLeftLeg", &"BackRightLeg"]
		)
		for bone_name: StringName in legs:
			assert_true(
				skeleton.find_bone(bone_name) >= 0,
				"%s is missing authored weight-bearing leg bone %s" % [species, bone_name]
			)
		var players := model.find_children("*", "AnimationPlayer", true, false)
		assert_true(players.size() >= 1, "%s needs imported skeletal animation" % species)
		var player := players[0] as AnimationPlayer
		assert_true(player.has_animation(Models.IDLE_ANIMATION))
		assert_true(player.has_animation(Models.WALK_ANIMATION))
		assert_eq(player.current_animation, Models.IDLE_ANIMATION)
		Models.sync_animation(host, host.position - Vector3(0.08, 0.0, 0.0), 0.1)
		assert_eq(player.current_animation, Models.WALK_ANIMATION)
		Models.sync_animation(host, host.position, 0.1)
		assert_eq(player.current_animation, Models.IDLE_ANIMATION)
		host.free()


func test_legacy_chicken_is_procedural_and_uses_articulated_animation_clips() -> void:
	var host := Node3D.new()
	var model := _legacy_model(host, MammalSpecies.SPECIES_CHICKEN)
	assert_true(model != null)
	assert_true(model.get_meta(&"procedural_animal_model", false))
	for part_name in [
		"AnimalMesh", "NeckPivot", "WingLeft", "WingRight", "TailPivot", "LegLeft", "LegRight",
	]:
		assert_true(model.find_child(part_name, true, false) != null, "Chicken is missing %s" % part_name)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() >= 20, "Procedural chicken needs a detailed primitive silhouette")
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_true(player != null)
	assert_true(player.has_animation(Models.IDLE_ANIMATION))
	assert_true(player.has_animation(Models.WALK_ANIMATION))
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	var walk := player.get_animation(Models.WALK_ANIMATION)
	assert_true(walk.find_track(NodePath("Rig/LegLeft:rotation"), Animation.TYPE_VALUE) >= 0)
	assert_true(walk.find_track(NodePath("Rig/LegRight:rotation"), Animation.TYPE_VALUE) >= 0)
	assert_true(
		walk.find_track(NodePath("Rig/BodyPivot/NeckPivot:rotation"), Animation.TYPE_VALUE) >= 0
	)
	Models.sync_animation(host, host.position - Vector3(0.08, 0.0, 0.0), 0.1)
	assert_eq(player.current_animation, Models.WALK_ANIMATION)
	Models.sync_animation(host, host.position, 0.1)
	assert_eq(player.current_animation, Models.IDLE_ANIMATION)
	host.free()


func test_domestic_goose_uses_the_relocated_storybook_greylag_model() -> void:
	assert_eq(
		Models.MODEL_PATHS[MammalSpecies.SPECIES_GOOSE],
		"res://assets/storybook/goose/goose.glb"
	)
	var host := Node3D.new()
	var model := Models.add_model(host, MammalSpecies.SPECIES_GOOSE)
	assert_true(model != null)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() >= 1)
	var goose_mesh := meshes[0] as MeshInstance3D
	assert_true(
		goose_mesh.mesh.get_surface_count() >= 7,
		"Goose needs distinct feather, bill, eye, leg, and foot materials"
	)
	assert_true(goose_mesh.get_aabb().size.y >= 0.75, "Goose needs its authored long-neck silhouette")
	assert_true(
		is_equal_approx(model.scale.y, 0.45),
		"Domestic goose must down-scale the catalog greylag so it stays yard-sized"
	)
	var world_height := _bounds(host).size.y
	assert_true(
		world_height >= 0.42 and world_height <= 0.72,
		"Domestic goose world height must stay beside hens, not cattle: %s" % world_height
	)
	host.free()


func test_cattle_variants_are_sculpted_rigged_and_walk_nose_first() -> void:
	# Two licensed sculpts share the storybook mammal rig. Seeds pick the coat;
	# both must stand beside the 1.65-unit horse and walk nose-first.
	var seen_paths := {}
	for variant_seed in 2:
		var host := Node3D.new()
		var model := Models.add_model(host, MammalSpecies.SPECIES_COW, variant_seed)
		assert_true(model != null)
		var path := Models.model_path(MammalSpecies.SPECIES_COW, variant_seed)
		seen_paths[path] = true
		var aabb := _bounds(model)
		assert_true(
			aabb.size.y >= 1.40 and aabb.size.y <= 1.60,
			"%s must keep small landrace cattle height: %s" % [path, aabb.size.y]
		)
		assert_true(
			aabb.size.z >= 2.2 and aabb.size.z <= 2.8,
			"%s needs a plausible nose-to-tail length along walk Z: %s" % [path, aabb.size.z]
		)
		assert_true(absf(aabb.position.y) < 0.035, "%s hooves must touch Y=0" % path)
		assert_true(is_equal_approx(model.rotation.y, PI), "Cattle shares grounded mammal yaw")
		# Sculpted sources are exported with the muzzle on mesh +Z; yaw leads walk -Z.
		var nose_after_yaw := model.transform.basis * Vector3(0.0, 0.0, 1.0)
		assert_true(nose_after_yaw.z < -0.5, "Cattle nose must point along walk -Z")
		var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for bone_name: StringName in [&"Body", &"Head", &"Tail", &"Foot.LF", &"Foot.RB"]:
			assert_true(skeleton.find_bone(bone_name) >= 0, "Cattle is missing %s" % bone_name)
		var player := host.get_meta(Models.ANIMATION_PLAYER_META) as AnimationPlayer
		assert_eq(player.current_animation, Models.IDLE_ANIMATION)
		Models.sync_animation(host, host.position - Vector3(0.1, 0.0, 0.0), 0.1)
		assert_eq(player.current_animation, Models.WALK_ANIMATION)
		Models.sync_animation(host, host.position, 0.1)
		assert_eq(player.current_animation, Models.IDLE_ANIMATION)
		host.free()
	assert_eq(seen_paths.size(), Models.COW_VARIANT_PATHS.size(), "Both cattle coats are reachable")


func test_pack_horse_has_tall_rigged_body_tail_and_locomotion_clips() -> void:
	var host := Node3D.new()
	var model := Models.add_model(host, MammalSpecies.SPECIES_HORSE)
	assert_true(model != null)
	var mesh := model.find_child("AnimalMesh", true, false) as MeshInstance3D
	assert_true(mesh != null)
	var aabb := mesh.get_aabb()
	assert_true(aabb.size.y >= 1.2, "Pack horse must keep a tall readable silhouette")
	assert_true(
		model.find_child("TailTuft", true, false) != null,
		"Pack horse needs an articulated tail"
	)
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


func test_legacy_medieval_livestock_carry_normal_and_roughness_maps() -> void:
	for species: StringName in [
		MammalSpecies.SPECIES_COW,
		MammalSpecies.SPECIES_PIG,
		MammalSpecies.SPECIES_SHEEP,
		MammalSpecies.SPECIES_HORSE,
	]:
		var host := Node3D.new()
		var model := _legacy_model(host, species)
		assert_true(model != null, "%s production model must load" % species)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		assert_true(meshes.size() >= 1, "%s needs render geometry" % species)
		var mesh_instance := model.find_child("AnimalMesh", true, false) as MeshInstance3D
		if mesh_instance == null:
			mesh_instance = meshes[0] as MeshInstance3D
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
	assert_true(
		std.normal_enabled and std.normal_texture != null,
		"%s needs hide/wool normal map" % label
	)
	assert_true(
		std.roughness_texture != null or (std.roughness > 0.05 and std.roughness < 1.0),
		"%s needs authored roughness response" % label
	)


func test_static_livestock_props_use_production_models() -> void:
	for kind: StringName in [
		MapTypes.PROP_KIND_CATTLE, MapTypes.PROP_KIND_SHEEP, MapTypes.PROP_KIND_HORSE
	]:
		var prop := MapViewMeshBuilder.build_prop(
			{"id": kind, "kind": kind, "position": Vector2.ZERO}, MapTypes.DEFAULT_CELL_SIZE
		)
		assert_true((prop.get_node("Model") as Node3D).get_meta(&"production_animal_model", false))
		prop.free()


func test_ambient_livestock_actors_share_production_models_without_collision() -> void:
	var penned := PennedFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(penned)
	penned.configure(&"north_quarter", MammalSpecies.CONTEXT_MARKET, 32)
	for actor in penned.fauna_actors():
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


func test_livestock_exposes_idle_walk_trot_and_graze_clips() -> void:
	for species: StringName in [
		MammalSpecies.SPECIES_COW,
		MammalSpecies.SPECIES_PIG,
		MammalSpecies.SPECIES_SHEEP,
		MammalSpecies.SPECIES_HORSE,
	]:
		var host := Node3D.new()
		var model := Models.add_model(host, species)
		assert_true(model != null)
		var players := model.find_children("*", "AnimationPlayer", true, false)
		assert_true(players.size() >= 1, "%s needs skeletal animation" % species)
		var player := players[0] as AnimationPlayer
		for clip: StringName in [
			Models.IDLE_ANIMATION,
			Models.WALK_ANIMATION,
			Models.TROT_ANIMATION,
			Models.GRAZE_ANIMATION,
		]:
			assert_false(Models._clip_name(player, clip).is_empty(), "%s is missing %s" % [species, clip])
		Models.sync_animation(host, host.position - Vector3(0.15, 0.0, 0.0), 0.1)
		assert_eq(player.current_animation, Models._clip_name(player, Models.TROT_ANIMATION))
		for idle_step in 72:
			Models.sync_animation(host, host.position, 0.1)
		assert_eq(player.current_animation, Models.GRAZE_ANIMATION)
		host.free()


func test_town_cat_plays_alive_clips_for_hunt_groom_and_play() -> void:
	var host := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var model := Models.add_model(host, MammalSpecies.SPECIES_CAT)
	assert_true(model != null, "Town cat needs the production rig")
	var player := host.get_meta(Models.ANIMATION_PLAYER_META) as AnimationPlayer
	assert_true(player != null)
	host.set_meta(&"companion_intent", &"hunt")
	Models.sync_animation(host, host.position - Vector3(0.05, 0.0, 0.0), 0.1)
	assert_eq(player.current_animation, Models._clip_name(player, Models.WALK_ANIMATION))
	Models.sync_animation(host, host.position, 0.1)
	assert_eq(player.current_animation, Models._clip_name(player, Models.LOOK_AROUND_ANIMATION))
	host.set_meta(&"companion_intent", &"groom")
	Models.sync_animation(host, host.position, 0.1)
	assert_eq(player.current_animation, Models._clip_name(player, Models.GROOM_ANIMATION))
	host.set_meta(&"companion_intent", &"play")
	Models.sync_animation(host, host.position - Vector3(0.1, 0.0, 0.0), 0.1)
	assert_eq(player.current_animation, Models._clip_name(player, Models.TROT_ANIMATION))
	Models.sync_animation(host, host.position, 0.1)
	assert_eq(player.current_animation, Models._clip_name(player, Models.STRETCH_ANIMATION))
	host.free()


func _bounds(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var box := AABB()
	var first := true
	for child: Node in node.get_children():
		if child is not Node3D:
			continue
		var xform := transform * (child as Node3D).transform
		var part := (
			xform * (child as MeshInstance3D).get_aabb()
			if child is MeshInstance3D
			else _bounds(child, xform)
		)
		if part.size == Vector3.ZERO:
			continue
		box = part if first else box.merge(part)
		first = false
	return box


func _legacy_model(host: Node3D, species: StringName) -> Node3D:
	if species == MammalSpecies.SPECIES_CHICKEN:
		var model := preload("res://scripts/map/view3d/procedural_chicken_model.gd").create()
		host.add_child(model)
		Models._configure_animation(host, model)
		return model
	return Models.add_model(host, species)
