extends Node

## Jump and slope-slide probe in the real seamless city. Picks the narrowest steep
## strip on the STEEP layer, walks Kalev up to it (blocked), hops it (crosses), and
## drops him into the strip (slides out). Prints positions and saves shots.
##   tools/godot_render.sh --resolution 1600x900 res://tools/capture_city_jump.tscn
## Output: docs/reports/images/city/jump_*.png, exit code 1 on failure.

const SCENE := preload("res://scenes/world/reval_city/reval_city.tscn")
const OUTPUT_DIR := "res://docs/reports/images/city"

var _city: Node
var _failed := false


func _ready() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	var image := get_tree().root.get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, name]))


func _strips() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for body in _city.get_node("CityCollision").get_children():
		if not String(body.name).begins_with("Steep"):
			continue
		for shape in body.get_children():
			var poly := (shape as CollisionPolygon2D).polygon
			var r := Rect2(poly[0], Vector2.ZERO)
			for p in poly:
				r = r.expand(p)
			out.append(r)
	return out


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_city = SCENE.instantiate()
	get_tree().root.add_child(_city)
	for i in 4:
		await get_tree().process_frame
	var player: Player = _city.player
	var plan: CityPlan = _city.plan
	var def: MapDefinition = _city.view.definition
	# Narrow, level-both-sides strips only, so the hop is the only way across.
	var candidates: Array[Rect2] = []
	for r in _strips():
		var w := r.size.x
		var a := r.position + Vector2(-48, r.size.y * 0.5)
		var b := r.end + Vector2(48, -r.size.y * 0.5)
		if w >= 24.0 and w <= 130.0 and r.size.y >= 64.0:
			var mid := r.get_center()
			# Open terrain: the slide needs a real gradient inside (not a site floor).
			if (
				def.slope_at_world(a) < 0.2
				and def.slope_at_world(b) < 0.2
				and def.downhill_at_world(mid).length() > 0.3
			):
				candidates.append(r)
	candidates.sort_custom(func(l: Rect2, r: Rect2) -> bool: return l.size.x < r.size.x)
	if candidates.is_empty():
		print("FAIL no suitable strip")
		get_tree().quit(1)
		return
	var tried := 0
	for strip in candidates:
		tried += 1
		_failed = false
		await _probe(strip, tried == 1 or tried == 3)
		if not _failed:
			break
		if tried >= 8:
			break
	print("RESULT %s after %d strip(s)" % ["FAIL" if _failed else "OK", tried])
	get_tree().quit(1 if _failed else 0)


func _probe(best: Rect2, shots: bool) -> void:
	var player: Player = _city.player
	var def: MapDefinition = _city.view.definition
	print("strip %s" % best)
	var y := best.position.y + best.size.y * 0.5
	var start := Vector2(best.position.x - 24.0, y)
	player.global_position = start
	player.velocity = Vector2.ZERO
	for i in 20:
		await get_tree().physics_frame
	if shots:
		await _shot("jump_1_before")
	# 1. Grounded: pushing into the strip is blocked.
	for i in 90:
		player.velocity = Vector2(180, 0)
		player.move_and_slide()
		await get_tree().physics_frame
	var blocked_x := player.global_position.x
	print("walker stopped at x=%.1f (strip starts %.1f)" % [blocked_x, best.position.x])
	if blocked_x > best.position.x:
		_failed = true
		print("FAIL walker entered the strip")
	if shots:
		await _shot("jump_2_blocked")
	# 2. Hop across (heading east).
	player.global_position = start
	await get_tree().physics_frame
	player._air_velocity = Vector2(180 * PlayerJumpState.AIR_SPEED_FRACTION, 0)
	player.stamina = 100.0
	player._jump.start()
	var shot_taken := false
	for i in 80:
		await get_tree().physics_frame
		player._update_jump(1.0 / 60.0)
		player.velocity = player._air_velocity if player.is_airborne() else Vector2.ZERO
		player.move_and_slide()
		if not shot_taken and player.jump_height() > 0.7:
			shot_taken = true
			print("apex at x=%.1f h=%.2f" % [player.global_position.x, player.jump_height()])
			if shots:
				await _shot("jump_3_apex")
	var landed_x := player.global_position.x
	print("hop landed at x=%.1f (strip ends %.1f)" % [landed_x, best.end.x])
	if landed_x < best.end.x:
		_failed = true
		print("FAIL hop did not clear the strip")
	if shots:
		await _shot("jump_4_landed")
	# 3. Dropped into the strip: the slide must carry him out downhill.
	var inside := Vector2(best.get_center().x, y)
	player.global_position = inside
	player._steep_ghost = true
	player._apply_steep_mask()
	var slope := def.slope_at_world(inside)
	print("inside slope %.1f deg downhill %s" % [rad_to_deg(slope), def.downhill_at_world(inside)])
	for i in 240:
		player.velocity = PlayerJumpState.slide_velocity(def.downhill_at_world(player.global_position))
		player.move_and_slide()
		player._update_jump(1.0 / 60.0)
		await get_tree().physics_frame
	var out_of_strip := not best.has_point(player.global_position)
	print(
		"slid to %s, out of strip: %s, ghost: %s"
		% [player.global_position, out_of_strip, player._steep_ghost]
	)
	if not out_of_strip:
		_failed = true
		print("FAIL slide did not leave the strip")
	if shots:
		await _shot("jump_5_slide")
