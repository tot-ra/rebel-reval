// Whole-tree wind shared by the crown shader (map_view_canopy.gdshader) and the
// bark shader (map_view_bark_wind.gdshader). Both call the SAME functions with
// the same inputs, so a branch and the leaf cards growing on it move together
// and foliage never tears off its limbs.
//
// Three scales, slowest to fastest, thicker to thinner:
//   trunk lean   - the whole bole leans with height; every vertex gets it
//   limb bend    - low-frequency heave that grows with height squared
//   twig sway    - quicker, larger motion that only thin parts take (flex ~ 1)
// `flex` is 0 for the trunk and 1 for twig tips (the bark mesh stores it in
// COLOR.a from the segment radius); thick limbs therefore move little and
// thin ones move a lot. All three scale with the shared weather wind
// (wind_strength_g), so a calm day barely stirs the wood and a storm whips it.
#include "res://scripts/map/view3d/wind_field.gdshaderinc"

// Thick limbs keep this share of the limb bend; twig tips take all of it, which
// is what the leaves (always on thin shoots) get.
const float TREE_THICK_BEND_SHARE = 0.3;

// Heave of a limb point at model height y. `x` only decorrelates the phase of
// neighbouring limbs. Same maths the crown always used for its leaves.
vec2 tree_limb_bend(vec2 wind, vec2 origin, float x, float y, float strength,
		float sway_strength, float push, float t) {
	float gust = push - 0.35;
	float height = clamp(y * 0.18, 0.0, 1.0);
	float limb = sin(t * 0.9 + dot(origin, vec2(0.37, 0.53)) + x * 0.8) * 0.5 + 0.5;
	return wind * (gust * 0.6 + limb * 0.4) * strength * strength
		* sway_strength * 2.2 * height * height;
}

// One cycle per roughly 13 s, phase from the trunk position so neighbouring
// trees lean out of step. Grows with height: the arc of a bending bole.
vec2 tree_trunk_lean(vec2 wind, vec2 origin, float y, float strength,
		float sway_strength, float trunk_sway, float t) {
	float sway_phase = sin(t * 0.47 + dot(origin, vec2(0.11, 0.17)));
	return wind * (0.55 + 0.45 * sway_phase) * strength * strength
		* sway_strength * trunk_sway * max(y, 0.0);
}

// Quick shiver of thin shoots riding the gust. flex^2 so only the thinnest
// parts take it; strength^1.5 so even a breeze visibly stirs twigs while the
// trunk waits for real wind.
vec2 tree_twig_sway(vec2 wind, vec2 origin, vec3 p, float flex, float strength,
		float sway_strength, float push, float t) {
	vec2 across = vec2(-wind.y, wind.x);
	float phase = dot(origin, vec2(0.23, 0.31)) + dot(p, vec3(0.7, 0.5, 0.6));
	float osc = 0.6 * sin(t * 1.7 + phase) + 0.4 * sin(t * 3.3 + phase * 1.9);
	float f = flex * flex;
	return (wind * (push * 0.55 + osc * 0.45 * wind_flutter_scale()) + across * osc * 0.35)
		* pow(strength, 1.5) * sway_strength * 2.4 * f;
}
