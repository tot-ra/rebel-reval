class_name MapViewMedievalAnimalModels
extends RefCounted

## Shared access to approved game-ready livestock GLBs. The same assets are used
## by authored map props and visual-only ambient actors so animal quality cannot
## drift between static and moving placements.

const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")

const IDLE_ANIMATION := &"Idle"
const WALK_ANIMATION := &"Walk"
const ANIMATION_PLAYER_META := &"animal_animation_player"

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
	&"goat": "res://assets/animals/hendrik_reyneke/goat.glb",
	MammalSpecies.SPECIES_COW: "res://assets/animals/medieval/medieval_cattle.glb",
	MammalSpecies.SPECIES_PIG: "res://assets/animals/medieval/medieval_pig.glb",
	MammalSpecies.SPECIES_SHEEP: "res://assets/animals/medieval/medieval_sheep.glb",
	MammalSpecies.SPECIES_HORSE: "res://assets/animals/medieval/medieval_pack_horse.glb",
	# The Lower Town street dog is an authored hound: closed anatomy, PBR coat,
	# and the shared livestock idle/walk clips instead of the procedural proxy.
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
	parent.add_child(model)
	_configure_animation(parent, model)
	return model


static func sync_animation(actor: Node3D, previous_position: Vector3, delta: float) -> void:
	if not actor.has_meta(ANIMATION_PLAYER_META):
		return
	var player := actor.get_meta(ANIMATION_PLAYER_META) as AnimationPlayer
	if player == null:
		return
	var displacement := Vector2(
		actor.position.x - previous_position.x, actor.position.z - previous_position.z
	)
	var wanted := _clip_name(
		player, WALK_ANIMATION if displacement.length_squared() > 0.0000001 else IDLE_ANIMATION
	)
	if wanted.is_empty() or player.current_animation == wanted:
		return
	player.play(wanted, 0.18)
	if wanted == WALK_ANIMATION:
		# Match the authored 1 m/s gait to slow penned movement without freezing it.
		player.speed_scale = clampf(displacement.length() / maxf(delta, 0.0001), 0.35, 1.35)
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
