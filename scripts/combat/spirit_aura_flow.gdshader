// SS-3 (ADR 0041): the aura's flowing field lines and its faint fresnel shell.
// Both meshes are built once by SpiritAuraView and never rebuilt; every frame
// only the seven anchor uniforms change and this vertex stage bends the mesh.
//
// Ribbons (shell_mode = false): UV.x = s, the position around one closed loop,
// UV.y = side (-1/1), UV2 = (line angle 0..1, line width scale). A loop is a
// magnetic dipole field line around the body axis: s 0..RISE climbs the spine
// through the seven lights (root to crown), then the return arc spills out over
// the head, bows around the body and flows back into the root, like water
// circulating or sap rising through the Hingepuu.
// Shell (shell_mode = true): a lathe around the spine curve, UV = (around, up).
//
// The view node is top_level with an identity basis: model space = world space
// translated, so INV_VIEW_MATRIX axes apply directly.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// ADR 0041 colour table, NATURAL aspect order; mirrored by SpiritAuraView.COLORS.
const vec3 COLORS[7] = vec3[7](
	vec3(0.95, 0.16, 0.12), vec3(1.0, 0.52, 0.10), vec3(1.0, 0.86, 0.18),
	vec3(0.25, 0.92, 0.36), vec3(0.22, 0.52, 1.0), vec3(0.40, 0.30, 0.95),
	vec3(0.78, 0.38, 1.0)
);
const float RISE = 0.34;

uniform vec3 anchors[7];
uniform float levels[7];
uniform vec3 facing = vec3(0.0, 0.0, 1.0);
uniform bool shell_mode = false;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// CPU-side from the profile (SpiritAuraView): mean level -> speed and spread,
// shimmer already damped by reduced flashing, turbulence = 1 - clarity.
uniform float flow_speed = 0.2;
uniform float shimmer = 0.1;
uniform float turbulence : hint_range(0.0, 1.0) = 0.0;
uniform float spread = 0.45;
uniform float strength = 1.0;
// Half the root-to-crown span relative to an adult; small animals shrink.
uniform float body_scale = 1.0;
uniform vec3 shell_color = vec3(0.6, 0.55, 1.0);
uniform float shell_strength = 0.2;
// The spine run is inside the torso; slide it toward the camera so the body
// does not hide it, and blend the bias out along the outer arc.
uniform float camera_bias = 0.32;

varying vec3 v_color;
varying float v_level;
varying float v_s;
varying float v_line;
varying float v_side;

vec3 spine_point(float t) {
	float x = clamp(t, 0.0, 1.0) * 6.0;
	int k = clamp(int(floor(x)), 0, 5);
	float f = x - float(k);
	vec3 p0 = anchors[max(k - 1, 0)];
	vec3 p1 = anchors[k];
	vec3 p2 = anchors[k + 1];
	vec3 p3 = anchors[min(k + 2, 6)];
	// Catmull-Rom keeps the climb smooth through every light.
	return 0.5 * (2.0 * p1 + (p2 - p0) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * f * f * f);
}

// Divergence-free field: each component ignores its own axis, so particles
// carried by it neither bunch nor thin out. Stands in for curl noise.
vec3 curl(vec3 p, float t) {
	return vec3(
		cos(p.y * 3.1 + t) - cos(p.z * 2.7 - t * 0.8),
		cos(p.z * 2.9 + t * 1.1) - cos(p.x * 3.3 + t),
		cos(p.x * 2.5 - t * 0.9) - cos(p.y * 3.7 + t * 1.2)
	);
}

void body_frame(out vec3 axis, out vec3 front, out vec3 side) {
	axis = normalize(anchors[6] - anchors[0] + vec3(0.0, 1e-4, 0.0));
	front = facing - axis * dot(facing, axis);
	front = length(front) > 1e-3 ? normalize(front) : vec3(0.0, 0.0, 1.0);
	side = cross(axis, front);
}

// Position along loop s for a line at angle phi; height01 = which light it is beside.
vec3 loop_point(float s, float phi, float width, out float height01, out float bias) {
	vec3 axis;
	vec3 front;
	vec3 side;
	body_frame(axis, front, side);
	vec3 root = anchors[0];
	vec3 crown = anchors[6];
	if (s < RISE) {
		float t = s / RISE;
		// A thin twist around the spine so lines read as separate strands.
		float a = phi * 2.0 * PI + t * 3.0;
		vec3 radial = side * cos(a) + front * sin(a);
		height01 = t;
		bias = 1.0;
		return spine_point(t) + radial * 0.035 * body_scale * (0.4 + sin(PI * t));
	}
	float u = (s - RISE) / (1.0 - RISE);
	float theta = PI * u;
	vec3 mid = (root + crown) * 0.5;
	float h = length(crown - root) * 0.5;
	vec3 outward = side * cos(phi * 2.0 * PI) + front * sin(phi * 2.0 * PI);
	// Dipole-like loop: rises above the crown first (the spill), bows out widest
	// at the waist, dips under the root and curls back into it.
	float axial = h * cos(theta) + 0.2 * h * sin(2.0 * theta);
	float radius = spread * body_scale * width * pow(sin(theta), 0.85);
	vec3 p = mid + axis * axial + outward * radius;
	height01 = clamp(dot(p - root, axis) / max(2.0 * h, 1e-3), 0.0, 1.0);
	bias = 1.0 - smoothstep(0.0, 0.14, u) * smoothstep(1.0, 0.86, u);
	return p;
}

void sample_lights(float height01, out vec3 color, out float level) {
	float x = height01 * 6.0;
	int k = clamp(int(floor(x)), 0, 5);
	float f = smoothstep(0.0, 1.0, x - float(k));
	color = mix(COLORS[k], COLORS[k + 1], f);
	// Absent lights (negative) carry the flow like closed ones.
	level = mix(max(levels[k], 0.0), max(levels[k + 1], 0.0), f);
}

void vertex() {
	vec3 view_dir = INV_VIEW_MATRIX[2].xyz;
	if (shell_mode) {
		vec3 axis;
		vec3 front;
		vec3 side;
		body_frame(axis, front, side);
		float up = UV.y;
		float a = UV.x * 2.0 * PI;
		vec3 radial = side * cos(a) + front * sin(a);
		// Hug the torso and head: wide at hips and chest, pinched at the neck.
		float r = 0.24 - 0.11 * smoothstep(0.55, 0.68, up) + 0.06 * smoothstep(0.7, 0.8, up);
		// Close the ends over the pelvis and the crown.
		r *= body_scale;
		r *= 0.75 + 0.35 * sin(PI * clamp(up, 0.04, 0.96)) - 0.6 * smoothstep(0.9, 1.0, up);
		VERTEX = spine_point(up * 0.92) + radial * r + view_dir * 0.05 * body_scale;
		NORMAL = radial;
		vec3 color;
		float level;
		sample_lights(up, color, level);
		v_color = color;
		v_level = level;
		v_s = up;
		v_side = 0.0;
		v_line = 0.0;
	} else {
		float phi = UV2.x;
		float s = UV.x;
		float height01;
		float bias;
		vec3 p = loop_point(s, phi, UV2.y, height01, bias);
		float dummy_h;
		float dummy_b;
		vec3 ahead = loop_point(fract(s + 0.004), phi, UV2.y, dummy_h, dummy_b);
		vec3 behind = loop_point(fract(s - 0.004 + 1.0), phi, UV2.y, dummy_h, dummy_b);
		// Low clarity: carry the line through the divergence-free field. Choppy,
		// not frantic: the time is advanced in small jerks.
		float jerk = TIME * 0.6 + 0.25 * sin(TIME * 3.0 + phi * 11.0) * turbulence;
		p += curl(p * 1.6 + phi * 3.0, jerk) * 0.1 * body_scale * turbulence * (1.0 - bias * 0.7);
		p += view_dir * camera_bias * body_scale * bias;
		vec3 tangent = ahead - behind;
		vec3 across = cross(tangent, view_dir);
		across = length(across) > 1e-5 ? normalize(across) : vec3(1.0, 0.0, 0.0);
		vec3 color;
		float level;
		sample_lights(height01, color, level);
		v_color = color;
		v_level = level;
		float width = (0.012 + 0.005 * level) * max(body_scale, 0.6);
		VERTEX = p + across * UV.y * width;
		v_s = s;
		v_line = phi;
		v_side = UV.y;
	}
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	if (shell_mode) {
		float rim = pow(1.0 - abs(dot(normalize(NORMAL), VIEW)), 3.0);
		ALBEDO = mix(shell_color, v_color, 0.35);
		ALPHA = rim * shell_strength * fade;
	} else {
		// Comets of light running round the loop; brighter lights run brighter.
		float phase = fract(v_s * 5.0 - TIME * flow_speed + v_line * 0.37);
		float comet = smoothstep(0.0, 0.08, phase) * smoothstep(1.0, 0.35, phase);
		float profile = pow(1.0 - abs(v_side), 1.5);
		float glint = 1.0 + shimmer * sin(TIME * 6.0 + v_s * 47.0 + v_line * 13.0);
		float level_gain = 0.12 + 0.17 * v_level;
		vec3 color = v_color * (0.7 + 0.12 * v_level);
		float alpha = profile * (0.22 + 0.78 * comet) * level_gain * glint * strength;
		// Murky soul: dark smoke streaks drift along the line.
		float smoke = value_noise(vec2(v_s * 16.0 - TIME * 0.45, v_line * 9.0));
		float smoke_mask = smoothstep(0.45, 0.75, smoke) * turbulence;
		color = mix(color, vec3(0.05, 0.04, 0.06), smoke_mask);
		alpha = max(alpha, smoke_mask * profile * 0.8);
		ALBEDO = color;
		ALPHA = clamp(alpha, 0.0, 1.0) * fade;
	}
}
