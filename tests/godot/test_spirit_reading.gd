extends "res://tests/godot/test_case.gd"
## SS-4 (R-1487): reading a soul. Depth by the hero's awareness light, closed mask, clarity
## words, focus delay, mouse and gamepad focus, the hero never read, hides when sight closes.

const AuraManager := preload("res://scripts/combat/spirit_aura_manager.gd")
const Sight := preload("res://scripts/combat/spirit_sight.gd")
const ReadingPanel := preload("res://scripts/ui/spirit_reading_panel.gd")

const FIXTURE_AURA := {
	"levels": {
		"aspect.nature": 0, "aspect.affection": 1, "aspect.tenacity": 2, "aspect.unity": 3,
		"aspect.resonance": 4, "aspect.awareness": 5, "aspect.light": 1,
	},
	"clarity": 0.5,
	"closed_mask": ["aspect.nature"],
}
const FIXTURE_CONTEXT := {
	"name": "Hanß", "temperament": ["stubborn", "proud", "proud"],
	"topic_tags": ["work", "bread", "family", "sin"],
}

var _host: Node3D
var _camera: Camera3D
var _manager: SpiritAuraManager
var _panel: SpiritReadingPanel
var _state: GameState


func before_each() -> void:
	super.before_each()
	_host = Node3D.new()
	_tree().root.add_child(_host)
	_camera = Camera3D.new()
	_host.add_child(_camera)
	_camera.look_at_from_position(Vector3(0.0, 1.6, 6.0), Vector3(0.0, 1.0, 0.0))
	_state = GameState.new()
	_manager = AuraManager.new()
	_manager.follow_session = false
	_manager.state = _state
	_manager.center_override = Vector3.ZERO
	_host.add_child(_manager)
	_manager.set_process(false)
	_panel = ReadingPanel.new()
	_panel.follow_session = false
	_panel.manager = _manager
	_panel.state = _state
	_panel.camera_override = _camera
	_host.add_child(_panel)
	_panel.set_process(false)


func after_each() -> void:
	_host.free()
	super.after_each()


func _profile() -> SpiritAuraProfile:
	return SpiritAuraProfile.from_record(&"char.reading_fixture", {"aura": FIXTURE_AURA})


func _body(body_name: String, at: Vector3, profile: SpiritAuraProfile) -> Node3D:
	var body := Node3D.new()
	body.name = body_name
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 1.8, 0.3)
	mesh.mesh = box
	mesh.position.y = 0.9
	body.add_child(mesh)
	_host.add_child(body)
	body.global_position = at
	_manager.register(body, profile)
	return body


## Box bodies have no rig, so their views treat closed lights as absent (animal rule);
## the people here are read as people.
func _show_auras() -> void:
	_manager.fade = 1.0
	_manager.refresh()
	for body: Node3D in _manager.candidates():
		if _manager.view_for(body) != null:
			_manager.view_for(body).closed_as_absent = false


func _chest_on_screen(body: Node3D) -> Vector2:
	var view := _manager.view_for(body)
	return _camera.unproject_position(view.anchors[3])


func _set_awareness(rank: int) -> void:
	_state.grant_natural_points(rank - GameState.NATURAL_ASPECT_BASELINE)
	while _state.get_natural_aspect_rank(&"aspect.awareness") < rank:
		assert_eq(_state.spend_natural_point(&"aspect.awareness"), &"")


func test_depth_grows_with_the_heros_awareness_light() -> void:
	var profile := _profile()
	var shallow := SpiritReading.read(profile, 1, FIXTURE_CONTEXT)
	assert_eq(shallow["depth"], 2, "a dim inner eye still reads the base card")
	assert_eq(SpiritReading.read(profile, 2, FIXTURE_CONTEXT), shallow)
	assert_eq(shallow["lights"].size(), 7)
	assert_eq(shallow["lights"][0]["id"], &"aspect.nature", "bottom-up: the root first")
	assert_eq(shallow["lights"][6]["id"], &"aspect.light")
	assert_eq(shallow["lights"][0]["state"], &"veiled", "the closed mask hides the root")
	assert_eq(shallow["lights"][0]["level"], -1)
	assert_eq(shallow["veiled_count"], 1)
	assert_eq(shallow["closed"], [], "a veiled light is not betrayed as closed")
	assert_eq(shallow["strongest"], ["Awareness"])
	assert_eq(shallow["lights"][1]["name"], "Affection", "GameState aspect names")
	assert_eq(shallow["lights"][1]["element_name"], "Coin")
	assert_eq(shallow["lights"][5]["element"], &"sight")
	assert_eq(shallow["temperament"], [])
	assert_eq(shallow["topic_hint"], "")
	var three := SpiritReading.read(profile, 3, FIXTURE_CONTEXT)
	assert_eq(three["temperament"], ["proud", "stubborn"], "sorted, unique tags")
	assert_eq(three["veiled_count"], 1)
	assert_eq(three["topic_hint"], "")
	var four := SpiritReading.read(profile, 4, FIXTURE_CONTEXT)
	assert_eq(four["lights"][0]["state"], &"closed", "awareness 4 sees through the mask")
	assert_eq(four["lights"][0]["level"], 0)
	assert_eq(four["closed"], ["Nature"])
	assert_eq(four["veiled_count"], 0)
	assert_eq(four["topic_hint"], "")
	var five := SpiritReading.read(profile, 5, FIXTURE_CONTEXT)
	assert_eq(five["topic_hint"], "work, bread, family", "first three topic tags")
	assert_eq(five["clarity_word"], "uneasy")


func test_unmasked_closed_light_shows_at_any_depth_and_ties_share_strongest() -> void:
	var profile := SpiritAuraProfile.from_record(&"char.x", {"aura": {
		"levels": {"aspect.affection": 0, "aspect.unity": 4, "aspect.light": 4}, "clarity": 1.0,
	}})
	var reading := SpiritReading.read(profile, 2)
	assert_eq(reading["closed"], ["Affection"])
	assert_eq(reading["strongest"], ["Unity", "Light"])
	assert_true(reading["lights"][3]["strongest"] and reading["lights"][6]["strongest"])


func test_clarity_words_and_animal_lights_are_absent_not_weak() -> void:
	assert_eq(SpiritReading.clarity_word(1.0), "calm")
	assert_eq(SpiritReading.clarity_word(0.67), "calm")
	assert_eq(SpiritReading.clarity_word(0.5), "uneasy")
	assert_eq(SpiritReading.clarity_word(0.34), "uneasy")
	assert_eq(SpiritReading.clarity_word(0.2), "torn")
	var dog := SpiritReading.read(SpiritAuraProfile.for_species("dog"), 5, {"absent_closed": true})
	assert_eq(dog["closed"], [], "a dog shows no false weak point")
	assert_eq(dog["absent"].size(), 4)
	assert_eq(dog["strongest"], ["Nature", "Unity"])


func test_context_reads_temperament_and_duel_topics_from_content() -> void:
	var examples := ContentDB.new()
	assert_true(examples.load_from_directories(["res://content/examples/valid"]))
	var fixture := SpiritReading.context_for(&"char.aura_fixture", examples)
	assert_eq(fixture["name"], "Test")
	assert_eq(fixture["temperament"], ["stubborn", "proud"])
	var db: ContentDB = SessionState.content_db
	var stranger := SpiritReading.context_for(&"char.nobody_at_all", db)
	assert_eq(stranger["topic_tags"], ["work", "bread", "family", "sin", "fear"],
		"anyone can be dueled on the stranger topic")
	var porter_duel := &"dialogue.prologue.porter_confrontation"
	var topic: Dictionary = db.get_dialogue(porter_duel)["duel"]["topic"]
	var porter := SpiritReading.context_for(&"char.nobody_at_all", db, porter_duel)
	assert_eq(porter["topic_tags"], topic["tags"], "a person's own duel topic wins")


func test_focus_opens_after_the_delay_and_closes_after_grace() -> void:
	var npc := _body("BerendRig", Vector3(0.0, 0.0, 0.0), _profile())
	_show_auras()
	_panel.focus_point_override = _chest_on_screen(npc)
	_panel.tick(0.3)
	assert_false(_panel.is_open(), "a glance is not a reading")
	_panel.tick(0.25)
	assert_true(_panel.is_open())
	assert_eq(_panel.target, npc)
	assert_eq(_panel.reading["lights"].size(), 7)
	_panel.focus_point_override = Vector2(-500.0, -500.0)
	_panel.tick(0.2)
	assert_true(_panel.is_open(), "short look-away keeps the card")
	_panel.tick(0.2)
	assert_false(_panel.is_open())
	assert_eq(_panel.target, null)


func test_depth_follows_the_session_awareness_and_closed_mask_reveal() -> void:
	var npc := _body("BerendRig", Vector3.ZERO, _profile())
	_show_auras()
	_panel.focus_point_override = _chest_on_screen(npc)
	_panel.tick(0.6)
	assert_eq(_panel.reading["depth"], 2, "a bare GameState sees at awareness 1")
	assert_eq(_panel.reading["veiled_count"], 1)
	_set_awareness(25)
	_panel.tick(0.1)
	assert_eq(_panel.reading["depth"], 4, "a Hingepuu spend deepens the open card")
	assert_eq(_panel.reading["closed"], ["Nature"])


func test_switching_focus_restarts_the_delay() -> void:
	var left := _body("LeftRig", Vector3(-1.5, 0.0, 0.0), _profile())
	var right := _body("RightRig", Vector3(1.5, 0.0, 0.0), _profile())
	_show_auras()
	_panel.focus_point_override = _chest_on_screen(left)
	_panel.tick(0.6)
	assert_eq(_panel.target, left)
	_panel.focus_point_override = _chest_on_screen(right)
	_panel.tick(0.3)
	assert_eq(_panel.target, left, "the card holds until the new look settles")
	_panel.tick(0.3)
	assert_eq(_panel.target, right)


func test_gamepad_focuses_the_camera_centre() -> void:
	var npc := _body("BerendRig", Vector3.ZERO, _profile())
	_show_auras()
	_camera.look_at_from_position(Vector3(0.0, 1.6, 6.0), _manager.view_for(npc).anchors[3])
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 0.6
	_panel._input(stick)
	assert_false(_panel.use_pointer)
	var centre := _panel.get_viewport().get_visible_rect().size * 0.5
	assert_eq(_panel.focus_point(), centre)
	_panel.tick(0.6)
	assert_eq(_panel.target, npc, "stick aim reads the being at the screen centre")
	var mouse := InputEventMouseMotion.new()
	_panel._input(mouse)
	assert_true(_panel.use_pointer, "moving the mouse returns to pointer focus")


func test_hero_and_far_glow_are_never_read() -> void:
	var hero := _body("PlayerRig", Vector3.ZERO, _profile())
	_show_auras()
	_panel.focus_point_override = _chest_on_screen(hero)
	_panel.tick(1.0)
	assert_false(_panel.is_open(), "the hero does not read himself")
	var far := _body("FarRig", Vector3(0.0, 0.0, -30.0), _profile())
	_show_auras()
	assert_eq(_manager.view_for(far).tier, SpiritAuraView.Tier.GLOW)
	_panel.focus_point_override = _chest_on_screen(far)
	_panel.tick(1.0)
	assert_false(_panel.is_open(), "a distant glow is too faint to read")


func test_card_hides_when_sight_closes_or_a_duel_opens() -> void:
	var npc := _body("BerendRig", Vector3.ZERO, _profile())
	_show_auras()
	_panel.focus_point_override = _chest_on_screen(npc)
	_panel.tick(0.6)
	assert_true(_panel.is_open())
	_manager.fade = 0.0
	_panel.tick(0.016)
	assert_false(_panel.is_open(), "leaving sight closes the card at once")
	_manager.fade = 1.0
	_panel.tick(0.6)
	assert_true(_panel.is_open())
	_manager.set_duel_fighters([npc] as Array[Node3D])
	_panel.tick(0.016)
	assert_false(_panel.is_open(), "the duel arena owns the screen")


func test_spirit_sight_mounts_the_reading_card() -> void:
	var sight := Sight.new()
	sight.follow_session = false
	sight.state = _state
	sight.environment_override = Environment.new()
	_host.add_child(sight)
	var card := sight.get_node_or_null("SpiritReadingPanel") as SpiritReadingPanel
	assert_true(card != null)
	assert_eq(card.manager, sight.get_node("SpiritAuras"))
	assert_eq(card.sight, sight)
	card.tick(0.6)
	assert_false(card.is_open(), "closed while sight is off")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
