extends Node

## Review capture for furnished houses and people at home in the seamless city
## (docs/SYSTEMS/HOUSEHOLDS.md): puts Kalev inside lived-in houses of each class
## near the spawn at a pinned hour and saves an oblique cutaway view over the
## room plus the top-down gameplay camera. Host scene so autoloads resolve:
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_households.tscn \
##     -- --city-spawn=poi.forum --city-hour=18.2 [--tag=evening] [--houses=4]
##        [--scene=res://scenes/world/sites/harju.tscn] [--trade=farmer]
## Output: docs/reports/images/city/households_<tag>_<n>.png (+ _eye.png from the
## doorway, _hearth.png close on the hearth and its chimney breast, _top.png from
## the gameplay camera, _outside.png on the chimney from the street); prints
## the pieces and who is at home doing what.

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://docs/reports/images/city"


func _ready() -> void:
	call_deferred("_run")


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return fallback


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _run() -> void:
	var tag := _arg("--tag=", "noon")
	var count := int(_arg("--houses=", "4"))
	# --scene=res://scenes/world/sites/harju.tscn captures a regional site's
	# farmhouses; --trade=farmer keeps only households of that trade.
	var scene_path := _arg("--scene=", "")
	var trade_filter := _arg("--trade=", "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var city: Node = (load(scene_path) as PackedScene if scene_path != "" else SCENE).instantiate()
	add_child(city)
	await _frames(120)
	var interiors: CityInteriors = city.interiors
	# Sky and sun follow the pinned hour too.
	if interiors.hour_override >= 0.0:
		city.runtime.cycle_progress = interiors.hour_override / 24.0
	var plan: CityPlan = city.plan
	var player: Node2D = city.player
	var spawn := CityPlan.to_world_xz(player.global_position)
	# One house per class, nearest the spawn first.
	var picks: Array = []
	var seen := {}
	var near := plan.buildings_near(spawn, 160.0 if trade_filter == "" else 2000.0)
	near.sort_custom(func(a: int, b: int) -> bool:
		return interiors._center(a).distance_to(spawn) < interiors._center(b).distance_to(spawn))
	for index: int in near:
		var lay := interiors.layout(index)
		if lay == null or lay.items.is_empty():
			continue
		if trade_filter != "" and String(interiors.household_at(index).get("trade", "")) != trade_filter:
			continue
		var cls := String(interiors.household_at(index)["class"])
		if trade_filter == "" and int(seen.get(cls, 0)) >= maxi(count / 3, 1):
			continue
		seen[cls] = int(seen.get(cls, 0)) + 1
		picks.append(index)
		if picks.size() >= count:
			break
	var failures := 0
	for n in picks.size():
		var index: int = picks[n]
		var lay := interiors.layout(index)
		var household := interiors.household_at(index)
		player.global_position = CityPlan.to_logic(lay.entry)
		if interiors.hour_override >= 0.0:
			city.runtime.cycle_progress = interiors.hour_override / 24.0
		# Frame cost while the houses round the new spot stream in.
		var citizens_node := city.find_child("CityCitizens", true, false) as CityCitizens
		var furnish: Array = []
		var scan: Array = []
		for _f in 90:
			await get_tree().process_frame
			furnish.append(interiors.last_update_usec / 1000.0)
			# Regional sites have no city population.
			scan.append(citizens_node.last_scan_usec / 1000.0 if citizens_node != null else 0.0)
		furnish.sort()
		scan.sort()
		print((
			"   main-thread ms after arrival: interiors p50 %.2f p95 %.2f max %.2f;"
			+ " citizen scan p95 %.2f max %.2f"
		) % [
			furnish[45], furnish[85], furnish[-1], scan[85], scan[-1]])
		var pieces: Array = []
		for item in lay.items:
			pieces.append(String(item["piece"]))
		print("house %s class=%s trade=%s size=%d area=%.0f m2: %s" % [
			plan.buildings[index]["id"], household["class"], household["trade"], household["size"],
			absf(CityBuildingBuilder.signed_area(lay.inner)), ", ".join(pieces)])
		var citizens := city.find_child("CityCitizens", true, false) as CityCitizens
		var home := 0
		for actor in (citizens.live_actors() if citizens != null else []):
			if actor.at_home:
				home += 1
				print("   %s (%d, %s): %s" % [
					actor.record["name"], actor.record["age"], actor.record["pattern"], actor.pose])
		print("   at home and shown: %d, furnished houses: %d" % [home, interiors.furnished_count()])
		if not interiors.is_furnished(index):
			failures += 1
			push_error("house %d not furnished with Kalev inside" % index)
		# Oblique cutaway over the room.
		var c := Vector2.ZERO
		for p in lay.inner:
			c += p
		c /= lay.inner.size()
		var radius := 0.0
		for p in lay.inner:
			radius = maxf(radius, p.distance_to(c))
		var cam := Camera3D.new()
		cam.fov = 50.0
		city.world.add_child(cam)
		var target := Vector3(c.x, lay.floor_y + 0.6, c.y)
		var away := (c - lay.entry).normalized()
		var lift := radius / tan(deg_to_rad(25.0)) * 0.95 + 1.5
		cam.global_position = (
			target + Vector3(-away.x, 0.0, -away.y) * radius * 0.25 + Vector3.UP * lift
		)
		cam.look_at(target, Vector3.UP)
		cam.make_current()
		await _frames(3)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("%s/households_%s_%d.png" % [OUTPUT_DIR, tag, n]))
		# From the corner farthest from the hearth, at eye height, looking at it.
		var look := c
		if lay.hearth >= 0:
			look = lay.items[lay.hearth]["pos"]
		var corner := c
		for p in lay.inner:
			if lay.room_of(p) == lay.room_of(look) and p.distance_to(look) > corner.distance_to(look):
				corner = p
		corner = corner.lerp(look, 0.08)
		cam.global_position = Vector3(corner.x, lay.floor_y + 2.0, corner.y)
		cam.look_at(Vector3(look.x, lay.floor_y + 0.7, look.y), Vector3.UP)
		cam.fov = 70.0
		await _frames(3)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("%s/households_%s_%d_eye.png" % [OUTPUT_DIR, tag, n]))
		# Close on the hearth: its hood, flue and the chimney breast above it.
		if lay.hearth >= 0:
			var h: Dictionary = lay.items[lay.hearth]
			var yaw := float(h["yaw"])
			var front := -Vector2(sin(yaw), cos(yaw))
			var hp: Vector2 = h["pos"]
			var eye: Vector2 = hp + front * 2.6 + front.orthogonal() * 0.9
			cam.global_position = Vector3(eye.x, lay.floor_y + 1.4, eye.y)
			cam.look_at(Vector3(hp.x, lay.floor_y + 1.5, hp.y), Vector3.UP)
			await _frames(3)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				ProjectSettings.globalize_path("%s/households_%s_%d_hearth.png" % [OUTPUT_DIR, tag, n]))
		cam.queue_free()
		city.view.view_camera().make_current()
		city.runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.TOP_DOWN)
		await _frames(30)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("%s/households_%s_%d_top.png" % [OUTPUT_DIR, tag, n]))
		city.runtime.set_camera_mode(MapViewRuntimeCamera.CameraMode.THIRD_PERSON)
		await _outside(city, lay, index, n, tag, spawn)
	print("captured %d houses, %d failures" % [picks.size(), failures])
	get_tree().quit(1 if failures > 0 or picks.is_empty() else 0)


## From the street, with Kalev back out (the roof down): the chimney stack over
## the gable where the hearth stands inside.
func _outside(
	city: Node, lay: HouseholdLayout, index: int, n: int, tag: String, spawn: Vector2
) -> void:
	if lay.hearth < 0:
		return
	var interiors: CityInteriors = city.interiors
	var top3 := Vector3.INF
	for c: Array in city.world.chimneys:
		if String(c[1]) == String(city.plan.buildings[index]["id"]):
			top3 = c[0]
	var top := Vector2(top3.x, top3.z) if top3 != Vector3.INF else Vector2.INF
	(city.player as Node2D).global_position = CityPlan.to_logic(spawn)
	await _frames(20)
	var h: Dictionary = lay.items[lay.hearth]
	var hp: Vector2 = h["pos"]
	var out := (hp - interiors._center(index)).normalized()
	var cam := Camera3D.new()
	cam.fov = 55.0
	city.world.add_child(cam)
	var aim := top3 if top3 != Vector3.INF else Vector3(hp.x, lay.floor_y + 4.0, hp.y)
	var eye := Vector2(aim.x, aim.z) + out * 13.0 + out.orthogonal() * 6.0
	cam.global_position = Vector3(eye.x, aim.y + 2.0, eye.y)
	cam.look_at(aim - Vector3.UP * 2.5, Vector3.UP)
	cam.make_current()
	await _frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("%s/households_%s_%d_outside.png" % [OUTPUT_DIR, tag, n]))
	var yaw := float(h["yaw"])
	var flue := hp + Vector2(sin(yaw), cos(yaw)) * HouseholdLayout.HEARTH_FLUE_BACK
	print("   chimney over the hearth flue: %.2f m" % (
		top.distance_to(flue) if top != Vector2.INF else -1.0))
	cam.queue_free()
	city.view.view_camera().make_current()
