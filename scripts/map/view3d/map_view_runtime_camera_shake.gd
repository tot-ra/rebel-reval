class_name MapViewRuntimeCameraShake
extends RefCounted

## Trauma-based screen shake for MapViewRuntimeCamera. Split out under P0-185 so
## mode, zoom, and follow code stays under the architecture soft cap.

const SHAKE_DECAY_RATE := 3.5
const SHAKE_MAX_OFFSET := 0.14

var _shake_trauma := 0.0
var _shake_phase := 0.0


func add(amount: float = 0.35) -> void:
	if not _enabled():
		return
	_shake_trauma = clampf(_shake_trauma + amount, 0.0, 1.0)


func apply(delta: float, position: Vector3) -> Vector3:
	if _shake_trauma <= 0.0:
		return position
	_shake_trauma = maxf(_shake_trauma - SHAKE_DECAY_RATE * delta, 0.0)
	var trauma_amount := _shake_trauma * _shake_trauma
	_shake_phase += delta * 42.0
	var offset := Vector3(
		sin(_shake_phase * 1.7) * SHAKE_MAX_OFFSET * trauma_amount,
		sin(_shake_phase * 2.3) * SHAKE_MAX_OFFSET * trauma_amount * 0.45,
		cos(_shake_phase * 1.3) * SHAKE_MAX_OFFSET * trauma_amount
	)
	return position + offset


func _enabled() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("/root/UserSettings"):
		return true
	var settings: Node = tree.root.get_node("/root/UserSettings")
	if not ("gameplay" in settings) or not ("dialogue" in settings):
		return true
	var gameplay: Variant = settings.get("gameplay")
	var dialogue: Variant = settings.get("dialogue")
	if gameplay == null or not gameplay.has_method("allows_screenshake"):
		return true
	var reduced_motion := bool(dialogue.reduced_motion) if dialogue != null else false
	return bool(gameplay.allows_screenshake(reduced_motion))
