extends "res://tests/godot/test_case.gd"

## R-1335: the opponent's spirit form in the arena follows the duel: the line's
## spirit_image_id picks the shape, a telegraphed blow swells it, lost pressure shrinks and
## cracks it, and blows and replies make it flash and flinch.

const CONFRONT := &"dialogue.prologue.porter_confrontation"
const CONTENT_DIRS: Array[String] = [
	"res://content/prologue",
	"res://content/examples/valid",
	"res://content/examples/support",
]

var _state: GameState
var _db: ContentDB
var _host: SpiritArenaHost


func before_each() -> void:
	super.before_each()
	_state = GameState.new()
	_db = ContentDB.new()
	assert_true(_db.load_from_directories(CONTENT_DIRS))
	for grant_id: StringName in AlmshouseOpening.STARTER_GRANTS:
		MagicResolver.apply_grant_operation(_state, _db, grant_id)
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, 8)
	_host = SpiritArenaHost.new()
	_host.freeze_world = false
	(Engine.get_main_loop() as SceneTree).root.add_child(_host)


func after_each() -> void:
	if is_instance_valid(_host):
		_host.close()
		_host.free()
	super.after_each()


func test_the_porter_opens_with_the_rusted_key() -> void:
	assert_true(_host.open_scripted(_db, _state, CONFRONT))
	var form := _host.form_view()
	assert_true(form.visible)
	assert_eq(form.image_id, &"rusted_key")
	assert_eq(form.image_kind(), 1)
	assert_eq(form.shader_material().get_shader_parameter(&"image_kind"), 1)
	assert_true(form.show_body, "no staged actor: the silhouette is drawn")


func test_a_telegraphed_blow_swells_the_image() -> void:
	assert_true(_host.open_scripted(_db, _state, CONFRONT))
	var form := _host.form_view()
	_host.duel.tick(SpiritDuel.TELEGRAPH_SEC * 0.5)
	form.advance(0.0)
	assert_true(form.swell > 0.3, "swell %s" % form.swell)
	_host.duel.tick(SpiritDuel.TELEGRAPH_SEC)
	form.advance(0.0)
	assert_eq(form.swell, 0.0, "no swell once the blow landed")


func test_lost_pressure_shrinks_and_cracks_the_image() -> void:
	assert_true(_host.open_scripted(_db, _state, CONFRONT))
	var form := _host.form_view()
	_host.duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	form.advance(10.0)
	assert_eq(form.presence, 1.0, "untouched porter")
	assert_eq(form.crack, 0.0)
	assert_true(_host.duel.answer("fire_hands"))
	assert_eq(form.flash, 1.0, "the cast and the reply flash the spirit")
	assert_true(form.recoil > 0.0, "and it flinches back")
	form.advance(10.0)
	var ratio := _host.duel.opponent.health / _host.duel.opponent.max_health
	assert_almost_eq(form.presence, ratio, 0.001)
	assert_true(form.presence < 1.0)
	assert_almost_eq(form.crack, 1.0 - ratio, 0.001)
	assert_eq(form.flash, 0.0, "impulses decay")
	assert_almost_eq(
		float(form.shader_material().get_shader_parameter(&"crack")), form.crack, 0.001
	)


func test_the_presence_eases_instead_of_jumping() -> void:
	assert_true(_host.open_scripted(_db, _state, CONFRONT))
	var form := _host.form_view()
	_host.duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_host.duel.answer("fire_hands"))
	form.advance(0.05)
	assert_true(form.presence > form.target_presence, "still easing down")


func test_the_landed_blow_flashes_the_spirit() -> void:
	assert_true(_host.open_scripted(_db, _state, CONFRONT))
	var form := _host.form_view()
	form.advance(10.0)
	_host.duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(form.flash >= 0.6, "the porter's blow lands")
	assert_true(form.recoil < 0.0, "the spirit lunges forward")


func test_the_rod_follows_the_next_line() -> void:
	assert_true(_host.open_scripted(_db, _state, CONFRONT))
	_host.duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
	assert_true(_host.duel.answer("still_hunger"))
	assert_eq(_host.form_view().image_id, &"rod")
	assert_eq(_host.form_view().image_kind(), 2)


func test_a_broken_porter_leaves_a_shattered_image() -> void:
	assert_true(_host.open_scripted(_db, _state, CONFRONT))
	var form := _host.form_view()
	for choice_id in ["fire_hands", "fire_lock", "fire_secret"]:
		_host.duel.tick(SpiritDuel.TELEGRAPH_SEC + 0.01)
		assert_true(_host.duel.answer(choice_id), choice_id)
	form.advance(10.0)
	assert_true(bool(_host.duel.last_outcome.get("broken", false)), "porter broken")
	assert_eq(form.presence, 0.0)
	assert_eq(form.crack, 1.0)


func test_observation_hides_the_form_and_close_unbinds_it() -> void:
	assert_true(_host.open_scripted(_db, _state, CONFRONT))
	_host.close()
	assert_false(_host.duel.line_presented.is_connected(_host.form_view()._on_line))
	assert_true(_host.observe(_db, _state, &"dialogue.prologue.almshouse_quarrel"))
	assert_false(_host.form_view().visible)


func test_tracking_a_staged_actor_hides_the_silhouette_and_pins_the_focus() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.5, 3.6), Vector3(0.0, 1.2, 0.0))
	var actor := Node3D.new()
	stage.add_child(actor)
	actor.position = Vector3(0.95, 0.0, 0.0)
	var form := _host.form_view()
	form.track_3d(camera, actor)
	assert_true(form.is_tracking())
	assert_false(form.show_body)
	assert_true(form.focus.x > 0.5 and form.focus.x < 1.0, "actor right of centre %s" % form.focus)
	assert_true(form.frame_height > 0.0)
	assert_eq(form.shader_material().get_shader_parameter(&"show_body"), 0.0)
	form.track_3d(null, null)
	assert_true(form.show_body)
	assert_eq(form.focus, SpiritFormView.DEFAULT_FOCUS)
	stage.free()


## A close two-shot makes one metre so tall that the image, two metres over the chest, would
## be cut off by the top of the screen; it is scaled down to fit instead of drifting off.
func test_a_close_camera_shrinks_the_image_so_it_stays_in_frame() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	var actor := Node3D.new()
	stage.add_child(actor)
	var form := _host.form_view()

	camera.look_at_from_position(Vector3(0.0, 1.3, 1.1), Vector3(0.0, 1.3, 0.0))
	form.track_3d(camera, actor)
	var near_height := form.frame_height
	var image_top := form.focus.y - SpiritFormView.IMAGE_TOP_METRES * form.frame_height
	assert_true(image_top >= 0.0, "image top on screen, got %s" % image_top)

	# A camera far enough back needs no clamp, so the metre keeps the camera's own scale.
	camera.look_at_from_position(Vector3(0.0, 1.3, 7.0), Vector3(0.0, 1.3, 0.0))
	form.track_3d(camera, actor)
	assert_true(form.frame_height < near_height, "far shot has the smaller metre")
	stage.free()
