shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// Expanding ripple on a puddle after a boot lands (CityPuddleStepVfx).
//
// WHY a shader and not a torus mesh: an 8-16 segment torus read as a hard white
// polygon on the water. A soft, double-edged ring on a flat quad is a wave crest with
// a trough behind it, and a second fainter ring trails the first like real ripples.

// 0 at impact, 1 when the ripple is gone.
uniform float progress = 0.0;
uniform vec3 tint : source_color = vec3(0.86, 0.93, 0.98);
uniform float strength = 0.5;

float ring(float r, float centre, float width) {
	return 1.0 - smoothstep(0.0, width, abs(r - centre));
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	// Rim of the quad is the ripple front; the second ring follows 0.22 behind it.
	float front = ring(r, 0.78, 0.12);
	float trail = ring(r, 0.52, 0.09) * 0.55;
	float fade = pow(1.0 - progress, 1.6);
	// A little break-up so the ring is not a perfect vector circle.
	float a = atan(UV.y - 0.5, UV.x - 0.5);
	float wobble = 0.8 + 0.2 * sin(a * 5.0 + progress * 6.0);
	ALBEDO = tint;
	ALPHA = clamp((front + trail) * wobble * fade * strength, 0.0, 1.0);
}
