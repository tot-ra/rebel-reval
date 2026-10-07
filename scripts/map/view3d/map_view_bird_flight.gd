class_name MapViewBirdFlight
extends Node3D

## Deterministic gliding bird silhouettes for outdoor maps (P0-105). Species
## selection reuses P0-117 spawn weights; song playback is MapViewBirdAmbientAudio.

const BirdAmbientAudio := preload("res://scripts/map/view3d/map_view_bird_ambient_audio.gd")
const BirdAssets := preload("res://scripts/map/view3d/map_view_bird_assets.gd")
const BirdMeshes := preload("res://scripts/map/view3d/map_view_bird_meshes.gd")
const BirdSpecies := preload("res://scripts/map/view3d/map_view_bird_species.gd")
const CrowdRenderer := preload("res://scripts/map/view3d/map_view_crowd_renderer.gd")

const MAX_CONCURRENT_BIRDS := 4
const MIN_SPAWN_INTERVAL_S := 4.0
const MAX_SPAWN_INTERVAL_S := 14.0
const FLIGHT_HEIGHT_MIN := 7.0
const FLIGHT_HEIGHT_MAX := 15.0
const FLIGHT_SPEED_MIN := 5.5
const FLIGHT_SPEED_MAX := 11.0
const EDGE_MARGIN := 5.0
const SWAY_AMPLITUDE_MIN := 0.18
const SWAY_AMPLITUDE_MAX := 0.55
const SWAY_FREQUENCY_MIN := 0.8
const SWAY_FREQUENCY_MAX := 1.45

## Wingbeat kinematics (R-1188). Real wingbeats are not a symmetric see-saw:
## the power downstroke takes a little more than half the cycle with the wing
## spread, and on the upstroke the hand folds back at the wrist so the wing
## rises with less drag. Frequency and flight style come from `flap_profile`.
const DOWNSTROKE_SHARE := 0.56
## Body heave per wingbeat as a share of body length: the body rises on the
## downstroke and sinks on the upstroke.
const BODY_HEAVE := 0.05
const STYLE_GLIDE := &"glide"
const STYLE_BOUND := &"bound"
## Per-family wingbeats. hz: wingbeats per second; burst: wingbeats per bout and
## pause: seconds between bouts (pause 0 = continuous rowing flight, as geese
## and ducks fly); style: glide keeps the wings spread between bouts, bound
## folds them to the body (finches, tits, woodpeckers); up/down: stroke
## amplitude in radians above and below the wing's rest line.
const FLAP_PROFILES := {
	&"gull": {"hz": 2.8, "burst": 5, "pause": 1.8, "style": STYLE_GLIDE, "up": 0.7, "down": 0.55},
	&"tern": {"hz": 3.2, "burst": 8, "pause": 0.6, "style": STYLE_GLIDE, "up": 0.8, "down": 0.65},
	&"waterfowl": {"hz": 4.6, "burst": 0, "pause": 0, "style": STYLE_GLIDE, "up": 0.85, "down": 0.75},
	&"wader": {"hz": 3.6, "burst": 0, "pause": 0.0, "style": STYLE_GLIDE, "up": 0.8, "down": 0.7},
	&"raptor": {"hz": 2.8, "burst": 4, "pause": 2.5, "style": STYLE_GLIDE, "up": 0.55, "down": 0.45},
	&"owl": {"hz": 2.6, "burst": 5, "pause": 1.2, "style": STYLE_GLIDE, "up": 0.7, "down": 0.6},
	&"corvid": {"hz": 3.8, "burst": 14, "pause": 0.9, "style": STYLE_GLIDE, "up": 0.75, "down": 0.65},
	&"swallow": {"hz": 7.0, "burst": 5, "pause": 0.4, "style": STYLE_GLIDE, "up": 0.8, "down": 0.7},
	&"songbird": {"hz": 9.0, "burst": 4, "pause": 0.3, "style": STYLE_BOUND, "up": 0.95, "down": 0.85},
	# gdlint: ignore=max-line-length
	&"woodpecker": {"hz": 7.5, "burst": 3, "pause": 0.45, "style": STYLE_BOUND, "up": 0.95, "down": 0.85},
}
## Species whose size or habits differ from their family default.
const FLAP_OVERRIDES := {
	&"mute_swan": {"hz": 2.6, "up": 0.70, "down": 0.60},
	&"greylag_goose": {"hz": 3.4},
	&"mallard": {"hz": 5.2},
	&"grey_heron": {"hz": 2.2, "up": 0.60, "down": 0.55},
	&"great_cormorant": {"hz": 3.8, "up": 0.75, "down": 0.65},
	&"common_snipe": {"hz": 6.0},
	&"white_tailed_eagle": {"hz": 2.0, "burst": 3, "pause": 3.5},
	&"common_kestrel": {"hz": 4.2, "burst": 6, "pause": 1.0},
	&"western_jackdaw": {"hz": 4.6},
	&"eurasian_magpie": {"hz": 5.0, "burst": 6, "pause": 0.6},
}

## Flock LOD (P0-159). Each spawned bird stays one fully rigged leader (the
## MAX_CONCURRENT_BIRDS cap and `bird_flight_peak` budget are unchanged);
## gregarious species bring followers drawn through the P0-152 MultiMesh crowd
## path in their glide pose, one draw per species part instead of one rigged
## node tree per bird. Followers never cast shadows.
const FLOCKING_GROUPS: Array[StringName] = [
	BirdSpecies.GROUP_GULL,
	BirdSpecies.GROUP_TERN,
	BirdSpecies.GROUP_WATERFOWL,
	BirdSpecies.GROUP_WADER,
	BirdSpecies.GROUP_CORVID,
	BirdSpecies.GROUP_SWALLOW,
]
const FLOCK_FOLLOWERS_MIN := 3
const FLOCK_FOLLOWERS_MAX := 9
## Concurrent cap for instanced followers across all flocks on a map.
const MAX_FLOCK_FOLLOWERS := 24
## Rigged leaders and instanced followers share one far cull distance so a
## flock never loses its leader while the followers are still drawn.
const BIRD_DETAIL_RANGE := 110.0
const FLOCK_VISIBILITY_RANGE := 110.0
const FLOCK_SPACING := 1.15
## Slow positional drift that keeps the formation loose; the wingbeat heave is
## added separately so followers bob in time with their own wings.
const FLOCK_DRIFT_AMPLITUDE := 0.06
## Followers flap through a baked flipbook: this many poses per wingbeat plus
## one rest pose (glide or folded) for the pauses between bouts. Each pose is
## one MultiMesh draw per species, so followers stay instanced (P0-159).
const FLOCK_FLAP_FRAMES := 8

## Flipbook mesh parts shared by every map this session (see _pose_cache_key).
static var _pose_cache: Dictionary = {}

## Optional: returns the corner (x, ground y, z) of the flight window for the
## next bird. Large continuous maps (the seamless city) pass a window around
## the player here; district maps leave it unset and fly over the whole map.
var path_origin := Callable()
var _birds: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _flight_enabled := true
var _context := &""
var _seed_key := &""
var _cycle_progress := 0.0
var _world_max := Vector2.ZERO
var _seconds_until_spawn := 0.0
var _spawn_tick := 0
## species -> Array[MapViewCrowdRenderer], one renderer per flipbook pose.
var _flock_renderers: Dictionary = {}
var _warm_queue: Array[StringName] = []
## Skinned model being baked and its species; the bake owns it until done.
var _warm_species := &""
var _warm_model: Node3D
var _warm_poses: Array = []


func _ready() -> void:
	for index in MAX_CONCURRENT_BIRDS:
		var bird := _make_bird_actor(index)
		add_child(bird)
		bird.visible = false
		_birds.append(bird)


func set_flight_enabled(enabled: bool) -> void:
	_flight_enabled = enabled
	if not enabled:
		_hide_all_birds()
		_seconds_until_spawn = 0.0


## Rigged leader birds only; instanced followers are `active_flock_follower_count`.
func flight_birds() -> Array[Node3D]:
	return _birds


func active_flock_follower_count() -> int:
	var count := 0
	for bird in _birds:
		if bird.visible:
			count += (bird.get_meta(&"flock_offsets", []) as Array).size()
	return count


## Instanced follower renderers for `species`, one per flipbook pose
## (FLOCK_FLAP_FRAMES wingbeat poses, then the rest pose). Empty before the
## species' first flock.
func flock_renderers_for(species: StringName) -> Array:
	return _flock_renderers.get(species, [])


## Tip-to-tip span in metres of the catalogue anatomy for `species`.
static func wingspan_m(species: StringName) -> float:
	var geometry := BirdSpecies.geometry_for(species)
	var body: Vector3 = geometry["body"]
	return float(geometry["wing_span"]) * BirdSpecies.scale_m(species) / maxf(body.x, 0.001)


## Wingbeat profile for `species`: family defaults plus per-species overrides.
static func flap_profile(species: StringName) -> Dictionary:
	var profile: Dictionary = (
		FLAP_PROFILES.get(BirdSpecies.group_for(species), FLAP_PROFILES[&"songbird"]) as Dictionary
	).duplicate()
	profile.merge(FLAP_OVERRIDES.get(species, {}), true)
	return profile


## Stroke phase in [0, 1) at `time` seconds into a flight (0 = top of the
## upstroke), or -1.0 while the bird rests its wings between flapping bouts.
static func flap_phase_at(time: float, profile: Dictionary) -> float:
	var hz := float(profile["hz"])
	var burst := int(profile["burst"])
	var pause := float(profile["pause"])
	if burst <= 0 or pause <= 0.0:
		return fposmod(time * hz, 1.0)
	var bout := float(burst) / hz
	var local := fposmod(time, bout + pause)
	if local >= bout:
		return -1.0
	return fposmod(local * hz, 1.0)


## Joint angles for one stroke phase (see `flap_phase_at`). Positive `arm` and
## `hand` raise the wing, positive sweeps move it forward; `heave` in -1..1 is
## the body's vertical position within the wingbeat.
static func wing_pose(phase: float, profile: Dictionary) -> Dictionary:
	if phase < 0.0:
		if profile["style"] == STYLE_BOUND:
			# Bounding flight: wings snap shut against the body between bursts.
			return {"arm": -0.12, "arm_sweep": -0.5, "hand": -0.1, "hand_sweep": -1.3, "heave": 0.0}
		return {"arm": 0.06, "arm_sweep": 0.0, "hand": -0.04, "hand_sweep": 0.0, "heave": 0.0}
	var theta := (
		PI * phase / DOWNSTROKE_SHARE
		if phase < DOWNSTROKE_SHARE
		else PI + PI * (phase - DOWNSTROKE_SHARE) / (1.0 - DOWNSTROKE_SHARE)
	)
	var up := float(profile["up"])
	var down := float(profile["down"])
	var stroke := cos(theta)
	var upstroke := maxf(0.0, -sin(theta))
	return {
		"arm": ((up - down) + (up + down) * stroke) * 0.5,
		# The arm reaches forward on the downstroke and swings back on the way up.
		"arm_sweep": 0.14 * sin(theta) - 0.18 * upstroke,
		# Wrist flexes on the upstroke: the hand trails low and folds back, then
		# flicks out straight for the next downstroke.
		"hand": -0.55 * upstroke * (up + down) * 0.5 + 0.1 * sin(theta),
		"hand_sweep": -0.85 * upstroke,
		"heave": -stroke,
	}


static func apply_wing_pose(bird: Node3D, pose: Dictionary) -> void:
	var root_l := bird.get_node_or_null("WingRootL") as Node3D
	var elbow_l := bird.get_node_or_null("WingRootL/WingElbowL") as Node3D
	var root_r := bird.get_node_or_null("WingRootR") as Node3D
	var elbow_r := bird.get_node_or_null("WingRootR/WingElbowR") as Node3D
	if root_l == null or elbow_l == null or root_r == null or elbow_r == null:
		return
	var arm := float(pose["arm"])
	var arm_sweep := float(pose["arm_sweep"])
	var hand := float(pose["hand"])
	var hand_sweep := float(pose["hand_sweep"])
	# Mirrored joints: the left wing lies along -X, so its signs flip.
	root_l.rotation = Vector3(0.0, -arm_sweep, -arm)
	elbow_l.rotation = Vector3(0.0, -hand_sweep, -hand)
	root_r.rotation = Vector3(0.0, arm_sweep, arm)
	elbow_r.rotation = Vector3(0.0, hand_sweep, hand)


static func is_flocking_species(species: StringName) -> bool:
	return BirdSpecies.group_for(species) in FLOCKING_GROUPS


func configure(map_id: StringName, context: StringName, size_cells: Vector2i) -> void:
	_context = context
	_seed_key = map_id
	_spawn_tick = 0
	_seconds_until_spawn = 0.0
	_world_max = Vector2(float(size_cells.x), float(size_cells.y))
	_hide_all_birds()
	_queue_flock_warmup()


func sync(context: StringName, cycle_progress: float, delta: float, enabled: bool = true) -> void:
	_flight_enabled = enabled
	_context = context
	_cycle_progress = wrapf(cycle_progress, 0.0, 1.0)
	if not _should_spawn():
		_hide_all_birds()
		return
	_advance_active_birds(delta)
	_sync_flocks()
	if delta <= 0.0:
		return
	if is_inside_tree():
		_warm_flock_poses_step()
	_seconds_until_spawn -= delta
	if _seconds_until_spawn > 0.0:
		return
	if active_bird_count() >= MAX_CONCURRENT_BIRDS:
		_seconds_until_spawn = MIN_SPAWN_INTERVAL_S
		return
	_spawn_bird()
	_sync_flocks()
	_spawn_tick += 1
	_seconds_until_spawn = _next_spawn_delay()


func active_bird_count() -> int:
	var count := 0
	for bird in _birds:
		if bird.visible:
			count += 1
	return count


static func pick_species(
	seed_key: StringName, context: StringName, cycle_progress: float, spawn_tick: int
) -> StringName:
	var candidates := weighted_flight_candidates(context, cycle_progress)
	if candidates.is_empty():
		return &""
	var rng := RandomNumberGenerator.new()
	rng.seed = BirdAmbientAudio.hash_seed(seed_key, context, spawn_tick) ^ 0x27D4EB2D
	var total_weight := 0.0
	for entry: Dictionary in candidates:
		total_weight += float(entry["weight"])
	if total_weight <= 0.0:
		return &""
	var roll := rng.randf() * total_weight
	var accumulated := 0.0
	for entry: Dictionary in candidates:
		accumulated += float(entry["weight"])
		if roll <= accumulated:
			return entry["species"] as StringName
	return candidates[candidates.size() - 1]["species"] as StringName


static func weighted_flight_candidates(context: StringName, cycle_progress: float) -> Array:
	var candidates: Array = []
	if context.is_empty():
		return candidates
	for species in BirdSpecies.ALL_SPECIES:
		var weight := BirdSpecies.spawn_weight(species, context)
		if weight <= 0.0:
			continue
		var song := BirdSpecies.song_profile_for(species)
		var time_tag := StringName(song.get("time", &"day"))
		if not BirdAmbientAudio.matches_song_time(time_tag, cycle_progress):
			continue
		if (
			not BirdAssets.has_animated_model(species)
			and BirdMeshes.mesh_for(species, BirdSpecies.POSE_GLIDING) == null
		):
			continue
		candidates.append({"species": species, "weight": weight})
	return candidates


static func distinct_species_for_context(
	seed_key: StringName, context: StringName, cycle_progress: float, sample_count: int
) -> Array[StringName]:
	var species_list: Array[StringName] = []
	var seen: Dictionary = {}
	for tick in sample_count:
		var species := pick_species(seed_key, context, cycle_progress, tick)
		if species.is_empty() or seen.has(species):
			continue
		seen[species] = true
		species_list.append(species)
	return species_list


func _should_spawn() -> bool:
	return _flight_enabled and not _context.is_empty() and _world_max.x > EDGE_MARGIN * 2.0


func _advance_active_birds(delta: float) -> void:
	for bird in _birds:
		if not bird.visible:
			continue
		var traveled := (
			float(bird.get_meta(&"traveled", 0.0)) + float(bird.get_meta(&"speed", 0.0)) * delta
		)
		var path_length := float(bird.get_meta(&"path_length", 1.0))
		if traveled >= path_length:
			bird.visible = false
			bird.remove_meta(&"flock_offsets")
			continue
		var t := traveled / path_length
		var position := _flight_position(bird, t)
		var look_ahead := _flight_position(bird, minf(t + 0.02, 1.0))
		bird.position = position
		_orient_bird_if_distinct(bird, look_ahead)
		_advance_flap(bird, delta)
		bird.position += Vector3.UP * float(bird.get_meta(&"flap_heave", 0.0))
		var sway_phase := float(bird.get_meta(&"sway_phase", 0.0))
		var sway_amplitude := float(bird.get_meta(&"sway_amplitude", 0.3))
		var sway_frequency := float(bird.get_meta(&"sway_frequency", 1.0))
		var bank := sin(t * TAU * sway_frequency + sway_phase) * sway_amplitude * 0.65 * sin(t * PI)
		bird.rotate_object_local(Vector3.FORWARD, bank)
		bird.set_meta(&"traveled", traveled)


func _orient_bird_if_distinct(bird: Node3D, target: Vector3) -> void:
	if bird.position.is_equal_approx(target):
		return
	bird.look_at(target, Vector3.UP)


func _install_modular_rig(bird: Node3D, frame: Dictionary, procedural_material: bool) -> bool:
	if frame.is_empty():
		return false
	for child in bird.get_children():
		child.free()
	var body := _make_mesh_node("Body", frame["body"] as ArrayMesh, procedural_material)
	bird.add_child(body)
	var left_shoulder := Node3D.new()
	left_shoulder.name = "WingRootL"
	left_shoulder.position = frame["left_shoulder"]
	bird.add_child(left_shoulder)
	var left_elbow := Node3D.new()
	left_elbow.name = "WingElbowL"
	left_elbow.position = frame["left_elbow"] - frame["left_shoulder"]
	left_shoulder.add_child(left_elbow)
	var left_upper := _make_mesh_node(
		"WingUpperL", frame["left_upper"] as ArrayMesh, procedural_material
	)
	left_upper.position = Vector3.ZERO
	left_shoulder.add_child(left_upper)
	var left_primary := _make_mesh_node(
		"WingPrimaryL", frame["left_primary"] as ArrayMesh, procedural_material
	)
	left_primary.position = Vector3.ZERO
	left_elbow.add_child(left_primary)
	var right_shoulder := Node3D.new()
	right_shoulder.name = "WingRootR"
	right_shoulder.position = frame["right_shoulder"]
	bird.add_child(right_shoulder)
	var right_elbow := Node3D.new()
	right_elbow.name = "WingElbowR"
	right_elbow.position = frame["right_elbow"] - frame["right_shoulder"]
	right_shoulder.add_child(right_elbow)
	var right_upper := _make_mesh_node(
		"WingUpperR", frame["right_upper"] as ArrayMesh, procedural_material
	)
	right_upper.position = Vector3.ZERO
	right_shoulder.add_child(right_upper)
	var right_primary := _make_mesh_node(
		"WingPrimaryR", frame["right_primary"] as ArrayMesh, procedural_material
	)
	right_primary.position = Vector3.ZERO
	right_elbow.add_child(right_primary)
	bird.set_meta(&"wing_rig_frame", frame)
	return true


func _make_mesh_node(
	node_name: String, mesh: ArrayMesh, procedural_material: bool
) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	model.name = node_name
	model.mesh = mesh
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_apply_detail_range(model)
	if procedural_material:
		_apply_mesh_material(model)
	else:
		_apply_authored_mesh_material(model)
	return model


func _apply_authored_mesh_material(model: MeshInstance3D) -> void:
	var source_mesh := model.mesh as ArrayMesh
	if source_mesh == null:
		return
	for surface_index in source_mesh.get_surface_count():
		var source_material := source_mesh.surface_get_material(surface_index)
		if source_material == null or not source_material is StandardMaterial3D:
			continue
		var material := (source_material as StandardMaterial3D).duplicate() as StandardMaterial3D
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		model.set_surface_override_material(surface_index, material)


## Pose the modular rig at stroke `phase` (see `flap_phase_at`; negative is
## the rest pose) with the bird's own wingbeat profile.
func _apply_wing_pose(bird: Node3D, phase: float) -> void:
	apply_wing_pose(bird, wing_pose(phase, flap_profile(bird.get_meta(&"species", &""))))


func _flight_position(bird: Node3D, t: float) -> Vector3:
	var start: Vector3 = bird.get_meta(&"start")
	var end: Vector3 = bird.get_meta(&"end")
	var forward := end - start
	var distance := maxf(forward.length(), 0.001)
	var direction := forward / distance
	var side := Vector3.UP.cross(direction)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	var up := direction.cross(side).normalized()
	var sway_phase := float(bird.get_meta(&"sway_phase", 0.0))
	var sway_amplitude := float(bird.get_meta(&"sway_amplitude", 0.3))
	var sway_frequency := float(bird.get_meta(&"sway_frequency", 1.0))
	# Smoothstep eases entry/exit while the two harmonics produce a shallow,
	# wind-carved S-curve rather than a predictable up/down elevator motion.
	var eased_t := smoothstep(0.0, 1.0, t)
	var base := start.lerp(end, eased_t)
	var envelope := sin(eased_t * PI)
	var lateral := sin(eased_t * TAU * sway_frequency + sway_phase) * sway_amplitude * envelope
	lateral += (
		sin(eased_t * TAU * sway_frequency * 0.47 + sway_phase * 1.7)
		* sway_amplitude
		* 0.32
		* envelope
	)
	var vertical := sin(eased_t * PI + sway_phase * 0.61) * sway_amplitude * 0.34 * envelope
	return base + side * lateral + up * vertical


func _spawn_bird() -> void:
	var species := pick_species(_seed_key, _context, _cycle_progress, _spawn_tick)
	if species.is_empty():
		return
	var bird := _first_idle_bird()
	if bird == null:
		return
	var path := _random_path(_seed_key, _spawn_tick)
	if not _install_species_rig(bird, species):
		return
	var start: Vector3 = path["start"]
	var end: Vector3 = path["end"]
	if path_origin.is_valid():
		var origin: Vector3 = path_origin.call()
		start += origin
		end += origin
	bird.position = start
	_orient_bird_if_distinct(bird, start + (end - start).normalized())
	bird.visible = true
	bird.set_meta(&"start", start)
	bird.set_meta(&"end", end)
	bird.set_meta(&"speed", path["speed"])
	bird.set_meta(&"path_length", start.distance_to(end))
	bird.set_meta(&"traveled", 0.0)
	bird.set_meta(&"sway_phase", path["sway_phase"])
	bird.set_meta(&"sway_amplitude", path["sway_amplitude"])
	bird.set_meta(&"sway_frequency", path["sway_frequency"])
	# Deterministic start offset so concurrent birds do not beat in unison.
	bird.set_meta(&"flap_time", float(path["flap_offset"]))
	bird.set_meta(&"flap_heave", 0.0)
	bird.set_meta(&"species", species)
	_advance_flap(bird, 0.0)
	bird.remove_meta(&"flock_offsets")
	if is_flocking_species(species) and not _ensure_flock_renderer(species).is_empty():
		var offsets := flock_offsets(
			_seed_key, _spawn_tick, MAX_FLOCK_FOLLOWERS - active_flock_follower_count()
		)
		if not offsets.is_empty():
			bird.set_meta(&"flock_offsets", offsets)


func _install_species_rig(bird: Node3D, species: StringName) -> bool:
	bird.remove_meta(&"flight_player")
	if BirdAssets.has_animated_model(species):
		var model := BirdAssets.create_animated_model(species)
		if model == null:
			return false
		for child: Node in bird.get_children():
			child.free()
		bird.remove_meta(&"wing_rig_frame")
		bird.add_child(model)
		for geometry: Node in model.find_children("*", "GeometryInstance3D", true, false):
			_apply_detail_range(geometry as GeometryInstance3D)
		bird.set_meta(&"flight_player", model.get_meta(&"flight_player"))
		bird.set_meta(&"species", species)
		return true
	var frame := BirdMeshes.modular_rig_for(species)
	if frame.is_empty() or not _install_modular_rig(bird, frame, false):
		return false
	bird.set_meta(&"species", species)
	return true


func _random_path(seed_key: StringName, spawn_tick: int) -> Dictionary:
	_rng.seed = BirdAmbientAudio.hash_seed(seed_key, _context, spawn_tick) ^ 0x165667B1
	var height := _rng.randf_range(FLIGHT_HEIGHT_MIN, FLIGHT_HEIGHT_MAX)
	var min_axis := EDGE_MARGIN
	var max_x := _world_max.x - EDGE_MARGIN
	var max_z := _world_max.y - EDGE_MARGIN
	var side := _rng.randi_range(0, 3)
	var start := Vector3.ZERO
	var end := Vector3.ZERO
	match side:
		0:
			start = Vector3(min_axis, height, _rng.randf_range(min_axis, max_z))
			end = Vector3(
				max_x, height + _rng.randf_range(-0.35, 0.35), _rng.randf_range(min_axis, max_z)
			)
		1:
			start = Vector3(max_x, height, _rng.randf_range(min_axis, max_z))
			end = Vector3(
				min_axis, height + _rng.randf_range(-0.35, 0.35), _rng.randf_range(min_axis, max_z)
			)
		2:
			start = Vector3(_rng.randf_range(min_axis, max_x), height, min_axis)
			end = Vector3(
				_rng.randf_range(min_axis, max_x), height + _rng.randf_range(-0.35, 0.35), max_z
			)
		_:
			start = Vector3(_rng.randf_range(min_axis, max_x), height, max_z)
			end = Vector3(
				_rng.randf_range(min_axis, max_x), height + _rng.randf_range(-0.35, 0.35), min_axis
			)
	return {
		"start": start,
		"end": end,
		"speed": _rng.randf_range(FLIGHT_SPEED_MIN, FLIGHT_SPEED_MAX),
		"sway_phase": _rng.randf_range(0.0, TAU),
		"sway_amplitude": _rng.randf_range(SWAY_AMPLITUDE_MIN, SWAY_AMPLITUDE_MAX),
		"sway_frequency": _rng.randf_range(SWAY_FREQUENCY_MIN, SWAY_FREQUENCY_MAX),
		"flap_offset": _rng.randf_range(0.0, 4.0),
	}


func _next_spawn_delay() -> float:
	_rng.seed = BirdAmbientAudio.hash_seed(_seed_key, _context, _spawn_tick) ^ 0x9E3779B9
	return _rng.randf_range(MIN_SPAWN_INTERVAL_S, MAX_SPAWN_INTERVAL_S)


func _first_idle_bird() -> Node3D:
	for bird in _birds:
		if not bird.visible:
			return bird
	return null


## Advance the leader's wingbeat clock and pose its wings. Skinned storybook
## birds switch between their Fly and Glide clips, with Fly retimed to the
## species' wingbeat frequency; catalogue birds pose the modular rig.
func _advance_flap(bird: Node3D, delta: float) -> void:
	var time := float(bird.get_meta(&"flap_time", 0.0)) + delta
	bird.set_meta(&"flap_time", time)
	var species: StringName = bird.get_meta(&"species", &"")
	var profile := flap_profile(species)
	var phase := flap_phase_at(time, profile)
	var pose := wing_pose(phase, profile)
	if bird.has_meta(&"flight_player"):
		var player := bird.get_meta(&"flight_player") as AnimationPlayer
		var clip := &"Glide" if phase < 0.0 else &"Fly"
		if player.current_animation != clip:
			player.play(clip, 0.15)
		player.speed_scale = 1.0
		if clip == &"Fly" and player.has_animation(clip):
			player.speed_scale = clampf(
				player.get_animation(clip).length * float(profile["hz"]), 0.5, 3.0
			)
	else:
		apply_wing_pose(bird, pose)
	bird.set_meta(
		&"flap_heave", float(pose["heave"]) * BirdSpecies.scale_m(species) * BODY_HEAVE
	)


func _hide_all_birds() -> void:
	for bird in _birds:
		bird.visible = false
		bird.remove_meta(&"flock_offsets")
	_sync_flocks()


## Deterministic loose chevron behind a leader, in leader-local space (-Z is
## the flight direction after `look_at`). `budget` is the remaining global
## follower allowance; the returned array never exceeds it.
static func flock_offsets(seed_key: StringName, spawn_tick: int, budget: int) -> Array:
	var offsets: Array = []
	if budget <= 0:
		return offsets
	var rng := RandomNumberGenerator.new()
	rng.seed = BirdAmbientAudio.hash_seed(seed_key, &"flock", spawn_tick) ^ 0x2545F491
	var count := mini(rng.randi_range(FLOCK_FOLLOWERS_MIN, FLOCK_FOLLOWERS_MAX), budget)
	for rank in count:
		var row := floori(rank / 2.0) + 1
		var side := -1.0 if rank % 2 == 0 else 1.0
		offsets.append(
			Vector3(
				side * float(row) * FLOCK_SPACING * 0.8 + rng.randf_range(-0.35, 0.35),
				rng.randf_range(-0.45, 0.45),
				float(row) * FLOCK_SPACING + rng.randf_range(-0.3, 0.3)
			)
		)
	return offsets


## Push every visible leader's followers to the flipbook renderer of their
## current wingbeat pose, one upload per pose renderer. Poses and species with
## no follower this frame get an empty set, which draws nothing.
func _sync_flocks() -> void:
	var per_species: Dictionary = {}  # species -> Array of {actor_id: Transform3D}, one per pose
	for species: StringName in _flock_renderers:
		var frames: Array = []
		for _frame in (_flock_renderers[species] as Array).size():
			frames.append({})
		per_species[species] = frames
	for bird_index in _birds.size():
		var bird := _birds[bird_index]
		if not bird.visible or not bird.has_meta(&"flock_offsets"):
			continue
		var species: StringName = bird.get_meta(&"species", &"")
		if not per_species.has(species):
			continue
		var frames: Array = per_species[species]
		var profile := flap_profile(species)
		var heave_scale := BirdSpecies.scale_m(species) * BODY_HEAVE
		# Open the formation for big birds so neighbouring wings never cross
		# mid-stroke (lateral gap ~85% of the wingspan, capped so a swan skein
		# stays a compact formation).
		var spread := clampf(wingspan_m(species) * 0.85 / (FLOCK_SPACING * 0.8), 1.0, 1.6)
		# The leader's node carries its own heave; strip it for the formation.
		var leader := bird.transform.orthonormalized()
		leader.origin -= Vector3.UP * float(bird.get_meta(&"flap_heave", 0.0))
		var traveled := float(bird.get_meta(&"traveled", 0.0))
		var leader_time := float(bird.get_meta(&"flap_time", 0.0))
		var offsets: Array = bird.get_meta(&"flock_offsets")
		for rank in offsets.size():
			var offset: Vector3 = offsets[rank]
			# Each follower beats on its own clock: a fixed lag plus a few
			# percent of tempo drift, so the skein ripples instead of beating
			# in lockstep, and flap-gliders do not all stop at once.
			var tempo := 1.0 + float((rank * 7) % 11 - 5) * 0.012
			var phase := flap_phase_at(leader_time * tempo + float(rank) * 0.37, profile)
			var frame := FLOCK_FLAP_FRAMES
			if phase >= 0.0:
				frame = floori(phase * FLOCK_FLAP_FRAMES) % FLOCK_FLAP_FRAMES
			var heave := float(wing_pose(phase, profile)["heave"]) * heave_scale
			var drift_phase := traveled * 0.55 + float(rank) * 1.7
			var drift := Vector3(0.0, sin(drift_phase) * FLOCK_DRIFT_AMPLITUDE + heave, 0.0)
			var roll := Basis(Vector3.FORWARD, sin(drift_phase * 0.8) * 0.08)
			(frames[frame] as Dictionary)[bird_index * 64 + rank] = Transform3D(
				leader.basis * roll, leader * (offset * spread) + drift
			)
	for species: StringName in per_species:
		var renderers: Array = _flock_renderers[species]
		var frames: Array = per_species[species]
		for frame in renderers.size():
			(renderers[frame] as MapViewCrowdRenderer).replace_actor_transforms(frames[frame])


## Flipbook renderers for `species`, built on its first flock and kept for
## the map: FLOCK_FLAP_FRAMES wingbeat poses then the rest pose. Empty while a
## skinned species is still warming; its leader then flies without followers.
func _ensure_flock_renderer(species: StringName) -> Array:
	if _flock_renderers.has(species):
		return _flock_renderers[species]
	var key := _pose_cache_key(species)
	if not _pose_cache.has(key):
		if BirdAssets.has_animated_model(species):
			if not species in _warm_queue:
				_warm_queue.append(species)
			return []
		var catalogue_poses := _catalogue_pose_parts(species)
		if catalogue_poses.is_empty():
			return []
		_pose_cache[key] = catalogue_poses
	var poses: Array = _pose_cache[key]
	var renderers: Array = []
	for frame in poses.size():
		var renderer := CrowdRenderer.new()
		renderer.name = "Flock_%s_%d" % [species, frame]
		renderer.configure_parts(
			poses[frame], MAX_FLOCK_FOLLOWERS, 0.0, FLOCK_VISIBILITY_RANGE, false
		)
		add_child(renderer)
		renderers.append(renderer)
	_flock_renderers[species] = renderers
	return renderers


## Skinned storybook flipbooks are keyed by model (both gulls share one GLB);
## catalogue flipbooks by species, since the pose depends on its wingbeat.
static func _pose_cache_key(species: StringName) -> String:
	if BirdAssets.has_animated_model(species):
		return BirdAssets.ANIMATED_MODELS[species]
	return String(species)


## Queue the map's gregarious skinned species for background baking.
func _queue_flock_warmup() -> void:
	if _warm_model != null:
		remove_child(_warm_model)
		_warm_model.free()
		_warm_model = null
	_warm_poses = []
	_warm_species = &""
	_warm_queue.clear()
	for species in BirdSpecies.ALL_SPECIES:
		if (
			is_flocking_species(species)
			and BirdAssets.has_animated_model(species)
			and BirdSpecies.spawn_weight(species, _context) > 0.0
			and not _pose_cache.has(_pose_cache_key(species))
		):
			_warm_queue.append(species)


## Bake at most one skinned pose per frame. CPU skinning a storybook bird costs
## ~15 ms per pose on an M5 Pro, so a whole flipbook in one frame would stall
## the game for ~130 ms the first time a gull or duck flock appears.
func _warm_flock_poses_step() -> void:
	while _warm_model == null and not _warm_queue.is_empty():
		var species: StringName = _warm_queue.pop_front()
		if _pose_cache.has(_pose_cache_key(species)):
			continue
		_warm_model = BirdAssets.create_animated_model(species)
		if _warm_model == null:
			continue
		_warm_species = species
		_warm_model.visible = false
		add_child(_warm_model)
		_warm_poses = []
	if _warm_model == null:
		return
	_warm_poses.append(_storybook_pose_parts(_warm_model, _warm_poses.size()))
	if _warm_poses.size() > FLOCK_FLAP_FRAMES:
		_pose_cache[_pose_cache_key(_warm_species)] = _warm_poses
		remove_child(_warm_model)
		_warm_model.free()
		_warm_model = null
		_warm_poses = []
		_warm_species = &""


## One skinned pose: frames sample the Fly clip, the last frame is Glide.
static func _storybook_pose_parts(model: Node3D, frame: int) -> Array:
	var player := model.get_meta(&"flight_player") as AnimationPlayer
	var clip := &"Fly" if frame < FLOCK_FLAP_FRAMES else &"Glide"
	var posed := player != null and player.has_animation(clip) and model.is_inside_tree()
	if posed:
		player.play(clip)
		var at := 0.0
		if frame < FLOCK_FLAP_FRAMES:
			at = (float(frame) + 0.5) / FLOCK_FLAP_FRAMES * player.get_animation(clip).length
		player.seek(at, true)
	return CrowdRenderer.mesh_parts_from_scene(model, posed)


## Catalogue flipbook: the leader's modular rig posed by `wing_pose`. Cheap
## (~15 ms for all poses of a species, once per session), so it is built
## synchronously on the first flock.
func _catalogue_pose_parts(species: StringName) -> Array:
	var rig_frame := BirdMeshes.modular_rig_for(species)
	if rig_frame.is_empty():
		return []
	var poses: Array = []
	var profile := flap_profile(species)
	var rig := Node3D.new()
	_install_modular_rig(rig, rig_frame, false)
	for frame in FLOCK_FLAP_FRAMES + 1:
		var phase := -1.0
		if frame < FLOCK_FLAP_FRAMES:
			phase = (float(frame) + 0.5) / FLOCK_FLAP_FRAMES
		apply_wing_pose(rig, wing_pose(phase, profile))
		poses.append([{"mesh": _merged_rig_mesh(rig), "transform": Transform3D.IDENTITY}])
	rig.free()
	return poses


## Bake the posed modular rig into one mesh so each follower pose is a single
## MultiMesh draw. Every catalogue part shares the plumage material.
static func _merged_rig_mesh(rig: Node3D) -> ArrayMesh:
	var surface := SurfaceTool.new()
	var material: Material = null
	for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null or part.mesh.get_surface_count() == 0:
			continue
		var xform := part.transform
		var parent := part.get_parent()
		while parent != null and parent != rig:
			xform = (parent as Node3D).transform * xform
			parent = parent.get_parent()
		surface.append_from(part.mesh, 0, xform)
		if material == null:
			material = part.mesh.surface_get_material(0)
	var mesh := surface.commit()
	if material != null and mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, material)
	return mesh


static func _apply_detail_range(geometry: GeometryInstance3D) -> void:
	geometry.visibility_range_end = BIRD_DETAIL_RANGE
	geometry.visibility_range_end_margin = CrowdRenderer.FAUNA_RANGE_MARGIN
	geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


func _make_bird_actor(index: int) -> Node3D:
	var actor := Node3D.new()
	actor.name = "FlightBird%d" % index
	return actor


func _apply_mesh_material(model: MeshInstance3D) -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.metallic = 0.0
	material.roughness = 0.92
	# Wing cards are mirrored across the body. Keep both faces visible because an
	# imported mirrored card can have the opposite winding on the far wing; the
	# runtime override must not cull that wing (or its flap frames).
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	model.material_override = material
