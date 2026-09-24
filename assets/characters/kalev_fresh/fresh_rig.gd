extends SharedCharacterRig
## Independent reconstruction: proportions and skin are authored into this mesh.

const FRESH_DIR := "res://assets/characters/kalev_fresh/"

@export var use_default_forge_outfit := false


func _ready() -> void:
	super._ready()
	if not use_default_forge_outfit:
		return
	for garment: String in ["linen_shirt", "smith_apron", "hose", "boots"]:
		var wearable := load(FRESH_DIR + garment + ".tres") as CharacterWearable
		if not equip_wearable(wearable):
			push_error("Fresh Kalev could not equip default garment: %s" % garment)


func _install_proportion_modifiers() -> void:
	pass

func _configure_lod0_visibility() -> void:
	pass

func _install_distance_lods() -> void:
	pass


func consume_foot_plant() -> StringName:
	if not LOCOMOTION_REFERENCE_SPEED.has(current_canonical_animation()):
		_planted_foot = &""
		return &""
	var player := animation_player()
	if player == null or player.current_animation_length <= 0.0:
		return &""
	# The fresh walk/run cycles keep both foot bones at nearly the same height
	# while their legs exchange load, so their authored half-cycle is the single
	# contact authority. Mixing it with height detection can double-trigger while
	# an animation blends between poses.
	var phase := fposmod(player.current_animation_position / player.current_animation_length, 1.0)
	var planted := RIGHT_FOOT_BONE if phase < 0.5 else LEFT_FOOT_BONE
	if planted == _planted_foot:
		return &""
	_planted_foot = planted
	return planted
