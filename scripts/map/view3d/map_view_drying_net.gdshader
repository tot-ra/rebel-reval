shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;

#include "res://scripts/map/view3d/wind_field.gdshaderinc"

// R-1640 drying net (MapViewDryingNet). UV is in metres: x along the pole, y the
// signed hang distance (float side negative). The CPU Verlet cloth carries the
// swing; this shader draws knotted diamond mesh at true scale and adds only the
// fine shiver. Grey: untarred hemp and flax bleach grey on the shore.

uniform vec3 twine_color : source_color = vec3(0.56, 0.555, 0.52);
// Knot-to-knot bar length in metres. Herring nets of the period ran 2-4 cm bars.
uniform float bar_length = 0.035;
// Twine thickness as a fraction of one diamond cell.
uniform float twine_width = 0.085;
// Metres of net per metre of pole (MapViewDryingNet.GATHER): a gathered net's
// diamonds close into tall slits.
uniform float gather = 1.8;
uniform float flutter = 0.02;
// Share of the far-field veil that stays opaque once single strands blur
// below a pixel: piled, pleated net reads denser than one layer would.
uniform float far_cover = 0.5;
instance uniform float motion_phase = 0.0;

varying float v_hang;

void vertex() {
	v_hang = abs(UV.y);
	// The row on the pole stays exact; the shiver grows down the hang.
	float free_w = smoothstep(0.0, 0.7, v_hang);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float s = wind_strength();
	float ripple = sin(TIME * 4.1 + world.x * 2.3 + world.z * 1.7 + motion_phase)
		+ 0.5 * sin(TIME * 6.3 - world.x * 3.1 + UV.y * 5.0 + motion_phase * 1.7);
	VERTEX += NORMAL * ripple * flutter * (0.3 + s) * free_w * wind_flutter_scale();
}

float dither(vec2 frag) {
	// Interleaved gradient noise: a stable screen-door threshold without arrays.
	return fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
}

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	// Diamond mesh: two families of twine at 45 degrees to the pole.
	vec2 net_uv = vec2(UV.x * gather, UV.y * 0.75);
	// Hand-knotted twine is never ruler-straight: a slow wobble breaks the
	// chain-link regularity without moving the knots off the grid.
	net_uv += 0.006 * vec2(sin(UV.y * 23.0 + UV.x * 3.0), sin(UV.x * 19.0 - UV.y * 4.0));
	vec2 cell = vec2(net_uv.x + net_uv.y, net_uv.x - net_uv.y) * (0.70710678 / bar_length);
	vec2 fw = max(fwidth(cell), vec2(1e-4));
	vec2 e = 0.5 - abs(fract(cell) - 0.5);
	// Strands never get thinner than about a pixel: with alpha scissor a sub-pixel
	// strand would be discarded and the net would vanish at mid range.
	vec2 half_w = max(vec2(twine_width * 0.5), fw * 0.6);
	vec2 line = 1.0 - smoothstep(half_w - fw * 0.5, half_w + fw * 0.5, e);
	float strand = max(line.x, line.y);
	// Sheet-bend knot where the strands cross.
	float knot = 1.0 - smoothstep(twine_width * 0.85 - fw.x * 0.5, twine_width * 0.85 + fw.x * 0.5, length(e));
	float near_alpha = max(strand, knot);
	// Once a cell shrinks under ~3 pixels the strands alias into moire; fade to a
	// screen-door veil instead of a solid sheet.
	float blur = smoothstep(0.18, 0.45, max(fw.x, fw.y));
	float far_alpha = step(dither(FRAGCOORD.xy), far_cover);
	ALPHA = mix(near_alpha, far_alpha, blur);
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	// Weathering: broad blotches where the net dried unevenly, damper hems below,
	// and knots a shade darker where fibre bunches and holds grime.
	vec2 blot_p = UV * 1.7;
	float blot = mix(hash12(floor(blot_p)), hash12(floor(blot_p) + 1.0), fract(blot_p.x));
	float tone = mix(0.82, 1.08, blot);
	tone *= mix(0.8, 1.0, 1.0 - smoothstep(0.4, 2.0, v_hang));
	tone *= mix(1.0, 0.82, knot * (1.0 - blur));
	ALBEDO = twine_color * tone;
	ROUGHNESS = 0.96;
	SPECULAR = 0.14;
}
