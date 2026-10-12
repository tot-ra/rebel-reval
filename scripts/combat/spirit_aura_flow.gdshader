// SS-3 (ADR 0041): the aura's flowing field lines and its faint fresnel shell.
// Both meshes are built once by SpiritAuraView and never rebuilt; every frame
// only the seven anchor uniforms change and this vertex stage bends the mesh.
//
// Ribbons (shell_mode = false): UV.x = s, the position along one arc, UV.y =
// side (-1/1), UV2 = (link index + line angle 0..1, line width scale). Each link
// joins two neighbouring lights (root-belly, belly-plexus .. brow-crown) with a
// bundle of nested arcs, like the field lines between two magnet poles
// (maintainer request, 2026-10-11): the field is a stack of small dipoles up
// the spine, and only the crown sends the sky beam on upward (light shader).
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
// The lights sit inside the torso; the arcs get the same depth pull as the
// lights (spirit_aura_light camera_bias) so the body does not hide them either.
uniform float camera_bias = 0.45;
// The environment adjustment saturation of the frame (SpiritAuraView pushes it);
// mirrors spirit_aura_light saturate_for_world.
uniform float world_saturation = 1.0;

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

// Projects a model-space point to clip space at its true screen position but with
// the depth of a point `bias` metres nearer the camera. The old approach moved
// the geometry itself toward the camera, which in a perspective view made the
// lights slide off the body as the camera orbited (parallax); shifting only the
// depth keeps them glued to the bones while the torso still cannot hide them.
vec4 depth_biased_clip(vec3 model_pos, float bias, mat4 modelview, mat4 projection) {
	vec4 view = modelview * vec4(model_pos, 1.0);
	vec4 clip = projection * view;
	// Never pull the depth past the near plane (view space looks down -Z).
	float pull = clamp(-view.z - 0.05, 0.0, bias);
	vec4 nearer = projection * vec4(view.xyz + vec3(0.0, 0.0, pull), 1.0);
	clip.z = nearer.z / nearer.w * clip.w;
	return clip;
}

void body_frame(out vec3 axis, out vec3 front, out vec3 side) {
	axis = normalize(anchors[6] - anchors[0] + vec3(0.0, 1e-4, 0.0));
	front = facing - axis * dot(facing, axis);
	front = length(front) > 1e-3 ? normalize(front) : vec3(0.0, 0.0, 1.0);
	side = cross(axis, front);
}

// Position along the arc of `link` (light k to light k + 1) at s 0..1 for a
// line at angle phi. The arc leaves one light, bows out to the side and enters
// the next; wider arcs for longer links, stronger lights and outer lines.
vec3 link_point(int link, float s, float phi, float width, float link_level) {
	vec3 axis;
	vec3 front;
	vec3 side;
	body_frame(axis, front, side);
	vec3 a = anchors[link];
	vec3 b = anchors[link + 1];
	float a_phi = phi * 2.0 * PI;
	vec3 outward = side * cos(a_phi) + front * sin(a_phi);
	vec3 mid = (a + b) * 0.5;
	vec3 half_span = (b - a) * 0.5;
	float span = 2.0 * length(half_span);
	float bend = sin(PI * s);
	// Like iron filings round a bar magnet: the line leaves one pole away from
	// the other (the overshoot past the pole), swings out and comes round into
	// the other pole from beyond it, so each link reads as an apple-shaped field.
	float overshoot = 1.0 + 1.1 * width * bend * bend;
	float bulge = (0.75 * span + 0.05 * width) * body_scale * (0.8 + 0.08 * link_level)
		* spread / 0.45;
	return mid - half_span * cos(PI * s) * overshoot + outward * bulge * bend;
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
		int link = clamp(int(floor(UV2.x)), 0, 5);
		float phi = fract(UV2.x);
		float s = UV.x;
		// Absent lights (negative) carry the flow like closed ones. A link is as
		// strong as its weaker end: a black hole starves the arcs it touches.
		float la = max(levels[link], 0.0);
		float lb = max(levels[link + 1], 0.0);
		float link_level = mix(min(la, lb), 0.5 * (la + lb), 0.4);
		vec3 p = link_point(link, s, phi, UV2.y, link_level);
		vec3 ahead = link_point(link, min(s + 0.02, 1.0), phi, UV2.y, link_level);
		vec3 behind = link_point(link, max(s - 0.02, 0.0), phi, UV2.y, link_level);
		// Low clarity: carry the line through the divergence-free field. Choppy,
		// not frantic: the time is advanced in small jerks. The ends stay on the lights.
		float jerk = TIME * 0.6 + 0.25 * sin(TIME * 3.0 + phi * 11.0) * turbulence;
		p += curl(p * 1.6 + phi * 3.0, jerk) * 0.06 * body_scale * turbulence * sin(PI * s);
		vec3 tangent = ahead - behind;
		vec3 across = cross(tangent, view_dir);
		across = length(across) > 1e-5 ? normalize(across) : vec3(1.0, 0.0, 0.0);
		float f = smoothstep(0.0, 1.0, s);
		v_color = mix(COLORS[link], COLORS[link + 1], f);
		v_level = mix(mix(la, lb, f), link_level, 0.5);
		float width = (0.0045 + 0.0015 * v_level) * max(body_scale, 0.6);
		VERTEX = p + across * UV.y * width;
		v_s = s;
		v_line = phi + float(link) * 0.21;
		v_side = UV.y;
		POSITION = depth_biased_clip(VERTEX, camera_bias * body_scale, MODELVIEW_MATRIX,
			PROJECTION_MATRIX);
	}
}

vec3 saturate_for_world(vec3 c) {
	float mean = (c.r + c.g + c.b) / 3.0;
	return max(vec3(mean) + (c - vec3(mean)) / max(world_saturation, 0.2), vec3(0.0));
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
		// Comets of light climbing each arc from the lower light to the upper one;
		// brighter lights run brighter.
		float phase = fract(v_s * 1.5 - TIME * flow_speed * 2.5 + v_line * 0.37);
		float comet = smoothstep(0.0, 0.08, phase) * smoothstep(1.0, 0.35, phase);
		// A crisp line, not a soft gradient (maintainer request 2026-10-12): a solid
		// core with a one-pixel antialiased edge and only a thin faint fringe, so the
		// arcs read as drawn lines up close as well as far away.
		float side = abs(v_side);
		float aa = max(fwidth(side), 1e-4);
		float profile = (1.0 - smoothstep(0.5 - aa, 0.5 + aa, side)) + 0.2 * (1.0 - side);
		float glint = 1.0 + shimmer * sin(TIME * 6.0 + v_s * 47.0 + v_line * 13.0);
		float level_gain = 0.28 + 0.12 * v_level;
		vec3 color = v_color * (0.8 + 0.08 * v_level);
		float alpha = profile * (0.45 + 0.55 * comet) * level_gain * glint * strength;
		// Murky soul: dark smoke streaks drift along the line.
		float smoke = value_noise(vec2(v_s * 5.0 - TIME * 0.45, v_line * 9.0));
		float smoke_mask = smoothstep(0.45, 0.75, smoke) * turbulence;
		color = mix(color, vec3(0.05, 0.04, 0.06), smoke_mask);
		alpha = max(alpha, smoke_mask * profile * 0.8);
		ALBEDO = saturate_for_world(color);
		ALPHA = clamp(alpha, 0.0, 1.0) * fade;
	}
}
