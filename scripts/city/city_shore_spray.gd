extends Node3D

## Event-driven spray, splash and mist (WR-6, docs/SYSTEMS/CITY_SEA.md).
##
## WHY: spray that streams off the waterline all the time reads as floating cotton.
## Real spray is thrown when a wave breaks. Each slot sits where the analytic surf
## breaks (CityWaterSurface.bed_state, the CPU mirror of shore_state) and fires one
## burst when the crest passes (the wave phase u crosses 0), in three layers:
## dense velocity-stretched fine droplets, torn white-water clumps and a wind-blown
## spume puff. In a gale, gusts also tear spray off whitecaps offshore. Nothing is emitted
## below WIND_ON.
##
## Cost: a fixed handful of slots near the camera (re-placed when the camera moves
## REPLACE_DISTANCE), one bed_state call per slot per frame, no scan of the coast.
## Deterministic: the burst comes from the wave phase (a function of the ocean time
## and the position) and the particle seed from slot and event id.

const Surface := preload("res://scripts/city/city_water_surface.gd")
const SprayShader := preload("res://scripts/city/city_spray.gdshader")

## Contour is searched this far (world units) around the camera for slot spots.
const NEAR_RANGE := 50.0
const REPLACE_DISTANCE := 12.0
## Wind (0..1) at which spray starts and where it is at full strength.
const WIND_ON := 0.35
const WIND_FULL := 0.9
## Sea level for the emitters, world units; crests ride above it in a gale.
const WATERLINE_Y := 0.35
## Extra emitter height (m) at full wind. WHY: storm crests stand above sea level, so
## drops born at WATERLINE_Y start inside the wave and vanish before they are seen.
const CREST_LIFT := 0.45
## Offshore distances (world units) scanned for the breaker line when a slot is placed.
const SCAN_STEP := 3.0
const SCAN_STEPS := 14
## A slot only fires where the wave is at least this close to breaking.
const BREAK_MIN := 0.5
## Fallback spot offshore of the waterline when nothing breaks nearby.
const BREAK_OFFSET := 5.0
## Droplets per burst as a multiple of the tier budget. WHY: real spray is thousands
## of tiny drops; a few hundred 7 cm quads read as sparse confetti, so the
## drops are smaller and denser (they are tiny quads, cheap to fill).
const DROPLET_DENSITY := 2.5
## Mist and sheet budgets as a share of the tier budget (per burst, per slot).
const MIST_SHARE := 0.12
const SHEET_SHARE := 0.2
const MIN_SHEET := 8
## Offshore whitecap tearing: wind where it starts / is full (needs a gust at gale),
## crest period (s) of the tearing slots and how far offshore they sit.
const GALE_ON := 0.9
const GALE_FULL := 1.0
const GALE_PERIOD := 2.3
const GALE_OFFSET := Vector2(24.0, 60.0)

class Slot:
	extends RefCounted
	var spot := Vector2.ZERO
	var landward := Vector2.ZERO
	var active := false
	var breaking := 0.0
	var last_event := -2147483648
	var droplets: GPUParticles3D
	var mist: GPUParticles3D
	var sheet: GPUParticles3D

## Bursts fired since configure (tests, sandbox logs).
var bursts := 0
var _contour := PackedVector2Array()
var _plan: CityPlan
var _shore := {}
var _material: ShaderMaterial
var _layers: Node3D
var _slots: Array[Slot] = []
var _gale_slots: Array[Slot] = []
var _budget := 0
var _anchor := Vector2(1.0e9, 1.0e9)
var _wind := 0.0
var _intensity := 0.0
var _gale := 0.0
var _placed_intensity := -1.0
var _clock := 0.0
var _wind_direction := Vector2(1.0, 0.0)


## `shore` is the baked CityShoreField dictionary; the city world is the parent and
## exposes it as `sea_shore`, so callers that do not pass it still work.
func configure(plan: CityPlan, contour: PackedVector2Array, shore := {}) -> void:
	_plan = plan
	_contour = contour
	_shore = shore
	_layers = Node3D.new()
	_layers.name = "Layers"
	add_child(_layers)
	_apply_budget(int(_preset()["spray_particles"]))


## Wind strength 0..1 from the sky weather (gust included); below WIND_ON no spray.
func set_wind(wind: float) -> void:
	_wind = wind
	_intensity = smoothstep(WIND_ON, WIND_FULL, wind)
	_gale = smoothstep(GALE_ON, GALE_FULL, wind)
	var drift := _drift()
	# WHY low throw: shore spray hugs the breaking crest (tens of cm, about 1 m in a
	# gale); 9 m/s threw drops 4 m into the air, far from the water.
	var throw_min := lerpf(1.0, 2.0, _intensity)
	var throw_max := lerpf(2.2, 4.8, _intensity)
	for slot in _slots + _gale_slots:
		var material := slot.droplets.process_material as ParticleProcessMaterial
		material.initial_velocity_min = throw_min
		material.initial_velocity_max = throw_max
		(slot.mist.process_material as ParticleProcessMaterial).gravity = drift
	if _intensity <= 0.01:
		_stop(_slots + _gale_slots)


## Number of slots and the per-burst particle budgets for a tier's droplet budget.
static func slot_count(budget: int) -> int:
	return clampi(roundi(3.5 + float(budget) / 100.0), 4, 12)


static func gale_slot_count(budget: int) -> int:
	return maxi(slot_count(budget) / 2, 2)


static func droplet_budget(budget: int) -> int:
	return int(float(budget) * DROPLET_DENSITY)


static func mist_budget(budget: int) -> int:
	return maxi(int(float(budget) * MIST_SHARE), MIN_SHEET)


static func sheet_budget(budget: int) -> int:
	return maxi(int(float(budget) * SHEET_SHARE), MIN_SHEET)


## Worst case particles allocated at once for a tier (every slot alive).
static func particle_ceiling(budget: int) -> int:
	var per_slot := droplet_budget(budget) + mist_budget(budget) + sheet_budget(budget)
	var per_gale := droplet_budget(budget) + mist_budget(budget)
	return slot_count(budget) * per_slot + gale_slot_count(budget) * per_gale


## Id of the latest crest that has passed, given the wave cycle at the slot. A burst
## fires when it grows; the first sample only records the current crest.
static func crest_event(cycle: float, last: int) -> int:
	return maxi(floori(cycle), last)


static func fires(cycle: float, last: int) -> bool:
	return last != -2147483648 and floori(cycle) > last


## Share of the budget a burst uses: harder breaking and stronger wind throw more.
static func burst_ratio(breaking: float, intensity: float) -> float:
	return clampf(breaking * (0.35 + 0.65 * intensity), 0.1, 1.0)


## Fixed particle seed for one burst: same slot and crest, same droplets.
static func burst_seed(slot: int, event: int) -> int:
	var unit := fposmod(sin(float(slot) * 12.9898 + float(event) * 78.233) * 43758.5453, 1.0)
	return int(absf(unit) * 2147483.0) + 1


## Does the gale tear spray off this crest? Share rises with the gale level.
static func gale_tears(slot: int, event: int, gale: float) -> bool:
	var roll := fposmod(sin(float(slot) * 31.7 + float(event) * 5.13) * 24634.6345, 1.0)
	return roll < gale * 0.8


## Run the burst logic for the current ocean time; returns the bursts fired.
## Called every frame by _process; public so tests and tools can step it.
func update_events(time: float) -> int:
	_ensure_material()
	if _intensity <= 0.01 or _material == null or _shore.is_empty():
		return 0
	var before := bursts
	for index in _slots.size():
		var slot := _slots[index]
		if not slot.active:
			continue
		var state := Surface.bed_state(_shore, slot.spot, time, _material)
		var cycle: float = state["cycle"]
		if fires(cycle, slot.last_event):
			_fire(slot, index, floori(cycle), burst_ratio(slot.breaking, _intensity), true)
		slot.last_event = crest_event(cycle, slot.last_event)
	# Whitecaps offshore: shorter crest period, only under a gale gust.
	for index in _gale_slots.size():
		var slot := _gale_slots[index]
		if not slot.active:
			continue
		var cycle := time / GALE_PERIOD + float(index) * 0.37
		var tears := fires(cycle, slot.last_event) and gale_tears(index, floori(cycle), _gale)
		if tears:
			_fire(slot, 100 + index, floori(cycle), clampf(0.3 + _gale * 0.7, 0.1, 1.0), false)
		slot.last_event = crest_event(cycle, slot.last_event)
	return bursts - before


func _process(delta: float) -> void:
	if _plan == null or _contour.is_empty() or _intensity <= 0.01:
		return
	_clock += delta
	if _clock >= 0.5:
		_clock = 0.0
		_refresh()
	update_events(OceanFftSampler.ocean_time())


func _refresh() -> void:
	var preset_budget := int(_preset()["spray_particles"])
	if preset_budget != _budget:
		_apply_budget(preset_budget)
	var direction := WindField.current().direction
	if direction.distance_to(_wind_direction) > 0.05:
		_wind_direction = direction
		set_wind(_wind)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := Vector2(camera.global_position.x, camera.global_position.z)
	# The breaker line moves with the sea state, so re-place when it changed a lot too.
	if at.distance_to(_anchor) < REPLACE_DISTANCE and absf(_intensity - _placed_intensity) < 0.2:
		return
	_anchor = at
	_placed_intensity = _intensity
	place_slots(at)


## Pick slot spots on the contour near `at` and slide each offshore to where the
## surf breaks hardest (scanned once here, not per frame).
func place_slots(at: Vector2) -> void:
	_ensure_material()
	var near := PackedVector2Array()
	for point in _contour:
		if point.distance_squared_to(at) < NEAR_RANGE * NEAR_RANGE:
			near.append(point)
	var time := OceanFftSampler.ocean_time()
	for index in _slots.size():
		var slot := _slots[index]
		slot.active = false
		if near.is_empty() or _material == null or _shore.is_empty():
			continue
		var point := near[(index * near.size()) / _slots.size()]
		slot.landward = _landward(point)
		var best := -1.0
		var best_spot := point - slot.landward * BREAK_OFFSET
		for step in SCAN_STEPS:
			var spot := point - slot.landward * (float(step) * SCAN_STEP)
			var state := Surface.bed_state(_shore, spot, time, _material)
			var score: float = float(state["breaking"]) * float(state["valid"])
			if score > best + 0.02:
				best = score
				best_spot = spot
		slot.breaking = best
		slot.spot = best_spot
		slot.active = best >= BREAK_MIN
		slot.last_event = -2147483648
		_aim(slot, slot.spot, WATERLINE_Y + CREST_LIFT * _intensity)
	for index in _gale_slots.size():
		var slot := _gale_slots[index]
		slot.active = not near.is_empty()
		if near.is_empty():
			continue
		var point := near[(index * 7 + 3) % near.size()]
		slot.landward = _landward(point)
		var out := lerpf(GALE_OFFSET.x, GALE_OFFSET.y, fposmod(float(index) * 0.618, 1.0))
		slot.spot = point - slot.landward * out
		slot.last_event = -2147483648
		_aim(slot, slot.spot, WATERLINE_Y + 0.3)


func _ensure_material() -> void:
	if _material == null:
		_material = MapViewMaterials.water_surface(MapTypes.TERRAIN_SHALLOW_WATER)
	if _shore.is_empty() and get_parent() != null:
		var shore: Variant = get_parent().get("sea_shore")
		if shore is Dictionary:
			_shore = shore


func _landward(point: Vector2) -> Vector2:
	# Uphill is landward.
	var uphill := Vector2(
		_plan.ground_height(point + Vector2(1.0, 0.0)) - _plan.ground_height(point - Vector2(1.0, 0.0)),
		_plan.ground_height(point + Vector2(0.0, 1.0)) - _plan.ground_height(point - Vector2(0.0, 1.0))
	)
	return uphill.normalized() if uphill.length() > 0.0001 else Vector2.ZERO


func _aim(slot: Slot, spot: Vector2, y: float) -> void:
	for layer in [slot.droplets, slot.mist, slot.sheet]:
		if layer == null:
			continue
		(layer as GPUParticles3D).position = Vector3(spot.x, y, spot.y)
	# A little drift landward so droplets fall on the sand, not back into the sea.
	var direction := Vector3(slot.landward.x * 0.5, 1.0, slot.landward.y * 0.5).normalized()
	(slot.droplets.process_material as ParticleProcessMaterial).direction = direction
	if slot.sheet != null:
		(slot.sheet.process_material as ParticleProcessMaterial).direction = direction


func _fire(slot: Slot, index: int, event: int, ratio: float, with_sheet: bool) -> void:
	bursts += 1
	var seed_value := burst_seed(index, event)
	for layer in [slot.droplets, slot.mist, slot.sheet if with_sheet else null]:
		if layer == null:
			continue
		var particles := layer as GPUParticles3D
		particles.use_fixed_seed = true
		particles.seed = seed_value
		particles.amount_ratio = ratio
		particles.restart(true)


func _stop(slots: Array) -> void:
	for slot: Slot in slots:
		for layer in [slot.droplets, slot.mist, slot.sheet]:
			if layer != null:
				(layer as GPUParticles3D).emitting = false


func _drift() -> Vector3:
	# Mist is blown downwind and settles; stronger wind carries it faster.
	var carry := lerpf(1.5, 5.0, _intensity)
	return Vector3(_wind_direction.x * carry, -0.3, _wind_direction.y * carry)


func _preset() -> Dictionary:
	return MapViewMaterials.WATER_MATERIALS.sea_lod_preset()


## (Re)build every slot emitter for a droplet budget per burst.
func _apply_budget(budget: int) -> void:
	_budget = budget
	for child in _layers.get_children():
		child.queue_free()
		_layers.remove_child(child)
	_slots.clear()
	_gale_slots.clear()
	for index in slot_count(budget):
		_slots.append(_make_slot(budget, true))
	for index in gale_slot_count(budget):
		_gale_slots.append(_make_slot(budget, false))
	_placed_intensity = -1.0
	_anchor = Vector2(1.0e9, 1.0e9)
	set_wind(_wind)


func _make_slot(budget: int, with_sheet: bool) -> Slot:
	var slot := Slot.new()
	slot.droplets = _make_droplets(droplet_budget(budget))
	slot.mist = _make_mist(mist_budget(budget))
	_layers.add_child(slot.droplets)
	_layers.add_child(slot.mist)
	if with_sheet:
		slot.sheet = _make_sheet(sheet_budget(budget))
		_layers.add_child(slot.sheet)
	return slot


static func _base(amount: int, lifetime: float, aabb: AABB) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.emitting = false
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = aabb
	return particles


static func _ramp(points: Array) -> GradientTexture1D:
	# points: [offset, alpha] pairs, ascending; colour stays white (the shader tints).
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for point: Array in points:
		offsets.append(float(point[0]))
		colors.append(Color(1.0, 1.0, 1.0, float(point[1])))
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _grow(from: float, to: float) -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, from))
	curve.add_point(Vector2(1.0, to))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func _quad(
	size: float, stretch: float, decay: float, aligned: bool, softness: float, ragged: float
) -> QuadMesh:
	var material := ShaderMaterial.new()
	material.shader = SprayShader
	material.set_shader_parameter("stretch", stretch)
	material.set_shader_parameter("stretch_decay", decay)
	material.set_shader_parameter("velocity_aligned", 1.0 if aligned else 0.0)
	material.set_shader_parameter("softness", softness)
	material.set_shader_parameter("ragged", ragged)
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material
	return quad


## Layer 1: fine droplets (1-3 cm quads), streaked along their velocity while fast, thrown
## low over the crest.
static func _make_droplets(budget: int) -> GPUParticles3D:
	var particles := _base(budget, 0.9, AABB(Vector3(-12, -2, -12), Vector3(24, 6, 24)))
	particles.explosiveness = 0.8
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# Along the crest line, thin across it.
	material.emission_box_extents = Vector3(3.5, 0.08, 3.5)
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 50.0
	material.initial_velocity_min = 0.8
	material.initial_velocity_max = 1.8
	material.gravity = Vector3(0.0, -9.8, 0.0)
	material.damping_min = 0.3
	material.damping_max = 0.9
	material.scale_min = 0.4
	material.scale_max = 1.3
	material.particle_flag_align_y = true
	material.color_ramp = _ramp([[0.0, 0.0], [0.04, 0.95], [0.6, 0.75], [1.0, 0.0]])
	particles.process_material = material
	particles.draw_pass_1 = _quad(0.022, 5.0, 2.0, true, 0.5, 0.0)
	return particles


## Layer 2: a short-lived splash sheet that opens and tears at the break.
static func _make_sheet(budget: int) -> GPUParticles3D:
	var particles := _base(budget, 0.45, AABB(Vector3(-10, -1, -10), Vector3(20, 8, 20)))
	particles.explosiveness = 1.0
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(3.0, 0.1, 3.0)
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 55.0
	material.initial_velocity_min = 0.8
	material.initial_velocity_max = 2.4
	material.gravity = Vector3(0.0, -5.0, 0.0)
	material.scale_min = 0.5
	material.scale_max = 1.0
	material.scale_curve = _grow(0.5, 1.4)
	# WHY faint and hard-edged: a bright soft 1 m disc read as steam, not torn water.
	material.color_ramp = _ramp([[0.0, 0.0], [0.12, 0.35], [1.0, 0.0]])
	particles.process_material = material
	particles.draw_pass_1 = _quad(0.28, 1.0, 0.0, false, 0.6, 1.0)
	return particles


## Layer 3: spume puff. WHY: a slow 3 s cloud read as fog; real breaker spume is
## blown out fast, brakes hard in the air and is gone in about a second.
static func _make_mist(budget: int) -> GPUParticles3D:
	var particles := _base(budget, 1.3, AABB(Vector3(-16, -2, -16), Vector3(32, 6, 32)))
	particles.explosiveness = 0.9
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(3.5, 0.05, 3.5)
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 75.0
	material.initial_velocity_min = 1.5
	material.initial_velocity_max = 3.5
	# Overwritten by set_wind with the downwind drift.
	material.gravity = Vector3(1.5, -0.3, 0.0)
	material.damping_min = 2.5
	material.damping_max = 4.0
	material.scale_min = 0.4
	material.scale_max = 0.9
	material.scale_curve = _grow(0.4, 1.6)
	material.color_ramp = _ramp([[0.0, 0.0], [0.08, 0.16], [0.4, 0.07], [1.0, 0.0]])
	particles.process_material = material
	particles.draw_pass_1 = _quad(1.0, 1.0, 0.0, false, 1.0, 0.0)
	return particles
