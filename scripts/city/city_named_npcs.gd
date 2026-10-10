class_name CityNamedNpcs
extends Node2D

## The named NPCs of the registry (NamedNpcRegistry, ADR 0044) in the seamless
## city: Konrad Preen at the castle, Hinrik at the harbour, Martin at the smiths'
## street (docs/SYSTEMS/NAMED_NPCS.md). Sibling of CityCitizens and deliberately
## like it: the position is a pure function of the clock (resolve), people are
## seated within the same streaming radius, and hover/click/interact open the
## same information panel, here with portrait, title and faction.
## Named NPCs have their own small cap, so the 30-resident crowd budget never
## culls them. A census resident a named NPC replaces is never spawned.

const SPAWN_RADIUS := CityCitizens.SPAWN_RADIUS
const DESPAWN_RADIUS := CityCitizens.DESPAWN_RADIUS
## Separate from CityCitizens.MAX_LIVE; more than the registry puts in one district.
const MAX_LIVE := 12
const SPAWN_PER_FRAME := 2
const SELECT_REACH := CityCitizens.SELECT_REACH
const PICK_RADIUS := CityCitizens.PICK_RADIUS
const REFRESH_SECONDS := 1.0
## Walking pace between posts (m/s), a little slower than an errand.
const WALK := 1.2
## Standing spots round an anchor: a sunflower ring, one cell per NPC.
const POST_SPREAD := 1.6

var plan: CityPlan
var player: Node2D
var citizens: CityCitizens
var registry: NamedNpcRegistry
## Highest act unlocked; NPCs with a later act_gate stay away. The campaign has no
## act state yet (docs/SYSTEMS/NAMED_NPCS.md, Limits), so this is 1 unless pinned.
var current_act := 1
## Test and capture hook: pins the hour (0..24) instead of the city clock.
var hour_override := -1.0

var _anchors: Dictionary = {}  # anchor id -> Vector2 world xz
var _anchor_names: Dictionary = {}  # anchor id -> 1343 name
var _live: Dictionary = {}  # npc id -> NamedNpcActor
var _since := REFRESH_SECONDS
var _tag: Label3D
var _hover: NamedNpcActor
var _selected: NamedNpcActor


static func create(
	city_plan: CityPlan, kalev: Node2D, crowd: CityCitizens, npc_registry: NamedNpcRegistry = null
) -> CityNamedNpcs:
	var node := CityNamedNpcs.new()
	node.name = "CityNamedNpcs"
	node.plan = city_plan
	node.player = kalev
	node.citizens = crowd
	node.registry = npc_registry if npc_registry != null else NamedNpcRegistry.load_default()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--city-hour="):
			node.hour_override = float(arg.substr(12))
		elif arg.begins_with("--city-act="):
			node.current_act = int(arg.substr(11))
	node._collect_anchors()
	if crowd != null:
		crowd.suppress_residents(node.registry.replaced_census_ids())
	return node


func _collect_anchors() -> void:
	for key: String in ["points_of_interest", "gates"]:
		for item: Dictionary in plan.data.get(key, []):
			_anchors[String(item["id"])] = Vector2(item["at"][0], item["at"][1])
			_anchor_names[String(item["id"])] = String(item.get("name_1343", item["id"]))


func _ready() -> void:
	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.pixel_size = 0.0035
	_tag.font_size = 40
	_tag.outline_size = 12
	_tag.modulate = Color(1, 0.95, 0.8)
	_tag.visible = false


func _exit_tree() -> void:
	if is_instance_valid(_tag) and _tag.get_parent() == null:
		_tag.free()


func hour() -> float:
	if hour_override >= 0.0:
		return hour_override
	if citizens != null and citizens.is_inside_tree():
		return citizens.hour()
	var time := Time.get_time_dict_from_system()
	return float(time["hour"]) + float(time["minute"]) / 60.0


func live_count() -> int:
	return _live.size()


func live_actors() -> Array[NamedNpcActor]:
	var out: Array[NamedNpcActor] = []
	for actor: NamedNpcActor in _live.values():
		out.append(actor)
	return out


func anchor_position(anchor_id: String) -> Vector2:
	return _anchors.get(anchor_id, Vector2.INF)


func eligible(npc: Dictionary) -> bool:
	return int(npc["act_gate"]) <= current_act


## Where `npc` (a registry row) is at `hour`: {visible, moving, pos, facing}.
## Pure in (row, hour): at a post the NPC stands on its own spot round the anchor
## facing it; when the post changes it walks the street route from the previous
## post (or out of home_anchor), and walking HOME it vanishes on arrival.
func resolve(npc: Dictionary, at_hour: float) -> Dictionary:
	var h := fposmod(at_hour, 24.0)
	var post := NamedNpcRegistry.schedule_post(npc["schedule"], h)
	var going_home: bool = post["anchor"] == NamedNpcRegistry.HOME
	var target := _post_spot(npc, post["anchor"])
	var origin := _post_spot(npc, post["prev_anchor"])
	var walked := (h - float(post["from"])) * 3600.0 * WALK
	var from: Vector2 = origin["pos"]
	var to: Vector2 = target["pos"]
	if not from.is_equal_approx(to):
		var route := _route(from, to)
		if walked < float(route["length"]):
			var spot := CitizenRoster.along(route["points"], walked)
			return {"visible": true, "moving": true, "pos": spot[0], "facing": spot[1]}
	return {
		"visible": not going_home, "moving": false, "pos": target["pos"], "facing": target["facing"],
	}


## Short English description of what the NPC is doing at `at_hour`.
func describe(npc: Dictionary, at_hour: float) -> String:
	var post := NamedNpcRegistry.schedule_post(npc["schedule"], fposmod(at_hour, 24.0))
	var state := resolve(npc, at_hour)
	var anchor := String(post["anchor"])
	if anchor == NamedNpcRegistry.HOME:
		return "On the way home" if state["visible"] else "At home"
	var place := String(_anchor_names.get(anchor, anchor))
	return ("On the way to the %s" if state["moving"] else "At the %s") % place


func _post_spot(npc: Dictionary, anchor: String) -> Dictionary:
	var key := String(npc["home_anchor"]) if anchor == NamedNpcRegistry.HOME else anchor
	var centre: Vector2 = _anchors.get(key, Vector2.ZERO)
	var slot := absi(hash(String(npc["id"]))) % 24
	var a := float(slot) * 2.39996
	var out := Vector2(cos(a), sin(a))
	return {"pos": centre + out * POST_SPREAD * sqrt(float(slot % 6 + 1)), "facing": -out}


func _route(a: Vector2, b: Vector2) -> Dictionary:
	if citizens != null and citizens.roster != null:
		return citizens.roster.route_between(a, b)
	return {"points": PackedVector2Array([a, b]), "length": a.distance_to(b)}


func _process(delta: float) -> void:
	_since += delta
	if _since >= REFRESH_SECONDS and player != null:
		_since = 0.0
		refresh(CityPlan.to_world_xz(player.global_position))
	_style_new_rigs()
	_update_tag()
	_update_markers(delta)
	if _selected != null and is_instance_valid(_selected) and _panel() != null:
		if _panel().is_open() and _panel().shown_id == _selected.npc_id():
			_panel().update_now(describe(_selected.npc, hour()))
		else:
			_selected = null  # panel closed or showing a census resident now


## Seats the eligible NPCs outdoors within SPAWN_RADIUS, nearest first, and
## frees those gone indoors or beyond DESPAWN_RADIUS. The registry is small
## (tens of rows), so every refresh resolves all of them.
func refresh(me: Vector2) -> void:
	var h := hour()
	var wanted: Array = []
	for npc in registry.npcs:
		var id := String(npc["id"])
		var state := resolve(npc, h) if eligible(npc) else {"visible": false}
		var distance: float = (state["pos"] as Vector2).distance_to(me) if state["visible"] else INF
		if _live.has(id):
			if distance > DESPAWN_RADIUS:
				_release(id)
		elif distance <= SPAWN_RADIUS:
			wanted.append([distance, id])
	wanted.sort()
	var spawned := 0
	for entry: Array in wanted:
		if _live.size() >= MAX_LIVE or spawned >= SPAWN_PER_FRAME:
			break
		_spawn(registry.get_npc(String(entry[1])))
		spawned += 1
	if spawned < wanted.size():
		_since = REFRESH_SECONDS  # the rest next frame


func _spawn(npc: Dictionary) -> void:
	var actor := NamedNpcActor.create(self, npc, style_record(npc))
	add_child(actor)
	_live[String(npc["id"])] = actor


## The census-shaped styling record of `npc`: the replaced resident's own (its
## body and clothes), else one built from the registry `body`.
func style_record(npc: Dictionary) -> Dictionary:
	var census := census_record(npc)
	var record := census
	if census.is_empty():
		var body: Dictionary = npc["body"]
		record = {
			"id": npc["id"], "name": npc["display_name"], "body": body["variant"],
			"height_scale": body["height_scale"], "head_scale": body["head_scale"],
			"cloth": body["cloth"], "under": body["under"],
		}
	# Faction livery over the base look: primary on the tunic, secondary on hose and
	# headwear (R-1565). Factions without identity keep their registry dyes.
	return FactionIdentity.styled_record(record, npc.get("faction"))


func census_record(npc: Dictionary) -> Dictionary:
	if npc.get("census_mode") != NamedNpcRegistry.REPLACES or citizens == null:
		return {}
	var index := citizens.roster.index_of(String(npc["census_id"]))
	return citizens.roster.residents[index] if index >= 0 else {}


func _release(id: String) -> void:
	var actor: NamedNpcActor = _live.get(id)
	_live.erase(id)
	if not is_instance_valid(actor):
		return
	if actor == _selected and _panel() != null and _panel().shown_id == id:
		_panel().hide_panel()
	if actor == _selected:
		_selected = null
	if actor == _hover:
		_hover = null
	if _tag.get_parent() != null and _tag.get_parent() == _rig_of(actor):
		_tag.get_parent().remove_child(_tag)
	actor.queue_free()


func _panel() -> CitizenInfoPanel:
	return citizens.info_panel() if citizens != null else null


func _runtime() -> MapViewRuntime:
	var scene := get_tree().get_first_node_in_group(&"seamless_city")
	return scene.get("runtime") as MapViewRuntime if scene != null else null


func _rig_of(actor: NamedNpcActor) -> SharedCharacterRig:
	var runtime := _runtime()
	return runtime.get_actor_rig(actor) if runtime != null else null


func _style_new_rigs() -> void:
	for actor: NamedNpcActor in _live.values():
		if actor.rig_styled or actor.npc.get("model_scene") != null:
			continue
		var rig := _rig_of(actor)
		if rig == null or not rig.is_node_ready():
			continue
		actor.rig_styled = true
		var model := rig.get_node_or_null("Model") as Node3D
		if model != null:
			model.scale = rig.model_scale * float(actor.record["height_scale"])
		CityCitizens.dye(rig, actor.record)
		FactionIdentity.attach_accent(rig, actor.npc.get("faction"), float(actor.record["height_scale"]))
		var proportions := rig.find_child("RealisticProportions", true, false)
		if proportions != null:
			proportions.set("head_scale", float(actor.record["head_scale"]))


## Named NPCs take input before CityCitizens (later sibling): a hit selects and
## consumes the event; a miss falls through so the crowd handles it.
func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseMotion:
		_hover = pick((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			var hit := pick(button.position)
			if hit != null:
				select(hit)
				get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"interact"):
		var near := nearest_to_player()
		if near != null:
			select(near)
			get_viewport().set_input_as_handled()


func select(actor: NamedNpcActor) -> void:
	if _panel() == null:
		return
	_selected = actor
	citizens.clear_selection()
	_panel().show_named(actor.npc, census_record(actor.npc), describe(actor.npc, hour()))


func nearest_to_player() -> NamedNpcActor:
	if player == null:
		return null
	var me := CityPlan.to_world_xz(player.global_position)
	var best: NamedNpcActor = null
	var best_distance := SELECT_REACH
	for actor: NamedNpcActor in _live.values():
		var distance := actor.world_xz().distance_to(me)
		if distance < best_distance:
			best = actor
			best_distance = distance
	return best


## The NPC under a screen point (same ray-to-body test as CityCitizens._pick).
func pick(screen: Vector2) -> NamedNpcActor:
	var runtime := _runtime()
	if runtime == null or runtime.view == null:
		return null
	var camera: Camera3D = runtime.view.view_camera()
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var best: NamedNpcActor = null
	var best_along := INF
	for actor: NamedNpcActor in _live.values():
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


## One NamedNpcMarker per live actor, parented to its mirrored rig (so it follows
## the body and dies with it). Fades by camera distance; hidden in dialogue,
## duels, cutscenes and spirit sight, and by the "Show NPC markers" setting.
func _update_markers(delta: float) -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var suppressed := NamedNpcMarker.suppressed_in(get_tree())
	for actor: NamedNpcActor in _live.values():
		var rig := _rig_of(actor)
		if rig == null:
			continue
		var marker := rig.get_node_or_null("NamedNpcMarker") as NamedNpcMarker
		if marker == null:
			marker = NamedNpcMarker.new()
			marker.name = "NamedNpcMarker"
			rig.add_child(marker)
			marker.setup(actor.npc, float(actor.record["height_scale"]))
		var distance := camera.global_position.distance_to(rig.global_position) if camera != null else 0.0
		marker.update_presence(distance, suppressed, delta)


func _update_tag() -> void:
	var target := _selected if _selected != null and is_instance_valid(_selected) else _hover
	var rig := _rig_of(target) if target != null and is_instance_valid(target) else null
	if rig == null:
		_tag.visible = false
		return
	if _tag.get_parent() != rig:
		if _tag.get_parent() != null:
			_tag.get_parent().remove_child(_tag)
		rig.add_child(_tag)
	_tag.position = Vector3(0.0, 2.1 * float(target.record["height_scale"]), 0.0)
	_tag.text = String(target.npc["display_name"])
	_tag.visible = true
