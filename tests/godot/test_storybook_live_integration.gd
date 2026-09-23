extends "res://tests/godot/test_case.gd"

const Models := preload("res://scripts/map/view3d/map_view_medieval_animal_models.gd")
const Birds := preload("res://scripts/map/view3d/map_view_bird_assets.gd")
const Flight := preload("res://scripts/map/view3d/map_view_bird_flight.gd")


func test_live_cast_retains_identity_health_and_fitted_equipment() -> void:
	for body: String in ["kalev", "mart", "aita", "ellen", "watchman", "henning", "jurgen", "kaja"]:
		var path := "res://assets/characters/kalev/kalev.tscn" if body == "kalev" else "res://assets/characters/variants/%s.tscn" % body
		var rig := (load(path) as PackedScene).instantiate() as SharedCharacterRig
		(Engine.get_main_loop() as SceneTree).root.add_child(rig)
		assert_eq(rig.body_basename(), "kalev_fresh" if body == "kalev" else body)
		assert_eq(rig.variant_id(), StringName("char." + body))
		assert_true(rig.has_node("HealthRing"), "Live combat feedback must survive model replacement")
		assert_eq(rig.validation_errors(), [])
		# Kalev is the fresh-rig body; its wardrobe is verified separately and
		# no longer uses the removed storybook per-person equipment bundle.
		if body != "kalev":
			for kind: String in ["mail", "helmet", "cape"]:
				var wearable := load("res://assets/storybook/equipment/%s_%s.tres" % [body, kind]) as CharacterWearable
				assert_true(rig.equip_wearable(wearable), "%s must accept fitted %s" % [body, kind])
		assert_true(rig.play_animation(&"sword_attack", 0.0))
		for slot: StringName in [&"right_hand", &"left_hand"]:
			var prop := "sword" if slot == &"right_hand" else "shield"
			assert_true(rig.equip(slot, load("res://assets/storybook/equipment/%s.tscn" % prop)) != null)
			rig.unequip(slot)
			assert_eq(rig.equipped(slot), null)
		rig.queue_free()


func test_forge_cat_routines_use_new_skinned_clips_and_coats_preserve_face() -> void:
	var cat := (load("res://assets/storybook/forge_cat.tscn") as PackedScene).instantiate() as CatRig
	(Engine.get_main_loop() as SceneTree).root.add_child(cat)
	var before: Dictionary = {}
	for mesh: MeshInstance3D in cat.find_children("*", "MeshInstance3D", true, false):
		for surface: int in mesh.mesh.get_surface_count():
			before[surface] = mesh.get_active_material(surface)
	cat.call("apply_coat", 17)
	for mesh: MeshInstance3D in cat.find_children("*", "MeshInstance3D", true, false):
		for surface: int in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface)
			if source.resource_name == "forge_cat_coat":
				assert_eq((mesh.get_active_material(surface) as StandardMaterial3D).albedo_texture, (source as StandardMaterial3D).albedo_texture, "Tint preserves authored face and coat texture")
			elif source.resource_name not in ["ginger", "stripe"]:
				assert_eq(mesh.get_active_material(surface), before[surface], "Coat recoloring must preserve eyes and whiskers")
	for canonical: StringName in [&"idle", &"walk", &"sleep", &"lick", &"stretch"]:
		assert_true(cat.play_animation(canonical, 0.0))
		assert_eq(cat.current_canonical_animation(), canonical)
		assert_true(cat.animation_player().is_playing())
	assert_false(cat.play_animation(&"sword_attack"))
	cat.queue_free()


func test_live_fauna_walk_run_and_rest_with_correct_facing() -> void:
	for species: StringName in [&"chicken", &"duck", &"goat", &"pig", &"sheep", &"dog", &"rat", &"red_fox", &"hare", &"wild_boar"]:
		var actor := Node3D.new()
		(Engine.get_main_loop() as SceneTree).root.add_child(actor)
		var model := Models.add_model(actor, species)
		assert_true(model.get_meta(&"grounded_model", false))
		assert_true((model.basis * Vector3.BACK).z < 0.0, "Nose must lead travel along -Z")
		var player := actor.get_meta(Models.ANIMATION_PLAYER_META) as AnimationPlayer
		Models.sync_animation(actor, actor.position - Vector3(0.05, 0, 0), 0.1)
		assert_eq(player.current_animation, &"Walk")
		assert_eq(player.get_animation(&"Walk").loop_mode, Animation.LOOP_LINEAR)
		if species not in [&"chicken", &"duck"]:
			Models.sync_animation(actor, actor.position - Vector3(0.2, 0, 0), 0.1)
			assert_eq(player.current_animation, &"Run")
		Models.sync_animation(actor, actor.position, 0.1)
		assert_eq(player.current_animation, &"Idle")
		for step in 80:
			Models.sync_animation(actor, actor.position, 0.1)
		assert_true(player.current_animation in [&"Graze", &"Peck"])
		actor.free()


func test_bird_pool_switches_between_skeletal_flight_and_existing_species() -> void:
	var flight := Flight.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(flight)
	var bird := flight.get_node("FlightBird0") as Node3D
	for species: StringName in [&"hooded_crow", &"mallard", &"european_robin", &"herring_gull"]:
		assert_true(flight._install_species_rig(bird, species))
		assert_eq(bird.get_child_count(), 1, "Reusing a pooled bird must remove the previous rig")
		var player := bird.get_meta(&"flight_player") as AnimationPlayer
		bird.set_meta(&"flap_pause", 0.0)
		flight._advance_flap(bird, 0.01)
		assert_eq(player.current_animation, &"Fly")
		bird.set_meta(&"flap_pause", 0.5)
		flight._advance_flap(bird, 0.01)
		assert_eq(player.current_animation, &"Glide")
		var skeleton := bird.find_child("Skeleton3D", true, false) as Skeleton3D
		assert_true(skeleton.find_bone("Wing.L") >= 0)
		assert_true(flight._install_species_rig(bird, &"house_sparrow"))
		assert_false(bird.has_meta(&"flight_player"))
		assert_true(bird.has_node("WingRootL"))
	flight.free()


func test_live_catalogue_flight_uses_the_revised_anatomy_and_plumage() -> void:
	var flight := Flight.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(flight)
	var bird := flight.get_node("FlightBird0") as Node3D
	# Not one of the five retained skinned-storybook birds: it must use the
	# active P0-212 mesh path the game instantiates for ambient flight.
	assert_true(flight._install_species_rig(bird, &"osprey"))
	assert_false(bird.has_meta(&"flight_player"))
	assert_true(bird.has_node("WingRootL/WingElbowL"))
	var body := bird.get_node("Body") as MeshInstance3D
	assert_eq(body.mesh.get_meta(&"bird_catalog_revision", 0), 213)
	var material := body.mesh.surface_get_material(0) as ShaderMaterial
	assert_true(material != null)
	assert_eq(material.shader.resource_path, "res://assets/birds/catalog_plumage.gdshader")
	flight.free()


func test_ground_and_flight_ducks_share_scale() -> void:
	var actor := Node3D.new()
	var ground := Models.add_model(actor, &"duck")
	var flying := Birds.create_animated_model(&"mallard")
	assert_eq(ground.scale, flying.scale)
	actor.free()
	flying.free()
