extends "res://tests/godot/test_case.gd"

## Animals of the seamless city (ADR 0031): deterministic placements on dry
## land, species coverage, and streaming around Kalev.

const REQUIRED_SPECIES: Array[StringName] = [
	&"dog", &"cat", &"horse", &"chicken", &"rat", &"pig", &"cow", &"goose", &"goat",
	&"sheep", &"hare", &"red_fox",
]


func _plan() -> CityPlan:
	return CityPlan.load_default()


func test_placements_are_deterministic_and_cover_every_planned_species() -> void:
	var plan := _plan()
	var first := CityFauna.groups_for(plan)
	var second := CityFauna.groups_for(plan)
	assert_eq(first.size(), second.size())
	var seen := {}
	for i in first.size():
		assert_eq(first[i]["id"], second[i]["id"])
		assert_eq(first[i]["members"], second[i]["members"])
		seen[first[i]["species"]] = true
	for species in REQUIRED_SPECIES:
		assert_true(seen.has(species), "%s has a placement" % species)
	assert_true(first.size() >= 40, "town yards plus fields, got %d" % first.size())


func test_every_animal_stands_on_dry_land_clear_of_buildings_and_inside_the_plan() -> void:
	var plan := _plan()
	for group in CityFauna.groups_for(plan):
		for xz: Vector2 in group["members"]:
			assert_true(plan.bounds.has_point(xz), "%s inside the plan" % group["id"])
			assert_true(plan.ground_height(xz) > CityFauna.MIN_GROUND, "%s on land" % group["id"])
			assert_eq(plan.building_at(xz), -1, "%s outside foundations" % group["id"])


func test_the_forum_has_life_when_kalev_arrives_and_the_far_fields_do_not() -> void:
	var plan := _plan()
	var kalev := Node2D.new()
	var forum := plan.point_of_interest("poi.forum")
	var at := Vector2(forum["at"][0], forum["at"][1])
	kalev.global_position = CityPlan.to_logic(at)
	var fauna := CityFauna.create(plan, kalev)
	Engine.get_main_loop().root.add_child(kalev)
	Engine.get_main_loop().root.add_child(fauna)
	fauna._stream(at)
	assert_true(fauna.live_actor_count() > 0, "forum animals exist")
	assert_true(fauna.live_actor_count() <= CityFauna.MAX_ACTORS)
	for actors: Array in fauna._live.values():
		for actor: Node3D in actors:
			assert_true(actor.has_meta(&"species"), "built through the shared animal loader")
			assert_true(actor.find_children("*", "CollisionObject3D", true, false).is_empty())
			assert_almost_eq(actor.scale.x, CityFauna.MODEL_SCALE, 0.0001)
			assert_true(actor.position.distance_to(Vector3(at.x, 0, at.y)) < CityFauna.DESPAWN_RANGE)
	# Walk to the south-east corner, far from every group: the forum herd is freed.
	var far := Vector2(700, 600)
	fauna._stream(far)
	for id: String in fauna._live.keys():
		assert_true((fauna._group_by_id(id)["centre"] as Vector2).distance_to(far) <= CityFauna.DESPAWN_RANGE)
	fauna.queue_free()
	kalev.queue_free()


func test_actors_walk_on_the_ground_and_face_their_travel() -> void:
	var plan := _plan()
	var kalev := Node2D.new()
	var forum := plan.point_of_interest("poi.forum")
	var at := Vector2(forum["at"][0], forum["at"][1])
	kalev.global_position = CityPlan.to_logic(at + Vector2(60, 60))
	var fauna := CityFauna.create(plan, kalev)
	Engine.get_main_loop().root.add_child(kalev)
	Engine.get_main_loop().root.add_child(fauna)
	fauna._stream(at)
	var listener := Vector3(at.x + 60.0, 0.0, at.y + 60.0)
	for step in 600:
		for actors: Array in fauna._live.values():
			for actor: Node3D in actors:
				fauna._advance(actor, listener, 0.1)
	for actors: Array in fauna._live.values():
		for actor: Node3D in actors:
			var ground := plan.ground_height(Vector2(actor.position.x, actor.position.z))
			assert_almost_eq(actor.position.y, ground + float(actor.get_meta(&"lift")), 0.001)
			assert_almost_eq(actor.scale.x, CityFauna.MODEL_SCALE, 0.0001)
			var home: Vector3 = actor.get_meta(&"home")
			var roam := float(actor.get_meta(&"radius")) + 0.5
			assert_true(
				Vector2(actor.position.x - home.x, actor.position.z - home.z).length() <= roam,
				"stays in its yard"
			)
	fauna.queue_free()
	kalev.queue_free()
