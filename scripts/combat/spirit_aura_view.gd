class_name SpiritAuraView
extends Node3D
## SS-3 (ADR 0041): one being's aura in spirit sight. Seven soul lights sit on
## bone anchors (SharedCharacterRig.SPIRIT_AURA_ANCHORS) or, for a body without
## the shared rig (animals), on a layout fitted to its mesh bounds. Three draw
## calls: field-line ribbons, the fresnel shell and the lights. The meshes are
## shared, built once and never rebuilt; each frame only the anchor uniforms
## move. SpiritAuraManager owns tiers and visibility.

enum Tier { NONE, GLOW, FULL }

const FLOW_SHADER := preload("res://scripts/combat/spirit_aura_flow.gdshader")
const LIGHT_SHADER := preload("res://scripts/combat/spirit_aura_light.gdshader")
## ADR 0041 colour table in NATURAL aspect order; the shaders mirror it. Colour
## is never the only cue: each light keeps its fixed place on the body.
const COLORS: Array[Color] = [
	Color(0.95, 0.16, 0.12), Color(1.0, 0.52, 0.10), Color(1.0, 0.86, 0.18),
	Color(0.25, 0.92, 0.36), Color(0.22, 0.52, 1.0), Color(0.40, 0.30, 0.95),
	Color(0.78, 0.38, 1.0),
]
## Light brightness by level 0..5 (0 closed knot .. 5 blazing); drives the
## distant glow and the ribbon strength.
const LEVEL_INTENSITY: Array[float] = [0.1, 0.3, 0.5, 0.7, 0.85, 1.0]
const RIBBON_LINES := 12
const RIBBON_SEGMENTS := 72
const SHELL_RINGS := 18
const SHELL_SIDES := 20
## Reduced flashing keeps this share of the shimmer and the breathing pulse.
const REDUCED_FLASHING_SHARE := 0.15
## Bounds for culling: the loops reach about spread * 1.2 m from the axis; the
## sky beam rises up to SKY_BEAM_MAX_HEIGHT above the crown.
const LOCAL_AABB := AABB(Vector3(-1.5, -0.8, -1.5), Vector3(3.0, 14.0, 3.0))
const SKY_BEAM_MAX_HEIGHT := 12.0
const MAX_LEVEL_SUM := 35.0
## Half the root-to-crown span of an adult on the shared rig; body_scale is
## measured against it so a dog's aura is dog-sized.
const ADULT_HALF_SPAN := 0.67
## SS-5 duel feedback: a landed word dims its light, then it recovers; falling pressure
## lowers clarity down to this share; a break shatters the aura over SHATTER_SEC.
const DIM_DEPTH := 0.7
const DIM_RECOVER_PER_SEC := 1.2
const PRESSURE_CLARITY_FLOOR := 0.35
const SHATTER_SEC := 0.8

static var _ribbon_mesh: ArrayMesh
static var _shell_mesh: ArrayMesh
static var _light_mesh: ArrayMesh

var body: Node3D
var profile: SpiritAuraProfile
var tier: Tier = Tier.NONE
var fade := 1.0
var reduced_flashing := false
## Bodies without the shared rig (animals) lack the lights their species does
## not have: a level-0 light is absent there, not a closed knot.
var closed_as_absent := false
var body_scale := 1.0
## World-space anchor points from the last update, NATURAL aspect order.
var anchors := PackedVector3Array()

## 0 untouched .. 1 fully dimmed, per light; decays back to 0.
var light_dim := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
## Opponent pressure left, 0..1; scales clarity so a beaten soul turns choppy.
var pressure_fraction := 1.0
## 0 whole .. 1 shattered (the aura of a broken opponent, mirrors SpiritFormView's crack).
var shatter := 0.0
var _shattering := false
var _duel: SpiritDuel
var _rig_bones: Array[Vector2i] = []
var _fallback_local := PackedVector3Array()
var _flow_material := ShaderMaterial.new()
var _shell_material := ShaderMaterial.new()
var _light_material := ShaderMaterial.new()
var _ribbons := MeshInstance3D.new()
var _shell := MeshInstance3D.new()
var _lights := MeshInstance3D.new()


func _init() -> void:
	name = "SpiritAura"
	# Uniform anchors live in world space; an identity basis keeps model space
	# equal to world space in the shaders whatever the body's scale or yaw.
	top_level = true
	anchors.resize(7)
	_flow_material.shader = FLOW_SHADER
	_shell_material.shader = FLOW_SHADER
	_shell_material.set_shader_parameter(&"shell_mode", true)
	_light_material.shader = LIGHT_SHADER
	for instance: MeshInstance3D in [_ribbons, _shell, _lights]:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.custom_aabb = LOCAL_AABB
		add_child(instance)
	_ribbons.name = "FieldLines"
	_ribbons.mesh = ribbon_mesh()
	_ribbons.material_override = _flow_material
	_shell.name = "Shell"
	_shell.mesh = shell_mesh()
	_shell.material_override = _shell_material
	_lights.name = "Lights"
	_lights.mesh = light_mesh()
	_lights.material_override = _light_material
	set_tier(Tier.NONE)


## Attach to a body and show `aura`. The view is a child of the body so it
## lives in the body's 3D world and is freed with it.
func bind(target: Node3D, aura: SpiritAuraProfile) -> void:
	body = target
	_resolve_anchor_source()
	closed_as_absent = _rig_bones.is_empty()
	update_anchors()
	# Measured once at bind: per-frame scale would breathe with the animation.
	body_scale = clampf(anchors[0].distance_to(anchors[6]) * 0.5 / ADULT_HALF_SPAN, 0.35, 1.6)
	for material: ShaderMaterial in [_flow_material, _shell_material, _light_material]:
		material.set_shader_parameter(&"body_scale", body_scale)
	set_profile(aura)


func set_profile(aura: SpiritAuraProfile) -> void:
	profile = aura
	var weighted := Color(0, 0, 0, 0)
	var weight := 0.0
	for i in SpiritAuraProfile.LIGHT_IDS.size():
		var level := level_at(i)
		weighted += COLORS[i] * LEVEL_INTENSITY[level]
		weight += LEVEL_INTENSITY[level]
	var mean := mean_level()
	var glow_color := weighted / maxf(weight, 0.001)
	var glow_rgb := Vector3(glow_color.r, glow_color.g, glow_color.b)
	_push_levels()
	_flow_material.set_shader_parameter(&"flow_speed", flow_speed_for(mean))
	_flow_material.set_shader_parameter(&"spread", 0.38 + 0.05 * mean)
	_flow_material.set_shader_parameter(&"turbulence", turbulence())
	_shell_material.set_shader_parameter(&"shell_color", glow_rgb)
	_shell_material.set_shader_parameter(&"shell_strength", 0.08 + 0.04 * mean)
	_light_material.set_shader_parameter(&"glow_color", glow_rgb)
	_light_material.set_shader_parameter(&"glow_strength", 0.25 + 0.5 * mean / 5.0)
	_light_material.set_shader_parameter(&"beam_strength", sky_beam_strength())
	_light_material.set_shader_parameter(&"turbulence", turbulence())
	_apply_motion_settings()


## Levels as the shaders see them: the dim and the shatter lower a light below its level (the
## shaders take float levels), an absent light stays absent.
func _push_levels() -> void:
	var levels := PackedFloat32Array()
	for i in SpiritAuraProfile.LIGHT_IDS.size():
		var level := level_at(i)
		if closed_as_absent and level == 0:
			levels.append(-1.0)
		else:
			levels.append(float(level) * (1.0 - DIM_DEPTH * light_dim[i]) * (1.0 - shatter))
	for material: ShaderMaterial in [_flow_material, _shell_material, _light_material]:
		material.set_shader_parameter(&"levels", levels)


## A word landed on `light_id`: the light dims at once (`strength` 0..1) and recovers.
func dim_light(light_id: StringName, strength: float = 1.0) -> void:
	var index := SpiritAuraProfile.LIGHT_IDS.find(light_id)
	if index < 0 or _shattering:
		return
	light_dim[index] = clampf(maxf(light_dim[index], strength), 0.0, 1.0)
	_push_levels()


## Opponent pressure left as a share of its pool: less pressure, less clarity.
func set_pressure_fraction(value: float) -> void:
	pressure_fraction = clampf(value, 0.0, 1.0)
	var turb := turbulence()
	_flow_material.set_shader_parameter(&"turbulence", turb)
	_light_material.set_shader_parameter(&"turbulence", turb)


## The break: the aura collapses into smoke and goes dark (reduced flashing: no sudden flare).
func shatter_now() -> void:
	_shattering = true


## Follow a duel: its exchanges dim the hit light and drain clarity, a broken opponent shatters.
func bind_duel(duel: SpiritDuel) -> void:
	unbind_duel()
	_duel = duel
	duel.exchange_resolved.connect(_on_exchange)
	duel.finished.connect(_on_duel_finished)
	pressure_fraction = 1.0


func unbind_duel() -> void:
	if _duel != null:
		if _duel.exchange_resolved.is_connected(_on_exchange):
			_duel.exchange_resolved.disconnect(_on_exchange)
		if _duel.finished.is_connected(_on_duel_finished):
			_duel.finished.disconnect(_on_duel_finished)
	_duel = null


func _on_exchange(result: Dictionary) -> void:
	var kind := String(result.get("kind", ""))
	if (kind == "reply" or kind == "word") and float(result.get("damage", 0.0)) > 0.0:
		dim_light(StringName(String(result.get("light_id", ""))))
	if _duel != null and _duel.opponent.max_health > 0.0:
		set_pressure_fraction(_duel.opponent.health / _duel.opponent.max_health)


func _on_duel_finished(outcome: Dictionary) -> void:
	if bool(outcome.get("broken", false)) and String(outcome.get("result", "")) == "won":
		shatter_now()


func _tick_duel_feedback(delta: float) -> void:
	var changed := false
	for i in light_dim.size():
		if light_dim[i] > 0.0:
			light_dim[i] = maxf(0.0, light_dim[i] - DIM_RECOVER_PER_SEC * delta)
			changed = true
	if _shattering and shatter < 1.0:
		shatter = minf(1.0, shatter + delta / SHATTER_SEC)
		changed = true
	if changed:
		_push_levels()
		if _shattering:
			set_pressure_fraction(pressure_fraction)


func set_tier(next: Tier) -> void:
	tier = next
	visible = tier != Tier.NONE
	_ribbons.visible = tier == Tier.FULL
	_shell.visible = tier == Tier.FULL
	_lights.visible = tier != Tier.NONE
	_light_material.set_shader_parameter(&"glow_only", tier == Tier.GLOW)
	set_process(tier != Tier.NONE)


func set_fade(value: float) -> void:
	fade = clampf(value, 0.0, 1.0)
	for material: ShaderMaterial in [_flow_material, _shell_material, _light_material]:
		material.set_shader_parameter(&"fade", fade)


func set_reduced_flashing(enabled: bool) -> void:
	if reduced_flashing == enabled:
		return
	reduced_flashing = enabled
	_apply_motion_settings()


func level_at(index: int) -> int:
	if profile == null:
		return 1
	return clampi(int(profile.levels.get(SpiritAuraProfile.LIGHT_IDS[index], 1)), 0, 5)


func mean_level() -> float:
	var total := 0
	for i in SpiritAuraProfile.LIGHT_IDS.size():
		total += level_at(i)
	return float(total) / float(SpiritAuraProfile.LIGHT_IDS.size())


func intensity_at(index: int) -> float:
	return LEVEL_INTENSITY[level_at(index)]


## 1 - clarity: 0 calm and clean, 1 choppy with smoke streaks.
func turbulence() -> float:
	return lerpf(1.0 - effective_clarity(), 1.0, shatter)


## Profile clarity scaled by the duel pressure left; the profile alone outside a duel.
func effective_clarity() -> float:
	var base := clampf(profile.clarity if profile != null else 1.0, 0.0, 1.0)
	return base * lerpf(PRESSURE_CLARITY_FLOOR, 1.0, pressure_fraction)


## The tie to the sky (maintainer request, 2026-10-09): a column of light rising
## from the crown. The sum of all seven levels sets its strength, gated by the
## crown light itself: a closed or absent crown has no beam, a whole soul at 5
## burns a full one. Strength, not virtue: no morality score is read from it.
func sky_beam_strength() -> float:
	var crown := level_at(6)
	if crown <= 0:
		return 0.0
	var total := 0
	for i in SpiritAuraProfile.LIGHT_IDS.size():
		total += level_at(i)
	return clampf(float(total) / MAX_LEVEL_SUM * (0.4 + 0.6 * float(crown) / 5.0), 0.0, 1.0)


static func flow_speed_for(mean: float) -> float:
	return 0.12 + 0.05 * mean


func shader_value(param: StringName) -> Variant:
	if param in [&"glow_only", &"glow_strength", &"calm", &"beam_strength"]:
		return _light_material.get_shader_parameter(param)
	return _flow_material.get_shader_parameter(param)


func _process(delta: float) -> void:
	update_anchors()
	_tick_duel_feedback(delta)


func update_anchors() -> void:
	if not is_instance_valid(body) or not body.is_inside_tree():
		return
	var skeleton := _rig_skeleton()
	if skeleton != null:
		var to_world := skeleton.global_transform
		var forward := _facing()
		for i in _rig_bones.size():
			var spec: Dictionary = SharedCharacterRig.SPIRIT_AURA_ANCHORS[i]
			var from := to_world * skeleton.get_bone_global_pose(_rig_bones[i].x).origin
			var to := to_world * skeleton.get_bone_global_pose(_rig_bones[i].y).origin
			anchors[i] = from.lerp(to, float(spec["t"])) + forward * float(spec["forward"])
	else:
		var xf := body.global_transform
		for i in _fallback_local.size():
			anchors[i] = xf * _fallback_local[i]
	# Anchors are passed relative to the root light so float precision holds far
	# from the world origin.
	global_transform = Transform3D(Basis(), anchors[0])
	var relative := PackedVector3Array()
	for point in anchors:
		relative.append(point - anchors[0])
	var facing := _facing()
	for material: ShaderMaterial in [_flow_material, _shell_material, _light_material]:
		material.set_shader_parameter(&"anchors", relative)
		material.set_shader_parameter(&"facing", facing)


func _apply_motion_settings() -> void:
	var share := REDUCED_FLASHING_SHARE if reduced_flashing else 1.0
	_flow_material.set_shader_parameter(&"shimmer", 0.04 * mean_level() * share)
	_light_material.set_shader_parameter(&"calm", 1.0 - share)


func _rig_skeleton() -> Skeleton3D:
	if _rig_bones.is_empty() or not body is SharedCharacterRig:
		return null
	return (body as SharedCharacterRig).skeleton()


func _facing() -> Vector3:
	var forward := body.global_basis.z if is_instance_valid(body) else Vector3.BACK
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.001 else Vector3.BACK


func _resolve_anchor_source() -> void:
	_rig_bones.clear()
	if body is SharedCharacterRig:
		var skeleton := (body as SharedCharacterRig).skeleton()
		if skeleton != null:
			for spec: Dictionary in SharedCharacterRig.SPIRIT_AURA_ANCHORS:
				var from := skeleton.find_bone(String(spec["from"]))
				var to := skeleton.find_bone(String(spec["to"]))
				if from < 0 or to < 0:
					_rig_bones.clear()
					break
				_rig_bones.append(Vector2i(from, to))
	if _rig_bones.is_empty():
		_fallback_local = fallback_layout(_mesh_bounds(body))


## Anchors for a body without the shared rig, in its local space: lights along
## the back from the hindquarters (nature) to the head (awareness), the last
## light above the head. Animal models face -Z (MapViewMedievalAnimalModels
## turns them to Godot forward), unlike the shared rig which faces +Z.
static func fallback_layout(bounds: AABB) -> PackedVector3Array:
	var size := bounds.size
	var low := bounds.position
	if size.length() < 0.01:
		size = Vector3(0.4, 0.6, 0.8)
		low = Vector3(-0.2, 0.0, -0.4)
	var points := PackedVector3Array()
	var spine_y := low.y + size.y * 0.62
	var center_x := low.x + size.x * 0.5
	for i in 6:
		var along := lerpf(0.15, 0.92, float(i) / 5.0)
		var lift := size.y * 0.25 * smoothstep(0.6, 1.0, along)
		points.append(Vector3(center_x, spine_y + lift, low.z + size.z * (1.0 - along)))
	points.append(Vector3(center_x, low.y + size.y * 1.3, low.z + size.z * 0.15))
	return points


static func _mesh_bounds(root: Node3D) -> AABB:
	var merged := AABB()
	var first := true
	if root == null:
		return merged
	var to_local := root.global_transform.affine_inverse()
	for found: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.get_parent() is SpiritAuraView:
			continue
		var box := (to_local * mesh_instance.global_transform) * mesh_instance.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	return merged


## RIBBON_LINES closed strips; each vertex carries its loop position (UV.x),
## side (UV.y), line angle and width scale (UV2). Positions are placeholders:
## the vertex shader places everything.
static func ribbon_mesh() -> ArrayMesh:
	if _ribbon_mesh != null:
		return _ribbon_mesh
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	for line in RIBBON_LINES:
		var phi := (float(line) + 0.5) / float(RIBBON_LINES)
		# Alternate inner and outer loops so the field reads as nested shells.
		var width := 0.7 + 0.5 * float(line % 3) / 2.0
		var base := vertices.size()
		for segment in RIBBON_SEGMENTS + 1:
			var s := float(segment) / float(RIBBON_SEGMENTS)
			for side: float in [-1.0, 1.0]:
				vertices.append(Vector3.ZERO)
				uvs.append(Vector2(s, side))
				uv2s.append(Vector2(phi, width))
		for segment in RIBBON_SEGMENTS:
			var a := base + segment * 2
			indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	_ribbon_mesh = _array_mesh(vertices, uvs, uv2s, indices)
	return _ribbon_mesh


static func shell_mesh() -> ArrayMesh:
	if _shell_mesh != null:
		return _shell_mesh
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	for ring in SHELL_RINGS + 1:
		for side in SHELL_SIDES + 1:
			vertices.append(Vector3.ZERO)
			uvs.append(Vector2(float(side) / SHELL_SIDES, float(ring) / SHELL_RINGS))
			uv2s.append(Vector2.ZERO)
	for ring in SHELL_RINGS:
		for side in SHELL_SIDES:
			var a := ring * (SHELL_SIDES + 1) + side
			var b := a + SHELL_SIDES + 1
			indices.append_array([a, b, a + 1, a + 1, b, b + 1])
	_shell_mesh = _array_mesh(vertices, uvs, uv2s, indices)
	return _shell_mesh


static func light_mesh() -> ArrayMesh:
	if _light_mesh != null:
		return _light_mesh
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	# Quads 0..6 are the lights; quad 7 is the sky beam above the crown.
	for light in 8:
		var base := vertices.size()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			vertices.append(Vector3.ZERO)
			uvs.append(corner)
			uv2s.append(Vector2(light, 0))
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	_light_mesh = _array_mesh(vertices, uvs, uv2s, indices)
	return _light_mesh


static func _array_mesh(
	vertices: PackedVector3Array, uvs: PackedVector2Array, uv2s: PackedVector2Array,
	indices: PackedInt32Array
) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
