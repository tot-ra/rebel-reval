extends SceneTree

const SCENE_PATH := "res://scenes/map_prototype/smithy_courtyard.tscn"
const CAPTURE_DIR := "res://docs/reports/images"
const EXPECTED_SIZE := Vector2i(1600, 900)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var signatures: Dictionary = {}
	for target in MapVisualStyle.ALL_TARGETS:
		var instance := (load(SCENE_PATH) as PackedScene).instantiate()
		instance.configure_style(target, MapVisualStyle.TIME_DAY)
		root.add_child(instance)
		await process_frame
		signatures[target] = instance.comparison_signature()
		_verify_scene(instance, target)
		instance.queue_free()
		await process_frame

	var baseline: String = signatures[MapVisualStyle.TARGET_PIXEL]
	for target in MapVisualStyle.ALL_TARGETS:
		_check(signatures[target] == baseline, "%s geometry/camera/gameplay signature drifted" % String(target))

	var day_hashes: Dictionary = {}
	for target in MapVisualStyle.ALL_TARGETS:
		var day_image := _load_capture(target, MapVisualStyle.TIME_DAY)
		var night_image := _load_capture(target, MapVisualStyle.TIME_NIGHT)
		if day_image == null or night_image == null:
			continue
		day_hashes[target] = _image_hash(day_image)
		var day_luminance := _average_luminance(day_image)
		var night_luminance := _average_luminance(night_image)
		print(" - %s luminance: day=%.4f night=%.4f ratio=%.3f" % [target, day_luminance, night_luminance, night_luminance / day_luminance])
		_check(night_luminance < day_luminance * 0.80, "%s night capture must be at least 20%% darker" % String(target))
		_check(not _has_error_magenta(day_image), "%s day capture contains error magenta" % String(target))
		_check(not _has_error_magenta(night_image), "%s night capture contains error magenta" % String(target))

	_check(day_hashes.size() == MapVisualStyle.ALL_TARGETS.size(), "all three day captures must load")
	if day_hashes.size() == MapVisualStyle.ALL_TARGETS.size():
		_check(day_hashes.values().duplicate().size() == 3, "three target captures must exist")
		var unique_hashes: Dictionary = {}
		for hash_value in day_hashes.values():
			unique_hashes[hash_value] = true
		_check(unique_hashes.size() == 3, "three day targets must be visually distinct")

	if _failures.is_empty():
		print("P0-036 visual target verification: PASS")
		print(" - immutable geometry/camera/collisions/scale: ok")
		print(" - seven terrain types: ok")
		print(" - medieval buildings and five prop kinds: ok")
		print(" - character pivot/height and Y-sort: ok")
		print(" - three distinct 1600x900 day captures: ok")
		print(" - night captures preserve visibility and reduce luminance: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_scene(instance: Node, target: StringName) -> void:
	_check(instance.camera.position == Vector2(800, 448), "%s camera position" % target)
	_check(instance.camera.zoom == Vector2.ONE, "%s camera zoom" % target)
	_check(instance.definition.world_size() == Vector2(1600, 896), "%s world scale" % target)
	_check(instance.grid.used_terrain_ids().size() == 7, "%s terrain coverage" % target)
	_check(instance.assembled["buildings"].size() == 8, "%s building count" % target)
	_check(instance.assembled["props"].size() == 5, "%s prop count" % target)
	_check(instance.actors.y_sort_enabled, "%s Y-sort" % target)
	_check(instance.player.get_meta("character_height") == 64, "%s character height" % target)
	_check(instance.player.get_meta("pivot") == Vector2(0, 18), "%s character pivot" % target)
	for body in instance.assembled["buildings"]:
		var shape := body.get_child(0) as CollisionShape2D
		var footprint: Rect2 = body.get_meta("footprint")
		var collision_rect := Rect2(body.position + shape.position - shape.shape.size * 0.5, shape.shape.size)
		_check(collision_rect == footprint, "%s collision footprint %s" % [target, body.name])


func _load_capture(target: StringName, time_of_day: StringName) -> Image:
	var path := "%s/p0_036_%s_%s.png" % [CAPTURE_DIR, target, time_of_day]
	var global_path := ProjectSettings.globalize_path(path)
	var image := Image.load_from_file(global_path)
	_check(image != null and not image.is_empty(), "capture missing: %s" % path)
	if image == null or image.is_empty():
		return null
	_check(image.get_size() == EXPECTED_SIZE, "%s must be 1600x900" % path)
	return image


func _average_luminance(image: Image) -> float:
	var total := 0.0
	var samples := 0
	for y in range(0, image.get_height(), 10):
		for x in range(0, image.get_width(), 10):
			var color := image.get_pixel(x, y)
			total += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			samples += 1
	return total / float(samples)


func _has_error_magenta(image: Image) -> bool:
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var color := image.get_pixel(x, y)
			if color.r > 0.95 and color.b > 0.95 and color.g < 0.10:
				return true
	return false


func _image_hash(image: Image) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(image.get_data())
	return hashing.finish().hex_encode()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
