class_name MapViewMaterialShaders
extends RefCounted

## Inline shader sources for animated MapViewMaterials surfaces.


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
// depth_draw_opaque keeps stacked blade layers sorted; cull_disabled shows both
// faces. Wind stays in vertex(), but grass must not cast shadows: animated
// vertices make shadow maps jitter on thin geometry.
render_mode cull_disabled, depth_draw_opaque;

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
	// Double-sided blades otherwise flip normals and shadowed lighting flickers.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
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


## Ground splat: two terrain pattern layers blended per vertex. CUSTOM0 carries
## pattern indices (x, y), blend weight (z), and brightness tone (w). COLOR.rgb
## is the palette tint lerp between the two terrain families.
const TERRAIN_BLEND_SHADER_CODE := "
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2DArray terrain_patterns;
uniform float pattern_layers = 1.0;

// CUSTOM0 is only readable in vertex(); layer indices must stay flat (an
// interpolated index would sample arbitrary in-between layers mid-triangle)
// while weight and tone interpolate for soft terrain borders.
varying flat ivec2 blend_layers;
varying vec2 blend_mix;

void vertex() {
	blend_layers = ivec2(int(CUSTOM0.x + 0.5), int(CUSTOM0.y + 0.5));
	blend_mix = CUSTOM0.zw;
}

void fragment() {
	float blend = clamp(blend_mix.x, 0.0, 1.0);
	float tone = blend_mix.y;

	vec3 primary = texture(terrain_patterns, vec3(UV, float(blend_layers.x))).rgb;
	vec3 secondary = texture(terrain_patterns, vec3(UV, float(blend_layers.y))).rgb;
	vec3 pattern = mix(primary, secondary, blend);
	ALBEDO = pattern * COLOR.rgb * tone;
	ROUGHNESS = mix(0.94, 0.82, blend * step(0.5, float(blend_layers.y)));
}
"

## Shallow wet patches on worked ground after rain. depth_prepass_alpha keeps
## soft edges without the speckled dither alpha_hash shows on flat decals.
const PUDDLE_SHADER_CODE := "
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, depth_draw_opaque, depth_prepass_alpha, blend_mix;

uniform vec3 wet_tint : source_color = vec3(0.72, 0.78, 0.82);
uniform vec3 sheen_tint : source_color = vec3(0.88, 0.92, 0.94);

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
	return value;
}

varying vec2 world_xz;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = world.xz * 0.55;
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float blob_warp = _fbm(world_xz * 1.6 + vec2(0.41, 0.67));
	vec2 warped = centered * (1.0 + vec2(blob_warp - 0.5) * 0.55);
	float radial = length(warped);
	float edge_wobble = _fbm(world_xz * 3.4 + vec2(0.19, 0.83)) * 0.22;
	float organic = _fbm(world_xz * 2.2 + vec2(0.73, 0.11));
	float mask = smoothstep(1.02 + edge_wobble, 0.34, radial);
	mask *= smoothstep(0.28, 0.62, organic + 0.18);
	float rim = smoothstep(0.58, 0.94, radial);

	vec2 ripple_uv = world_xz * 2.4 + vec2(TIME * 0.018, -TIME * 0.013);
	float ripples = _fbm(ripple_uv) * 0.7 + _fbm(ripple_uv * 1.8 + vec2(TIME * 0.03)) * 0.3;

	vec3 ground = COLOR.rgb;
	vec3 wet = ground * wet_tint;
	vec3 sheen = mix(wet, ground * sheen_tint, ripples * 0.08 + rim * 0.05);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.6);
	sheen = mix(sheen, ground * sheen_tint, fresnel * 0.10);
	sheen = mix(sheen, ground * 0.82, smoothstep(0.0, 0.42, radial) * 0.35);

	ALBEDO = sheen;
	ALPHA = mask * 0.62;
	ROUGHNESS = mix(0.42, 0.62, ripples);
	SPECULAR = mix(0.08, 0.16, fresnel);
}
"

static func reset() -> void:
	_cache.clear()


static func shader(name: String, code: String) -> Shader:
	var key := "shader:%s" % name
	if _cache.has(key):
		return _cache[key]
	var shader := Shader.new()
	shader.code = code
	_cache[key] = shader
	return shader
