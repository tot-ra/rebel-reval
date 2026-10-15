class_name SmithyOpening
extends Node
## New-game opening in the seamless city (R-1872; moved to the Holy Spirit almshouse sick-room
## by ADR 0052, the healer's apprentice). The class keeps its R-1872 name because many tests and
## tools reference it; it no longer plays in the smithy. Three beats, all with the normal city
## Player, camera, movement, roll and guard (a duel is a combat mode over normal play):
##
## 1. The porter Hanß catches the boy in the almshouse with the loaf and the cold-store key: the
##    first spirit duel (`dialogue.prologue.porter_confrontation`), guilt rule for the shove.
## 2. At dusk the watch carries in Lambert with a broken spearhead in his side. Matron Gertrud
##    sends for the smith who can speak to iron and sets the boy at the bed
##    (`dialogue.prologue.lambert_carried_in`, framed by ConversationShot). The boy then meets
##    Lambert's fear as a phantom in a gentle, healing duel (`dialogue.prologue.lambert_fear`).
## 3. Kalev kneels at the bed, finds his own mark on the spearhead, speaks the origin-of-iron
##    charm and takes the boy in (`dialogue.prologue.kalev_arrives`, ConversationShot). Play
##    then continues in the almshouse; Lambert stays on the sickbed and the boy may walk to the
##    forge.
##
## Places come from the almshouse anchors in `content/world/reval_city/sites/holy_spirit.json`
## (`anchor.holy_spirit.sickbed`, `.sickbed_attendant`, `.almshouse_kalev`), with fallbacks to the
## room anchor, the yard door and finally to offsets from the boy (city-free test fixtures).
## Holding `ui_cancel` skips (the press is eaten so the pause menu stays shut).

signal stage_changed(stage: StringName)
signal finished

const STAGE_WAITING := &"waiting"
const STAGE_CONFRONTATION := &"confrontation"
const STAGE_CARRIED_IN := &"carried_in"
const STAGE_LAMBERT := &"lambert"
const STAGE_KALEV := &"kalev"
const STAGE_DONE := &"done"
const ACTIVE_STAGES: Array[StringName] = [
	STAGE_CONFRONTATION, STAGE_CARRIED_IN, STAGE_LAMBERT, STAGE_KALEV
]

const CONFRONTATION := &"dialogue.prologue.porter_confrontation"
const CARRIED_IN := &"dialogue.prologue.lambert_carried_in"
const LAMBERT_FEAR := &"dialogue.prologue.lambert_fear"
const KALEV_ARRIVES := &"dialogue.prologue.kalev_arrives"
## Holding `ui_cancel` this long during the opening skips the rest.
const HOLD_TO_SKIP_SEC := 0.8
## The hero's first magic. The duel needs these as replies, so the opening grants them
## itself instead of relying on the forge's later seeding.
const STARTER_GRANTS: Array[StringName] = [
	&"magic.grant.starter_fireball",
	&"magic.grant.starter_earth_tremor",
	&"magic.grant.starter_iron_skin",
]
const DUEL_WILLPOWER := 8
## The physical answer in the duel (`[Shove him away]`) only sets a dialogue flag; the
## opening turns it into guilt the same way a melee blow on an unarmed target would
## (PhysicalBlowGuilt's `act.<actor>.blow` id, so it records once per save).
const FLAG_STRUCK_PORTER := &"flag.prologue.struck_porter"
const PORTER_BLOW_ACT := &"act.almshouse_porter.blow"
const PORTER_BLOW_CIRCUMSTANCE := &"act.unarmed_victim"
## Story flags the opening guarantees even when skipped.
const FLAG_APPRENTICED := &"flag.prologue.apprenticed"
## Kalev saw his own mark on the spearhead: the lead for the later maker's-mark quest.
const FLAG_SAW_MAKERS_MARK := &"flag.prologue.saw_makers_mark"

const SPAWN_ID := "holy_spirit_almshouse"
const ANCHOR_SICKBED := "anchor.holy_spirit.sickbed"
const ANCHOR_ATTENDANT := "anchor.holy_spirit.sickbed_attendant"
const ANCHOR_KALEV := "anchor.holy_spirit.almshouse_kalev"
const ANCHOR_ALMSHOUSE := "anchor.holy_spirit.almshouse"
const DOOR_ALMSHOUSE := "door.holy_spirit.almshouse"

const PORTER_SCENE := preload("res://assets/characters/variants/citizen_m_adult_heavy.tscn")
const MATRON_SCENE := preload("res://assets/characters/variants/citizen_f_adult_thin.tscn")
const WATCHMAN_SCENE := preload("res://assets/characters/variants/watchman.tscn")
const KALEV_SCENE := preload("res://assets/characters/kalev/kalev.tscn")
const PORTER_SPEAKER_ID := &"char.almshouse_porter"
const MATRON_SPEAKER_ID := &"char.almshouse_matron"
const LAMBERT_SPEAKER_ID := &"char.watchman_lambert"
const KALEV_SPEAKER_ID := &"char.kalev"
const SpiritSightScript := preload("res://scripts/combat/spirit_sight.gd")
const ConversationShotScript := preload("res://scripts/prologue/conversation_shot.gd")
## The porter stops this far in front of the boy (the sick-room is about 10 x 5.5 m).
const PORTER_STEP := 2.2
## The porter duel's disc; the room's walls keep their collision.
const ARENA_RADIUS := 2.8
## The porter stands this far (radians) to the side of the camera's line through the boy.
const PORTER_ANGLE := 0.6
## Lambert's phantom rises this far beyond the foot of the bed, in the aisle (no room known).
const PHANTOM_STEP := 1.4
## In a known room the phantom stands this far from the boy, on the side that leaves the
## third-person camera (about CAMERA_BACK behind him) inside the room.
const PHANTOM_DISTANCE := 2.0
const CAMERA_BACK := 5.0
const LAMBERT_ARENA_RADIUS := 2.2
## Kalev stands at the foot of the bed, this far beyond it.
const KALEV_FOOT_STEP := 0.55
## Gertrud stands beside the foot of the bed, on the side away from the boy.
const MATRON_ACROSS := 0.9
const MATRON_ALONG := 0.6
## Half the length of a straw tick when no head/feet points are authored.
const BED_HALF_LENGTH := 0.85
## A lying rig's origin is its foot end, this far inside the tick (HouseholdLayout sleep slots).
const LIE_FOOT_INSET := 0.12
## The shot keeps the camera this close around the sickbed.
const SICKROOM_SHOT_RADIUS := 3.0
## Lambert's phantom: a pale, half-seen copy of him in his watch kit.
const PHANTOM_TRANSPARENCY := 0.4
const PHANTOM_COLOR := Color(0.62, 0.78, 1.0, 0.35)
## Frames to wait after the city is ready so the runtime has mirrored the player rig.
const SETTLE_FRAMES := 3
const HIT_RECOVER_SEC := 0.5

## Set by the main menu before it loads the city; the city consumes it once in _ready.
static var pending := false

var stage: StringName = STAGE_WAITING

var _state: GameState
var _db: ContentDB
var _city: Node
var _player: Node2D
var _host: SpiritArenaHost
var _porter: Node3D
var _matron: Node3D
var _lambert: Node3D
var _phantom: Node3D
var _kalev: Node3D
var _runner: Node
var _runner_done := Callable()
var _dialogue_ui: Node
var _cancel_held := 0.0
var _hint_layer: CanvasLayer
var _shot: Node
var _arena_center := Vector3.ZERO
var _floor_y := 0.0
var _room: Dictionary = {}


## The menu's New Game: arm the opening and arrive in the almshouse.
static func start_new_game(navigator: Node) -> void:
	pending = true
	navigator.call(&"go_to_scene", &"reval_city", StringName(SPAWN_ID))


## Called by the city level. Returns the opening when one was pending (and mounts it).
static func consume(city: Node) -> SmithyOpening:
	if not pending:
		return null
	pending = false
	var opening := SmithyOpening.new()
	opening.name = "SmithyOpening"
	city.add_child(opening)
	return opening


func _ready() -> void:
	_city = get_parent()
	_player = _city.get(&"player") as Node2D
	var session := get_node_or_null(^"/root/SessionState")
	if session != null:
		_state = session.state
		_db = session.content_db
	_arrive_without_site_spawn()
	for _frame in SETTLE_FRAMES:
		await get_tree().process_frame
	if is_inside_tree():
		begin_duel()


func _process(delta: float) -> void:
	if stage in ACTIVE_STAGES:
		_cancel_held = _cancel_held + delta if Input.is_action_pressed(&"ui_cancel") else 0.0
		if _cancel_held >= HOLD_TO_SKIP_SEC:
			skip()


## WHY _input: in the city Esc opens the pause menu from _unhandled_input; while the opening
## runs Esc means "hold to skip", so its press is consumed before the menu sees it.
func _input(event: InputEvent) -> void:
	if not (stage in ACTIVE_STAGES):
		return
	if event.is_action(&"ui_cancel"):
		get_viewport().set_input_as_handled()


## Beat 1: spawn the porter in front of the boy and open the duel on a disc in the sick-room.
func begin_duel() -> bool:
	if stage != STAGE_WAITING or _state == null or _db == null or _player == null:
		return false
	for grant_id in STARTER_GRANTS:
		MagicResolver.apply_grant_operation(_state, _db, grant_id)
	_state.set_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER, DUEL_WILLPOWER)
	_set_stage(STAGE_CONFRONTATION)
	_show_skip_hint()
	var world := _world()
	var hero_rig := _hero_rig()
	_floor_y = hero_rig.global_position.y if hero_rig != null else 0.0
	var hero_at := _hero_world(_floor_y)
	# Off the camera axis so the boy's own rig and aura never hide the porter behind him.
	var facing := _camera_facing().rotated(PORTER_ANGLE)
	var porter_at := hero_at + Vector3(facing.x, 0.0, facing.y) * PORTER_STEP
	_porter = _place_actor(PORTER_SCENE, "Porter", world, porter_at, hero_at, PORTER_SPEAKER_ID)
	if _open_duel(_porter, hero_at, porter_at, ARENA_RADIUS, CONFRONTATION, _on_confrontation_closed):
		return true
	_begin_carried_in()
	return false


func skip() -> void:
	if stage == STAGE_DONE:
		return
	if _host != null and is_instance_valid(_host):
		for handler: Callable in [_on_confrontation_closed, _on_lambert_closed]:
			if _host.closed.is_connected(handler):
				_host.closed.disconnect(handler)
		_host.close()
		_host.queue_free()
		_host = null
	_close_dialogue()
	record_duel_guilt(_state)
	var sight := get_tree().get_first_node_in_group(SpiritSightScript.SIGHT_GROUP)
	if sight != null:
		sight.call(&"leave_immediately")
	_state.set_flag(FLAG_APPRENTICED, true)
	_state.set_flag(FLAG_SAW_MAKERS_MARK, true)
	_finish()


## Turn the duel's physical outcome into guilt. Returns the weights applied ({} when the
## porter was not struck or the blow was already recorded).
static func record_duel_guilt(state: GameState) -> Dictionary:
	if state == null or not state.get_flag(FLAG_STRUCK_PORTER):
		return {}
	return state.guilt.record_act(PORTER_BLOW_ACT, PORTER_BLOW_CIRCUMSTANCE)


func host() -> SpiritArenaHost:
	return _host


func porter() -> Node3D:
	return _porter


func matron() -> Node3D:
	return _matron


## The wounded watchman lying on the sickbed (stays after the opening).
func lambert() -> Node3D:
	return _lambert


## Lambert's fear, the opponent of the calming duel.
func phantom() -> Node3D:
	return _phantom


func kalev() -> Node3D:
	return _kalev


func dialogue_runner() -> Node:
	return _runner


func shot() -> Node:
	return _shot


## World XZ points of the sick-room set: {bed, head, feet, lie_h, attendant, kalev_entry}.
func sickroom() -> Dictionary:
	if _room.is_empty():
		_room = _resolve_sickroom()
	return _room


func _on_confrontation_closed(_outcome: Dictionary) -> void:
	record_duel_guilt(_state)
	_host.queue_free()
	_host = null
	_begin_carried_in()


## Beat 2a: dusk; Lambert lies on the sickbed, Gertrud sets the boy beside him.
func _begin_carried_in() -> void:
	_set_stage(STAGE_CARRIED_IN)
	_close_sight()
	_free_actor(_porter)
	_porter = null
	_stage_sickroom()
	_frame_conversation(_matron)
	if not _start_dialogue(CARRIED_IN, _on_carried_in_finished):
		_on_carried_in_finished(CARRIED_IN)


func _on_carried_in_finished(_dialogue_id: StringName) -> void:
	_close_dialogue()
	_release_shot()
	_begin_lambert_duel()


## Beat 2b: the boy kneels by the bed and meets Lambert's fear as a phantom.
func _begin_lambert_duel() -> void:
	_set_stage(STAGE_LAMBERT)
	_state.set_magic_resource(
		GameState.MAGIC_RESOURCE_WILLPOWER,
		maxi(DUEL_WILLPOWER, _state.get_magic_resource(GameState.MAGIC_RESOURCE_WILLPOWER))
	)
	var hero_at := _hero_world(_floor_y)
	var at := _phantom_spot(Vector2(hero_at.x, hero_at.z))
	var phantom_at := Vector3(at.x, _floor_y, at.y)
	_phantom = _place_actor(
		WATCHMAN_SCENE, "LambertPhantom", _world(), phantom_at, hero_at, LAMBERT_SPEAKER_ID
	)
	_make_phantom(_phantom)
	_turn_camera(Vector2(phantom_at.x - hero_at.x, phantom_at.z - hero_at.z))
	if not _open_duel(
		_phantom, hero_at, phantom_at, LAMBERT_ARENA_RADIUS, LAMBERT_FEAR, _on_lambert_closed
	):
		_free_actor(_phantom)
		_phantom = null
		_begin_kalev()


func _on_lambert_closed(_outcome: Dictionary) -> void:
	_host.queue_free()
	_host = null
	_free_actor(_phantom)
	_phantom = null
	_begin_kalev()


## Beat 3: Kalev at the foot of the bed speaks to the iron and takes the boy in.
func _begin_kalev() -> void:
	_set_stage(STAGE_KALEV)
	# Dialogue closes spirit sight (ADR 0041 section 2): the reverse ripple plays as he enters.
	_close_sight()
	if _lambert == null:
		_stage_sickroom()
	_bring_in_kalev()
	_frame_conversation(_kalev)
	if not _start_dialogue(KALEV_ARRIVES, _on_kalev_finished):
		_state.set_flag(FLAG_APPRENTICED, true)
		_state.set_flag(FLAG_SAW_MAKERS_MARK, true)
		_finish()


func _on_kalev_finished(_dialogue_id: StringName) -> void:
	_finish()


## Kalev goes ahead to the forge and Gertrud to her work; Lambert stays on the sickbed. Play
## continues where the boy stands.
func _finish() -> void:
	if stage == STAGE_DONE:
		return
	_set_stage(STAGE_DONE)
	if _hint_layer != null:
		_hint_layer.visible = false
	for actor: Node3D in [_porter, _phantom, _kalev, _matron]:
		_free_actor(actor)
	_porter = null
	_phantom = null
	_kalev = null
	_matron = null
	_release_shot()
	_close_dialogue()
	finished.emit()


## Opens a scripted duel against `opponent` on a disc between it and the boy.
func _open_duel(
	opponent: Node3D, hero_at: Vector3, opponent_at: Vector3, radius: float,
	dialogue_id: StringName, on_closed: Callable
) -> bool:
	_host = SpiritArenaHost.new()
	_host.model_front_plus_z = true
	add_child(_host)
	_host.closed.connect(on_closed)
	var keep: Array[Node3D] = [opponent]
	var hero_rig := _hero_rig()
	if hero_rig != null:
		keep.append(hero_rig)
	_arena_center = (hero_at + opponent_at) * 0.5
	# The city player is a logic-plane body: 32 logic px per world metre (CityPlan).
	if _host.attach_arena(
		_world(), _arena_center, keep, true, _player, opponent,
		int(CityPlan.LOGIC_PX_PER_UNIT), radius
	):
		# R-1764: the opponent's visible soul lights are the ones the duel scores.
		if is_instance_valid(_host.opponent_aura_view) and _host.opponent_aura_view.profile != null:
			_host.opponent_aura = _host.opponent_aura_view.profile
	if _host.open_scripted(_db, _state, dialogue_id):
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			_host.form_view().track_3d(camera, opponent)
		_host.duel.exchange_resolved.connect(_react_to_exchange.bind(opponent))
		return true
	_host.closed.disconnect(on_closed)
	_host.detach_arena()
	_host.queue_free()
	_host = null
	return false


func _start_dialogue(dialogue_id: StringName, on_done: Callable) -> bool:
	_close_dialogue()
	_dialogue_ui = DialogueUI.new()
	add_child(_dialogue_ui)
	_dialogue_ui.apply_settings(UserSettings.dialogue)
	# R-1888: a speaker's lines cut to them over the boy's shoulder; a reply cuts to the boy.
	_dialogue_ui.line_shown.connect(_on_line_shown)
	_dialogue_ui.choices_shown.connect(_on_choices_shown)
	_runner = DialogueRunner.new()
	add_child(_runner)
	var presenter := DialogueUiPresenter.new()
	presenter.configure(_dialogue_ui, _runner)
	_runner.configure(_db, _state, presenter)
	_runner_done = on_done
	_runner.finished.connect(on_done)
	return _runner.start(dialogue_id)


func _close_dialogue() -> void:
	if _runner != null and is_instance_valid(_runner):
		if _runner_done.is_valid() and _runner.finished.is_connected(_runner_done):
			_runner.finished.disconnect(_runner_done)
		_runner.queue_free()
	_runner = null
	_runner_done = Callable()
	if _dialogue_ui != null and is_instance_valid(_dialogue_ui):
		_dialogue_ui.queue_free()
	_dialogue_ui = null


func _close_sight() -> void:
	var sight := get_tree().get_first_node_in_group(SpiritSightScript.SIGHT_GROUP)
	if sight != null and _state.spirit_sight:
		sight.call(&"set_enabled", false)


## Lambert on the sickbed, Gertrud at its foot, the boy at the attendant's place facing him.
func _stage_sickroom() -> void:
	var room := sickroom()
	var head: Vector2 = room["head"]
	var feet: Vector2 = room["feet"]
	var head_to_foot := (feet - head).normalized()
	if not is_instance_valid(_lambert):
		var origin := feet - head_to_foot * LIE_FOOT_INSET
		var lie_y := _floor_y + float(room["lie_h"]) + CitizenActor.LIE_LIFT
		_lambert = _place_lying(
			Vector3(origin.x, lie_y, origin.y), head_to_foot
		)
	var attendant: Vector2 = room["attendant"]
	if CityPlan.to_world_xz(_player.global_position).distance_to(attendant) > 0.05:
		_player.global_position = CityPlan.to_logic(attendant)
	var bed: Vector2 = room["bed"]
	if _player.has_method(&"set_view_facing"):
		_player.call(&"set_view_facing", bed - attendant)
	if not is_instance_valid(_matron):
		var across := Vector2(-head_to_foot.y, head_to_foot.x)
		if across.dot(attendant - bed) > 0.0:
			across = -across
		var at := feet + head_to_foot * MATRON_ALONG + across * MATRON_ACROSS
		_matron = _place_actor(
			MATRON_SCENE, "Matron", _world(), Vector3(at.x, _floor_y, at.y),
			Vector3(bed.x, _floor_y, bed.y), MATRON_SPEAKER_ID
		)


func _bring_in_kalev() -> void:
	if is_instance_valid(_kalev):
		return
	var room := sickroom()
	var head: Vector2 = room["head"]
	var feet: Vector2 = room["feet"]
	var at := feet + (feet - head).normalized() * KALEV_FOOT_STEP
	var bed: Vector2 = room["bed"]
	_kalev = _place_actor(
		KALEV_SCENE, "Kalev", _world(), Vector3(at.x, _floor_y, at.y),
		Vector3(bed.x, _floor_y, bed.y)
	)


## Cuts to an eye-level shot of the boy and `speaker` by the sickbed, kept inside the room.
func _frame_conversation(speaker: Node3D) -> void:
	if not is_instance_valid(speaker):
		return
	_release_shot()
	var hero_rig := _hero_rig()
	var hero_at := hero_rig.global_position if hero_rig != null else _hero_world(_floor_y)
	# The boy turns to the one who is speaking to him (logic plane shares the world's x/z axes).
	var toward := Vector2(speaker.global_position.x - hero_at.x, speaker.global_position.z - hero_at.z)
	if _player.has_method(&"set_view_facing"):
		_player.call(&"set_view_facing", toward)
	_shot = ConversationShotScript.new()
	_shot.name = "ConversationShot"
	add_child(_shot)
	var subjects: Array[Node3D] = [speaker]
	# The patient is in the picture: the shot keeps the bed between the speakers in frame.
	if is_instance_valid(_lambert):
		subjects.append(_lambert)
		var framed_only: Array[Node3D] = [_lambert]
		_shot.set(&"framed_only", framed_only)
	if hero_rig != null:
		subjects.push_front(hero_rig)
	var bed: Vector2 = sickroom()["bed"]
	_shot.call(
		&"frame_subjects", _world(), subjects, Vector3(bed.x, _floor_y, bed.y),
		SICKROOM_SHOT_RADIUS, self
	)


func _release_shot() -> void:
	if _shot != null and is_instance_valid(_shot):
		_shot.call(&"release")
		_shot.queue_free()
	_shot = null


func _on_line_shown(speaker_id: StringName) -> void:
	if _shot == null or not is_instance_valid(_shot):
		return
	var speaker: Node3D = {KALEV_SPEAKER_ID: _kalev, MATRON_SPEAKER_ID: _matron}.get(speaker_id)
	if is_instance_valid(speaker):
		_shot.call(&"cue_line", speaker)


func _on_choices_shown() -> void:
	var hero_rig := _hero_rig()
	if _shot != null and is_instance_valid(_shot) and hero_rig != null:
		_shot.call(&"focus", hero_rig)


func _react_to_exchange(result: Dictionary, opponent: Node3D) -> void:
	# Words and spells that cost the opponent pressure make him flinch (same rule the
	# retired almshouse stage used); the boy's own rig belongs to the city runtime.
	if not is_instance_valid(opponent):
		return
	var kind := String(result.get("kind", ""))
	var hurt := (
		(kind in ["reply", "word"] and float(result.get("damage", 0.0)) > 0.0)
		or (kind == "spell" and String(result.get("arena_effect", "")) in ["pressure", "stagger"])
	)
	if not hurt:
		return
	if opponent.has_method(&"play_animation") and opponent.call(&"play_animation", &"hit"):
		get_tree().create_timer(HIT_RECOVER_SEC).timeout.connect(_recover.bind(opponent))


func _recover(actor: Node3D) -> void:
	if is_instance_valid(actor) and actor.call(&"current_canonical_animation") == &"hit":
		actor.call(&"play_animation", &"idle")


func _world() -> Node3D:
	var world := _city.get(&"world") as Node3D
	return world if world != null else _city.get_viewport().find_world_3d() as Node3D


func _hero_rig() -> Node3D:
	return get_tree().get_first_node_in_group(&"player_view_rig") as Node3D


func _hero_world(floor_y: float) -> Vector3:
	var xz := CityPlan.to_world_xz(_player.global_position)
	return Vector3(xz.x, floor_y, xz.y)


## Without the site's own `holy_spirit_almshouse` spawn the city put the boy at its default
## spawn; move him into the sick-room (attendant's place, else the room anchor).
func _arrive_without_site_spawn() -> void:
	var plan: Variant = _city.get(&"plan")
	if plan == null or _player == null or not CityTravel.site_spawn(plan, SPAWN_ID).is_empty():
		return
	for anchor_id in [ANCHOR_ATTENDANT, ANCHOR_ALMSHOUSE]:
		var anchor := _site_anchor(anchor_id)
		if not anchor.is_empty():
			push_warning("SmithyOpening: no site spawn %s, arriving at %s" % [SPAWN_ID, anchor_id])
			_player.global_position = CityPlan.to_logic(anchor["at"])
			return


## Where Lambert's fear stands. In a site room: the direction from the boy whose phantom spot
## is in the room and whose camera spot behind the boy stays in it longest (the walls keep their
## collision and the camera would otherwise sit outside them). Else beyond the foot of the bed.
func _phantom_spot(hero: Vector2) -> Vector2:
	var polygon := _room_polygon(hero)
	if not polygon.is_empty():
		var best := Vector2.INF
		var best_back := -1.0
		for step in 16:
			var dir := Vector2.from_angle(TAU * step / 16.0)
			var spot := hero + dir * PHANTOM_DISTANCE
			if not Geometry2D.is_point_in_polygon(spot, polygon):
				continue
			var back := 0.0
			while back < CAMERA_BACK:
				if not Geometry2D.is_point_in_polygon(hero - dir * (back + 0.25), polygon):
					break
				back += 0.25
			if back > best_back:
				best_back = back
				best = spot
		if best.is_finite():
			return best
	var room := sickroom()
	var feet: Vector2 = room["feet"]
	return feet + (feet - (room["head"] as Vector2)).normalized() * PHANTOM_STEP


func _room_polygon(at: Vector2) -> PackedVector2Array:
	var plan: Variant = _city.get(&"plan")
	if plan == null:
		return PackedVector2Array()
	for site: CitySite in (plan as CityPlan).sites:
		var room := site.room_at(at)
		if not room.is_empty():
			return room["polygon"]
	return PackedVector2Array()


## The sick-room set from the site anchors, with fallbacks (see the class comment).
func _resolve_sickroom() -> Dictionary:
	var hero := CityPlan.to_world_xz(_player.global_position)
	var attendant_anchor := _site_anchor(ANCHOR_ATTENDANT)
	var room_anchor := _site_anchor(ANCHOR_ALMSHOUSE)
	var bed_anchor := _site_anchor(ANCHOR_SICKBED)
	var attendant: Vector2 = attendant_anchor.get("at", room_anchor.get("at", hero))
	var facing: Vector2 = attendant_anchor.get("facing", _spawn_facing())
	var bed: Vector2 = bed_anchor.get("at", attendant + facing)
	var head: Variant = bed_anchor.get("head")
	var feet: Variant = bed_anchor.get("feet")
	if head == null or feet == null:
		# The attendant kneels at the bed's long side: the body lies across that line.
		var across := (bed - attendant).normalized()
		var along := Vector2(-across.y, across.x)
		head = bed - along * BED_HALF_LENGTH
		feet = bed + along * BED_HALF_LENGTH
	var kalev_entry: Vector2 = _site_anchor(ANCHOR_KALEV).get("at", Vector2.INF)
	if not kalev_entry.is_finite():
		kalev_entry = _door_inside(DOOR_ALMSHOUSE)
	if not kalev_entry.is_finite():
		kalev_entry = (feet as Vector2) + ((feet as Vector2) - (head as Vector2)).normalized()
	return {
		"bed": bed,
		"head": head,
		"feet": feet,
		# Without an authored bed the body lies on the floor.
		"lie_h": float(bed_anchor.get("lie_h", 0.0)),
		"attendant": attendant,
		"kalev_entry": kalev_entry,
	}


## A site anchor in world XZ: {at, facing?, head?, feet?, lie_h?}; {} when no site has it.
func _site_anchor(anchor_id: String) -> Dictionary:
	var plan: Variant = _city.get(&"plan")
	if plan == null:
		return {}
	for site: CitySite in (plan as CityPlan).sites:
		for a: Dictionary in site.data.get("anchors", []):
			if String(a.get("id", "")) != anchor_id:
				continue
			var out := {"at": site.to_world(_vec(a["at"]))}
			if a.has("facing_deg"):
				out["facing"] = Vector2.from_angle(deg_to_rad(float(a["facing_deg"]))).rotated(
					site.rotation
				)
			if a.has("head_at") and a.has("feet_at"):
				out["head"] = site.to_world(_vec(a["head_at"]))
				out["feet"] = site.to_world(_vec(a["feet_at"]))
			if a.has("lie_h"):
				out["lie_h"] = float(a["lie_h"])
			return out
	return {}


## A step inside a site door (midpoint plus 1.2 m along its `inward`), INF when absent.
func _door_inside(door_id: String) -> Vector2:
	var plan: Variant = _city.get(&"plan")
	if plan == null:
		return Vector2.INF
	for site: CitySite in (plan as CityPlan).sites:
		for d: Dictionary in site.data.get("doors", []):
			if String(d.get("id", "")) == door_id:
				var mid := (_vec(d["a"]) + _vec(d["b"])) * 0.5 + _vec(d["inward"]) * 1.2
				return site.to_world(mid)
	return Vector2.INF


static func _vec(raw: Variant) -> Vector2:
	return Vector2(float(raw[0]), float(raw[1]))


## Where the gameplay camera looks, flattened. The porter stands that way from the boy so the
## third-person camera sees the boy's back and the porter's face, never the porter's back.
func _camera_facing() -> Vector2:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		var forward := -camera.global_basis.z
		var flat := Vector2(forward.x, forward.z)
		if not flat.is_zero_approx():
			return flat.normalized()
	return _spawn_facing()


## Turn the gameplay camera to look along `look` (world XZ), as the city does on arrival.
func _turn_camera(look: Vector2) -> void:
	var runtime: Variant = _city.get(&"runtime")
	var view: Variant = _city.get(&"view")
	if runtime == null or view == null or look.is_zero_approx():
		return
	var controller: Variant = runtime.get(&"_camera_controller")
	var camera := view.call(&"view_camera") as Camera3D
	if controller == null or camera == null:
		return
	var yaw := rad_to_deg(atan2(-look.x, -look.y))
	controller.call(&"rotate_view_degrees", yaw - camera.rotation_degrees.y)


func _spawn_facing() -> Vector2:
	var plan: Variant = _city.get(&"plan")
	var site := CityTravel.site_spawn(plan, SPAWN_ID) if plan != null else {}
	var facing: Vector2 = site.get("facing", Vector2.ZERO)
	if facing.is_zero_approx() and _player.has_method(&"facing_direction"):
		facing = _player.call(&"facing_direction")
	return facing.normalized() if not facing.is_zero_approx() else Vector2.UP


func _place_actor(
	scene: PackedScene, actor_name: String, parent: Node3D, at: Vector3, look_at_point: Vector3,
	speaker_id: StringName = &""
) -> Node3D:
	var actor := scene.instantiate() as Node3D
	actor.name = actor_name
	_rekey(actor, speaker_id)
	parent.add_child(actor)
	actor.global_position = at
	var direction := look_at_point - at
	# glTF rigs face +Z.
	actor.rotation.y = atan2(direction.x, direction.z)
	if actor.has_method(&"play_animation"):
		actor.call(&"play_animation", &"idle")
	return actor


## RealisticRig talks when the announced speaker equals its variant id; re-key a borrowed
## crowd body on a copy so the shared variant resource stays untouched. `drop_equipment` also
## takes the spear out of a watchman's hand.
static func _rekey(actor: Node3D, speaker_id: StringName, drop_equipment := false) -> void:
	if speaker_id.is_empty() or not actor.get(&"variant") is CharacterVariant:
		return
	var keyed := (actor.get(&"variant") as CharacterVariant).duplicate() as CharacterVariant
	keyed.stable_id = speaker_id
	if drop_equipment:
		keyed.equipment = null
	actor.set(&"variant", keyed)


## Lambert on his back on the tick, head toward the wall: the standing idle turned flat (as
## CityCitizens lays sleepers), the origin at the foot end, +Z from head to foot. Bare-headed
## and without his spear. Not an aura bearer, so the duel arena neither hides him nor gives him
## an aura of his own (his phantom is the opponent).
func _place_lying(origin: Vector3, head_to_foot: Vector2) -> Node3D:
	var actor := WATCHMAN_SCENE.instantiate() as Node3D
	actor.name = "Lambert"
	_rekey(actor, LAMBERT_SPEAKER_ID, true)
	var outfit: Variant = actor.get(&"default_outfit")
	if outfit is Array:
		var kept: Array[CharacterWearable] = []
		for wearable: CharacterWearable in outfit:
			if wearable != null and not wearable.resource_path.contains("kettle_hat"):
				kept.append(wearable)
		actor.set(&"default_outfit", kept)
	_world().add_child(actor)
	actor.remove_from_group(SharedCharacterRig.SPIRIT_AURA_GROUP)
	actor.global_position = origin
	actor.rotation.y = atan2(head_to_foot.x, head_to_foot.y)
	var model := actor.get_node_or_null(^"Model") as Node3D
	if model != null:
		model.rotation.x = -PI * 0.5
	if actor.has_method(&"play_animation"):
		actor.call(&"play_animation", &"idle")
	return actor


## Pale and half-seen: every mesh of the rig goes translucent under a cold overlay.
static func _make_phantom(actor: Node3D) -> void:
	if not is_instance_valid(actor):
		return
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	overlay.albedo_color = PHANTOM_COLOR
	for node in actor.find_children("*", "GeometryInstance3D", true, false):
		var mesh := node as GeometryInstance3D
		mesh.transparency = PHANTOM_TRANSPARENCY
		mesh.material_overlay = overlay
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _free_actor(actor: Node3D) -> void:
	if is_instance_valid(actor):
		actor.queue_free()


func _set_stage(next: StringName) -> void:
	stage = next
	stage_changed.emit(next)


func _show_skip_hint() -> void:
	if _hint_layer != null:
		return
	_hint_layer = CanvasLayer.new()
	_hint_layer.layer = 91
	add_child(_hint_layer)
	var label := Label.new()
	label.text = "Hold Esc to skip the introduction"
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(1, 1, 1, 0.6)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.position += Vector2(-16, 12)
	_hint_layer.add_child(label)
