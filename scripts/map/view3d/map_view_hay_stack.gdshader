shader_type spatial;

// Hay stack surface: one shader for the body (shell = 0) and the hair-like fur
// shells grown over it (shell > 0, see MapViewHayMeshes.add_rick).
//
// Why shells: the body mesh alone is a smooth egg whatever the albedo. Each
// shell re-draws the same mesh pushed out along its normal and keeps only the
// pixels that fall on a strand, so the silhouette and the lit surface gain real
// stalks. Strands live on an angle x height lattice of the stack's own model
// space, so they stay glued to the hay when the flank yields or the wind sways it.
//
// Wind: the shared gust field (wind_field.gdshaderinc). The whole mass leans a
// little with height, outer shells lean and flutter more, so the loose top layer
// ripples as a gust front crosses while the core barely moves.
#include "res://scripts/map/view3d/wind_field.gdshaderinc"

render_mode cull_back;

uniform sampler2D fiber_tex : source_color, filter_linear_mipmap, repeat_enable;
// 0 = solid body; 0..1 = how far out this fur shell sits.
uniform float shell : hint_range(0.0, 1.0) = 0.0;
// How far the outermost shell stands off the body, model metres.
uniform float fur_length = 0.11;
// Dry hay is grey-gold, not saturated yellow: damp shade inside, bleached tips.
uniform vec3 shade_color : source_color = vec3(0.22, 0.18, 0.10);
uniform vec3 mid_color : source_color = vec3(0.44, 0.36, 0.20);
uniform vec3 bleach_color : source_color = vec3(0.62, 0.55, 0.36);
// Model-space height used to weight the lean of the crown.
uniform float stack_height = 2.8;
uniform float sway_amount = 0.05;
uniform float strand_density = 340.0;

varying vec3 v_rest;
varying vec3 v_normal;

vec2 world_to_model_xz(mat4 model, vec2 w) {
	vec3 m = inverse(mat3(model)) * vec3(w.x, 0.0, w.y);
	return m.xz;
}

void vertex() {
	v_rest = VERTEX;
	v_normal = NORMAL;
	vec2 wd = wind_dir();
	float ws = wind_strength();
	vec2 origin = MODEL_MATRIX[3].xz;
	float push = wind_pressure(origin + VERTEX.xz * 0.5, TIME);
	float height = clamp(VERTEX.y / stack_height, 0.0, 1.0);
	// Whole mass: a slow lean that grows with height squared.
	vec2 world_move = wd * ws * push * sway_amount * height * height;
	// Fur: stalks stand off the body, droop under their own weight, and the outer
	// ones lean downwind and shiver. Phase from the stalk lattice cell so
	// neighbours move out of step but each one stays coherent over time.
	if (shell > 0.0) {
		float cell = floor(atan(VERTEX.z, VERTEX.x) / TAU * strand_density);
		float ph = wind_cell_hash(vec2(cell, floor(VERTEX.y * 7.0)));
		float reach = shell * shell;
		float flutter = sin(TIME * (5.0 + 4.0 * ph) + ph * 40.0 + VERTEX.y * 3.0);
		vec2 across = vec2(-wd.y, wd.x);
		world_move += (wd * push * ws * 0.9 + across * flutter * ws * wind_flutter_scale() * 0.35)
			* reach * fur_length * 1.6;
		VERTEX += NORMAL * shell * fur_length;
		VERTEX.y -= shell * shell * fur_length * 0.45;
	}
	VERTEX.xz += world_to_model_xz(MODEL_MATRIX, world_move);
}

void fragment() {
	vec3 p = v_rest;
	float ang = atan(p.z, p.x) / TAU;
	// Each column is offset in height by its own amount, so the cell borders do not
	// line up into visible horizontal courses.
	float col = floor(ang * strand_density);
	vec2 id_uv = vec2(ang * strand_density, p.y / 0.16 + wind_cell_hash(vec2(col, 3.0)) * 7.0);
	vec2 id = floor(id_uv);
	vec2 f = fract(id_uv);
	float h1 = wind_cell_hash(id);
	float h2 = wind_cell_hash(id + vec2(17.3, 5.1));
	// Strands run roughly up and down, each leaning its own way.
	float x = f.x - 0.5 + (f.y - 0.5) * (h2 - 0.5) * 1.1 - (h1 - 0.5) * 0.35;
	// Strand length: 0.35..1 of the fur height; thinner toward the tip.
	float reach = mix(0.35, 1.0, h2);
	float half_w = 0.46;
	if (shell > 0.0) {
		if (shell > reach) {
			discard;
		}
		half_w = 0.46 * (1.0 - 0.75 * shell / reach);
		if (abs(x) > half_w) {
			discard;
		}
	}
	// Biplanar fibre texture in model space, stretched vertically so it reads as
	// strands combed down the flank instead of an isotropic scribble.
	vec3 n = normalize(abs(v_normal) + vec3(0.001));
	float tex_a = texture(fiber_tex, p.zy * vec2(1.9, 0.75)).r;
	float tex_b = texture(fiber_tex, p.xy * vec2(1.9, 0.75) + 0.37).r;
	float fiber = mix(tex_b, tex_a, clamp(n.x / (n.x + n.z + 0.001), 0.0, 1.0));
	// Per-strand tone and a dark seam between strands inside the mass.
	float tone = mix(0.78, 1.12, h1) * mix(0.72, 1.18, fiber);
	vec3 base = mix(mid_color, bleach_color, smoothstep(0.35, 0.95, h2 * 0.7 + fiber * 0.5));
	float edge = smoothstep(half_w * 0.55, half_w, abs(x));
	vec3 color = base * tone;
	color = mix(color, shade_color, edge * 0.55 * (shell > 0.0 ? 0.0 : 1.0));
	if (shell > 0.0) {
		// Fur: dark at the root, bleached at the tip, so layers read as depth.
		color = mix(mix(shade_color, mid_color, 0.7), mix(color, bleach_color, 0.45), shell);
	} else {
		// Damp, dark foot of the stack; the baked vertex tone carries it.
		color *= COLOR.rgb;
	}
	ALBEDO = color;
	ROUGHNESS = 0.96;
	SPECULAR = 0.25;
	// Straw is translucent: the sun side bleeds through thin crowns and fur.
	BACKLIGHT = color * 0.22;
	RIM = 0.18;
	RIM_TINT = 0.6;
}
