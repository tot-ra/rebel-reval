class_name DialogueTextScale
extends RefCounted

## Supported dialogue text scales for P1-012. P1-013 persists the player choice.

const BASE_BODY_SIZE := 22
const BASE_SPEAKER_SIZE := 24
const BASE_CHOICE_SIZE := 20
const BASE_HINT_SIZE := 16
const BASE_BACKLOG_SIZE := 18

const SCALE_FACTORS := {
	"small": 0.85,
	"normal": 1.0,
	"large": 1.25,
	"extra_large": 1.5,
}


static func supported_scale_names() -> Array[String]:
	return ["small", "normal", "large", "extra_large"]


static func is_supported(scale_name: String) -> bool:
	return SCALE_FACTORS.has(scale_name)


static func factor_for(scale_name: String) -> float:
	return float(SCALE_FACTORS.get(scale_name, 1.0))


static func body_size(scale_name: String) -> int:
	return _scaled(BASE_BODY_SIZE, scale_name)


static func speaker_size(scale_name: String) -> int:
	return _scaled(BASE_SPEAKER_SIZE, scale_name)


static func choice_size(scale_name: String) -> int:
	return _scaled(BASE_CHOICE_SIZE, scale_name)


static func hint_size(scale_name: String) -> int:
	return _scaled(BASE_HINT_SIZE, scale_name)


static func backlog_size(scale_name: String) -> int:
	return _scaled(BASE_BACKLOG_SIZE, scale_name)


static func _scaled(base: int, scale_name: String) -> int:
	return maxi(10, int(round(float(base) * factor_for(scale_name))))
