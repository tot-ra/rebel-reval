class_name CityInteriors
extends Node3D

## Furnished houses round Kalev (docs/SYSTEMS/HOUSEHOLDS.md). Every enterable
## house whose census household lives there gets its HouseholdLayout built as
## models when Kalev comes within FURNISH_RADIUS: hearth, beds, table and
## benches, chest, shelf, firewood, pots and the table light. The hearth and
## the firewood pile follow HouseholdDay (lit, banked, full, half, low), the
## table light burns on dark evenings, and the solid pieces block Kalev on the
## logic plane. Houses are freed again past RELEASE_RADIUS.
##
## Also answers where a resident is inside their house (indoor_state), so
## CityCitizens can show the people of a furnished house at home.

const FURNISH_RADIUS := 26.0
const RELEASE_RADIUS := 36.0
const MAX_FURNISHED := 14
const REFRESH_SECONDS := 0.5
## Main-thread time spent building furniture models per frame.
const BUILD_BUDGET_USEC := 1500
const DARK_BELOW := 0.35
## Houses that keep their own scene behind the door.
const SKIP_LANDMARKS := ["landmark.kalev_smithy"]

var plan: CityPlan
var roster: CitizenRoster
## 2D scene node that receives the furniture collision bodies.
var collision_parent: Node
## Test and capture hook: pins the hour (0..24) instead of the city clock.
var hour_override := -1.0
var progress_override := -1.0
## Off (`--no-interiors`, for comparisons): no house is furnished.
var enabled := true
## Main-thread cost of the last update_for (microseconds), for budget checks.
var last_update_usec := 0

var _chimneys: Dictionary = {}  # building id -> chimney world xz
var _layouts: Dictionary = {}  # building index -> HouseholdLayout (or null)
var _homes: Dictionary = {}  # building index -> {node, body, hearth, firewood, lights, state}
var _templates: Dictionary = {}
var _cooks: Dictionary = {}  # hh id -> resident index or -1
var _since := REFRESH_SECONDS
var _origin := Vector2.INF
## Layouts being built on worker threads: index -> {task, out (Array)}.
var _pending: Dictionary = {}
## Houses near Kalev waiting to be furnished, nearest first.
var _queue: Array = []


static func create(city_plan: CityPlan, citizen_roster: CitizenRoster, chimneys: Array) -> CityInteriors:
	var node := CityInteriors.new()
	node.name = "Interiors"
	node.plan = city_plan
	node.roster = citizen_roster
	for c: Array in chimneys:
		var top: Vector3 = c[0]
		node._chimneys[String(c[1])] = Vector2(top.x, top.z)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--city-hour="):
			node.hour_override = float(arg.substr(12))
	# Load the catalog on this thread: worker layouts only read it.
	HouseholdLayout.object("")
	return node


func hour() -> float:
	if hour_override >= 0.0:
		return hour_override
	return DayNightCycle.progress_to_hour(_progress())


func _progress() -> float:
	if progress_override >= 0.0:
		return progress_override
	if hour_override >= 0.0:
		return hour_override / 24.0
	var scene := get_tree().get_first_node_in_group(&"seamless_city") if is_inside_tree() else null
	var runtime: Variant = scene.get("runtime") if scene != null else null
	if runtime != null:
		return float(runtime.get("cycle_progress"))
	return DayNightCycle.DEFAULT_PROGRESS


## The household living in plan building `index`, or {}.
func household_at(index: int) -> Dictionary:
	if index < 0:
		return {}
	var hh := String(roster.household_of_building.get(String(plan.buildings[index]["id"]), ""))
	return roster.households.get(hh, {})


## The furnishing of plan building `index` (built once, then cached), or null
## for houses nobody lives in or that cannot be entered.
func layout(index: int) -> HouseholdLayout:
	if _layouts.has(index):
		return _layouts[index]
	_finish_pending(index, true)
	if not _layouts.has(index):
		_layouts[index] = (
			HouseholdLayout.build(plan, index, household_at(index), _chimney(index))
			if is_lived_in(index) else null
		)
	return _layouts[index]


## An ordinary enterable house with a census household (and not Kalev's forge).
func is_lived_in(index: int) -> bool:
	var b: Dictionary = plan.buildings[index]
	return (
		bool(b.get("enterable", false))
		and String(b.get("kind", "")) == "house"
		and not String(b.get("landmark_id", "")) in SKIP_LANDMARKS
		and not household_at(index).is_empty()
	)


func _chimney(index: int) -> Vector2:
	return _chimneys.get(String(plan.buildings[index]["id"]), Vector2.INF)


## Starts building a layout on a worker thread (the layout is a pure function).
func _request(index: int) -> void:
	if _layouts.has(index) or _pending.has(index):
		return
	if not is_lived_in(index):
		_layouts[index] = null
		return
	var out: Array = []
	var household := household_at(index)
	var chimney := _chimney(index)
	var task := WorkerThreadPool.add_task(
		func() -> void: out.append(HouseholdLayout.build(plan, index, household, chimney))
	)
	_pending[index] = {"task": task, "out": out}


## Collects a finished worker layout (or waits for it when `wait`).
func _finish_pending(index: int, wait: bool) -> void:
	if not _pending.has(index):
		return
	var job: Dictionary = _pending[index]
	if not wait and not WorkerThreadPool.is_task_completed(job["task"]):
		return
	WorkerThreadPool.wait_for_task_completion(job["task"])
	_pending.erase(index)
	_layouts[index] = job["out"][0] if not (job["out"] as Array).is_empty() else null


func furnished_count() -> int:
	return _homes.size()


func is_furnished(index: int) -> bool:
	return _homes.has(index)


func furnished_indices() -> Array:
	return _homes.keys()


## Call each frame with Kalev's world xz. Layouts are built on worker threads
## and at most one house is furnished per frame, so walking never hitches.
func update_for(world_xz: Vector2, delta: float) -> void:
	if not enabled:
		return
	var start := Time.get_ticks_usec()
	_update(world_xz, delta)
	last_update_usec = Time.get_ticks_usec() - start


func _update(world_xz: Vector2, delta: float) -> void:
	_sync_upper()
	for index: int in _pending.keys():
		_finish_pending(index, false)
	_furnish_next()
	_since += delta
	if _since < REFRESH_SECONDS and world_xz.distance_to(_origin) < 2.0:
		return
	_since = 0.0
	_origin = world_xz
	_release_far(world_xz)
	_queue = _wanted(world_xz)
	for entry: Array in _queue:
		_request(int(entry[1]))
	_apply_states()


## Furnishes every lived-in house near `world_xz` at once (tests, captures).
func refresh(world_xz: Vector2) -> void:
	_release_far(world_xz)
	for entry: Array in _wanted(world_xz):
		if _homes.size() >= MAX_FURNISHED:
			break
		if layout(int(entry[1])) != null:
			_furnish(int(entry[1]))
	for index: int in _homes:
		if not _complete(index):
			_build_items(index, 0)
	_apply_states()


## Same nearness test as _wanted (footprint, not centre), so a big house is
## never released and furnished again on alternate refreshes.
func _release_far(world_xz: Vector2) -> void:
	if _homes.is_empty():
		return
	var keep := {}
	for index: int in plan.buildings_near(world_xz, RELEASE_RADIUS):
		keep[index] = true
	for index: int in _homes.keys():
		if not keep.has(index):
			_release(index)


## Lived-in houses within FURNISH_RADIUS not yet furnished: [distance, index], nearest first.
func _wanted(world_xz: Vector2) -> Array:
	var wanted: Array = []
	for index: int in plan.buildings_near(world_xz, FURNISH_RADIUS):
		if _homes.has(index) or (_layouts.has(index) and _layouts[index] == null):
			continue
		if not _layouts.has(index) and not is_lived_in(index):
			_layouts[index] = null
			continue
		wanted.append([_center(index).distance_to(world_xz), index])
	wanted.sort()
	return wanted


func _furnish_next() -> void:
	# Finish the house under construction first.
	for index: int in _homes:
		if not _complete(index):
			_build_items(index, BUILD_BUDGET_USEC)
			return
	while not _queue.is_empty() and _homes.size() < MAX_FURNISHED:
		var index := int(_queue[0][1])
		if _homes.has(index) or (_layouts.has(index) and _layouts[index] == null):
			_queue.pop_front()
			continue
		if not _layouts.has(index):
			return  # still building; keep the nearest-first order
		_queue.pop_front()
		_furnish(index)
		_build_items(index, BUILD_BUDGET_USEC)
		return


func _center(index: int) -> Vector2:
	var c := Vector2.ZERO
	var ring := plan.footprint(index)
	for p in ring:
		c += p
	return c / maxf(ring.size(), 1)


func _furnish(index: int) -> void:
	var lay := layout(index)
	var b: Dictionary = plan.buildings[index]
	var node := Node3D.new()
	node.name = "Home_%s" % String(b["id"]).replace(".", "_")
	add_child(node)
	var home := {
		"node": node, "hearth": null, "firewood": null, "lights": {}, "state": {}, "next": 0,
	}
	home["upper"] = _partitions(node, lay, b)
	home["body"] = _collision(lay)
	_homes[index] = home


## Builds the models of a furnished house, a few pieces at a time: stops once
## `budget_usec` is spent (0 = all). Returns true when the house is complete.
func _build_items(index: int, budget_usec: int) -> bool:
	var home: Dictionary = _homes[index]
	var lay: HouseholdLayout = _layouts[index]
	var start := Time.get_ticks_usec()
	var node: Node3D = home["node"]
	while int(home["next"]) < lay.items.size():
		var i := int(home["next"])
		home["next"] = i + 1
		var item: Dictionary = lay.items[i]
		var holder := Node3D.new()
		holder.name = "%s_%d" % [String(item["piece"]), i]
		var p: Vector2 = item["pos"]
		holder.position = Vector3(p.x, lay.floor_y + float(item["y"]), p.y)
		holder.rotation.y = float(item["yaw"])
		node.add_child(holder)
		if i == lay.hearth:
			home["hearth"] = holder
		elif i == lay.firewood:
			home["firewood"] = holder
		elif i in lay.lights:
			home["lights"][i] = holder
		else:
			var model := _instance(String(item["object"]), "")
			if model != null:
				holder.add_child(model)
		if budget_usec > 0 and Time.get_ticks_usec() - start >= budget_usec:
			break
	if int(home["next"]) < lay.items.size():
		return false
	_apply_states_for(index)
	return true


func _complete(index: int) -> bool:
	return int(_homes[index]["next"]) >= (_layouts[index] as HouseholdLayout).items.size()


## Plank (timber houses) or limewashed (stone houses) partitions between the
## rooms of a big house. The part above the cutaway height goes in `upper`,
## which hides with the roof while Kalev is inside.
func _partitions(node: Node3D, lay: HouseholdLayout, b: Dictionary) -> Node3D:
	if lay.partitions.is_empty():
		return null
	var upper := Node3D.new()
	upper.name = "PartitionsUpper"
	node.add_child(upper)
	var top := float(b["wall_h"]) - 0.05
	var cut := CityBuildingBuilder.CUT_HEIGHT
	var material := (
		CityBuildingBuilder.interior_material() if String(b["material"]) in ["limestone", "plaster"]
		else CityBuildingBuilder.timber_material()
	)
	for part: Dictionary in lay.partitions:
		for w: Array in part["walls"]:
			var p: Vector2 = w[0]
			var q: Vector2 = w[1]
			var length := p.distance_to(q)
			if length < 0.05:
				continue
			var yaw := atan2(-(q - p).y, (q - p).x)
			for band: Array in [[0.0, cut, node], [cut, top, upper]]:
				var h := float(band[1]) - float(band[0])
				if h <= 0.01:
					continue
				var mesh := BoxMesh.new()
				mesh.size = Vector3(length, h, HouseholdLayout.PARTITION_THICK)
				var wall := MeshInstance3D.new()
				wall.mesh = mesh
				wall.material_override = material
				var c := (p + q) * 0.5
				wall.position = Vector3(c.x, lay.floor_y + float(band[0]) + h * 0.5, c.y)
				wall.rotation.y = yaw
				(band[2] as Node3D).add_child(wall)
	return upper


## Upper partition boards follow the roof: hidden while it is lifted.
func _sync_upper() -> void:
	var world := get_parent()
	var roofs: Dictionary = world.get("roof_nodes") if world != null and world.get("roof_nodes") != null else {}
	for index: int in _homes:
		var upper: Node3D = _homes[index].get("upper")
		if upper == null:
			continue
		var roof: Node3D = roofs.get(index)
		upper.visible = roof == null or roof.visible


func _release(index: int) -> void:
	var home: Dictionary = _homes[index]
	_homes.erase(index)
	(home["node"] as Node).queue_free()
	if is_instance_valid(home["body"]):
		(home["body"] as Node).queue_free()


func _collision(lay: HouseholdLayout) -> StaticBody2D:
	if collision_parent == null:
		return null
	var body := StaticBody2D.new()
	body.name = "Furniture_%d" % lay.building_index
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	for item in lay.items:
		if not item["solid"]:
			continue
		var shape := CollisionPolygon2D.new()
		var scaled := PackedVector2Array()
		for p: Vector2 in item["poly"]:
			scaled.append(p * CityPlan.LOGIC_PX_PER_UNIT)
		shape.polygon = scaled
		body.add_child(shape)
	for part: Dictionary in lay.partitions:
		for w: Array in part["walls"]:
			var p: Vector2 = w[0]
			var q: Vector2 = w[1]
			var n := lay.axis * HouseholdLayout.PARTITION_THICK * 0.5
			var shape := CollisionPolygon2D.new()
			var poly := PackedVector2Array()
			for v: Vector2 in [p - n, q - n, q + n, p + n]:
				poly.append(v * CityPlan.LOGIC_PX_PER_UNIT)
			shape.polygon = poly
			body.add_child(shape)
	collision_parent.add_child(body)
	return body


## Hearth, firewood and lights follow the household's day.
func _apply_states() -> void:
	for index: int in _homes:
		if _complete(index):
			_apply_states_for(index)


func _apply_states_for(index: int) -> void:
	var h := hour()
	var progress := _progress()
	var dark := DayNightCycle.day_blend(progress) < DARK_BELOW
	var home: Dictionary = _homes[index]
	var lay: HouseholdLayout = _layouts[index]
	var bid := String(plan.buildings[index]["id"])
	var state: Dictionary = home["state"]
	var changed := false
	if home["hearth"] != null:
		var fire := HouseholdDay.hearth_state(bid, h)
		if state.get("hearth") != fire:
			state["hearth"] = fire
			changed = true
			_clear(home["hearth"])
			MapViewDomesticHearthModels.add_model(
				home["hearth"], {"style_variant": "hearth.%s" % fire, "id": bid}
			)
	if home["firewood"] != null:
		if not home.has("refill"):
			home["refill"] = _refill_hour(index)
		var pile := HouseholdDay.firewood_state(h, float(home["refill"]))
		if state.get("firewood") != pile:
			state["firewood"] = pile
			_clear(home["firewood"])
			var model := _instance("obj.firewood_pile_indoor", String(pile))
			if model != null:
				(home["firewood"] as Node3D).add_child(model)
	var lit := HouseholdDay.light_lit(h, dark)
	for i: int in home["lights"]:
		var key := "light_%d" % i
		if state.get(key) == lit:
			continue
		state[key] = lit
		changed = true
		var holder: Node3D = home["lights"][i]
		_clear(holder)
		var piece: StringName = lay.items[i]["piece"]
		if lit:
			MapViewMedievalLightingModels.add_model(
				holder, {"style_variant": _light_variant(piece), "id": "%s:%d" % [bid, i]}
			)
		else:
			var model := _instance(String(lay.items[i]["object"]), "")
			if model != null:
				holder.add_child(model)
	if changed or not home.has("controllers"):
		# The fire and light controllers sit beside their models in the holders.
		var controllers: Array = []
		var holders: Array = home["lights"].values()
		if home["hearth"] != null:
			holders.append(home["hearth"])
		for holder: Node in holders:
			for child in holder.get_children():
				if child.has_method(&"apply_cycle_progress") and not child.is_queued_for_deletion():
					controllers.append(child)
		home["controllers"] = controllers
	for controller: Node in home["controllers"]:
		if is_instance_valid(controller):
			controller.call(&"apply_cycle_progress", progress)


static func _light_variant(piece: StringName) -> StringName:
	match piece:
		&"candle_poor":
			return MapTypes.LIGHTING_VARIANT_POOR_TALLOW
		&"candle_rich":
			return MapTypes.LIGHTING_VARIANT_RICH_BEESWAX
		&"splint":
			return MapTypes.LIGHTING_VARIANT_PINE_SPLINT
	return MapTypes.LIGHTING_VARIANT_ARTISAN_TALLOW


## When this household's firewood comes home: the earliest fetcher's return.
func _refill_hour(index: int) -> float:
	var hh := String(roster.household_of_building.get(String(plan.buildings[index]["id"]), ""))
	var best := HouseholdDay.DEFAULT_REFILL
	for r_index: int in roster.members.get(hh, PackedInt32Array()):
		var r: Dictionary = roster.residents[r_index]
		var entries: Array = roster.patterns[r["pattern"]]
		for k in range(1, entries.size()):
			if String(entries[k - 1][1]) == "fuel":
				best = minf(best, float(entries[k][0]) + float(r["jitter"]))
	return best


static func _clear(holder: Node3D) -> void:
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()


## A fresh copy of a catalog object's model (or one of its states).
func _instance(object_id: String, state: String) -> Node3D:
	var key := object_id + "#" + state
	if not _templates.has(key):
		_templates[key] = _template(object_id, state)
	var template: Node3D = _templates[key]
	return template.duplicate() as Node3D if template != null else null


static func _template(object_id: String, state: String) -> Node3D:
	var model: Dictionary = HouseholdLayout.object(object_id).get("model", {})
	if String(model.get("status", "")) != "glb":
		push_warning("CityInteriors: %s has no GLB model" % object_id)
		return null
	var scene := MapViewPackedScenes.load_scene(String(model["glb"]))
	if scene == null:
		return null
	var root := scene.instantiate() as Node3D
	var node_name := String(model.get("states", {}).get(state, "")) if state != "" else String(model.get("node", ""))
	if node_name == "":
		root.position = Vector3.ZERO
		return root
	var found := root.find_child(node_name, true, false) as Node3D
	if found == null:
		push_warning("CityInteriors: %s has no node %s" % [object_id, node_name])
		root.free()
		return null
	found.get_parent().remove_child(found)
	root.free()
	found.position = Vector3.ZERO
	_own(found, found)
	return found


static func _own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_own(child, owner_node)


func _exit_tree() -> void:
	for index: int in _pending.keys():
		WorkerThreadPool.wait_for_task_completion(_pending[index]["task"])
	_pending.clear()
	for t: Variant in _templates.values():
		if t != null and is_instance_valid(t):
			(t as Node).free()
	_templates.clear()
	for index: int in _homes.keys():
		var body: Variant = _homes[index]["body"]
		if body != null and is_instance_valid(body):
			(body as Node).queue_free()


# --- people at home ------------------------------------------------------------


## The resident who keeps the fire in household `hh`: the first woman of the
## house on the domestic timetable (wife, maid, servant), else the first adult woman.
func cook_of(hh: String) -> int:
	if _cooks.has(hh):
		return _cooks[hh]
	var cook := -1
	for pass_k in 2:
		for r_index: int in roster.members.get(hh, PackedInt32Array()):
			var r: Dictionary = roster.residents[r_index]
			if String(r["sex"]) != "f" or int(r["age"]) < 14:
				continue
			if pass_k == 0 and String(r["pattern"]) != "domestic":
				continue
			cook = r_index
			break
		if cook >= 0:
			break
	_cooks[hh] = cook
	return cook


## Where resident `index`, at home at `hour`, is inside their furnished house:
## {pos, facing, pose (sleep, sit, stand, hearth, work), h (seat or bed height),
## moving}. Empty when the house is not furnished or has no slot for them.
func indoor_state(index: int, hour_now: float, arrived: float) -> Dictionary:
	var r: Dictionary = roster.residents[index]
	var hh := String(r["household"])
	var household: Dictionary = roster.households.get(hh, {})
	if household.is_empty():
		return {}
	var building := plan.building_index_by_id(String(household["building"]))
	if building < 0 or not _homes.has(building) or not _complete(building):
		return {}
	var lay: HouseholdLayout = _layouts[building]
	var mates: PackedInt32Array = roster.members[hh]
	var k := mates.find(index)
	var has_work := not lay.slots_of(&"work").is_empty() and k == 0
	var act := HouseholdDay.activity(r, hour_now, index == cook_of(hh), has_work)
	var pose: StringName = act["pose"]
	if pose == &"hearth" and HouseholdDay.hearth_state(String(household["building"]), hour_now) != &"lit":
		pose = &"stand"
		act["slot"] = &"stand"
	var choices := lay.slots_of(act["slot"])
	if choices.is_empty():
		choices = lay.slots_of(&"stand")
		pose = &"stand"
	if choices.is_empty():
		return {}
	var slot: Dictionary = choices[k % choices.size()]
	# Coming in: walk from the door to the place first.
	var target: Vector2 = slot["pos"]
	var path := lay.path_to(target)
	var walked := arrived * 3600.0 * HouseholdDay.INDOOR_WALK
	if arrived >= 0.0:
		for i in range(1, path.size()):
			var seg := path[i - 1].distance_to(path[i])
			if walked < seg:
				var dir := (path[i] - path[i - 1]) / maxf(seg, 0.001)
				return {
					"pos": path[i - 1] + dir * walked,
					"facing": dir,
					"pose": &"walk",
					"h": 0.0,
					"moving": true,
				}
			walked -= seg
	return {
		"pos": target,
		"facing": slot["facing"],
		"pose": pose,
		"h": float(slot["h"]),
		"moving": false,
	}
