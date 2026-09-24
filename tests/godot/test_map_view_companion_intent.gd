extends "res://tests/godot/test_case.gd"

const CompanionIntent := preload("res://scripts/map/view3d/map_view_companion_intent.gd")
const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")
const MedievalAnimalModels := preload(
	"res://scripts/map/view3d/map_view_medieval_animal_models.gd"
)
const UrbanFauna := preload("res://scripts/map/view3d/map_view_urban_fauna.gd")


func test_lower_town_authors_a_hunting_cat_and_a_playing_dog() -> void:
	var hunt_cats := 0
	var play_dogs := 0
	for placement: Dictionary in UrbanFauna.MAP_PLACEMENTS[&"lower_town_slice"]:
		var species: StringName = placement.get("species", &"")
		var behavior: StringName = placement.get("behavior", &"")
		if species == MammalSpecies.SPECIES_CAT and behavior == UrbanFauna.BEHAVIOR_HUNT:
			hunt_cats += 1
		if species == MammalSpecies.SPECIES_DOG and behavior == UrbanFauna.BEHAVIOR_PLAY:
			play_dogs += 1
	assert_true(hunt_cats >= 1, "one town cat should hunt instead of loafing")
	assert_true(play_dogs >= 1, "one town dog should play instead of only wandering")


func test_companion_cats_and_dogs_use_purposeful_intents_and_clips() -> void:
	var fauna := UrbanFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	var seen_intents: Dictionary = {}
	var seen_clips: Dictionary = {}
	var moved: Dictionary = {}
	var previous: Dictionary = {}
	for actor in fauna.get_children():
		previous[actor.name] = actor.position
	for step in 80:
		fauna.sync(MammalSpecies.CONTEXT_LOWER_TOWN, 0.25, Vector3.ZERO, true)
		for actor in fauna.get_children():
			var species: StringName = actor.get_meta(&"species", &"")
			if species != MammalSpecies.SPECIES_CAT and species != MammalSpecies.SPECIES_DOG:
				continue
			var intent: StringName = actor.get_meta(&"companion_intent", &"")
			seen_intents[intent] = true
			if actor.position.distance_to(previous[actor.name]) > 0.01:
				moved[species] = true
			previous[actor.name] = actor.position
			var player := actor.get_meta(
				MedievalAnimalModels.ANIMATION_PLAYER_META
			) as AnimationPlayer
			if player != null and not player.current_animation.is_empty():
				seen_clips[player.current_animation] = true
	assert_true(seen_intents.has(CompanionIntent.INTENT_HUNT), "cats must enter a hunt")
	assert_true(seen_intents.has(CompanionIntent.INTENT_PLAY), "dogs or cats must play")
	assert_true(moved.get(MammalSpecies.SPECIES_CAT, false), "town cats must travel")
	assert_true(moved.get(MammalSpecies.SPECIES_DOG, false), "town dogs must travel")
	var alive := false
	for clip: String in [
		"Walk",
		"Run",
		"LookAround",
		"Groom",
		"Stretch",
		"Sleep",
		"Alert",
		"Graze",
	]:
		if seen_clips.has(clip):
			alive = true
			break
	assert_true(alive, "companions must play a live clip, got %s" % seen_clips)
	fauna.queue_free()


func test_companion_intent_stays_inside_the_authored_yard() -> void:
	var fauna := UrbanFauna.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(fauna)
	fauna.configure(&"lower_town_slice", MammalSpecies.CONTEXT_LOWER_TOWN, 32)
	for step in 64:
		fauna.sync(MammalSpecies.CONTEXT_LOWER_TOWN, 0.2, Vector3.ZERO, true)
	for actor in fauna.get_children():
		var species: StringName = actor.get_meta(&"species", &"")
		if species != MammalSpecies.SPECIES_CAT and species != MammalSpecies.SPECIES_DOG:
			continue
		var radius := float(actor.get_meta(&"radius", 0.0))
		var intent: StringName = actor.get_meta(&"companion_intent", &"")
		assert_true(
			fauna.actor_offset_from_home(actor) <= radius * 1.05,
			"%s left its yard during %s" % [actor.name, intent]
		)
	fauna.queue_free()
