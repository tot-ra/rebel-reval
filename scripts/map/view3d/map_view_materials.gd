class_name MapViewMaterials
extends RefCounted

## Procedural placeholder materials for the P0-052 3D view layer.
## Every material derives from the frozen palette colors so the view never
## blocks on texture generation; the P0-051/P0-053 AI-generated textures
## replace only the albedo maps without changing this wiring. Patterns are
## grayscale multipliers over the palette albedo so tinting stays palette-led.

const TEXTURE_SIZE := 128
const EMBER_COLOR := Color8(224, 108, 48)
const EMBER_ENERGY := 1.6

const WATER_TERRAINS: Array[StringName] = [
	MapTypes.TERRAIN_WATER,
	MapTypes.TERRAIN_SHALLOW_WATER,
	MapTypes.TERRAIN_DEEP_WATER,
]

## World units covered by one repeat of the terrain detail texture. Terrain
## meshes emit world-space UVs divided by this, so patterns run seamlessly
## across cell borders instead of restarting per cell.
const TERRAIN_TEXTURE_WORLD_SIZE := 4.0

## Pattern families for terrain and building surfaces.
const PATTERN_GRASS := &"grass"
const PATTERN_SPECKLE := &"speckle"
const PATTERN_COBBLE := &"cobble"
const PATTERN_BRICK := &"brick"
const PATTERN_PLANK := &"plank"
const PATTERN_LIMESTONE := &"limestone"
const PATTERN_ROOF_TILE := &"roof_tile"
const PATTERN_PLASTER := &"plaster"
const PATTERN_STRAW := &"straw"

const TERRAIN_PATTERN := {
	MapTypes.TERRAIN_GRASS: PATTERN_GRASS,
	MapTypes.TERRAIN_MEADOW: PATTERN_GRASS,
	MapTypes.TERRAIN_FOREST_FLOOR: PATTERN_GRASS,
	MapTypes.TERRAIN_BOG: PATTERN_GRASS,
	MapTypes.TERRAIN_HAY: PATTERN_STRAW,
	MapTypes.TERRAIN_STRAW: PATTERN_STRAW,
	MapTypes.TERRAIN_FARM_SOIL: PATTERN_STRAW,
	MapTypes.TERRAIN_DIRT: PATTERN_SPECKLE,
	MapTypes.TERRAIN_MUD: PATTERN_SPECKLE,
	MapTypes.TERRAIN_SAND: PATTERN_SPECKLE,
	MapTypes.TERRAIN_COAST_SAND: PATTERN_SPECKLE,
	MapTypes.TERRAIN_ASH: PATTERN_SPECKLE,
	MapTypes.TERRAIN_COBBLESTONE: PATTERN_COBBLE,
	MapTypes.TERRAIN_CASTLE_PAVING: PATTERN_COBBLE,
	MapTypes.TERRAIN_STONE: PATTERN_LIMESTONE,
	MapTypes.TERRAIN_TIMBER_FLOOR: PATTERN_PLANK,
	MapTypes.TERRAIN_PLASTER: PATTERN_PLASTER,
}

## Denser tiling for paving so individual stones stay readable at gameplay zoom.
const TERRAIN_UV_SCALE := {
	MapTypes.TERRAIN_COBBLESTONE: 2.0,
	MapTypes.TERRAIN_CASTLE_PAVING: 2.0,
	MapTypes.TERRAIN_TIMBER_FLOOR: 2.0,
}

## BoxMesh and CylinderMesh map UV 0-1 across each face. Without extra
## repeats, one procedural tile spans an entire house wall and bricks read
## billboard-sized. Values are tuned for typical 3-6 unit footprints at the
## frozen 32 px/cell scale (character height 2.0 units).
## Stretcher courses need more vertical UV repeats than horizontal ones so each
## block reads wider than tall (running bond, not soldier/stack bond).
const BUILDING_UV_SCALE := {
	PATTERN_BRICK: Vector3(5.0, 6.5, 5.0),
	PATTERN_LIMESTONE: Vector3(4.0, 6.0, 4.0),
	PATTERN_PLANK: Vector3(5.0, 3.0, 5.0),
	PATTERN_PLASTER: Vector3(3.5, 2.5, 3.5),
	PATTERN_ROOF_TILE: Vector3(4.0, 2.5, 4.0),
}
## Reference box size the fixed BUILDING_UV_SCALE repeats were tuned against.
## building_uv_scale() scales repeats proportionally so long fortification
## walls keep brick and stone courses the same world size as house facades.
const BUILDING_UV_REFERENCE_SIZE := Vector3(4.0, 3.5, 4.0)

const WATER_SHADER_CODE := "
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.45, 0.62, 0.75);
uniform vec3 deep_color : source_color = vec3(0.16, 0.30, 0.44);
uniform vec3 highlight_color : source_color = vec3(0.396, 0.694, 0.769);
uniform float ripple_scale = 1.15;

float _hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float _noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(_hash(i), _hash(i + vec2(1.0, 0.0)), u.x),
		mix(_hash(i + vec2(0.0, 1.0)), _hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float _fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	value += amplitude * _noise(p);
	p = p * 2.03 + vec2(1.7);
	amplitude *= 0.5;
	value += amplitude * _noise(p);
	p = p * 2.03 + vec2(-2.3);
	amplitude *= 0.5;
	value += amplitude * _noise(p);
	p = p * 2.03 + vec2(0.4);
	amplitude *= 0.5;
	value += amplitude * _noise(p);
	return value;
}

void fragment() {
	vec2 world_uv = UV * ripple_scale * 8.0;
	float t = TIME;
	vec2 flow_a = vec2(t * 0.12, t * 0.08);
	vec2 flow_b = vec2(-t * 0.09, t * 0.11);

	float ripples = _fbm(world_uv * 0.85 + flow_a);
	float fine = _fbm(world_uv * 2.4 + flow_b * 1.3 + ripples * 0.35);
	float surface = mix(ripples, fine, 0.45);
	float depth = _fbm(world_uv * 0.35 + vec2(t * 0.02, -t * 0.015));

	vec3 water_color = mix(
		deep_color,
		shallow_color,
		clamp(surface * 0.65 + depth * 0.35, 0.08, 0.95)
	);

	float bright = smoothstep(0.52, 0.82, surface) * smoothstep(0.38, 0.72, fine);
	water_color = mix(water_color, highlight_color, bright * 0.28);

	float glint_field = _noise(world_uv * 5.5 + flow_a * 2.0);
	float glint = smoothstep(0.88, 0.97, glint_field) * smoothstep(0.55, 0.85, surface);
	water_color += vec3(0.12, 0.14, 0.10) * glint;

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.8);
	ALBEDO = mix(water_color, mix(water_color, highlight_color, 0.35), fresnel * 0.22);

	float eps = 0.04;
	vec2 ripple_uv = world_uv * 1.1 + flow_a;
	float hx = _fbm(ripple_uv + vec2(eps, 0.0)) - _fbm(ripple_uv - vec2(eps, 0.0));
	float hz = _fbm(ripple_uv + vec2(0.0, eps)) - _fbm(ripple_uv - vec2(0.0, eps));
	NORMAL = normalize(NORMAL + TANGENT * hx * 0.18 + BINORMAL * hz * 0.18);

	ROUGHNESS = mix(0.08, 0.28, 1.0 - surface);
	SPECULAR = mix(0.65, 0.35, depth);
}
"

## Grass blades: instance color carries the tint, UV.y runs root(0) to tip(1)
## and weights a two-frequency wind sway so tips travel and roots hold.
const GRASS_SHADER_CODE := "
shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_color : source_color = vec3(0.38, 0.48, 0.24);
uniform float sway_strength = 0.10;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 1.9 + world.z * 1.4;
	float gust = sin(TIME * 0.9 + phase * 0.23);
	float sway = sin(TIME * 2.0 + phase) * (0.55 + 0.45 * gust)
		+ 0.4 * sin(TIME * 3.4 + phase * 1.7);
	float weight = UV.y * UV.y;
	VERTEX.x += sway * sway_strength * weight;
	VERTEX.z += cos(TIME * 1.5 + phase * 1.2) * sway_strength * 0.6 * weight;
}

void fragment() {
	ALBEDO = base_color * COLOR.rgb * mix(0.5, 1.1, UV.y);
	ROUGHNESS = 0.95;
}
"

## Tree canopies: same wind idea, far gentler, weighted by height above the
## canopy base so trunks stay planted.
const CANOPY_SHADER_CODE := "
shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_color : source_color = vec3(0.30, 0.42, 0.26);
uniform float sway_strength = 0.05;
uniform float shade_bottom = 0.62;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.9 + world.z * 0.7;
	float weight = clamp(VERTEX.y * 0.4 + 0.4, 0.0, 1.0);
	VERTEX.x += sin(TIME * 1.3 + phase) * sway_strength * weight;
	VERTEX.z += cos(TIME * 1.05 + phase * 1.3) * sway_strength * 0.8 * weight;
}

void fragment() {
	// Primitive-mesh UVs run v = 0 at the top, so invert for canopy shading.
	float shade = mix(1.05, shade_bottom, clamp(UV.y, 0.0, 1.0));
	ALBEDO = base_color * COLOR.rgb * shade;
	ROUGHNESS = 0.95;
}
"

static var _cache: Dictionary = {}


static func reset() -> void:
	_cache.clear()


static func terrain(terrain_id: StringName, noise_seed: int) -> StandardMaterial3D:
	var key := "terrain:%s:%d" % [String(terrain_id), noise_seed]
	if _cache.has(key):
		return _cache[key]
	var base := OutdoorTerrainPalette.color(terrain_id)
	var pattern: StringName = TERRAIN_PATTERN.get(terrain_id, PATTERN_GRASS)
	if WATER_TERRAINS.has(terrain_id):
		pattern = PATTERN_PLASTER
	var material := _make_material(base, pattern, noise_seed + int(terrain_id.hash()))
	var uv := float(TERRAIN_UV_SCALE.get(terrain_id, 1.0))
	material.uv1_scale = Vector3(uv, uv, 1.0)
	if WATER_TERRAINS.has(terrain_id):
		material.roughness = 0.15
	_cache[key] = material
	return material


## Animated water surface for water-family terrain cells; colors derive from
## the same frozen palette entry the flat material uses.
static func water_surface(terrain_id: StringName) -> ShaderMaterial:
	var key := "water_surface:%s" % String(terrain_id)
	if _cache.has(key):
		return _cache[key]
	var base := OutdoorTerrainPalette.color(terrain_id)
	var material := ShaderMaterial.new()
	material.shader = _shader("water", WATER_SHADER_CODE)
	material.set_shader_parameter("shallow_color", base.lightened(0.18))
	material.set_shader_parameter("deep_color", base.darkened(0.42))
	# ART_BIBLE highlight #65B1C4 blended toward the terrain palette entry.
	material.set_shader_parameter("highlight_color", base.lerp(Color8(101, 177, 196), 0.55))
	_cache[key] = material
	return material


## Wind-swaying grass blade material; instance colors modulate the tint.
static func grass_blades() -> ShaderMaterial:
	var key := "grass_blades"
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = _shader("grass", GRASS_SHADER_CODE)
	material.set_shader_parameter("base_color", Color8(104, 130, 62))
	_cache[key] = material
	return material


static func canopy(kind: StringName) -> ShaderMaterial:
	var key := "canopy:%s" % String(kind)
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = _shader("canopy", CANOPY_SHADER_CODE)
	match kind:
		&"spruce":
			material.set_shader_parameter("base_color", Color8(58, 84, 56))
			material.set_shader_parameter("sway_strength", 0.035)
		_:
			material.set_shader_parameter("base_color", Color8(96, 118, 60))
			material.set_shader_parameter("sway_strength", 0.06)
	_cache[key] = material
	return material


static func wall(color: Color) -> StandardMaterial3D:
	return _building_surface("wall", color, PATTERN_PLASTER)


## Building wall surface in an explicit material family so houses read as
## built from something: plastered timber frame, brick, plank, or limestone.
static func wall_surface(family: StringName, color: Color) -> StandardMaterial3D:
	match family:
		&"brick":
			return _building_surface("wall_brick", color, PATTERN_BRICK)
		&"plank":
			return _building_surface("wall_plank", color, PATTERN_PLANK)
		&"limestone":
			return _building_surface("wall_limestone", color, PATTERN_LIMESTONE)
		_:
			return _building_surface("wall_plaster", color, PATTERN_PLASTER)


## Wall material with UV repeats derived from the mesh world size so BoxMesh
## faces tile instead of stretching one pattern across the full span.
static func wall_surface_for_size(family: StringName, color: Color, size: Vector3) -> StandardMaterial3D:
	var material := wall_surface(family, color).duplicate()
	material.uv1_scale = building_uv_scale(_wall_pattern(family), size)
	return material


## Object-space triplanar mapping keeps masonry density independent of whether a
## BoxMesh wall runs along X or Z. Regular BoxMesh UVs only use uv1_scale.x/y,
## which makes Z-aligned walls derive their visible repeat count from thickness.
static func wall_surface_triplanar(family: StringName, color: Color) -> StandardMaterial3D:
	var pattern := _wall_pattern(family)
	var material := wall_surface(family, color).duplicate()
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	material.uv1_scale = building_uv_density(pattern)
	return material


static func wall_for_size(color: Color, size: Vector3) -> StandardMaterial3D:
	var material := wall(color).duplicate()
	material.uv1_scale = building_uv_scale(PATTERN_PLASTER, size)
	return material


static func roof(color: Color) -> StandardMaterial3D:
	return _building_surface("roof", color, PATTERN_ROOF_TILE)


## UV repeat density per world unit. Triplanar materials use this directly so
## X- and Z-facing walls receive the same masonry scale.
static func building_uv_density(pattern: StringName) -> Vector3:
	var repeats: Vector3 = BUILDING_UV_SCALE.get(pattern, Vector3.ONE)
	return repeats / BUILDING_UV_REFERENCE_SIZE


## UV repeat counts for a box face whose width, height, and depth are size.
static func building_uv_scale(pattern: StringName, size: Vector3) -> Vector3:
	return size * building_uv_density(pattern)


## CylinderMesh wraps U around the circumference; pass radius and height.
static func building_uv_scale_cylinder(pattern: StringName, radius: float, height: float) -> Vector3:
	return building_uv_scale(pattern, Vector3(TAU * radius, height, TAU * radius))


## Prop surface materials keyed by the shared visual-style roles so the
## placeholder palette carries over from the approved clean-painted profile.
static func role(role_name: StringName) -> StandardMaterial3D:
	var key := "role:%s" % String(role_name)
	if _cache.has(key):
		return _cache[key]
	var base := MapVisualStyle.role_color(role_name, MapVisualStyle.TARGET_CLEAN_PAINTED, MapVisualStyle.TIME_DAY)
	var pattern := PATTERN_PLASTER
	match role_name:
		&"wood", &"timber":
			pattern = PATTERN_PLANK
		&"stone":
			pattern = PATTERN_LIMESTONE
		&"hay":
			pattern = PATTERN_STRAW
	var material := _make_material(base, pattern, int(role_name.hash()))
	match role_name:
		&"metal":
			material.metallic = 0.55
			material.roughness = 0.45
		&"window":
			# Glazed openings read as dark tinted glass, not bright sky panels.
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = base.darkened(0.42)
			material.albedo_color.a = 0.52
			material.roughness = 0.1
			material.specular = 0.35
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"water_highlight":
			material.roughness = 0.15
		&"ember":
			material.emission_enabled = true
			material.emission = EMBER_COLOR
			material.emission_energy_multiplier = EMBER_ENERGY
	_cache[key] = material
	return material


## Flat vegetation and landscape tints for the view-only scatter and treeline.
## Instance colors modulate these through vertex_color_use_as_albedo.
static func foliage_tuft() -> StandardMaterial3D:
	return _patterned("foliage_tuft", Color8(96, 122, 60), PATTERN_GRASS)


static func foliage_spruce() -> StandardMaterial3D:
	return _patterned("foliage_spruce", Color8(56, 82, 54), PATTERN_GRASS)


static func foliage_leaf() -> StandardMaterial3D:
	return _patterned("foliage_leaf", Color8(94, 116, 58), PATTERN_GRASS)


static func bark() -> StandardMaterial3D:
	return _patterned("bark", Color8(74, 56, 42), PATTERN_PLANK)


static func surroundings_ground() -> StandardMaterial3D:
	var key := "surroundings_ground"
	if _cache.has(key):
		return _cache[key]
	var material := _make_material(Color8(74, 88, 60), PATTERN_GRASS, 8117)
	material.uv1_scale = Vector3(96.0, 96.0, 1.0)
	_cache[key] = material
	return material


## Untextured, unshaded billboard for chimney smoke. Radial vertex alpha on the
## puff mesh and the particle color ramp provide tint and lifetime fade.
## Untextured, unshaded billboard for chimney smoke. Tint and lifetime fade come
## from the particle color ramp only.
static func smoke() -> StandardMaterial3D:
	var key := "smoke"
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Particle COLOR carries the lifetime ramp, including the alpha fade.
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	_cache[key] = material
	return material


static func _shader(name: String, code: String) -> Shader:
	var key := "shader:%s" % name
	if _cache.has(key):
		return _cache[key]
	var shader := Shader.new()
	shader.code = code
	_cache[key] = shader
	return shader


static func _patterned(prefix: String, color: Color, pattern: StringName) -> StandardMaterial3D:
	var key := "%s:%s:%s" % [prefix, color.to_html(), String(pattern)]
	if _cache.has(key):
		return _cache[key]
	var material := _make_material(color, pattern, int(key.hash()))
	_cache[key] = material
	return material


static func _building_surface(prefix: String, color: Color, pattern: StringName) -> StandardMaterial3D:
	var material := _patterned(prefix, color, pattern)
	material.uv1_scale = building_uv_scale(pattern, BUILDING_UV_REFERENCE_SIZE)
	return material


static func _wall_pattern(family: StringName) -> StringName:
	match family:
		&"brick":
			return PATTERN_BRICK
		&"plank":
			return PATTERN_PLANK
		&"limestone":
			return PATTERN_LIMESTONE
		_:
			return PATTERN_PLASTER


static func _make_material(base: Color, pattern: StringName, noise_seed: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base
	material.albedo_texture = _pattern_texture(pattern, noise_seed)
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Terrain cells and scatter instances carry per-cell tone in vertex/instance
	# colors; meshes without a color attribute stay white so nothing shifts.
	material.vertex_color_use_as_albedo = true
	return material


## Deterministic grayscale detail texture per pattern family; multiplies with
## albedo_color so the same texture serves every tint. Mipmapped and linearly
## filtered so surfaces stop reading as pixel noise.
static func _pattern_texture(pattern: StringName, noise_seed: int) -> ImageTexture:
	var key := "pattern:%s:%d" % [String(pattern), noise_seed]
	if _cache.has(key):
		return _cache[key]
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGB8)
	match pattern:
		PATTERN_COBBLE:
			_paint_cobble(image, noise_seed)
		PATTERN_BRICK:
			_paint_brick(image, noise_seed)
		PATTERN_PLANK:
			_paint_plank(image, noise_seed)
		PATTERN_LIMESTONE:
			_paint_limestone(image, noise_seed)
		PATTERN_ROOF_TILE:
			_paint_roof_tile(image, noise_seed)
		PATTERN_STRAW:
			_paint_straw(image, noise_seed)
		PATTERN_SPECKLE:
			_paint_speckle(image, noise_seed)
		PATTERN_PLASTER:
			_paint_plaster(image, noise_seed)
		_:
			_paint_grass(image, noise_seed)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func _hash01(x: int, y: int, noise_seed: int) -> float:
	var hashed := ((x * 374761393) + (y * 668265263) + noise_seed * 69069) & 0x7fffffff
	hashed = (hashed ^ (hashed >> 13)) * 1274126177 & 0x7fffffff
	return float(hashed % 100000) / 99999.0


## Tileable smooth value noise: bilinear blend of a wrapped lattice.
static func _lattice(x: float, y: float, period: int, noise_seed: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - float(xi)
	var fy := y - float(yi)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x0 := posmod(xi, period)
	var x1 := posmod(xi + 1, period)
	var y0 := posmod(yi, period)
	var y1 := posmod(yi + 1, period)
	var a := _hash01(x0, y0, noise_seed)
	var b := _hash01(x1, y0, noise_seed)
	var c := _hash01(x0, y1, noise_seed)
	var d := _hash01(x1, y1, noise_seed)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _fill_value(image: Image, x: int, y: int, value: float) -> void:
	var v := clampf(value, 0.0, 1.0)
	image.set_pixel(x, y, Color(v, v, v))


static func _paint_grass(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var broad := _lattice(float(x) / 16.0, float(y) / 16.0, size / 16, noise_seed)
			var fine := _lattice(float(x) / 5.0, float(y) / 5.0, size / 5, noise_seed + 51)
			var streak := _lattice(float(x) / 3.0, float(y) / 11.0, size / 3, noise_seed + 907)
			var value := 0.82 + broad * 0.16 + fine * 0.10
			if streak > 0.78:
				value += 0.07
			elif streak < 0.2:
				value -= 0.06
			_fill_value(image, x, y, value)


static func _paint_speckle(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var broad := _lattice(float(x) / 20.0, float(y) / 20.0, size / 20, noise_seed)
			var fine := _hash01(x, y, noise_seed + 3)
			var value := 0.84 + broad * 0.14 + (fine - 0.5) * 0.08
			if fine > 0.965:
				value -= 0.18
			elif fine < 0.02:
				value += 0.12
			_fill_value(image, x, y, value)


static func _paint_plaster(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var broad := _lattice(float(x) / 24.0, float(y) / 24.0, size / 24, noise_seed)
			var fine := _lattice(float(x) / 6.0, float(y) / 6.0, size / 6, noise_seed + 77)
			_fill_value(image, x, y, 0.88 + broad * 0.09 + fine * 0.05)


## Rounded field stones packed on a jittered grid with dark seams (Worley-ish).
static func _paint_cobble(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	var stones := 8
	var cell := float(size) / float(stones)
	for y in size:
		for x in size:
			var best := 10.0
			var tone := 0.0
			var gx := floori(float(x) / cell)
			var gy := floori(float(y) / cell)
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var sx := posmod(gx + ox, stones)
					var sy := posmod(gy + oy, stones)
					var jx := (float(gx + ox) + 0.25 + _hash01(sx, sy, noise_seed) * 0.5) * cell
					var jy := (float(gy + oy) + 0.25 + _hash01(sx, sy, noise_seed + 13) * 0.5) * cell
					var distance := Vector2(x - jx, y - jy).length() / cell
					if distance < best:
						best = distance
						tone = _hash01(sx, sy, noise_seed + 29)
			var dome := clampf(1.0 - best * best * 1.4, 0.0, 1.0)
			var value := 0.55 + dome * 0.42 + (tone - 0.5) * 0.14
			_fill_value(image, x, y, value)


static func _paint_brick(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	# Half the legacy course/brick span so each tile carries more bricks; UV
	# repeats on building faces finish the scale for typical house footprints.
	# Keep brick_w >> course so stretcher courses stay visibly horizontal.
	var course := 5
	var brick_w := 16
	for y in size:
		var row := y / course
		var in_course := y % course
		for x in size:
			var offset := (row % 2) * brick_w / 2
			var column := (x + offset) / brick_w
			var in_brick := (x + offset) % brick_w
			var tone := _hash01(column, row, noise_seed)
			var value := 0.82 + (tone - 0.5) * 0.16
			value += _lattice(float(x) / 7.0, float(y) / 7.0, size / 7, noise_seed + 5) * 0.06
			if in_course < 1 or in_brick < 1:
				value = 0.62 + _hash01(x, y, noise_seed + 9) * 0.06
			_fill_value(image, x, y, value)


static func _paint_plank(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	var plank := 16
	for y in size:
		var row := y / plank
		var in_plank := y % plank
		for x in size:
			var grain := _lattice(float(x) / 4.0, float(y) / 18.0, size / 4, noise_seed + row * 131)
			var value := 0.80 + grain * 0.18
			value += sin(float(x) * 0.35 + float(row) * 2.1) * 0.02
			if in_plank < 1:
				value = 0.52
			elif in_plank == 1:
				value -= 0.10
			# Occasional butt joint inside a course.
			if posmod(x + int(_hash01(row, 0, noise_seed) * 100.0), 96) < 1:
				value = 0.55
			_fill_value(image, x, y, value)


## Irregular ashlar courses: Tallinn's grey limestone masonry. Keep block width
## well above course height so tall fortification walls read horizontal courses.
static func _paint_limestone(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	var courses := 16
	var course_h := size / courses
	for y in size:
		var row := y / course_h
		var in_course := y % course_h
		for x in size:
			var width := 16 + int(_hash01(row, 3, noise_seed) * 12.0)
			var offset := int(_hash01(row, 7, noise_seed + 3) * 24.0)
			var column := (x + offset) / width
			var in_block := (x + offset) % width
			var tone := _hash01(column, row, noise_seed + 17)
			var value := 0.80 + (tone - 0.5) * 0.18
			value += _lattice(float(x) / 9.0, float(y) / 9.0, size / 9, noise_seed + 23) * 0.08
			if in_course < 1 or in_block < 1:
				value = 0.58 + _hash01(x, y, noise_seed + 31) * 0.05
			_fill_value(image, x, y, value)


## Overlapping tile courses: each row shades darker toward its lower edge and
## staggers its vertical joints, reading as hand-laid clay tiles.
static func _paint_roof_tile(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	var course := 10
	var tile_w := 10
	for y in size:
		var row := y / course
		var in_course := y % course
		for x in size:
			var offset := (row % 2) * tile_w / 2
			var column := (x + offset) / tile_w
			var in_tile := (x + offset) % tile_w
			var tone := _hash01(column, row, noise_seed)
			# Curved tile profile: brighter crown at tile center.
			var profile := sin(float(in_tile) / float(tile_w) * PI)
			var value := 0.72 + profile * 0.20 + (tone - 0.5) * 0.14
			# Overlap shadow at the bottom of each course.
			value -= clampf(1.0 - float(in_course) / 5.0, 0.0, 1.0) * 0.22
			if in_tile < 1:
				value -= 0.12
			_fill_value(image, x, y, value)


static func _paint_straw(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var strand := _lattice(float(x) / 2.0, float(y) / 14.0, size / 2, noise_seed)
			var broad := _lattice(float(x) / 20.0, float(y) / 20.0, size / 20, noise_seed + 41)
			_fill_value(image, x, y, 0.74 + strand * 0.20 + broad * 0.08)
