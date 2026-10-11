class_name CityLeafFall
extends GPUParticles3D

## ADR 0045: autumn leaf fall for the seamless city. One pooled GPUParticles3D
## (city_leaf_fall.gdshader). Every 0.3 s the trees around the player are read
## from CityTreeLod; each sheds in proportion to the leaves it still carries
## (VegetationPhenology) and the wind, so a bare tree drops nothing, a full
## crown in a gale drops a lot, and an October gust strips the crowns. Leaves
## ride the shared wind and vanish at the ground: nothing is left lying around.
## Presentation only: no state, no saving.

const TREE_SLOTS := 16
const SAMPLE_INTERVAL := 0.3
const NEAR_RADIUS := 36.0
const FADE_START := 12.0
const FADE_END := 34.0
const LEAF_LIFETIME := 10.0
const FALL_SPEED := 1.5
## Horizontal metres per second at wind strength 1 (SkyWeather3D.WIND_MS_AT_FULL).
const WIND_MS_AT_FULL := 16.0
const WIND_FOLLOW := 0.8
## Weather: a gale strips a leafed crown even in summer.
const STORM_SHED := 0.3

var tree_lod: Node
## 0..1 share of the particle budget currently shedding.
var shedding := 0.0
var _params: ShaderMaterial
var _timer := 0.0
var _crown_cache: Dictionary = {}
var _state_cache: Dictionary = {}
var _state_key := ""
## Horizontal look direction of the camera: trees in view shed more than those behind.
var _look := Vector2.ZERO


func configure(lod: Node, budget: int = 900) -> void:
	name = "CityLeafFall"
	tree_lod = lod
	amount = budget
	lifetime = LEAF_LIFETIME
	local_coords = false
	visibility_aabb = AABB(Vector3(-90.0, -40.0, -90.0), Vector3(180.0, 80.0, 180.0))
	_params = ShaderMaterial.new()
	_params.shader = preload("res://scripts/city/city_leaf_fall.gdshader")
	_params.set_shader_parameter("fall_speed", FALL_SPEED)
	process_material = _params
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	var leaf := _leaf_mesh()
	leaf.surface_set_material(0, material)
	draw_pass_1 = leaf
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitting = false
	visible = false


## Per-frame hook. `wind_direction` is the unit world x,z heading, `wind_strength` 0..1.
func update_leaves(
	focus: Vector3,
	date: Dictionary,
	wind_direction: Vector2,
	wind_strength: float,
	delta: float,
	look: Vector3 = Vector3.ZERO
) -> void:
	if tree_lod == null or _params == null:
		return
	var wind_ms := wind_direction * wind_strength * WIND_MS_AT_FULL * WIND_FOLLOW
	_params.set_shader_parameter("wind_velocity", Vector3(wind_ms.x, 0.0, wind_ms.y))
	global_position = focus
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SAMPLE_INTERVAL
	var flat := Vector2(look.x, look.z)
	_look = flat.normalized() if flat.length() > 0.01 else Vector2.ZERO
	_resample(focus, date, wind_strength)


## Weight of one tree: 0 bare, up to ~1.5 in an October gale. Pure, for tests.
static func shed_weight(species: StringName, date: Dictionary, wind_strength: float) -> float:
	var state := VegetationPhenology.state_for(species, date)
	var density := float(state["leaf_density"])
	if VegetationPhenology.is_evergreen(species) or density <= 0.02:
		return 0.0
	var storm := smoothstep(0.55, 0.9, wind_strength)
	return density * (float(state["fall_rate"]) * (0.4 + 1.4 * wind_strength) + STORM_SHED * storm)


func _resample(focus: Vector3, date: Dictionary, wind_strength: float) -> void:
	var key := GameCalendar.format_date(date)
	if key != _state_key:
		_state_key = key
		_state_cache.clear()
	var candidates: Array = []
	for tree: Array in tree_lod.call(&"trees_near", focus, NEAR_RADIUS):
		var species: StringName = tree[0]
		var origin: Vector3 = tree[1]
		var base := _species_weight(species, date, wind_strength)
		if base <= 0.0:
			continue
		var distance := Vector2(origin.x - focus.x, origin.z - focus.z).length()
		var weight := base * (1.0 - smoothstep(FADE_START, FADE_END, distance)) * float(tree[2])
		if _look != Vector2.ZERO and distance > 0.5:
			var facing := Vector2(origin.x - focus.x, origin.z - focus.z).normalized().dot(_look)
			weight *= lerpf(0.2, 1.0, smoothstep(-0.3, 0.5, facing))
		if weight > 0.001:
			candidates.append([weight, species, origin, float(tree[2])])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var count := mini(candidates.size(), TREE_SLOTS)
	var positions := PackedVector4Array()
	var colors := PackedVector4Array()
	var cumulative := PackedFloat32Array()
	positions.resize(TREE_SLOTS)
	colors.resize(TREE_SLOTS)
	cumulative.resize(TREE_SLOTS)
	var total := 0.0
	for i in count:
		total += float(candidates[i][0])
	var running := 0.0
	for i in count:
		var entry: Array = candidates[i]
		running += float(entry[0])
		var crown := _crown(entry[1])
		var scale: float = entry[3]
		var centre: Vector3 = entry[2] + Vector3.UP * float(crown["centre"]) * scale
		positions[i] = Vector4(centre.x, centre.y, centre.z, float(crown["radius"]) * scale)
		var palette := _palette(entry[1], date)
		var leaf: Color = palette[i % palette.size()]
		colors[i] = Vector4(leaf.r, leaf.g, leaf.b, (entry[2] as Vector3).y)
		cumulative[i] = running / total
	_params.set_shader_parameter("tree_pos", positions)
	_params.set_shader_parameter("tree_col", colors)
	_params.set_shader_parameter("tree_cum", cumulative)
	_params.set_shader_parameter("tree_count", count)
	shedding = clampf(total / 3.0, 0.0, 1.0)
	amount_ratio = maxf(shedding, 0.05)
	emitting = count > 0
	visible = count > 0


func _species_weight(species: StringName, date: Dictionary, wind_strength: float) -> float:
	return shed_weight(species, date, wind_strength)


func _palette(species: StringName, date: Dictionary) -> Array:
	var key := "%s:%s" % [species, _state_key]
	if not _state_cache.has(key):
		_state_cache[key] = VegetationPhenology.falling_leaf_colors(species, date)
	return _state_cache[key]


## Crown centre height and radius in model units, from the shared far crown.
func _crown(species: StringName) -> Dictionary:
	if not _crown_cache.has(species):
		var box := MapViewTreeMeshes.city_canopy_far_mesh(species).get_aabb()
		_crown_cache[species] = {
			"centre": box.position.y + box.size.y * 0.55,
			"radius": maxf(box.size.x, box.size.z) * 0.4,
		}
	return _crown_cache[species]


## A leaf: a flat diamond, double-sided material, white vertex colour.
static func _leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip_a := Vector3(0.0, 0.0, -0.5)
	var tip_b := Vector3(0.0, 0.0, 0.5)
	var left := Vector3(-0.3, 0.02, -0.05)
	var right := Vector3(0.3, 0.02, -0.05)
	for tri: Array in [[tip_a, right, left], [tip_b, left, right]]:
		for v: Vector3 in tri:
			st.set_color(Color.WHITE)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()
