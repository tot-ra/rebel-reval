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

## Wing flap timing: seconds between keyframe advances. 0.12s gives roughly
## 3-4 flaps/second which looks natural for most species at gameplay distance.
const FLAP_INTERVAL_S := 0.12
## Some species glide more than they flap; skip that many flaps between active
## stroke bursts so swallows flap often while eagles mostly soar.
const GLIDE_SKIP_DEFAULT := 3
const WING_ROOT_ANGLES: Array[float] = [-0.34, -0.18, 0.0, 0.28, 0.48, 0.28, 0.0, -0.18]
const WING_ELBOW_ANGLES: Array[float] = [-0.10, -0.05, 0.0, 0.12, 0.20, 0.12, 0.0, -0.05]
const WING_SWEEP_ANGLES: Array[float] = [0.14, 0.08, -0.02, -0.10, -0.16, -0.08, 0.03, 0.10]

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
const FLOCK_BOB_AMPLITUDE := 0.16

var _birds: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _flight_enabled := true
var _context := &""
var _seed_key := &""
var _cycle_progress := 0.0
var _world_max := Vector2.ZERO
var _seconds_until_spawn := 0.0
var _spawn_tick := 0
var _flock_renderers: Dictionary = {}  # species -> MapViewCrowdRenderer


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


## Instanced follower renderer for `species`, or null before its first flock.
func flock_renderer_for(species: StringName) -> MapViewCrowdRenderer:
	return _flock_renderers.get(species) as MapViewCrowdRenderer


static func is_flocking_species(species: StringName) -> bool:
	return BirdSpecies.group_for(species) in FLOCKING_GROUPS


func configure(map_id: StringName, context: StringName, size_cells: Vector2i) -> void:
	_context = context
	_seed_key = map_id
	_spawn_tick = 0
	_seconds_until_spawn = 0.0
	_world_max = Vector2(float(size_cells.x), float(size_cells.y))
	_hide_all_birds()


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
		var sway_phase := float(bird.get_meta(&"sway_phase", 0.0))
		var sway_amplitude := float(bird.get_meta(&"sway_amplitude", 0.3))
		var sway_frequency := float(bird.get_meta(&"sway_frequency", 1.0))
		var bank := sin(t * TAU * sway_frequency + sway_phase) * sway_amplitude * 0.65 * sin(t * PI)
		bird.rotate_object_local(Vector3.FORWARD, bank)
		bird.set_meta(&"traveled", traveled)
		# Advance wing flap animation
		_advance_flap(bird, delta)


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


func _apply_wing_pose(bird: Node3D, phase: float) -> void:
	var root_l := bird.get_node_or_null("WingRootL") as Node3D
	var elbow_l := bird.get_node_or_null("WingRootL/WingElbowL") as Node3D
	var root_r := bird.get_node_or_null("WingRootR") as Node3D
	var elbow_r := bird.get_node_or_null("WingRootR/WingElbowR") as Node3D
	if root_l == null or elbow_l == null or root_r == null or elbow_r == null:
		return
	var root_angle := _sample_flap_angle(WING_ROOT_ANGLES, phase)
	var elbow_angle := _sample_flap_angle(WING_ELBOW_ANGLES, phase)
	var sweep_angle := _sample_flap_angle(WING_SWEEP_ANGLES, phase)
	root_l.rotation = Vector3(0.0, -sweep_angle, -root_angle)
	elbow_l.rotation = Vector3(0.0, sweep_angle * 0.65, -elbow_angle)
	root_r.rotation = Vector3(0.0, sweep_angle, root_angle)
	elbow_r.rotation = Vector3(0.0, -sweep_angle * 0.65, elbow_angle)


func _sample_flap_angle(keyframes: Array[float], phase: float) -> float:
	var wrapped := fposmod(phase, float(keyframes.size()))
	var first := floori(wrapped)
	var second := (first + 1) % keyframes.size()
	return lerpf(keyframes[first], keyframes[second], wrapped - float(first))


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
	# Flapping state is continuous; mesh frames are used for the neutral shape,
	# while the modular pivots carry the smooth animation.
	bird.set_meta(&"flap_index", 2)
	bird.set_meta(&"flap_phase", 2.0)
	bird.set_meta(&"flap_pause", 0.0)
	bird.set_meta(&"glide_skip", _glide_skip_for_species(species))
	bird.set_meta(&"species", species)
	_apply_wing_pose(bird, 2.0)
	bird.remove_meta(&"flock_offsets")
	if is_flocking_species(species) and _ensure_flock_renderer(species) != null:
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
	return not frame.is_empty() and _install_modular_rig(bird, frame, false)


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
	}


func _next_spawn_delay() -> float:
	_rng.seed = BirdAmbientAudio.hash_seed(_seed_key, _context, _spawn_tick) ^ 0x9E3779B9
	return _rng.randf_range(MIN_SPAWN_INTERVAL_S, MAX_SPAWN_INTERVAL_S)


func _first_idle_bird() -> Node3D:
	for bird in _birds:
		if not bird.visible:
			return bird
	return null


func _advance_flap(bird: Node3D, delta: float) -> void:
	var pause := maxf(float(bird.get_meta(&"flap_pause", 0.0)) - delta, 0.0)
	if bird.has_meta(&"flight_player"):
		var player := bird.get_meta(&"flight_player") as AnimationPlayer
		var clip := &"Glide" if pause > 0.0 else &"Fly"
		if player.current_animation != clip:
			player.play(clip, 0.15)
	if pause > 0.0:
		bird.set_meta(&"flap_pause", pause)
		_apply_wing_pose(bird, 2.0)
		return
	var phase := float(bird.get_meta(&"flap_phase", 2.0)) + delta / FLAP_INTERVAL_S
	if phase >= 10.0:
		phase = 2.0
		bird.set_meta(
			&"flap_pause", float(bird.get_meta(&"glide_skip", GLIDE_SKIP_DEFAULT)) * FLAP_INTERVAL_S
		)
	bird.set_meta(&"flap_phase", phase)
	_apply_wing_pose(bird, phase)


## Larger soaring birds (raptors, gulls) hold the glide longer between flap
## bursts; small songbirds and swallows flap nearly continuously.
func _glide_skip_for_species(species: StringName) -> int:
	var group := BirdSpecies.group_for(species)
	match group:
		BirdSpecies.GROUP_RAPTOR:
			return 6
		BirdSpecies.GROUP_GULL, BirdSpecies.GROUP_WATERFOWL:
			return 4
		BirdSpecies.GROUP_OWL:
			return 5
		BirdSpecies.GROUP_SWALLOW:
			return 1
		BirdSpecies.GROUP_TERN:
			return 2
		_:
			return GLIDE_SKIP_DEFAULT


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


## Push every visible leader's followers to its species MultiMesh in one
## upload per species. Species without an active flock get an empty set, which
## leaves their renderer drawing nothing.
func _sync_flocks() -> void:
	var per_species: Dictionary = {}
	for species: StringName in _flock_renderers:
		per_species[species] = {}
	for bird_index in _birds.size():
		var bird := _birds[bird_index]
		if not bird.visible or not bird.has_meta(&"flock_offsets"):
			continue
		var species: StringName = bird.get_meta(&"species", &"")
		if not per_species.has(species):
			continue
		var transforms: Dictionary = per_species[species]
		var leader := bird.transform.orthonormalized()
		var traveled := float(bird.get_meta(&"traveled", 0.0))
		var offsets: Array = bird.get_meta(&"flock_offsets")
		for rank in offsets.size():
			var offset: Vector3 = offsets[rank]
			# Per-follower phase keeps the formation breathing instead of
			# sliding as one rigid block.
			var phase := traveled * 0.55 + float(rank) * 1.7
			var bob := Vector3(0.0, sin(phase) * FLOCK_BOB_AMPLITUDE, 0.0)
			var roll := Basis(Vector3.FORWARD, sin(phase * 0.8) * 0.12)
			transforms[bird_index * 64 + rank] = Transform3D(
				leader.basis * roll, leader * offset + bob
			)
	for species: StringName in per_species:
		(_flock_renderers[species] as MapViewCrowdRenderer).replace_actor_transforms(
			per_species[species]
		)


func _ensure_flock_renderer(species: StringName) -> MapViewCrowdRenderer:
	if _flock_renderers.has(species):
		return _flock_renderers[species]
	var parts := _flock_parts_for(species)
	if parts.is_empty():
		return null
	var renderer := CrowdRenderer.new()
	renderer.name = "Flock_%s" % species
	renderer.configure_parts(parts, MAX_FLOCK_FOLLOWERS, 0.0, FLOCK_VISIBILITY_RANGE, false)
	add_child(renderer)
	_flock_renderers[species] = renderer
	return renderer


## Followers reuse the leader's own geometry: the skinned storybook model
## frozen on its Glide clip (legs tucked) where one exists, otherwise the
## catalogue glide mesh. The clip only evaluates inside the tree; outside it
## the bind pose (wings spread, legs down) is used.
func _flock_parts_for(species: StringName) -> Array:
	if BirdAssets.has_animated_model(species):
		var model := BirdAssets.create_animated_model(species)
		if model == null:
			return []
		var posed := false
		if is_inside_tree():
			add_child(model)
			var player := model.get_meta(&"flight_player") as AnimationPlayer
			if player != null and player.has_animation(&"Glide"):
				player.play(&"Glide")
				player.seek(0.0, true)
				posed = true
		var parts := CrowdRenderer.mesh_parts_from_scene(model, posed)
		if model.get_parent() != null:
			remove_child(model)
		model.free()
		return parts
	var mesh := BirdMeshes.mesh_for(species, BirdSpecies.POSE_GLIDING)
	if mesh == null:
		return []
	var holder := MeshInstance3D.new()
	holder.mesh = mesh
	if mesh.get_surface_count() > 0 and mesh.surface_get_material(0) != null:
		_apply_authored_mesh_material(holder)
	else:
		_apply_mesh_material(holder)
	var part := {
		"mesh": CrowdRenderer.mesh_with_active_materials(holder),
		"transform": Transform3D.IDENTITY,
	}
	if holder.material_override != null:
		part["material"] = holder.material_override
	holder.free()
	return [part]


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
