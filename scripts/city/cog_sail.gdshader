shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://scripts/map/view3d/wind_field.gdshaderinc"

// Square sail of the cog, fixed along the yard (UV.y = 0) and at the clews (the
// foot corners, UV.x = 0 / 1). Mesh contract: CogRig.sail_mesh().
//
// The pocket is filled by the shared world wind seen in the sail's own frame
// (the ship turns, the wind does not): wind blowing from astern fills the sail
// forward; wind from ahead lays it back against the mast (aback); wind along the
// yard leaves it edge-on and it shivers (luffs), hardest along the free foot.
// Gust fronts from the shared field make the pocket breathe.

uniform vec3 base_color : source_color = vec3(0.9, 0.86, 0.76);
uniform float pocket = 1.7;
uniform float sail_half = 6.0;
uniform float sail_depth = 7.4;

float belly_shape(float u, float v) {
	float across = pow(max(sin(PI * u), 0.0), 0.85);
	float down = smoothstep(0.0, 0.5, v) * (1.0 - 0.3 * v);
	return across * down;
}

void vertex() {
	vec2 wd = wind_dir();
	vec3 wl = normalize((inverse(MODEL_MATRIX) * vec4(wd.x, 0.0, wd.y, 0.0)).xyz);
	float push = wl.x;
	float power = mix(0.2, 1.3, wind_strength());
	float gust = wind_gust_signed(MODEL_MATRIX[3].xz, TIME);
	float pressure = power * (0.85 + 0.25 * gust);
	float u = UV.x;
	float v = UV.y;
	float fill = clamp(push * 1.6, -1.0, 1.0);
	float shape = belly_shape(u, v);
	float lift = pocket * pressure * fill;
	float dx = lift * shape;
	// Luff: the less the wind pushes square on, the more the free parts shiver.
	float luff = (1.0 - smoothstep(0.1, 0.65, abs(push))) * pressure;
	float free_edge = 0.25 + 0.75 * v;
	float phase = u * 9.0 + v * 6.0;
	float shiver = (sin(TIME * 6.5 + phase) * 0.55 + sin(TIME * 10.7 + phase * 1.7) * 0.3) * wind_flutter_scale();
	dx += luff * 0.55 * shiver * free_edge * sin(PI * u) * v;
	// Wind along the yard also blows the foot sideways and the cloth pulls in as it fills.
	float dz = wl.z * pressure * 0.5 * v * v * (0.4 + shape)
		- (u * 2.0 - 1.0) * sail_half * 0.07 * abs(fill) * shape * pressure;
	float dy = shape * abs(fill) * 0.28 * pressure * v + luff * 0.12 * shiver * v;
	VERTEX += vec3(dx, dy, dz);
	// Normal from the pocket's slope (x-displacement over z and y).
	float e = 0.02;
	float f0 = lift * belly_shape(u - e, v);
	float f1 = lift * belly_shape(u + e, v);
	float g0 = lift * belly_shape(u, v - e);
	float g1 = lift * belly_shape(u, v + e);
	float dfdz = (f1 - f0) / (2.0 * e * 2.0 * sail_half);
	float dfdy = -(g1 - g0) / (2.0 * e * sail_depth);
	NORMAL = normalize(vec3(1.0, -dfdy, -dfdz));
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = base_color * COLOR.rgb;
	ROUGHNESS = 0.95;
	// Canvas lets the sun through: thin, warm back-light.
	BACKLIGHT = vec3(0.34, 0.3, 0.22);
}
