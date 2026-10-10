extends RefCounted

## A procedural winter-wheat plant for the fields (docs/SYSTEMS/FARMLAND.md,
## Wheat): one crown of TILLERS culms, each with a jointed stem, arching leaf
## blades that droop at the tip, an upright flag leaf, and a two-row ear of
## spikelets with short awns (bearded wheat). The field ripens plant by plant, so
## there is one cached mesh per stage and a field mixes them:
##
## - green: upright ears, every leaf alive.
## - turning: ears start to nod, the lowest leaf dies back.
## - ripe: heavy nodding ears, lower leaves dead and curled.
## - stubble: the cut stalks left after harvest (built at real height).
##
## Vertex colours carry only part-relative tone (ear against leaf, dead leaf
## against live one). The stage hue comes from the MultiMesh instance colour
## (`tint`): vertex colours are 8-bit, and a gold ear needs a multiplier well
## above 1 against the grass shader's green base colour.

const MeshMath := preload("res://scripts/map/view3d/map_view_mesh_builder_math.gd")

const STAGE_GREEN := &"green"
const STAGE_TURNING := &"turning"
const STAGE_RIPE := &"ripe"
const STAGE_STUBBLE := &"stubble"
const STAGES: Array[StringName] = [STAGE_GREEN, STAGE_TURNING, STAGE_RIPE, STAGE_STUBBLE]

const TILLERS := 10
## Only the first tillers carry leaf blades; the rest are bare culms with ears.
## Ears and stems are what fill a ripe stand, and blades cost most triangles.
const LEAFY_TILLERS := 4
## Full height of the tallest culm, metres (medieval long-straw wheat).
const HEIGHT := 1.0
const SPIKELETS := 5
const STUBBLE_HEIGHT := 0.16
## Grass shader base colour (MapViewWindMaterials._grass_material): the instance
## tint divides it out so `tint` returns the colour the plant should show.
const SHADER_BASE := Color8(104, 130, 62)
## sRGB colours the tops of the plants should read at, by ripeness 0 .. 1.
const RIPENING: Array[Color] = [
	Color(0.38, 0.55, 0.30),  # glaucous green, still in milk
	Color(0.62, 0.66, 0.30),  # yellowing ears over green leaves
	Color(0.86, 0.71, 0.38),  # dead ripe gold
]
const STUBBLE_COLOR := Color(0.74, 0.64, 0.42)
const BRIGHTNESS := 1.0

static var _cache: Dictionary = {}


## Cached mesh for one ripening stage (STAGES).
static func mesh(stage: StringName) -> ArrayMesh:
	if _cache.has(stage):
		return _cache[stage]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tiller in TILLERS:
		_append_tiller(surface, tiller, stage)
	var built := surface.commit()
	_cache[stage] = built
	return built


static func reset_cache() -> void:
	_cache.clear()


## Stage geometry for a plant's ripeness 0 (green) .. 1 (dead ripe).
static func stage_for(ripeness: float) -> StringName:
	if ripeness < 0.3:
		return STAGE_GREEN
	if ripeness < 0.72:
		return STAGE_TURNING
	return STAGE_RIPE


## Instance colour that makes the grass shader show RIPENING at `ripeness`
## (continuous, so neighbouring plants of different stages do not pop apart).
static func tint(ripeness: float) -> Color:
	var r := clampf(ripeness, 0.0, 1.0) * float(RIPENING.size() - 1)
	var i := mini(int(r), RIPENING.size() - 2)
	return _instance_color(RIPENING[i].lerp(RIPENING[i + 1], r - float(i)))


static func stubble_tint() -> Color:
	return _instance_color(STUBBLE_COLOR)


## Target over the shader base, channel by channel in sRGB: calibrated against
## captures (the Compatibility renderer multiplies the raw vertex/instance colour
## into the albedo, so a linear-space ratio came out about three times too bright).
static func _instance_color(srgb: Color) -> Color:
	return Color(
		srgb.r / SHADER_BASE.r * BRIGHTNESS,
		srgb.g / SHADER_BASE.g * BRIGHTNESS,
		srgb.b / SHADER_BASE.b * BRIGHTNESS,
		1.0
	)


static func _append_tiller(surface: SurfaceTool, tiller: int, stage: StringName) -> void:
	var yaw := TAU * float(tiller) / float(TILLERS) + (MeshMath.hash01(tiller, 3, 5101) - 0.5) * 0.9
	var out := Vector3(cos(yaw), 0.0, sin(yaw))
	var side := Vector3(-out.z, 0.0, out.x)
	var root := out * lerpf(0.015, 0.07, MeshMath.hash01(tiller, 5, 5113))
	# The main shoot stands tallest; side tillers splay out and stay shorter.
	var height := HEIGHT * (1.0 if tiller == 0 else lerpf(0.8, 0.96, MeshMath.hash01(tiller, 7, 5119)))
	var splay := 0.03 if tiller == 0 else lerpf(0.08, 0.2, MeshMath.hash01(tiller, 11, 5127))
	if stage == STAGE_STUBBLE:
		var cut := root + (out * splay + Vector3.UP).normalized() * STUBBLE_HEIGHT * lerpf(0.75, 1.1, MeshMath.hash01(tiller, 13, 5131))  # gdlint: ignore=max-line-length
		_append_strip(surface, [root, cut], [0.006, 0.005], side, Color(0.95, 0.92, 0.86), [0.0, 0.9])
		return
	# Culm: three joints, bowing outward a little more toward the top.
	var mid := root + out * splay * 0.35 * height + Vector3.UP * height * 0.5
	var top := root + out * splay * height + Vector3.UP * height * 0.86
	var stem := Color(0.92, 0.96, 0.86)
	_append_strip(surface, [root, mid, top], [0.0055, 0.005, 0.004], side, stem, [0.0, 0.5, 0.86])
	# Leaves: two blades low on the culm and the flag leaf under the ear.
	var leaf_heights := [0.16, 0.38, 0.62]
	for leaf in (3 if tiller < LEAFY_TILLERS else 0):
		var flag := leaf == 2
		var t: float = leaf_heights[leaf]
		var at := root.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(top, (t - 0.5) / 0.36)
		# Jitter keeps neighbouring leaves from turning in lockstep
		var turn := yaw + (PI if leaf % 2 == 1 else 0.0)
		turn += (MeshMath.hash01(tiller, leaf, 5141) - 0.5) * 0.8
		var dead := (stage == STAGE_RIPE and leaf < 2) or (stage == STAGE_TURNING and leaf == 0)
		var colour := Color(0.92, 0.86, 0.74) if dead else Color(1.0, 1.0, 1.0)
		var length := (0.16 if flag else 0.26) * lerpf(0.85, 1.12, MeshMath.hash01(tiller, leaf, 5147))
		if dead:
			length *= 0.6  # withered and curled
		# Dead blades hang limp; the flag leaf stands stiffer than the lower ones.
		var rise := 0.95 if flag else (0.35 if dead else 0.7)
		var droop := 1.6 if dead else (0.7 if flag else 1.1)
		_append_blade(surface, at, turn, length, 0.011 if flag else 0.013, rise, droop, colour, t)
	_append_ear(surface, top, out, side, tiller, stage)


## Arching leaf blade: rises at `rise` (radians from horizontal), bends down by
## `droop` over its length, tapers to a point. Three segments, five triangles.
static func _append_blade(
	surface: SurfaceTool,
	at: Vector3,
	yaw: float,
	length: float,
	width: float,
	rise: float,
	droop: float,
	colour: Color,
	uv_base: float
) -> void:
	var out := Vector3(cos(yaw), 0.0, sin(yaw))
	var side := Vector3(-out.z, 0.0, out.x)
	var points: Array[Vector3] = [at]
	var widths: Array[float] = [width * 0.7]
	var uvs: Array[float] = [uv_base]
	var p := at
	for k in 3:
		var angle := rise - droop * (float(k) + 0.5) / 3.0
		p += (out * cos(angle) + Vector3.UP * sin(angle)) * length / 3.0
		points.append(p)
		widths.append(width * (1.0 - float(k + 1) / 3.0))
		uvs.append(clampf(uv_base + (p.y - at.y) / HEIGHT, 0.0, 1.0))
	_append_strip(surface, points, widths, side, colour, uvs)


## The ear: a rachis with SPIKELETS spikelets alternating on two sides, each a
## diamond whose plane turns a quarter from one spikelet to the next so the ear
## reads from any side, with an awn. Green
## ears stand up, turning ones lean, ripe ones nod under their weight.
static func _append_ear(
	surface: SurfaceTool, base: Vector3, out: Vector3, side: Vector3, tiller: int, stage: StringName
) -> void:
	var nod := {STAGE_GREEN: 0.1, STAGE_TURNING: 0.45, STAGE_RIPE: 1.05}[stage] as float
	nod *= lerpf(0.75, 1.2, MeshMath.hash01(tiller, 17, 5153))
	var axis := (Vector3.UP * cos(nod) + out * sin(nod)).normalized()
	var face := axis.cross(side).normalized()
	var length := 0.095 * lerpf(0.85, 1.1, MeshMath.hash01(tiller, 19, 5159))
	var ear := Color(1.0, 1.0, 0.94) if stage == STAGE_GREEN else Color(1.0, 0.97, 0.88)
	# The neck: the top of the culm curves over into the ear.
	var start := base + axis * 0.04
	_append_strip(surface, [base, start], [0.003, 0.003], side, Color(0.94, 0.96, 0.86), [0.86, 0.9])
	var spike_len := length / float(SPIKELETS) * 1.7
	for s in SPIKELETS:
		var t := (float(s) + 0.5) / float(SPIKELETS)
		var centre := start + axis * length * t
		# Spikelets thin out toward the tip of the ear.
		var half := 0.0075 * lerpf(1.0, 0.65, t)
		var lean := side if s % 2 == 0 else -side
		var c := centre + lean * half * 0.6
		var lo := c - axis * spike_len * 0.5
		var hi := c + axis * spike_len * 0.5
		var uv := 0.9 + 0.1 * t
		var plane := side if s % 2 == 0 else face
		_triangle(surface, lo, c + plane * half, hi, ear, uv)
		_triangle(surface, lo, hi, c - plane * half, ear.darkened(0.06), uv)
		# Awn: a thin spine off the spikelet tip, splayed outward.
		var awn_tip := hi + (axis + lean * 0.35).normalized() * 0.045
		_triangle(surface, hi - lean * 0.0012, hi + lean * 0.0012, awn_tip, ear.lightened(0.04), 1.0)


## Ribbon through `points` with per-point half widths; UV.y drives the wind.
static func _append_strip(
	surface: SurfaceTool,
	points: Array,
	widths: Array,
	side: Vector3,
	colour: Color,
	uvs: Array
) -> void:
	for k in points.size() - 1:
		var a: Vector3 = points[k]
		var b: Vector3 = points[k + 1]
		var wa: float = widths[k]
		var wb: float = widths[k + 1]
		var ua: float = uvs[k]
		var ub: float = uvs[k + 1]
		_vertex(surface, a - side * wa, colour, Vector2(0.0, ua))
		_vertex(surface, a + side * wa, colour, Vector2(1.0, ua))
		_vertex(surface, b + side * wb, colour, Vector2(1.0, ub))
		if wb > 0.0:
			_vertex(surface, a - side * wa, colour, Vector2(0.0, ua))
			_vertex(surface, b + side * wb, colour, Vector2(1.0, ub))
			_vertex(surface, b - side * wb, colour, Vector2(0.0, ub))


static func _triangle(
	surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color, uv_y: float
) -> void:
	_vertex(surface, a, colour, Vector2(0.5, uv_y))
	_vertex(surface, b, colour, Vector2(1.0, uv_y))
	_vertex(surface, c, colour, Vector2(0.0, uv_y))


## Normals point up: the grass shader leans them to the sky anyway, and a flat
## strip shaded by its face normal would flip dark from behind (cull_disabled).
static func _vertex(surface: SurfaceTool, at: Vector3, colour: Color, uv: Vector2) -> void:
	surface.set_color(colour)
	surface.set_normal(Vector3.UP)
	surface.set_uv(uv)
	surface.add_vertex(at)
