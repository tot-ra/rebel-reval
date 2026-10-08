shader_type spatial;

// Loose hay shed by a stack in the wind (MapViewHayMeshes.wisp_mesh).
//
// Each wisp is a short ribbon tucked on the stack surface. Stateless life cycle
// from TIME alone, so no script touches it per frame:
//   1. at the start of every cycle the shared gust field is sampled at the stack;
//      the wisp lets go only if the wind then beats its own threshold (a calm
//      day sheds nothing, a gusty one a few strands, a storm most of them)
//   2. a released wisp lifts off, tumbles downwind with drag, falls under
//      gravity and lands on the ground (the stack's base plane)
//   3. it lies there a while, then shrinks away before the cycle repeats
// Per-vertex data (see the mesh builder): CUSTOM0.xyz = attachment point on the
// stack (model space), CUSTOM0.w = seed 0..1; COLOR.r = release threshold,
// COLOR.g = strand length (m), COLOR.b = tone; UV = (along -0.5..0.5, across -1..1).
#include "res://scripts/map/view3d/wind_field.gdshaderinc"

render_mode cull_disabled, shadows_disabled;

uniform vec3 mid_color : source_color = vec3(0.46, 0.38, 0.22);
uniform vec3 bleach_color : source_color = vec3(0.64, 0.57, 0.38);
uniform float cycle_seconds = 11.0;
uniform float strand_width = 0.018;

varying float v_tone;

void vertex() {
	vec3 attach = CUSTOM0.xyz;
	float seed = CUSTOM0.w;
	float threshold = COLOR.r;
	float length_m = COLOR.g;
	v_tone = COLOR.b;

	vec2 origin = MODEL_MATRIX[3].xz;
	float period = cycle_seconds * (0.7 + 0.6 * fract(seed * 7.13));
	float clock = TIME / period + seed;
	float cycle = floor(clock);
	float p = fract(clock);
	float launch_time = (cycle - seed) * period;
	float drive = wind_strength() * wind_pressure(origin, launch_time);
	float released = step(threshold, drive);

	mat3 to_world = mat3(MODEL_MATRIX);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 n_world = normalize(to_world * NORMAL);
	vec3 across = normalize(cross(n_world, up) + vec3(0.0001, 0.0, 0.0));
	vec2 wd = wind_dir();
	vec3 down_wind = vec3(wd.x, 0.0, wd.y);

	// Flight clock in seconds since lift-off. The release strength sets the speed.
	float t = p * period;
	float speed = 0.8 + 3.2 * clamp(drive, 0.0, 1.2);
	float drag = 1.1;
	float travel = speed * (1.0 - exp(-drag * t)) / drag;
	float lateral = sin(t * 2.3 + seed * 31.0) * 0.35 * min(t, 1.5) * (0.4 + wind_turbulence_g);
	vec3 attach_world = to_world * attach;
	// Light hay: a puff upward from the gust, then it settles under gravity.
	float y_free = attach_world.y + (0.9 + 1.5 * drive) * t - 1.2 * t * t;
	float ground = 0.03;
	float landed = smoothstep(ground + 0.25, ground, y_free);
	// Attachment point is relative to the model origin, which sits on the ground.
	float y_world = max(y_free, ground);
	vec3 offset = down_wind * travel + across * lateral + n_world * 0.04 * smoothstep(0.0, 0.2, t);
	offset.y = y_world - attach_world.y;

	// Orientation: upright along the stack while attached, tumbling while in the
	// air, flat once down.
	float a = t * (3.0 + 5.0 * fract(seed * 3.7));
	vec3 axis_air = normalize(up * cos(a) + down_wind * sin(a));
	vec3 flat_axis = normalize(vec3(axis_air.x, 0.0, axis_air.z) + vec3(0.0001, 0.0, 0.0));
	vec3 axis = normalize(mix(axis_air, flat_axis, landed));
	vec3 width_axis = mix(across, normalize(cross(axis, up) + vec3(0.0001)), landed);

	// Grow in at lift-off, shrink away at the end of the cycle.
	float size = released * smoothstep(0.0, 0.04, p) * (1.0 - smoothstep(0.78, 0.97, p));
	vec3 local = (axis * UV.x * length_m + width_axis * UV.y * strand_width) * size;
	vec3 world_move = offset * size + local;
	VERTEX = attach + inverse(to_world) * world_move;
	NORMAL = normalize(inverse(to_world) * normalize(cross(axis, width_axis) + vec3(0.0001)));
}

void fragment() {
	float tip = smoothstep(0.1, 0.5, abs(UV.x));
	vec3 color = mix(mid_color, bleach_color, tip * 0.6 + 0.2) * v_tone;
	ALBEDO = color;
	ROUGHNESS = 0.95;
	BACKLIGHT = color * 0.3;
}
