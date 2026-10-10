class_name CityCitizens
extends Node2D

## The census residents of Reval walking their own streets (docs/SYSTEMS/CITIZENS.md).
## Replaces the generic townsfolk pool: people near Kalev are the real residents
## of the houses around him, seated by the timetable in CitizenRoster, in the blank
## body that matches their sex, age and build. Hover shows a name, click (or
## interact beside them) opens the information panel. Residents at home in a
## furnished house near Kalev (CityInteriors) are shown inside it, asleep, at
## table or at the hearth; residents fetching firewood carry it home on their back.

const SPAWN_RADIUS := 62.0
const DESPAWN_RADIUS := 80.0
const MAX_LIVE := 30
## People shown at home: within this distance of Kalev, at most MAX_INDOOR.
const INDOOR_RADIUS := 16.0
const MAX_INDOOR := 18
const SPAWN_PER_FRAME := 3
const SELECT_REACH := 3.0
const PICK_RADIUS := 0.55
const REFRESH_SECONDS := 1.0
const SCAN_PER_FRAME := 250

static var _armful: PackedScene

var plan: CityPlan
var player: Node2D
var roster: CitizenRoster
## Test and capture hook: pins the hour (0..24) instead of the city clock.
var hour_override := -1.0
## Main-thread cost of the last scan step (microseconds), for budget checks.
var last_scan_usec := 0

var _live: Dictionary = {}  # resident index -> CitizenActor
var _since := REFRESH_SECONDS
var _scan_origin := Vector2.ZERO
var _scan_hour := 0.0
var _candidates := PackedInt32Array()
var _cursor := 0
var _wanted: Array = []
var _panel: CitizenInfoPanel
var _tag: Label3D
var _hover: CitizenActor
var _selected: CitizenActor
var _interiors: CityInteriors


static func create(city_plan: CityPlan, kalev: Node2D) -> CityCitizens:
	var node := CityCitizens.new()
	node.name = "CityCitizens"
	node.plan = city_plan
	node.player = kalev
	node.roster = CitizenRoster.load_for(city_plan)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--city-hour="):
			node.hour_override = float(arg.substr(12))
	return node


func _ready() -> void:
	_panel = CitizenInfoPanel.new()
	# On the tree root: the 2D actors layer this node lives under is not drawn in the 3D city.
	get_tree().root.add_child.call_deferred(_panel)
	_panel.closed.connect(_on_panel_closed)
	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = false
	_tag.pixel_size = 0.0035
	_tag.font_size = 40
	_tag.outline_size = 12
	_tag.modulate = Color(1, 0.95, 0.8)
	_tag.visible = false


func _exit_tree() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	if is_instance_valid(_tag) and _tag.get_parent() == null:
		_tag.free()


func hour() -> float:
	if hour_override >= 0.0:
		return hour_override
	var scene := get_tree().get_first_node_in_group(&"seamless_city")
	var runtime: Variant = scene.get("runtime") if scene != null else null
	if runtime != null:
		return DayNightCycle.progress_to_hour(float(runtime.get("cycle_progress")))
	var time := Time.get_time_dict_from_system()
	return float(time["hour"]) + float(time["minute"]) / 60.0


func live_count() -> int:
	return _live.size()


func live_actors() -> Array[CitizenActor]:
	var out: Array[CitizenActor] = []
	for actor: CitizenActor in _live.values():
		out.append(actor)
	return out


func _process(delta: float) -> void:
	_since += delta
	if _since >= REFRESH_SECONDS and player != null and _cursor >= _candidates.size():
		_since = 0.0
		refresh(CityPlan.to_world_xz(player.global_position))
	var start := Time.get_ticks_usec()
	_scan_step()
	last_scan_usec = Time.get_ticks_usec() - start
	_style_new_rigs()
	_pose_rigs()
	_update_tag()
	if _selected != null and is_instance_valid(_selected) and _panel.is_open():
		_panel.update_now(roster.describe(_selected.index, hour()))


## Seat the residents who are outdoors within SPAWN_RADIUS and free the rest.
## Candidates are scanned SCAN_PER_FRAME at a time so a crowded forum never hitches.
func refresh(me: Vector2) -> void:
	_scan_origin = me
	_scan_hour = hour()
	_candidates = roster.candidates_near(me, SPAWN_RADIUS)
	_cursor = 0
	_wanted.clear()
	for index: int in _live.keys():
		var actor: CitizenActor = _live[index]
		if (
			not is_instance_valid(actor)
			or (not actor.outdoors and not actor.at_home)
			or actor.world_xz().distance_to(me) > DESPAWN_RADIUS
			or (actor.at_home and actor.world_xz().distance_to(me) > INDOOR_RADIUS + 4.0)
		):
			_release(index)


func _scan_step() -> void:
	if _cursor >= _candidates.size():
		if not _wanted.is_empty():
			_spawn_wanted()
		return
	var end := mini(_cursor + SCAN_PER_FRAME, _candidates.size())
	var interiors := interiors_node()
	for k in range(_cursor, end):
		var index := _candidates[k]
		if _live.has(index):
			continue
		var state := roster.resolve(index, _scan_hour)
		if state["visible"]:
			var distance := (state["pos"] as Vector2).distance_to(_scan_origin)
			if distance <= SPAWN_RADIUS:
				_wanted.append([distance, index, false])
		elif interiors != null:
			var inside := interiors.indoor_state(index, _scan_hour, float(state["arrived"]))
			if not inside.is_empty():
				var distance := (inside["pos"] as Vector2).distance_to(_scan_origin)
				if distance <= INDOOR_RADIUS:
					_wanted.append([distance, index, true])
	_cursor = end
	if _cursor < _candidates.size():
		return
	if _wanted.is_empty():
		return
	_wanted.sort()
	_spawn_wanted()


## Seats the wanted residents nearest first, at most SPAWN_PER_FRAME a frame
## (loading a body is the expensive part); the rest wait for the next frames.
func _spawn_wanted() -> void:
	var interiors := interiors_node()
	var outdoor := 0
	var indoor := 0
	for actor: CitizenActor in _live.values():
		if is_instance_valid(actor) and actor.at_home:
			indoor += 1
		else:
			outdoor += 1
	var spawned := 0
	while not _wanted.is_empty() and spawned < SPAWN_PER_FRAME:
		var entry: Array = _wanted.pop_front()
		if _live.has(int(entry[1])):
			continue
		if entry[2]:
			if indoor >= MAX_INDOOR:
				continue
			indoor += 1
		else:
			if outdoor >= MAX_LIVE:
				continue
			outdoor += 1
		var actor := CitizenActor.create(roster, int(entry[1]), Callable(self, "hour"))
		actor.interiors = interiors
		add_child(actor)
		_live[int(entry[1])] = actor
		spawned += 1


## The scene's furnished houses (CityInteriors), or null outside the city.
func interiors_node() -> CityInteriors:
	if _interiors == null or not is_instance_valid(_interiors):
		var scene := get_tree().get_first_node_in_group(&"seamless_city")
		_interiors = scene.get("interiors") as CityInteriors if scene != null else null
	return _interiors


func _release(index: int) -> void:
	var actor: CitizenActor = _live.get(index)
	_live.erase(index)
	if not is_instance_valid(actor):
		return
	if actor == _selected:
		_panel.hide_panel()
	if actor == _hover:
		_hover = null
	if _tag.get_parent() != null and _tag.get_parent() == _rig_of(actor):
		_tag.get_parent().remove_child(_tag)
	actor.queue_free()


func _runtime() -> MapViewRuntime:
	var scene := get_tree().get_first_node_in_group(&"seamless_city")
	return scene.get("runtime") as MapViewRuntime if scene != null else null


func _rig_of(actor: CitizenActor) -> SharedCharacterRig:
	var runtime := _runtime()
	return runtime.get_actor_rig(actor) if runtime != null else null


## Height and head size of a resident's rig; the body is the nearest blank, this
## makes it the right stature (the rig only exists once MapViewRuntime has mirrored the actor).
func _style_new_rigs() -> void:
	for actor: CitizenActor in _live.values():
		if actor.rig_styled:
			continue
		var rig := _rig_of(actor)
		if rig == null or not rig.is_node_ready():
			continue
		actor.rig_styled = true
		var model := rig.get_node_or_null("Model") as Node3D
		if model != null:
			model.scale = rig.model_scale * float(actor.record["height_scale"])
		_dye(rig, actor.record)
		CitizenGear.arm(rig, actor.record)
		var proportions := rig.find_child("RealisticProportions", true, false)
		if proportions != null:
			proportions.set("head_scale", float(actor.record["head_scale"]))


## Sleepers lie on their backs on the bed (the standing idle turned flat, head
## behind the origin); people carrying firewood home have an armful on their back.
func _pose_rigs() -> void:
	for actor: CitizenActor in _live.values():
		if not is_instance_valid(actor) or not actor.rig_styled:
			continue
		var rig := _rig_of(actor)
		if rig == null:
			continue
		var model := rig.get_node_or_null("Model") as Node3D
		if model != null:
			var lying := -PI * 0.5 if actor.is_lying() else 0.0
			if not is_equal_approx(model.rotation.x, lying):
				model.rotation.x = lying
		var carrying := rig.equipped(&"back") != null
		if actor.carrying_wood != carrying:
			if actor.carrying_wood:
				var bundle := rig.equip(&"back", _armful_scene())
				if bundle != null:
					_strap_on_back(bundle, actor.view_facing())
			else:
				rig.unequip(&"back")


## The chest bone lives inside the scaled body: set the bundle's world
## transform instead, logs across the shoulders, resting on the upper back.
static func _strap_on_back(bundle: Node3D, facing: Vector2) -> void:
	var parent := bundle.get_parent() as Node3D
	var forward := Vector3(facing.x, 0.0, facing.y).normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var world := Transform3D(Basis(right, Vector3.UP, right.cross(Vector3.UP)), Vector3.ZERO)
	world.origin = parent.global_position - forward * 0.24 - Vector3.UP * 0.08
	bundle.transform = parent.global_transform.affine_inverse() * world


static func _armful_scene() -> PackedScene:
	if _armful == null:
		var model := CityInteriors._template("obj.firewood_armful", "")
		_armful = PackedScene.new()
		if model != null:
			_armful.pack(model)
			model.free()
	return _armful


## Garment dyes: the body ships undyed cloth; this resident's own colours replace it.
func _dye(rig: Node, record: Dictionary) -> void:
	var cloth := Color(record["cloth"][0], record["cloth"][1], record["cloth"][2])
	var under := Color(record["under"][0], record["under"][1], record["under"][2])
	for found: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if material == null:
				continue
			var tint := Color.WHITE
			var name := material.resource_name
			if name.ends_with("_short_tunic") or name.ends_with("_wool_tunic") \
					or name.ends_with("_work_gown") or name.ends_with("_gown"):
				tint = cloth
			elif name.ends_with("_hose") or name.ends_with("_headscarf"):
				tint = under
			else:
				continue
			var dyed := material.duplicate() as StandardMaterial3D
			dyed.albedo_color = tint
			mesh_instance.set_surface_override_material(surface, dyed)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseMotion:
		_set_hover(_pick((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			var hit := _pick(button.position)
			if hit != null:
				_select(hit)
				get_viewport().set_input_as_handled()
			elif _panel.is_open():
				_panel.hide_panel()
	elif event.is_action_pressed(&"interact"):
		var near := _nearest_to_player()
		if near != null:
			_select(near)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") and _panel.is_open():
		_panel.hide_panel()
		get_viewport().set_input_as_handled()


func _select(actor: CitizenActor) -> void:
	_selected = actor
	_panel.show_citizen(actor.record, roster.describe(actor.index, hour()))


func _on_panel_closed() -> void:
	_selected = null


func _set_hover(actor: CitizenActor) -> void:
	_hover = actor


func _nearest_to_player() -> CitizenActor:
	if player == null:
		return null
	var me := CityPlan.to_world_xz(player.global_position)
	var best: CitizenActor = null
	var best_distance := SELECT_REACH
	for actor: CitizenActor in _live.values():
		var distance := actor.world_xz().distance_to(me)
		if distance < best_distance:
			best = actor
			best_distance = distance
	return best


## The resident under a screen point: the ray's closest approach to the standing
## body (a vertical segment feet..head) must pass within PICK_RADIUS.
func _pick(screen: Vector2) -> CitizenActor:
	var runtime := _runtime()
	if runtime == null or runtime.view == null:
		return null
	var camera: Camera3D = runtime.view.view_camera()
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var best: CitizenActor = null
	var best_along := INF
	for actor: CitizenActor in _live.values():
		var rig := _rig_of(actor)
		if rig == null:
			continue
		var feet := rig.global_position
		var top := feet + Vector3.UP * 1.75 * float(actor.record["height_scale"])
		var closest := Geometry3D.get_closest_points_between_segments(
			origin, origin + dir * 200.0, feet, top
		)
		if closest[0].distance_to(closest[1]) > PICK_RADIUS:
			continue
		var along := origin.distance_to(closest[0])
		if along < best_along:
			best = actor
			best_along = along
	return best


func _update_tag() -> void:
	var target := _selected if _selected != null and is_instance_valid(_selected) else _hover
	if target == null or not is_instance_valid(target):
		_tag.visible = false
		return
	var rig := _rig_of(target)
	if rig == null:
		_tag.visible = false
		return
	if _tag.get_parent() != rig:
		if _tag.get_parent() != null:
			_tag.get_parent().remove_child(_tag)
		rig.add_child(_tag)
	_tag.position = Vector3(0.0, 2.1 * float(target.record["height_scale"]), 0.0)
	_tag.text = String(target.record["name"])
	_tag.visible = true
