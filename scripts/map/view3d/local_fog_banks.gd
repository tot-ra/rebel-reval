class_name LocalFogBanks
extends Node3D

## Localized fog banks: patches of ground fog that gather near water, only on damp,
## calm air. Presentation only; no gameplay state, nothing is persisted.
##
## The world is cut into CELL_SIZE cells around the camera focus. Each cell scores
##   density(weather) * water_affinity(distance to water) * patch_mask(noise)
## so fog needs all three: damp still air (dawn mist, overcast, after rain), water within
## WATER_REACH, and a drifting noise patch that leaves most of the shore clear. The best
## cells claim one of POOL_SIZE emitters (GPUParticles3D, soft camera-facing puffs lit by
## local_fog_puff.gdshader: sun/moon side, forward scatter, ambient hue, lightning).
## GL Compatibility has no volumetric fog, so this is the localized layer on top of the
## global height fog that MapViewLighting.apply_ground_mist still draws at dawn.
##
## Patches drift on the shared CloudCells clock, so a save/load or a map swap shows the
## same fog pattern at the same simulated time.

const PUFF_SHADER := preload("res://scripts/map/view3d/local_fog_puff.gdshader")
const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const CELL_SIZE := 16.0
const SCAN_RADIUS_CELLS := 3
## Retain only a small halo, not every cell visited during seamless travel.
const CACHE_RADIUS_CELLS := SCAN_RADIUS_CELLS + 2
const POOL_SIZE := 14
const PUFFS_PER_BANK := 12
const PUFF_LIFETIME := 16.0
## Puff width in world units; the quad is PUFF_ASPECT as tall as it is wide.
const PUFF_WIDTH_MIN := 15.0
const PUFF_WIDTH_MAX := 26.0
const PUFF_ASPECT := 0.55
## A puff's centre rides this far above the ground; its foot fades out below that.
const PUFF_LIFT := 1.6
## Water within this many world units feeds fog; affinity falls off linearly to zero.
const WATER_REACH := 44.0
const PROBE_RINGS: Array[float] = [6.0, 18.0, 34.0]
const PROBE_DIRECTIONS := 8
## Cells whose water distance is measured per frame (each costs ~25 probes, cached).
const AFFINITY_CELLS_PER_FRAME := 3
const RESCAN_SECONDS := 0.5
const FADE_IN_PER_SECOND := 0.25
const FADE_OUT_PER_SECOND := 0.4
## Noise patches: lattice spacing in world units, drift in lattice units per simulated
## second. The threshold falls as the air gets damper, so heavy fog covers more shore.
const PATCH_LATTICE := 60.0
const PATCH_DRIFT_PER_SECOND := 0.012
const PATCH_THRESHOLD_DRY := 0.58
const PATCH_THRESHOLD_DAMP := 0.3
const PATCH_SOFTNESS := 0.22
## Below this strength a bank is hidden and may be handed to another cell.
const VISIBLE_STRENGTH := 0.015
const MAX_ALPHA := 0.9
## Cloud shadows draw at -100. Fog must follow them but precede screen-reading
## water: Compatibility loses opaque depth after the water back-buffer copy.
const FOG_RENDER_PRIORITY := -90
## Moonlight is a few percent of sunlight, and fog keeps it a faint cold rim.
const MOON_LIGHT_SCALE := 0.35
const MOON_COLOR := Color(0.62, 0.72, 0.95)
const SUN_COLOR := Color(1.0, 0.92, 0.78)
const NIGHT_AMBIENT_LEVEL := 0.12
const LIGHTNING_AMBIENT_GAIN := 1.2
## Perspective focus sits this far ahead of the camera along its heading, so a level
## (third/first person) view keeps the banks around the player instead of at the horizon.
const FOCUS_AHEAD := 20.0
const GROUP := &"local_fog_banks"


class Bank extends RefCounted:
	var emitter: GPUParticles3D
	var material: ShaderMaterial
	var cell := Vector2i(-2147483648, 0)
	var strength := 0.0
	var target := 0.0
	## No longer one of the best cells: fades out, then the slot is free for another.
	var released := false

	func assigned() -> bool:
		return cell.x != -2147483648


var _camera: Camera3D
## Callable(Vector2 view_xz) -> float: water surface height, NAN on dry land.
var _water_surface := Callable()
## Callable(Vector2 view_xz) -> float: terrain height, or an empty Callable for flat ground.
var _ground := Callable()
var _banks: Array[Bank] = []
var _process_material: ParticleProcessMaterial
var _affinity: Dictionary = {}
var _pending: Array[Vector2i] = []
var _density := 0.0
var _clock := 0.0
var _rescan_age := RESCAN_SECONDS
var _focus := Vector2.ZERO
var _active_limit := POOL_SIZE


## Damp, calm air is what holds fog. Dawn mist (date-based radiation fog) and the damp
## signals (overcast, rain, puddles) each count; wind disperses the damp share (the dawn
## share is already dispersed in ground_mist_amount). Hot sun burns the damp share off.
static func density_for(presentation: SkyWeather.WeatherPresentation) -> float:
	if presentation == null:
		return 0.0
	var quality := clampf(presentation.fog_quality, 0.0, 1.0)
	var dawn := Lighting.ground_mist_amount(presentation, false)
	var damp := Lighting.air_dampness(presentation)
	damp *= clampf(1.0 - presentation.wind_strength * 0.8, 0.0, 1.0)
	var burn := smoothstep(0.35, 0.85, presentation.sun_direction.y)
	damp *= 1.0 - 0.5 * burn * (1.0 - presentation.cloud_coverage)
	return clampf(maxf(dawn, damp * quality), 0.0, 1.0)


## 0..1 pull of the nearest water; `distance` is world units to the closest water probe.
static func affinity_for_distance(distance: float) -> float:
	return clampf(1.0 - distance / WATER_REACH, 0.0, 1.0)


## 0..1 drifting noise patch at a view XZ. Deterministic in (position, clock).
static func patch_at(view_xz: Vector2, clock: float) -> float:
	var p := view_xz / PATCH_LATTICE + Vector2(clock, clock * 0.6) * PATCH_DRIFT_PER_SECOND
	return clampf(_value_noise(p) * 0.65 + _value_noise(p * 2.3 + Vector2(7.1, 3.3)) * 0.35, 0.0, 1.0)


## Share of the density a cell keeps for its patch value: 0 outside the patch, 1 inside.
static func patch_mask(patch: float, density: float) -> float:
	var threshold := lerpf(PATCH_THRESHOLD_DRY, PATCH_THRESHOLD_DAMP, clampf(density, 0.0, 1.0))
	return smoothstep(threshold, threshold + PATCH_SOFTNESS, patch)


static func cell_target(density: float, affinity: float, patch: float) -> float:
	return clampf(density * affinity * patch_mask(patch, density), 0.0, 1.0)


## Light the fog wears, from the shared presentation: sun (or moon) side and colour,
## ambient hue from the horizon the dome draws, and a lightning flash lifting the lot.
static func light_params(presentation: SkyWeather.WeatherPresentation) -> Dictionary:
	var sun_light := (
		presentation.sun_visibility
		* presentation.sun_cloud_clear
		* clampf(presentation.sun_energy, 0.0, 1.0)
	)
	var moon_light := (
		presentation.lunar_light_strength
		* presentation.moon_cloud_clear
		* clampf(presentation.moon_direction.y * 4.0, 0.0, 1.0)
		* MOON_LIGHT_SCALE
	)
	var use_sun := sun_light >= moon_light
	var direction := presentation.sun_direction if use_sun else presentation.moon_direction
	var color := SUN_COLOR if use_sun else MOON_COLOR
	if use_sun and presentation.atmosphere_available:
		color = presentation.physical_sun_color.lerp(SUN_COLOR, 0.35)
	var ambient := Lighting.FOG_MORNING_COLOR
	if presentation.atmosphere_available:
		ambient = Lighting.physical_hue(presentation.horizon_display_color, ambient)
	var ambient_amount := lerpf(NIGHT_AMBIENT_LEVEL, 1.0, presentation.day_blend)
	ambient_amount *= lerpf(1.0, 0.8, presentation.overcast)
	ambient_amount += presentation.lightning * LIGHTNING_AMBIENT_GAIN
	return {
		"light_dir": direction.normalized(),
		"light_color": color,
		"light_amount": maxf(sun_light if use_sun else moon_light, 0.0),
		"ambient_color": ambient,
		"ambient_amount": ambient_amount,
	}


static func should_create(indoor: bool) -> bool:
	return not indoor


func configure(camera: Camera3D, water_surface: Callable, ground: Callable = Callable()) -> void:
	name = "LocalFogBanks"
	_camera = camera
	_water_surface = water_surface
	_ground = ground
	add_to_group(GROUP)
	_process_material = _build_process_material()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.0, PUFF_ASPECT)
	for i in POOL_SIZE:
		var bank := Bank.new()
		bank.material = ShaderMaterial.new()
		bank.material.shader = PUFF_SHADER
		bank.material.render_priority = FOG_RENDER_PRIORITY
		bank.material.set_shader_parameter(&"max_alpha", MAX_ALPHA)
		bank.emitter = _build_emitter(mesh, bank.material)
		add_child(bank.emitter)
		_banks.append(bank)


func _exit_tree() -> void:
	remove_from_group(GROUP)


func banks() -> Array[Bank]:
	return _banks


func visible_bank_count() -> int:
	var count := 0
	for bank in _banks:
		if bank.emitter.visible:
			count += 1
	return count


func _build_process_material() -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(CELL_SIZE * 0.5, 0.3, CELL_SIZE * 0.5)
	process.direction = Vector3.RIGHT
	process.spread = 25.0
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = 0.15
	process.initial_velocity_max = 0.5
	process.scale_min = PUFF_WIDTH_MIN
	process.scale_max = PUFF_WIDTH_MAX
	# Alpha envelope over a puff's life; the shader multiplies it into the density.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)
	])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	return process


func _build_emitter(mesh: Mesh, material: ShaderMaterial) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.name = "FogBank"
	emitter.amount = PUFFS_PER_BANK
	emitter.lifetime = PUFF_LIFETIME
	# Pre-run most of a life so a newly placed bank is already populated as it fades in.
	emitter.preprocess = PUFF_LIFETIME * 0.8
	# World-space puffs keep drifting on their own when the emitter is re-placed.
	emitter.local_coords = false
	emitter.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	emitter.visibility_aabb = AABB(Vector3(-44.0, -8.0, -44.0), Vector3(88.0, 20.0, 88.0))
	emitter.process_material = _process_material
	emitter.draw_pass_1 = mesh
	emitter.material_override = material
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.visible = false
	emitter.emitting = false
	return emitter


## `clock` is the simulated weather clock (SkyWeather3D.cloud_cell_clock) so patches
## repeat after a load. `enabled` is false in roofed rooms.
func update(
	delta: float, presentation: SkyWeather.WeatherPresentation, clock: float, enabled: bool = true
) -> void:
	if _camera == null or presentation == null or _banks.is_empty():
		return
	# Hosted neighbours each build a layer over the same camera; only the first draws.
	var first: Node = null
	for layer in get_tree().get_nodes_in_group(GROUP):
		if layer.get_viewport() == get_viewport():
			first = layer
			break
	_density = density_for(presentation) if enabled and first == self else 0.0
	_clock = clock
	_active_limit = clampi(
		roundi(POOL_SIZE * clampf(presentation.fog_quality, 0.0, 1.0)), 1, POOL_SIZE
	)
	if _density <= 0.005 and not _any_visible():
		return
	_rescan_age += delta
	if _rescan_age >= RESCAN_SECONDS:
		_rescan_age = 0.0
		_focus = _focus_point()
		_rescan()
	_measure_pending_cells()
	var light := light_params(presentation)
	var wind := presentation.wind_direction * presentation.wind_strength
	_process_material.direction = (
		Vector3(wind.x, 0.1, wind.y).normalized() if wind.length() > 0.05 else Vector3.UP * 0.2
	)
	_process_material.initial_velocity_min = 0.1 + wind.length() * 0.6
	_process_material.initial_velocity_max = 0.4 + wind.length() * 1.6
	for bank in _banks:
		_advance_bank(bank, delta, light)


func _any_visible() -> bool:
	for bank in _banks:
		if bank.strength > VISIBLE_STRENGTH:
			return true
	return false


## View-local XZ the banks gather around. The orthographic overview uses the exact point
## the view ray meets y = 0; a perspective camera uses a point FOCUS_AHEAD along its heading.
func _focus_point() -> Vector2:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		camera = _camera
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var hit := origin
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		if forward.y < -0.01:
			hit = origin + forward * (-origin.y / forward.y)
	else:
		var flat := Vector3(forward.x, 0.0, forward.z)
		if flat.length() > 0.01:
			hit = origin + flat.normalized() * FOCUS_AHEAD
	var local := to_local(hit)
	return Vector2(local.x, local.z)


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


func _cell_of(view_xz: Vector2) -> Vector2i:
	return Vector2i(floori(view_xz.x / CELL_SIZE), floori(view_xz.y / CELL_SIZE))


## Hands the best-scoring cells (affinity already measured) to emitters, keeping banks
## that are already showing a cell so they fade rather than jump.
func _rescan() -> void:
	var centre := _cell_of(_focus)
	_prune_probe_cache(centre)
	var scored: Array[Dictionary] = []
	var wanted: Dictionary = {}
	for dy in range(-SCAN_RADIUS_CELLS, SCAN_RADIUS_CELLS + 1):
		for dx in range(-SCAN_RADIUS_CELLS, SCAN_RADIUS_CELLS + 1):
			var cell := centre + Vector2i(dx, dy)
			if not _affinity.has(cell):
				if not _pending.has(cell):
					_pending.append(cell)
				continue
			var target := _cell_score(cell)
			if target > 0.03:
				# Nearer cells win the limited pool: fog in front of the player reads,
				# fog at the edge of the scan does not.
				var nearness := 1.0 - 0.5 * Vector2(dx, dy).length() / float(SCAN_RADIUS_CELLS)
				scored.append({"cell": cell, "target": target, "rank": target * nearness})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["rank"] > b["rank"])
	for i in mini(scored.size(), _active_limit):
		wanted[scored[i]["cell"]] = true
	# Nearest cells measure first so the view in front of the player fills in early.
	_pending.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (Vector2(a - centre)).length_squared() < (Vector2(b - centre)).length_squared()
	)
	var claimed: Dictionary = {}
	for bank in _banks:
		if bank.assigned():
			bank.released = not wanted.has(bank.cell)
			if not bank.released:
				claimed[bank.cell] = true
			elif bank.strength <= VISIBLE_STRENGTH:
				bank.cell = Vector2i(-2147483648, 0)
	for cell: Vector2i in wanted:
		if claimed.has(cell):
			continue
		for bank in _banks:
			if not bank.assigned():
				_assign(bank, cell)
				claimed[cell] = true
				break


## Evict travel history and queued probes outside the current camera halo. Otherwise
## a fixed emitter pool still grows memory without bound on a long seamless walk.
func _prune_probe_cache(centre: Vector2i) -> void:
	for cell: Vector2i in _affinity.keys():
		if not _within_cache(cell, centre):
			_affinity.erase(cell)
	for i in range(_pending.size() - 1, -1, -1):
		if not _within_cache(_pending[i], centre):
			_pending.remove_at(i)


static func _within_cache(cell: Vector2i, centre: Vector2i) -> bool:
	var offset := cell - centre
	return absi(offset.x) <= CACHE_RADIUS_CELLS and absi(offset.y) <= CACHE_RADIUS_CELLS


func _cell_score(cell: Vector2i) -> float:
	var centre := _cell_center(cell)
	return cell_target(_density, float(_affinity.get(cell, 0.0)), patch_at(centre, _clock))


func _measure_pending_cells() -> void:
	var budget := AFFINITY_CELLS_PER_FRAME
	while budget > 0 and not _pending.is_empty():
		var cell: Vector2i = _pending.pop_front()
		_affinity[cell] = affinity_for_distance(_water_distance(_cell_center(cell)))
		budget -= 1


## Distance from `view_xz` to the nearest water among the centre and PROBE_RINGS x
## PROBE_DIRECTIONS samples; WATER_REACH when none is wet. Measured once per cell.
func _water_distance(view_xz: Vector2) -> float:
	if not _water_surface.is_valid():
		return WATER_REACH
	if not is_nan(float(_water_surface.call(view_xz))):
		return 0.0
	for ring in PROBE_RINGS:
		for k in PROBE_DIRECTIONS:
			var angle := TAU * float(k) / float(PROBE_DIRECTIONS)
			var probe := view_xz + Vector2(cos(angle), sin(angle)) * ring
			if not is_nan(float(_water_surface.call(probe))):
				return ring
	return WATER_REACH


func _assign(bank: Bank, cell: Vector2i) -> void:
	bank.cell = cell
	bank.released = false
	bank.strength = 0.0
	var centre := _cell_center(cell)
	var base_y := 0.0
	if _ground.is_valid():
		base_y = float(_ground.call(centre))
	var surface := float(_water_surface.call(centre)) if _water_surface.is_valid() else NAN
	if not is_nan(surface):
		base_y = maxf(base_y, surface)
	bank.material.set_shader_parameter(&"ground_height", to_global(Vector3(0, base_y, 0)).y)
	bank.emitter.position = Vector3(centre.x, base_y + PUFF_LIFT, centre.y)
	bank.emitter.seed = int(_hash(cell) * 2147483647.0)
	bank.emitter.emitting = true
	bank.emitter.restart()


func _advance_bank(bank: Bank, delta: float, light: Dictionary) -> void:
	# Patches drift, so the target follows the live clock while the cell is held.
	bank.target = 0.0 if not bank.assigned() or bank.released else _cell_score(bank.cell)
	var rate := FADE_IN_PER_SECOND if bank.target > bank.strength else FADE_OUT_PER_SECOND
	bank.strength = move_toward(bank.strength, bank.target, rate * delta)
	var showing := bank.strength > VISIBLE_STRENGTH
	bank.emitter.visible = showing
	if not showing and bank.target <= VISIBLE_STRENGTH:
		bank.emitter.emitting = false
	elif showing:
		bank.emitter.emitting = true
	if not showing:
		return
	bank.emitter.amount_ratio = clampf(bank.strength * 1.4, 0.35, 1.0)
	var material := bank.material
	material.set_shader_parameter(&"bank_strength", bank.strength)
	for key: StringName in [
		&"light_dir", &"light_color", &"light_amount", &"ambient_color", &"ambient_amount"
	]:
		material.set_shader_parameter(key, light[String(key)])


static func _hash(cell: Vector2i) -> float:
	var h := sin(float(cell.x) * 127.1 + float(cell.y) * 311.7) * 43758.5453
	return h - floorf(h)


static func _value_noise(p: Vector2) -> float:
	var base := Vector2i(floori(p.x), floori(p.y))
	var f := p - Vector2(base)
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := lerpf(_hash(base), _hash(base + Vector2i(1, 0)), f.x)
	var b := lerpf(_hash(base + Vector2i(0, 1)), _hash(base + Vector2i(1, 1)), f.x)
	return lerpf(a, b, f.y)
