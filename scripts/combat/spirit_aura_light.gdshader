// SS-3 (ADR 0041): the seven soul lights of one aura in a single draw call.
// The mesh is seven unit quads (UV in -1..1, UV2.x = light index) built once by
// SpiritAuraView; the vertex stage billboards each quad onto its anchor uniform.
// Level 0 is a dark crackling knot, 1 ember .. 5 a blazing corona; every light
// breathes slowly. `calm` (reduced flashing) stills the crackle and the breath.
// A negative level is an absent light (animals): nothing is drawn.
// glow_only collapses the aura to one soft glow for the distant LOD tier.
// Quad 7 is the sky beam: a column of violet-white light rising from the crown,
// strength from SpiritAuraView.sky_beam_strength (all levels, gated by the
// crown). It billboards around the vertical axis only, so it stays upright.
// Low clarity breaks it into stuttering pieces; `calm` slows the rise.
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
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float calm : hint_range(0.0, 1.0) = 0.0;
uniform bool glow_only = false;
uniform vec3 glow_color = vec3(0.6, 0.5, 1.0);
uniform float glow_strength = 0.5;
// Half the root-to-crown span relative to an adult; small animals shrink.
uniform float body_scale = 1.0;
// Lights sit inside the torso; slide them toward the camera so the body does
// not hide them. Orthographic gameplay sees no screen-space shift from this.
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

void vertex() {
	if (int(UV2.x + 0.5) == 7) {
		float s = glow_only ? 0.0 : beam_strength;
		vec3 base = anchors[6] + INV_VIEW_MATRIX[2].xyz * camera_bias * body_scale;
		vec3 side = cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz);
		side = length(side) > 0.001 ? normalize(side) : INV_VIEW_MATRIX[0].xyz;
		float height = mix(BEAM_MIN_HEIGHT, BEAM_MAX_HEIGHT, s) * body_scale;
		float width = (0.06 + 0.22 * s) * body_scale * step(0.001, s);
		float along = UV.y * 0.5 + 0.5;
		VERTEX = base + side * UV.x * width + vec3(0.0, along * height - 0.04 * body_scale, 0.0);
		VERTEX *= step(0.001, s);
		v_uv = UV;
		v_level = s;
		v_index = 7.0;
	} else {
		int i = clamp(int(UV2.x + 0.5), 0, 6);
		float level = levels[i];
		// About 0.2 Hz: one slow breath every five seconds, phase-shifted per light.
		float breath = sin(TIME * 1.26 + float(i) * 0.9);
		float size = (0.1 + 0.055 * level) * (1.0 + 0.09 * breath * (1.0 - calm)) * body_scale;
		if (level < 0.0) {
			size = 0.0;
		}
		vec3 center = anchors[i];
		if (glow_only) {
			center = anchors[3];
			size = i == 3 ? 0.85 * body_scale : 0.0;
		}
		center += INV_VIEW_MATRIX[2].xyz * camera_bias * body_scale;
		VERTEX = center + (INV_VIEW_MATRIX[0].xyz * UV.x + INV_VIEW_MATRIX[1].xyz * UV.y) * size;
		v_uv = UV;
		v_level = level;
		v_index = float(i);
	}
}

void fragment() {
	if (v_index > 6.5) {
		float s = v_level;
		float x = v_uv.x;
		float h = v_uv.y * 0.5 + 0.5;
		float core = exp(-x * x * 22.0);
		float halo = exp(-x * x * 3.5) * 0.3;
		// Pulses of light climbing toward the sky, faster in a stronger soul.
		float rise = fract(h * 7.0 - TIME * (0.25 + 0.55 * s) * (1.0 - 0.85 * calm));
		float pulse = smoothstep(0.0, 0.12, rise) * smoothstep(0.55, 0.12, rise);
		float taper = pow(1.0 - h, 1.4) * smoothstep(0.0, 0.03, h);
		float flare = smoothstep(0.1, 0.0, h) * 0.6;
		// A torn soul's tie to the sky stutters: pieces drop out in steps.
		float step_time = floor(TIME * 5.0 * (1.0 - calm));
		float piece = hash(vec2(floor(h * 9.0), step_time));
		float broken = mix(1.0, step(0.45, piece), turbulence * 0.8);
		vec3 col = mix(COLORS[6], vec3(1.0, 0.97, 0.92), core * 0.7);
		ALBEDO = col;
		ALPHA = clamp((core * 0.85 + halo + pulse * core * 0.6) * (taper + flare) * broken, 0.0, 1.0)
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
			// Halo widens and the core whitens with the level.
			float halo = exp(-r * r * mix(9.0, 3.2, level / 5.0));
			float core = smoothstep(0.42, 0.0, r) * level / 5.0;
			vec3 glow = mix(col, vec3(1.0, 0.97, 0.9), core * 0.65) * (0.75 + 0.1 * level);
			float glow_alpha = halo * (0.3 + 0.14 * level);
			// Corona rays for radiant (4) and blazing (5) lights.
			float angle = atan(v_uv.y, v_uv.x);
			float rays = pow(abs(sin(angle * 6.0 + TIME * 0.25 * (1.0 - calm))), 10.0);
			float corona = rays * smoothstep(1.0, 0.35, r) * smoothstep(0.15, 0.4, r);
			glow_alpha += corona * clamp(level - 3.0, 0.0, 2.0) * 0.28;
			// Closed light: a dark knot with thin cracks of its colour that flicker in
			// steps (still under reduced flashing).
			float step_time = floor(TIME * 7.0 * step(calm, 0.5));
			float jitter = hash(vec2(v_index, step_time)) * 6.28;
			float crack = smoothstep(0.12, 0.0, abs(sin(angle * 3.0 + r * 5.0 + jitter)));
			crack *= step(0.4, hash(vec2(floor(angle * 1.9 + 6.0), step_time))) * smoothstep(0.8, 0.2, r);
			vec3 knot = mix(vec3(0.04, 0.02, 0.05), col * 1.1, crack);
			float knot_alpha = smoothstep(0.75, 0.35, r) * 0.85 + crack * 0.4;
			ALBEDO = mix(knot, glow, lit);
			ALPHA = clamp(mix(knot_alpha, glow_alpha, lit), 0.0, 1.0) * fade;
		}
	}
}
