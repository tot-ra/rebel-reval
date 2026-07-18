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
