// SS-3 (ADR 0041): the seven soul lights of one aura in a single draw call.
// The mesh is fifteen unit quads (UV in -1..1, UV2.x = quad index) built once by
// SpiritAuraView; the vertex stage places each quad from the anchor uniforms.
// Quads 0..6, the lights: a level-0 light is a black hole, a black core that
// keeps its colour in concentric rings toward the rim with colour swirling
// inward; 1 ember .. 5 a blazing corona, a solid coloured ball a little brighter
// than daylight (maintainer request, 2026-10-11). Every light breathes slowly.
// `calm` (reduced flashing) stills the swirl and the breath.
// A negative level is an absent light (animals): nothing is drawn.
// glow_only collapses the aura to one soft glow for the distant LOD tier.
// Quad 7, the sky beam: a white column rising from the crown, width from
// SpiritAuraView.sky_beam_strength (all levels, the crown as the bottleneck):
// a thread for a weak or narrow-crowned soul, a pillar for a whole one. It
// billboards around the vertical axis only, so it stays upright. Low clarity
// breaks it into stuttering pieces; `calm` slows the rise.
// Quads 8..14, the earth tethers of lights 0..6: dark lines from a closed or
// dim light down into the ground, the counterweight of the beam (strength
// mirrors SpiritAuraView.earth_tether_for_level). They splay apart toward the
// ground like chains, with pulses running down.
// The view node is top_level with an identity basis, so model space is world
// space translated: camera axes from INV_VIEW_MATRIX apply directly.
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
// Ground height relative to the root light (negative: below the pelvis).
uniform float ground = -0.95;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float calm : hint_range(0.0, 1.0) = 0.0;
uniform bool glow_only = false;
uniform vec3 glow_color = vec3(0.6, 0.5, 1.0);
uniform float glow_strength = 0.5;
// Half the root-to-crown span relative to an adult; small animals shrink.
uniform float body_scale = 1.0;
// Lights sit inside the torso; their depth (not their position) is pulled this
// far toward the camera so the body does not hide them. See depth_biased_clip.
uniform float camera_bias = 0.45;
uniform float beam_strength : hint_range(0.0, 1.0) = 0.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.0;
// Mirrors SpiritAuraView.SKY_BEAM_MAX_HEIGHT; the beam starts at 2.5 m.
const float BEAM_MIN_HEIGHT = 2.5;
const float BEAM_MAX_HEIGHT = 12.0;

varying vec2 v_uv;
varying float v_level;
varying float v_index;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Mirrors SpiritAuraView.earth_tether_for_level.
float tether_strength(float level) {
	return level < 0.0 ? 0.0 : clamp((1.5 - level) / 1.5, 0.0, 1.0);
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

void vertex() {
	int quad = int(UV2.x + 0.5);
	float bias = camera_bias * body_scale;
	if (quad == 7) {
		float s = glow_only ? 0.0 : beam_strength;
		vec3 base = anchors[6];
		vec3 side = cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz);
		side = length(side) > 0.001 ? normalize(side) : INV_VIEW_MATRIX[0].xyz;
		float height = mix(BEAM_MIN_HEIGHT, BEAM_MAX_HEIGHT, s) * body_scale;
		// Squared: a narrow crown or a weak soul shows a thread, a whole soul a
		// pillar about as wide as the body.
		float width = (0.02 + 0.46 * s * s) * body_scale * step(0.001, s);
		float along = UV.y * 0.5 + 0.5;
		VERTEX = base + side * UV.x * width + vec3(0.0, along * height - 0.04 * body_scale, 0.0);
		VERTEX *= step(0.001, s);
		v_uv = UV;
		v_level = s;
		v_index = 7.0;
	} else if (quad >= 8) {
		int i = clamp(quad - 8, 0, 6);
		float s = glow_only ? 0.0 : tether_strength(levels[i]);
		vec3 top = anchors[i];
		// Splay sideways by the light's place so several tethers read apart.
		vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), facing) + vec3(1e-4, 0.0, 0.0));
		vec3 bottom = vec3(anchors[i].x, ground, anchors[i].z)
			+ side * (float(i) - 3.0) * 0.09 * body_scale;
		float along = 0.5 - UV.y * 0.5;
		vec3 line = bottom - top;
		vec3 across = cross(line, INV_VIEW_MATRIX[2].xyz);
		across = length(across) > 1e-5 ? normalize(across) : INV_VIEW_MATRIX[0].xyz;
		float width = (0.012 + 0.03 * s) * body_scale;
		VERTEX = (top + line * along + across * UV.x * width) * step(0.001, s);
		v_uv = vec2(UV.x, along);
		v_level = s;
		v_index = 8.0 + float(i);
	} else {
		int i = clamp(quad, 0, 6);
		float level = levels[i];
		// About 0.2 Hz: one slow breath every five seconds, phase-shifted per light.
		float breath = sin(TIME * 1.26 + float(i) * 0.9);
		float size = (0.12 + 0.045 * level) * (1.0 + 0.09 * breath * (1.0 - calm)) * body_scale;
		if (level < 0.0) {
			size = 0.0;
		}
		vec3 center = anchors[i];
		if (glow_only) {
			center = anchors[3];
			size = i == 3 ? 0.85 * body_scale : 0.0;
		}
		VERTEX = center + (INV_VIEW_MATRIX[0].xyz * UV.x + INV_VIEW_MATRIX[1].xyz * UV.y) * size;
		v_uv = UV;
		v_level = level;
		v_index = float(i);
	}
	POSITION = depth_biased_clip(VERTEX, bias, MODELVIEW_MATRIX, PROJECTION_MATRIX);
}

void fragment() {
	if (v_index > 7.5) {
		// Earth tether: a dark core with a rim of the light's colour, dark knots
		// sliding down toward the ground as if the soul is dragged down.
		int i = clamp(int(v_index - 8.0 + 0.5), 0, 6);
		float s = v_level;
		float x = v_uv.x;
		float h = v_uv.y;
		float core = exp(-x * x * 9.0);
		float rim = smoothstep(0.35, 0.75, abs(x)) * smoothstep(1.0, 0.75, abs(x));
		float pull = fract(h * 9.0 - TIME * 0.7 * (1.0 - 0.85 * calm));
		float knot = smoothstep(0.0, 0.2, pull) * smoothstep(0.6, 0.2, pull);
		// The rim keeps the light's colour so the tether reads on a dark night.
		vec3 dark = vec3(0.03, 0.02, 0.03);
		ALBEDO = mix(COLORS[i] * 0.8, dark, smoothstep(0.2, 0.9, core) * (0.75 + 0.25 * knot));
		// Fades in out of the light and sinks into the ground at the far end.
		float ends = smoothstep(0.0, 0.08, h) * smoothstep(1.0, 0.9, h);
		ALPHA = clamp((core * (0.7 + 0.25 * knot) + rim * 0.75) * ends * (0.4 + 0.6 * s), 0.0, 1.0)
			* fade;
	} else if (v_index > 6.5) {
		// Sky beam: white, its width carries the strength.
		float s = v_level;
		float x = v_uv.x;
		float h = v_uv.y * 0.5 + 0.5;
		// Both fall to zero at the quad edge so a wide pillar shows no box.
		float edge = 1.0 - x * x;
		float core = exp(-x * x * mix(22.0, 6.0, s)) * edge;
		float halo = exp(-x * x * 3.0) * 0.3 * edge * edge;
		// Pulses of light climbing toward the sky, faster in a stronger soul.
		float rise = fract(h * 7.0 - TIME * (0.25 + 0.55 * s) * (1.0 - 0.85 * calm));
		float pulse = smoothstep(0.0, 0.12, rise) * smoothstep(0.55, 0.12, rise);
		float taper = pow(1.0 - h, 1.4) * smoothstep(0.0, 0.03, h);
		// A soft round flare at the crown instead of a hard bottom edge.
		float flare = smoothstep(0.1, 0.0, h) * 0.6 * smoothstep(0.0, 0.025, h);
		// A torn soul's tie to the sky stutters: pieces drop out in steps.
		float step_time = floor(TIME * 5.0 * (1.0 - calm));
		float piece = hash(vec2(floor(h * 9.0), step_time));
		float broken = mix(1.0, step(0.45, piece), turbulence * 0.8);
		ALBEDO = mix(vec3(0.9, 0.93, 1.0), vec3(1.0), core);
		ALPHA = clamp((core * mix(0.85, 0.7, s) + halo + pulse * core * 0.6) * (taper + flare) * broken,
			0.0, 1.0)
			* clamp(0.35 + s, 0.0, 1.0) * fade;
	} else {
		float r = length(v_uv);
		if (r > 1.0) {
			discard;
		}
		if (glow_only) {
			float soft = exp(-r * r * 4.0) * (1.0 - r);
			ALBEDO = glow_color;
			ALPHA = soft * glow_strength * fade;
		} else {
			int i = int(v_index + 0.5);
			vec3 col = COLORS[i];
			float level = v_level;
			float lit = clamp(level, 0.0, 1.0);
			float l01 = clamp(level / 5.0, 0.0, 1.0);
			// A solid coloured ball inside a soft halo: the ball whitens and the halo
			// widens with the level. Peak slightly above 1 so a bright light reads a
			// touch brighter than the lit world around it, never sun-white.
			float ball = smoothstep(0.36, 0.26, r);
			float halo = exp(-r * r * mix(8.0, 3.0, l01));
			float core = smoothstep(0.3, 0.0, r);
			vec3 glow = mix(col, vec3(1.0, 0.98, 0.93), core * (0.15 + 0.5 * l01))
				* (0.85 + 0.06 * level);
			float glow_alpha = ball * (0.55 + 0.09 * level) + halo * (0.3 + 0.1 * level);
			// Corona rays for radiant (4) and blazing (5) lights.
			float angle = atan(v_uv.y, v_uv.x);
			float rays = pow(abs(sin(angle * 6.0 + TIME * 0.25 * (1.0 - calm))), 10.0);
			float corona = rays * smoothstep(1.0, 0.35, r) * smoothstep(0.15, 0.4, r);
			glow_alpha += corona * clamp(level - 3.0, 0.0, 2.0) * 0.28;
			// Closed light, a black hole: black at the centre, its colour returning
			// in a concentric gradient toward a glowing rim, swirling inward.
			float swirl = 0.5 + 0.5 * sin(angle * 2.0 + r * 10.0 + TIME * 1.6 * (1.0 - calm));
			float depth = smoothstep(0.08, 0.62, r);
			vec3 hole = col * depth * depth * (0.55 + 0.45 * swirl);
			float horizon = smoothstep(0.14, 0.0, abs(r - 0.6));
			hole = mix(hole, col * 1.05, horizon);
			float hole_alpha = smoothstep(0.82, 0.62, r) * 0.95 + horizon * 0.5
				+ smoothstep(1.0, 0.6, r) * 0.2;
			ALBEDO = mix(hole, glow, lit);
			ALPHA = clamp(mix(hole_alpha, glow_alpha, lit), 0.0, 1.0) * fade;
		}
	}
}
