class_name ClothingStrip
extends Node
## Debug-gallery prototype: hover an adult character and the cursor becomes a hand; press on a
## garment and drag the mouse down to pull that one layer off (gown, apron, headscarf, boots).
## Only fitted wearables come off; whatever is baked into the body stays. Minors and the
## apprentice are refused via SpiritUndress.is_protected. Press U to redress everyone.
## docs/SYSTEMS/CLOTHING_STRIP.md

signal stripped(rig: SharedCharacterRig, slot: StringName)

## Body radius around the feet..head segment for the fallback pick (no layer left under
## the cursor).
const BODY_RADIUS := 0.4
const BODY_HEIGHT := 1.75
## Slot name for "what is left": dragging bare body pulls off the baked outfit, showing the
## nude twin.
const BODY_SLOT := &"body"

## Downward travel in screen pixels that turns a press into "pull it off".
const DRAG_PX := 56.0
const CURSOR_KIND := &"grab"

var camera_provider: Callable
var _rigs: Array[SharedCharacterRig] = []
## rig -> {slot: CharacterWearable}, so redress can put the same wearables back.
var _removed: Dictionary = {}
var _bared: Dictionary = {}
var _press_target: Dictionary = {}
var _press_y := 0.0
var _hover := false


func register(rig: SharedCharacterRig) -> void:
	# Freed rigs cannot be passed to a typed lambda, so prune by index.
	for i in range(_rigs.size() - 1, -1, -1):
		if not is_instance_valid(_rigs[i]):
			_rigs.remove_at(i)
	if not _rigs.has(rig) and not SpiritUndress.is_protected(rig):
		_rigs.append(rig)


## Nearest-layer hit along a world ray: {rig, slot} or {}. Layer boxes overlap (apron over
## gown), so the smallest box wins, which is the outermost, most specific garment.
func pick(origin: Vector3, direction: Vector3) -> Dictionary:
	var best := {}
	var best_volume := INF
	for rig in _rigs:
		if not is_instance_valid(rig):
			continue
		var skeleton := rig.skeleton()
		if skeleton == null:
			continue
		for slot: String in CharacterWardrobe.SLOTS:
			var wearable := rig.equipped_wearable(StringName(slot))
			if wearable == null:
				continue
			var prefix := "Garment_wearable_%s_" % slot
			for child: Node in skeleton.get_children():
				var mesh := child as MeshInstance3D
				if mesh == null or mesh.is_queued_for_deletion() or not mesh.visible:
					continue
				if not String(mesh.name).begins_with(prefix):
					continue
				var inverse := mesh.global_transform.affine_inverse()
				var box := mesh.get_aabb()
				if (
					box.intersects_ray(inverse * origin, (inverse.basis * direction).normalized())
					== null
				):
					continue
				var volume := box.get_volume()
				if volume < best_volume:
					best_volume = volume
					best = {"rig": rig, "slot": StringName(slot)}
	if best.is_empty():
		best = _pick_body(origin, direction)
	return best


## Fallback: the standing body (a vertical segment) nearest the ray, for rigs that still show
## their baked outfit and have a nude twin.
func _pick_body(origin: Vector3, direction: Vector3) -> Dictionary:
	var best := {}
	var best_along := INF
	for rig in _rigs:
		if (
			not is_instance_valid(rig)
			or not SpiritUndress.eligible(rig)
			or SpiritUndress.is_undressed(rig)
		):
			continue
		var model := rig.get_node_or_null("Model") as Node3D
		var stature := (
			model.scale.y / rig.model_scale.y if model != null and rig.model_scale.y > 0.0 else 1.0
		)
		var feet := rig.global_position
		var closest := Geometry3D.get_closest_points_between_segments(
			origin, origin + direction * 200.0, feet, feet + Vector3.UP * BODY_HEIGHT * stature
		)
		if closest[0].distance_to(closest[1]) > BODY_RADIUS:
			continue
		var along := origin.distance_to(closest[0])
		if along < best_along:
			best_along = along
			best = {"rig": rig, "slot": BODY_SLOT}
	return best


func strip(rig: SharedCharacterRig, slot: StringName) -> bool:
	if SpiritUndress.is_protected(rig):
		return false
	if slot == BODY_SLOT:
		if not SpiritUndress.eligible(rig) or SpiritUndress.is_undressed(rig):
			return false
		SpiritUndress.undress(rig)
		_bared[rig] = true
		stripped.emit(rig, slot)
		return true
	var wearable := rig.equipped_wearable(slot)
	if wearable == null:
		return false
	var kept: Dictionary = _removed.get(rig, {})
	kept[slot] = wearable
	_removed[rig] = kept
	rig.unequip_wearable(slot)
	stripped.emit(rig, slot)
	return true


func redress_all() -> void:
	for rig: SharedCharacterRig in _bared:
		if is_instance_valid(rig):
			SpiritUndress.restore(rig)
	_bared.clear()
	for rig: SharedCharacterRig in _removed:
		if not is_instance_valid(rig):
			continue
		for wearable: CharacterWearable in _removed[rig].values():
			rig.equip_wearable(wearable)
	_removed.clear()


func _pick_at(screen_position: Vector2) -> Dictionary:
	var camera := camera_provider.call() as Camera3D if camera_provider.is_valid() else null
	if camera == null:
		return {}
	return pick(
		camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position)
	)


func _set_hover(on: bool) -> void:
	if on == _hover:
		return
	_hover = on
	CursorService.set_layer_cursor(CursorService.LAYER_CHARACTER, CURSOR_KIND if on else &"")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _press_target.is_empty():
			_set_hover(not _pick_at(motion.position).is_empty())
		elif motion.position.y - _press_y >= DRAG_PX:
			strip(_press_target["rig"], _press_target["slot"])
			_press_target = {}
			_set_hover(not _pick_at(motion.position).is_empty())
	elif (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	):
		var button := event as InputEventMouseButton
		if button.pressed:
			# Not consumed: a press without a drag is a click, which CityCitizens turns into a
			# conversation on release (R-1887). Only the drag strips.
			_press_target = _pick_at(button.position)
			_press_y = button.position.y
		else:
			_press_target = {}
	elif (
		event is InputEventKey
		and (event as InputEventKey).pressed
		and (event as InputEventKey).keycode == KEY_U
	):
		redress_all()


func _exit_tree() -> void:
	_set_hover(false)
