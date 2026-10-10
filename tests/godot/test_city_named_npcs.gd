extends "res://tests/godot/test_case.gd"

## Named NPCs in the seamless city (docs/SYSTEMS/NAMED_NPCS.md, task R-1563):
## spawn by the clock, determinism, act gate, census suppression, interact reach
## and the information panel with portrait and faction.

const LINKED_PATH := "user://named_npcs_linked.json"
const LINKED_CENSUS := "cit.lt.inst_town_hall.009"


func _spawner(registry: NamedNpcRegistry = null) -> CityNamedNpcs:
	var plan := CityPlan.load_default()
	var crowd := CityCitizens.create(plan, null)
	var named := CityNamedNpcs.create(plan, null, crowd, registry)
	named.hour_override = 10.0
	named.current_act = 1
	return named


func _free(named: CityNamedNpcs) -> void:
	var crowd := named.citizens
	named.free()
	crowd.free()


func test_two_registry_npcs_at_the_forum_at_ten() -> void:
	var named := _spawner()
	named.refresh(named.anchor_position("poi.forum"))
	named.refresh(named.anchor_position("poi.forum"))
	var ids := PackedStringArray()
	for actor in named.live_actors():
		ids.append(actor.npc_id())
	assert_true(ids.size() >= 2, "at least two named NPCs near the forum, got %s" % [ids])
	assert_true(ids.has("char.johann_von_minden"), "merchant at the market")
	assert_true(ids.has("char.mart_weaver"), "weaver at the cloth stalls")
	_free(named)


func test_resolve_is_deterministic_and_follows_the_post() -> void:
	var named := _spawner()
	var johann := named.registry.get_npc("char.johann_von_minden")
	assert_eq(named.resolve(johann, 10.0), named.resolve(johann, 10.0))
	var at_post := named.resolve(johann, 10.0)
	assert_true(at_post["visible"])
	assert_false(at_post["moving"])
	assert_true((at_post["pos"] as Vector2).distance_to(named.anchor_position("poi.forum")) < 5.0)
	assert_false(named.resolve(johann, 2.0)["visible"], "at home at night")
	var walking := named.resolve(johann, 12.55)
	assert_true(walking["visible"] and walking["moving"], "walking home from the forum")
	assert_eq(named.describe(johann, 12.55), "On the way home")
	assert_false(named.resolve(johann, 13.4)["visible"], "home: gone indoors")
	assert_eq(named.describe(johann, 2.0), "At home")
	assert_true(named.describe(johann, 10.0).begins_with("At the forum"), named.describe(johann, 10.0))
	_free(named)


func test_later_acts_stay_away() -> void:
	var named := _spawner()
	var jana := named.registry.get_npc("char.jana_podajalnaja")
	assert_false(named.eligible(jana), "Wave B waits for act 2")
	named.refresh(named.anchor_position("poi.forum"))
	for actor in named.live_actors():
		assert_ne(actor.npc_id(), "char.jana_podajalnaja")
	named.current_act = 2
	assert_true(named.eligible(jana))
	_free(named)


func test_linked_census_resident_is_suppressed() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NamedNpcRegistry.DATA_PATH))
	raw["npcs"][7]["census_mode"] = "replaces"
	raw["npcs"][7]["census_id"] = LINKED_CENSUS
	var file := FileAccess.open(LINKED_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var registry := NamedNpcRegistry.new()
	assert_true(registry.load_file(LINKED_PATH), "; ".join(registry.errors))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LINKED_PATH))
	var named := _spawner(registry)
	var index := named.citizens.roster.index_of(LINKED_CENSUS)
	assert_true(index >= 0)
	assert_true(named.citizens.is_suppressed(index), "the census copy never walks")
	var npc := registry.get_npc(String(raw["npcs"][7]["id"]))
	assert_eq(named.style_record(npc)["body"], named.citizens.roster.residents[index]["body"],
		"the named NPC wears the resident's own body")
	assert_false(named.citizens.is_suppressed(index + 1))
	_free(named)


func test_interact_reach_and_panel_shows_portrait_and_faction() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var named := _spawner()
	var kalev := Node2D.new()
	tree.root.add_child(kalev)
	named.player = kalev
	tree.root.add_child(named.citizens)
	named.citizens.add_child(named)
	await tree.process_frame
	var forum := named.anchor_position("poi.forum")
	named.refresh(forum)
	named.refresh(forum)
	var johann: NamedNpcActor = null
	for actor in named.live_actors():
		if actor.npc_id() == "char.johann_von_minden":
			johann = actor
	assert_true(johann != null)
	var spot: Vector2 = named.resolve(johann.npc, 10.0)["pos"]
	kalev.global_position = CityPlan.to_logic(spot + Vector2(10.0, 0.0))
	assert_true(named.nearest_to_player() == null, "10 m is out of reach")
	kalev.global_position = CityPlan.to_logic(spot + Vector2(1.0, 0.0))
	await tree.physics_frame
	assert_true(named.nearest_to_player() != null, "within 3 m")
	named.select(johann)
	await tree.process_frame
	var panel := named.citizens.info_panel()
	assert_true(panel.is_open())
	assert_eq(panel.shown_id, "char.johann_von_minden")
	assert_true(panel.portrait_texture() != null, "portrait shown")
	assert_eq(panel.faction_text(), "Brotherhood of Blackheads")
	assert_true(panel.faction_badge != null, "badge slot for NPC-5")
	kalev.free()
	named.citizens.queue_free()
	await tree.process_frame
