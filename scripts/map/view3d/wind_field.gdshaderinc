// R-1321 (VEGR-2): one shared wind field for grass, crowns, cloth, ropes and
// nets. WindField (scripts/map/view3d/wind_field.gd) is the only writer: it
// pushes these globals through RenderingServer.global_shader_parameter_set
// whenever the weather presentation changes. Defaults live in project.godot
// [shader_globals] and equal WindField.params_for(default heading, 0.22), so a
// map that never publishes wind keeps the pre-R-1321 look.
//
// A gust is one event in the world: its phase is distance along the wind minus
// time * front speed, so the bend travels as a front across a field and reaches
// the trees and flags downwind later. No texture is sampled (no sampler slot,
// no unbound-sampler hazard on GLES); WindField mirrors every function below
// on the CPU so tests and leaf fall read the same field.

global uniform vec2 wind_dir_g;
global uniform float wind_strength_g;
global uniform float wind_gust_amp_g;
global uniform float wind_gust_wavelength_g;
global uniform float wind_speed_g;
global uniform float wind_turbulence_g;

vec2 wind_dir() {
	return length(wind_dir_g) > 0.001 ? normalize(wind_dir_g) : vec2(0.9285, 0.3714);
}

float wind_strength() {
	return clamp(wind_strength_g, 0.0, 1.0);
}

float wind_cell_hash(vec2 cell) {
	// Wrapped cells keep sin() arguments small so the hash stays stable on GPUs.
	vec2 c = mod(cell, 289.0);
	return fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
}

float wind_value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = wind_cell_hash(cell);
	float b = wind_cell_hash(cell + vec2(1.0, 0.0));
	float c = wind_cell_hash(cell + vec2(0.0, 1.0));
	float d = wind_cell_hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Gust front intensity, 0 in a lull and about 1.2 at the crest of a front.
float wind_gust(vec2 xz, float t) {
	vec2 d = wind_dir();
	vec2 across = vec2(-d.y, d.x);
	float lambda = max(wind_gust_wavelength_g, 1.0);
	float along = dot(xz, d) - t * wind_speed_g;
	float side = dot(xz, across);
	// Broad scale: the visible front, bowed a little across the wind.
	float broad = 0.5 + 0.5 * sin(along * TAU / lambda + 0.6 * sin(side * TAU / (lambda * 2.3)));
	// Narrow scale: the ripple riding inside the front.
	float narrow = 0.5 + 0.5 * sin(along * TAU / (lambda * 0.37) + 1.7);
	// Patchiness along the front so it never reads as a ruled line.
	float patch = wind_value_noise(vec2(along, side) / (lambda * 1.5));
	float front = broad * broad * broad * mix(0.55, 1.25, patch);
	return clamp(front * 0.78 + narrow * narrow * 0.22, 0.0, 1.25);
}

// Same front without the patch noise (its mean, 0.9, instead): 3 sin() like
// the pre-R-1321 crown sway. For consumers that sample once per tree or staff
// on dense meshes, where the vertex cost multiplies by shadow cascades.
float wind_gust_coarse(vec2 xz, float t) {
	vec2 d = wind_dir();
	float lambda = max(wind_gust_wavelength_g, 1.0);
	float along = dot(xz, d) - t * wind_speed_g;
	float side = dot(xz, vec2(-d.y, d.x));
	float broad = 0.5 + 0.5 * sin(along * TAU / lambda + 0.6 * sin(side * TAU / (lambda * 2.3)));
	float narrow = 0.5 + 0.5 * sin(along * TAU / (lambda * 0.37) + 1.7);
	return clamp(broad * broad * broad * 0.9 * 0.78 + narrow * narrow * 0.22, 0.0, 1.25);
}

float wind_pressure_coarse(vec2 xz, float t) {
	return 0.48 + wind_gust_amp_g * 2.0 * wind_gust_coarse(xz, t);
}

// Downwind push factor (about 0.48 in a lull, 0.8 mean, up to 1.8 in a storm
// front). Consumers multiply it by wind_strength() and their own sway scale.
float wind_pressure(vec2 xz, float t) {
	return 0.48 + wind_gust_amp_g * 2.0 * wind_gust(xz, t);
}

// Signed gust in -1..1 for cloth and ropes that used a sine gust before.
float wind_gust_signed(vec2 xz, float t) {
	return clamp((wind_pressure(xz, t) - 0.8) * 1.6, -1.0, 1.0);
}

// Flutter multiplier: 1.0 on the default breeze, rising with turbulence.
float wind_flutter_scale() {
	return 0.8 + 1.05 * wind_turbulence_g;
}
