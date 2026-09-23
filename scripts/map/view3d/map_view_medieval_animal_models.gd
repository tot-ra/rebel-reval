class_name MapViewMedievalAnimalModels
extends RefCounted

## Shared access to approved game-ready livestock GLBs. The same assets are used
## by authored map props and visual-only ambient actors so animal quality cannot
## drift between static and moving placements.

const MammalSpecies := preload("res://scripts/map/view3d/map_view_mammal_species.gd")

const IDLE_ANIMATION := &"Idle"
const WALK_ANIMATION := &"Walk"
const TROT_ANIMATION := &"Trot"
const GRAZE_ANIMATION := &"Graze"
const SNIFF_ANIMATION := &"Sniff"
const ANIMATION_PLAYER_META := &"animal_animation_player"
const ANIMATION_STATE_META := &"animal_animation_state"
const WALK_REFERENCE_SPEED_META := &"animal_walk_reference_speed"
const RUN_REFERENCE_SPEED_META := &"animal_run_reference_speed"
const GAIT_SKELETON_META := &"animal_gait_skeleton"
const IDLE_VARIATION_TIME_META := &"animal_idle_variation_time"
const DOG_TROT_SPEED := 1.0
const DOG_TROT_REFERENCE_SPEED := 1.35
const DOG_SNIFF_INTERVAL := 5.5
const LIVESTOCK_GRAZE_INTERVAL := 7.0
const LIVESTOCK_TROT_SPEED := 1.2
const LIVESTOCK_TROT_REFERENCE_SPEED := 0.95
const PROCEDURAL_GAIT_MODEL_META := &"procedural_gait_model"
const PROCEDURAL_GAIT_PHASE_META := &"procedural_gait_phase"
const PROCEDURAL_GAIT_WEIGHT_META := &"procedural_gait_weight"
const PROCEDURAL_FOWL: Array[StringName] = []
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
	MammalSpecies.SPECIES_CHICKEN: "res://assets/storybook/hen.glb",
	MammalSpecies.SPECIES_RAT: "res://assets/storybook/rat.glb",
	MammalSpecies.SPECIES_RED_FOX: "res://assets/storybook/fox.glb",
	MammalSpecies.SPECIES_HARE: "res://assets/storybook/hare.glb",
	MammalSpecies.SPECIES_WILD_BOAR: "res://assets/storybook/boar.glb",
	MammalSpecies.SPECIES_DUCK: "res://assets/storybook/duck.glb",
	MammalSpecies.SPECIES_GOOSE: "res://assets/birds/greylag_goose/walking.glb",
	&"goat": "res://assets/storybook/goat.glb",
	MammalSpecies.SPECIES_COW: "res://assets/animals/medieval/medieval_cattle.glb",
	MammalSpecies.SPECIES_PIG: "res://assets/storybook/pig.glb",
	MammalSpecies.SPECIES_SHEEP: "res://assets/storybook/sheep.glb",
	MammalSpecies.SPECIES_HORSE: "res://assets/animals/medieval/medieval_pack_horse.glb",
	# The Lower Town street dog uses the rebuilt shaggy village-dog surface.
	# Its shared six-clip rig supplies Idle, Walk, Run and Graze aliases.
	MammalSpecies.SPECIES_DOG: "res://assets/storybook/dog.glb",
	# Town cats are the same production cat as Kalev's, dressed in another coat.
	MammalSpecies.SPECIES_CAT: "res://assets/storybook/forge_cat.tscn",
	MammalSpecies.SPECIES_BROWN_BEAR: "res://assets/animals/medieval/medieval_brown_bear.glb",
	MammalSpecies.SPECIES_ELK: "res://assets/animals/medieval/medieval_elk.glb",
}

## Yaw applied to a model so its nose points along -Z, which is the direction
## ambient actors are turned toward by `look_at` while walking. The cat rig is
## and grounded replacement GLBs face +Z. The retained cattle and horse face
## -X; each entry corrects its own authored axis so they walk nose-first.
# The greylag walking GLB is about 1.42 m tall in mesh space. Domestic yard
# geese must sit beside hens, not beside cattle, so they share the same
# down-scale pattern as duck/chicken.
const MODEL_SCALE: Dictionary = {
	MammalSpecies.SPECIES_DUCK: 0.7,
	MammalSpecies.SPECIES_CHICKEN: 0.8,
	MammalSpecies.SPECIES_GOOSE: 0.45,
}

const MODEL_YAW: Dictionary = {
	MammalSpecies.SPECIES_CHICKEN: PI,
	MammalSpecies.SPECIES_DUCK: PI,
	MammalSpecies.SPECIES_RAT: PI,
	MammalSpecies.SPECIES_RED_FOX: PI,
	MammalSpecies.SPECIES_HARE: PI,
	MammalSpecies.SPECIES_WILD_BOAR: PI,
	MammalSpecies.SPECIES_CAT: PI,
	MammalSpecies.SPECIES_COW: -PI * 0.5,
	MammalSpecies.SPECIES_PIG: PI,
	MammalSpecies.SPECIES_SHEEP: PI,
	MammalSpecies.SPECIES_HORSE: -PI * 0.5,
	MammalSpecies.SPECIES_DOG: PI,
	&"goat": PI,
	MammalSpecies.SPECIES_BROWN_BEAR: -PI * 0.5,
	MammalSpecies.SPECIES_ELK: -PI * 0.5,
}


static func has_model(species: StringName) -> bool:
	return MODEL_PATHS.has(species)


static func add_model(parent: Node3D, species: StringName) -> Node3D:
	var path := String(MODEL_PATHS.get(species, ""))
	if path.is_empty():
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Animal model is not imported: %s" % path)
		return null
	var model := scene.instantiate() as Node3D
	model.name = "Model"
	model.set_meta(&"grounded_model", path.begins_with("res://assets/storybook/"))
	model.rotation.y = float(MODEL_YAW.get(species, 0.0))
	model.scale *= float(MODEL_SCALE.get(species, 1.0))
	model.set_meta(&"production_animal_model", true)
	model.set_meta(&"species", species)
	# The coat is stored in COLOR_0. Godot leaves vertex_color_use_as_albedo off
	# on glTF import, so horns, hooves, the mane, and the muzzle would not show.
	if (
		species == MammalSpecies.SPECIES_COW
		or species == MammalSpecies.SPECIES_HORSE
		or species == MammalSpecies.SPECIES_BROWN_BEAR
		or species == MammalSpecies.SPECIES_ELK
	):
		_enable_vertex_coat(model)
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
			if (
				(species == MammalSpecies.SPECIES_DOG and speed >= DOG_TROT_SPEED)
				or (species != MammalSpecies.SPECIES_DOG and speed >= LIVESTOCK_TROT_SPEED)
			)
			else WALK_ANIMATION
		)
		actor.set_meta(IDLE_VARIATION_TIME_META, 0.0)
	else:
		var idle_time := float(actor.get_meta(IDLE_VARIATION_TIME_META, 0.0)) + delta
		actor.set_meta(IDLE_VARIATION_TIME_META, idle_time)
		# Deterministic long idle variants make herds feel alive without random
		# animation churn. Dogs sniff; livestock periodically lower their heads.
		if species == MammalSpecies.SPECIES_DOG:
			if fmod(idle_time, DOG_SNIFF_INTERVAL * 2.0) >= DOG_SNIFF_INTERVAL:
				wanted_canonical = SNIFF_ANIMATION
		elif fmod(idle_time, LIVESTOCK_GRAZE_INTERVAL * 2.0) >= LIVESTOCK_GRAZE_INTERVAL:
			wanted_canonical = GRAZE_ANIMATION
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
		if _has_anatomical_gait(actor):
			player.speed_scale = speed / _gait_reference_speed(actor, WALK_REFERENCE_SPEED_META)
		else:
			player.speed_scale = clampf(speed / 0.62, 0.55, 1.25)
	elif wanted_canonical == TROT_ANIMATION:
		var reference_speed := (
			DOG_TROT_REFERENCE_SPEED
			if species == MammalSpecies.SPECIES_DOG
			else LIVESTOCK_TROT_REFERENCE_SPEED
		)
		if _has_anatomical_gait(actor):
			player.speed_scale = speed / _gait_reference_speed(actor, RUN_REFERENCE_SPEED_META)
		else:
			player.speed_scale = clampf(speed / reference_speed, 0.75, 1.35)
	else:
		player.speed_scale = 1.0


static func _enable_vertex_coat(model: Node3D) -> void:
	var mesh_instance := model.find_child("AnimalMesh", true, false) as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	if mesh_instance.mesh.get_surface_count() < 1:
		return
	var format_flags: int = mesh_instance.mesh.surface_get_format(0)
	if (format_flags & Mesh.ARRAY_FORMAT_COLOR) == 0:
		return
	var source := mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
	if source == null:
		return
	# Keep the imported material. A surface override is reported as null by the
	# headless dummy renderer and fails the livestock suite.
	source.vertex_color_use_as_albedo = true
	source.albedo_color = Color.WHITE
	# The extracted atlas is a dot grid on small islands. Vertex color is the coat.
	source.albedo_texture = null


static func _configure_animation(parent: Node3D, model: Node3D) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	# Loops are explicit for imported GLBs, including the new skeletal fowl.
	for clip: StringName in player.get_animation_list():
		if clip in [&"Idle", &"Walk", &"Run", &"Graze", &"Peck", &"LookAround", &"Alert"]:
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	parent.set_meta(ANIMATION_PLAYER_META, player)
	_configure_anatomical_gait(parent, model, player)
	var idle := _clip_name(player, IDLE_ANIMATION)
	if not idle.is_empty():
		player.play(idle)


static func _has_anatomical_gait(actor: Node3D) -> bool:
	return actor.has_meta(WALK_REFERENCE_SPEED_META) and actor.has_meta(RUN_REFERENCE_SPEED_META)


static func _configure_anatomical_gait(
	parent: Node3D, model: Node3D, player: AnimationPlayer
) -> void:
	# Imported sculpted rigs publish their measured support speeds. Their rest
	# flexion and authored clip durations differ; body-height guesses cause skating.
	var rig_nodes: Array[Node] = [model]
	rig_nodes.append_array(model.find_children("*", "Node3D", true, false))
	for node in rig_nodes:
		var extras: Dictionary = node.get_meta(&"extras", {})
		if not extras.has("walk_reference_speed") or not extras.has("run_reference_speed"):
			continue
		var walk := float(extras["walk_reference_speed"])
		var run := float(extras["run_reference_speed"])
		if walk > 0.0 and run > 0.0:
			parent.set_meta(GAIT_SKELETON_META, node)
			parent.set_meta(WALK_REFERENCE_SPEED_META, walk)
			parent.set_meta(RUN_REFERENCE_SPEED_META, run)
			return
	for skeleton: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		if skeleton.find_bone("Ankle.LB") < 0:
			continue
		var body := skeleton.find_bone("Body")
		if body < 0 or not player.has_animation("Walk") or not player.has_animation("Run"):
			continue
		# Build-time cycle() in mammal_limb_anatomy.py expresses stride in body
		# heights. During support, root translation must cancel sole translation.
		var height := skeleton.get_bone_global_rest(body).origin.y
		var hare := String(parent.get_meta(&"species", "")) == "hare"
		var walk_cycle := 0.72 if hare else 0.68
		var walk_speed := (
			height * (0.50 if hare else 0.48) / walk_cycle / player.get_animation("Walk").length
		)
		var run_speed := height * (0.60 if hare else 0.65) / 0.58 / player.get_animation("Run").length
		if walk_speed > 0.0 and run_speed > 0.0:
			parent.set_meta(GAIT_SKELETON_META, skeleton)
			parent.set_meta(WALK_REFERENCE_SPEED_META, walk_speed)
			parent.set_meta(RUN_REFERENCE_SPEED_META, run_speed)


static func _gait_reference_speed(actor: Node3D, key: StringName) -> float:
	# Read current local transforms: coat variants scale the cat after loading.
	# This also works while a prop actor is being built outside the scene tree.
	var relative := Transform3D.IDENTITY
	var ancestor := actor.get_meta(GAIT_SKELETON_META) as Node3D
	while ancestor != null:
		relative = ancestor.transform * relative
		if ancestor == actor:
			break
		ancestor = ancestor.get_parent() as Node3D
	return maxf(float(actor.get_meta(key)) * relative.basis.y.length(), 0.0001)


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
	var aliases := {TROT_ANIMATION: "Run", SNIFF_ANIMATION: "Graze", GRAZE_ANIMATION: "Peck"}
	var candidates: Array[String] = [
		String(canonical),
		String(canonical).to_lower(),
		String(aliases.get(canonical, "")),
	]
	for candidate in candidates:
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
