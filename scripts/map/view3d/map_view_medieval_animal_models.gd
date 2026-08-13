class_name MapViewMedievalAnimalModels
extends RefCounted

## Shared access to approved game-ready livestock GLBs. The same assets are used
## by authored map props and visual-only ambient actors so animal quality cannot
## drift between static and moving placements.

const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")

const IDLE_ANIMATION := &"Idle"
const WALK_ANIMATION := &"Walk"
const TROT_ANIMATION := &"Trot"
const SNIFF_ANIMATION := &"Sniff"
const ANIMATION_PLAYER_META := &"animal_animation_player"
const ANIMATION_STATE_META := &"animal_animation_state"
const IDLE_VARIATION_TIME_META := &"animal_idle_variation_time"
const DOG_TROT_SPEED := 1.0
const DOG_TROT_REFERENCE_SPEED := 1.35
const DOG_SNIFF_INTERVAL := 5.5
const PROCEDURAL_GAIT_MODEL_META := &"procedural_gait_model"
const PROCEDURAL_GAIT_PHASE_META := &"procedural_gait_phase"
const PROCEDURAL_GAIT_WEIGHT_META := &"procedural_gait_weight"
const PROCEDURAL_FOWL: Array[StringName] = [
	MammalSpecies.SPECIES_CHICKEN,
	MammalSpecies.SPECIES_DUCK,
	MammalSpecies.SPECIES_GOOSE,
]
const FOWL_STEP_FREQUENCY := 9.0
const FOWL_WADDLE_ANGLE := deg_to_rad(4.5)
const FOWL_BODY_BOB := 0.018
const FOWL_BODY_PITCH := deg_to_rad(1.8)

# The imported horse rig exposes the lower leg as a single bone. Its local +Y
# endpoint is the hoof contact proxy after glTF axis conversion. Keep the
# envelope deliberately small: the walk clip may lift the body by 2.5 cm, but
# must not float above or sink below the authored ground plane.
const HORSE_LEG_BONES: Array[StringName] = [
	&"FrontLeftLeg", &"FrontRightLeg", &"BackLeftLeg", &"BackRightLeg"
]
const HORSE_LEG_BONE_LENGTH := 0.6595
const HORSE_HOOF_EXTENSION := 0.1405
const HORSE_GROUND_MIN_Y := -0.005
const HORSE_GROUND_MAX_Y := 0.04

# Runtime loading avoids a clean-clone parse cycle before Godot has imported the
# new GLBs for the first time.
const MODEL_PATHS: Dictionary = {
	MammalSpecies.SPECIES_CHICKEN: "res://assets/animals/hendrik_reyneke/chicken.glb",
	MammalSpecies.SPECIES_DUCK: "res://assets/birds/mallard/standing.glb",
	MammalSpecies.SPECIES_GOOSE: "res://assets/birds/greylag_goose/standing.glb",
	&"goat": "res://assets/animals/hendrik_reyneke/goat.glb",
	MammalSpecies.SPECIES_COW: "res://assets/animals/medieval/medieval_cattle.glb",
	MammalSpecies.SPECIES_PIG: "res://assets/animals/medieval/medieval_pig.glb",
	MammalSpecies.SPECIES_SHEEP: "res://assets/animals/medieval/medieval_sheep.glb",
	MammalSpecies.SPECIES_HORSE: "res://assets/animals/medieval/medieval_pack_horse.glb",
	# The Lower Town street dog is an authored hound with closed anatomy, PBR
	# coat, and dog-specific idle, walk, trot, and sniff animation clips.
	MammalSpecies.SPECIES_DOG: "res://assets/animals/medieval/medieval_dog.glb",
	# Town cats are the same production cat as Kalev's, dressed in another coat.
	MammalSpecies.SPECIES_CAT: "res://assets/characters/cat/cat_rig.tscn",
}

## Yaw applied to a model so its nose points along -Z, which is the direction
## ambient actors are turned toward by `look_at` while walking. The cat rig is
## authored facing +Z for `SharedCharacterRig`.
const MODEL_YAW: Dictionary = {
	MammalSpecies.SPECIES_CAT: PI,
}


static func has_model(species: StringName) -> bool:
	return MODEL_PATHS.has(species)


static func add_model(parent: Node3D, species: StringName) -> Node3D:
	var path := String(MODEL_PATHS.get(species, ""))
	if path.is_empty():
		return null
	var scene := load(path) as PackedScene
	assert(scene != null, "Medieval animal GLB must be imported before map assembly: %s" % path)
	var model := scene.instantiate() as Node3D
	assert(model != null, "Medieval animal GLB root must be Node3D: %s" % path)
	model.name = "Model"
	model.rotation.y = float(MODEL_YAW.get(species, 0.0))
	model.set_meta(&"production_animal_model", true)
	model.set_meta(&"species", species)
	# Animation selection runs on the visual actor rather than the imported model.
	# Store species there as well so direct placements and tests get dog states.
	parent.set_meta(&"species", species)
	parent.add_child(model)
	_configure_animation(parent, model)
	_configure_procedural_gait(parent, model, species)
	return model


static func sync_animation(actor: Node3D, previous_position: Vector3, delta: float) -> void:
	var displacement := Vector2(
		actor.position.x - previous_position.x, actor.position.z - previous_position.z
	)
	_sync_procedural_gait(actor, displacement, delta)
	if not actor.has_meta(ANIMATION_PLAYER_META):
		return
	var player := actor.get_meta(ANIMATION_PLAYER_META) as AnimationPlayer
	if player == null:
		return
	var speed := displacement.length() / maxf(delta, 0.0001)
	var species: StringName = actor.get_meta(&"species", &"")
	var wanted_canonical := IDLE_ANIMATION
	if speed > 0.001:
		wanted_canonical = (
			TROT_ANIMATION
			if species == MammalSpecies.SPECIES_DOG and speed >= DOG_TROT_SPEED
			else WALK_ANIMATION
		)
		actor.set_meta(IDLE_VARIATION_TIME_META, 0.0)
	elif species == MammalSpecies.SPECIES_DOG:
		var idle_time := float(actor.get_meta(IDLE_VARIATION_TIME_META, 0.0)) + delta
		actor.set_meta(IDLE_VARIATION_TIME_META, idle_time)
		# Alternate a head-down sniff with alert idle while paused. This remains
		# deterministic and gives nearby dogs variety without per-frame randomness.
		if fmod(idle_time, DOG_SNIFF_INTERVAL * 2.0) >= DOG_SNIFF_INTERVAL:
			wanted_canonical = SNIFF_ANIMATION
	var wanted := _clip_name(player, wanted_canonical)
	if wanted.is_empty():
		wanted = _clip_name(player, WALK_ANIMATION if speed > 0.001 else IDLE_ANIMATION)
	if wanted.is_empty():
		return
	if player.current_animation != wanted:
		player.play(wanted, 0.16)
		actor.set_meta(ANIMATION_STATE_META, wanted_canonical)
	if wanted_canonical == WALK_ANIMATION:
		# Advance in proportion to distance so paws do not skate during slow wander.
		player.speed_scale = clampf(speed / 0.62, 0.55, 1.25)
	elif wanted_canonical == TROT_ANIMATION:
		player.speed_scale = clampf(speed / DOG_TROT_REFERENCE_SPEED, 0.75, 1.35)
	else:
		player.speed_scale = 1.0


static func _configure_animation(parent: Node3D, model: Node3D) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	parent.set_meta(ANIMATION_PLAYER_META, player)
	var idle := _clip_name(player, IDLE_ANIMATION)
	if not idle.is_empty():
		player.play(idle)


## Static fowl assets have no skeleton or clips. Keep the imported model under a
## lightweight motion pivot so walking still reads as planted steps rather than a
## rigid mesh sliding over the terrain.
static func _configure_procedural_gait(
	parent: Node3D, model: Node3D, species: StringName
) -> void:
	if species not in PROCEDURAL_FOWL or parent.has_meta(ANIMATION_PLAYER_META):
		return
	var rest_transform := model.transform
	var gait_pivot := Node3D.new()
	gait_pivot.name = "GaitPivot"
	parent.remove_child(model)
	parent.add_child(gait_pivot)
	gait_pivot.add_child(model)
	model.transform = rest_transform
	parent.set_meta(PROCEDURAL_GAIT_MODEL_META, gait_pivot)
	parent.set_meta(PROCEDURAL_GAIT_PHASE_META, 0.0)
	parent.set_meta(PROCEDURAL_GAIT_WEIGHT_META, 0.0)


static func _sync_procedural_gait(
	actor: Node3D, displacement: Vector2, delta: float
) -> void:
	if not actor.has_meta(PROCEDURAL_GAIT_MODEL_META):
		return
	var gait_pivot := actor.get_meta(PROCEDURAL_GAIT_MODEL_META) as Node3D
	if gait_pivot == null:
		return
	var safe_delta := maxf(delta, 0.0001)
	var speed := displacement.length() / safe_delta
	var target_weight := 1.0 if displacement.length_squared() > 0.0000001 else 0.0
	var weight := move_toward(
		float(actor.get_meta(PROCEDURAL_GAIT_WEIGHT_META, 0.0)), target_weight, delta * 8.0
	)
	var phase := float(actor.get_meta(PROCEDURAL_GAIT_PHASE_META, 0.0))
	if target_weight > 0.0:
		# Advance by distance travelled so a slow penned bird does not moonwalk.
		phase = fmod(phase + speed * delta * FOWL_STEP_FREQUENCY, TAU)
	actor.set_meta(PROCEDURAL_GAIT_PHASE_META, phase)
	actor.set_meta(PROCEDURAL_GAIT_WEIGHT_META, weight)
	var stride := sin(phase)
	var step_lift := absf(sin(phase * 2.0))
	gait_pivot.position.y = FOWL_BODY_BOB * step_lift * weight
	gait_pivot.rotation.x = FOWL_BODY_PITCH * stride * weight
	gait_pivot.rotation.z = FOWL_WADDLE_ANGLE * stride * weight


## Livestock GLBs ship capitalised clip names; the cat rig ships the lowercase
## canonical names shared with the character rigs. Accept either.
static func _clip_name(player: AnimationPlayer, canonical: StringName) -> String:
	for candidate in [String(canonical), String(canonical).to_lower()]:
		if player.has_animation(candidate):
			return candidate
	return ""


## Return the four hoof contact proxies in the skeleton's local space.
##
## WHY: MeshInstance3D.get_aabb() is the undeformed import bound in Godot, so
## it cannot detect a skinned leg floating during an animation. The authored
## quadruped rig has straight lower-leg bones; transforming their known local
## endpoints plus the authored hoof extension gives a stable runtime regression
## signal without adding collision.
static func horse_hoof_contact_points(skeleton: Skeleton3D) -> Dictionary:
	var contacts: Dictionary = {}
	for bone_name: StringName in HORSE_LEG_BONES:
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			continue
		var pose := skeleton.get_bone_global_pose(index)
		contacts[bone_name] = pose * Vector3(0.0, HORSE_LEG_BONE_LENGTH + HORSE_HOOF_EXTENSION, 0.0)
	return contacts
