shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// Expanding ripple on a puddle after a boot lands (CityPuddleStepVfx).
//
// WHY a shader and not a torus mesh: an 8-16 segment torus read as a hard white
// polygon on the water. A soft, double-edged ring on a flat quad is a wave crest with
// a trough behind it, and a second fainter ring trails the first like real ripples.

// 0 at impact, 1 when the ripple is gone.
uniform float progress = 0.0;
// Wave crest catches a dim sky; the trough behind it is dark water. Both stay far below
// white so the ripple reads as relief in the puddle (like wind ripples), not a HUD
// ring, and does not glow at night (the shader is unshaded).
uniform vec3 tint : source_color = vec3(0.42, 0.5, 0.56);
uniform vec3 trough_tint : source_color = vec3(0.05, 0.07, 0.09);
uniform float strength = 0.42;

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
	// Dark trough just inside each crest; the pair is what makes a ring look like a wave.
	float trough = (ring(r, 0.64, 0.1) + ring(r, 0.4, 0.08) * 0.6) * wobble * fade;
	float crest = (front + trail) * wobble * fade;
	ALBEDO = mix(trough_tint, tint, crest / max(crest + trough, 0.001));
	ALPHA = clamp((crest * 0.8 + trough * 1.1) * strength, 0.0, 1.0);
}
