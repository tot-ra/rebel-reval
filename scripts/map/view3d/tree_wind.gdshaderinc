// Whole-tree wind shared by the crown shader (map_view_canopy.gdshader) and the
// bark shader (map_view_bark_wind.gdshader). Both call tree_wind_offset() with
// the same inputs, so a branch and the leaf cards growing on it move together
// and foliage never tears off its limbs.
//
// The model is a loaded cantilever, not a sine on a vertex:
//   load     - drag on a flexible crown grows as u^1.4, not u^2: leaves and
//              twigs fold and streamline in strong wind (Vogel exponent), so a
//              storm bends a tree a lot but does not fold it flat. Saturates
//              at TREE_Q_MAX.
//   trunk    - deflection of a uniformly loaded cantilever,
//              y^2 (3L - y) / (2 L^3): grows with height squared, straight
//              (constant slope) above the tree top. Rings at the tree's own
//              sway frequency (~0.5 Hz) so a gust overshoots and rebounds.
//   limbs    - each branch is a smaller cantilever: its tip lags with the
//              square of its horizontal reach from the trunk axis, and rings
//              faster (~1.2 Hz) than the bole.
//   twigs    - thin shoots (`flex` ~ 1, the bark mesh stores it in COLOR.a)
//              shiver quickly on top.
//   arc      - a bent bole keeps its length, so the crown sinks as it leans.
// Everything is computed in world metres and scales with the shared weather
// wind (wind_strength_g and the gust front), so a calm day barely stirs the
// wood and a storm gust heaves whole limbs.
#include "res://scripts/map/view3d/wind_field.gdshaderinc"

// Reference tree height in metres; taller trees bend more because the
// deflection keeps growing past it, shorter ones stay stiffer.
const float TREE_REF_HEIGHT = 9.0;
// Crown-top deflection per metre of tree height at unit load.
const float TREE_TRUNK_BEND = 0.05;
// Tip lag of a limb of reach r metres: TREE_LIMB_BEND * load * r^2.
const float TREE_LIMB_BEND = 0.012;
const float TREE_LIMB_REACH_MAX = 5.0;
const float TREE_TWIG_BEND = 0.09;
const float TREE_Q_MAX = 3.0;
// sway_strength of the default crown; per-species stiffness (conifers 0.03,
// orchard 0.075) scales every amplitude relative to it.
const float TREE_REF_SWAY = 0.06;

// Aerodynamic load: `strength` * `push` is the local wind speed, 0..~3.
float tree_wind_load(float strength, float push) {
	float u = max(strength * push, 0.0);
	float q = pow(u, 1.4);
	return q / (1.0 + q / TREE_Q_MAX);
}

// Cantilever deflection shape, 0 at the root and 1 at height L, with the
// straight continuation above L.
float tree_cantilever_shape(float h) {
	float hc = min(h, TREE_REF_HEIGHT);
	float L = TREE_REF_HEIGHT;
	float s = hc * hc * (3.0 * L - hc) / (2.0 * L * L * L);
	return s + max(h - L, 0.0) * 1.5 / L;
}

// World-space displacement (metres) of a point of a tree.
//   origin  trunk position in world xz (decorrelates neighbouring trees)
//   p       point in tree-local model space (trunk axis = y)
//   flex    0 for the bole .. 1 for twig tips
//   scale   metres per model unit (the instance scale)
//   push    gust pressure sampled at the trunk (wind_pressure_coarse)
vec3 tree_wind_offset(vec2 origin, vec3 p, float flex, float scale, float strength,
		float sway_strength, float push, float t) {
	vec2 wind = wind_dir();
	vec2 across = vec2(-wind.y, wind.x);
	float stiffness = sway_strength / TREE_REF_SWAY;
	float q = tree_wind_load(strength, push);
	float phase = dot(origin, vec2(0.11, 0.17));

	// Bole: lean of the whole tree, with the gust ringing on the sway mode.
	float hw = max(p.y, 0.0) * scale;
	float ring = 1.0 + 0.22 * sin(t * 3.1 + phase) * min(q, 1.0);
	float lean = TREE_TRUNK_BEND * q * TREE_REF_HEIGHT * stiffness * ring
		* tree_cantilever_shape(hw);
	// Gusts also slew the crown sideways (swirl behind the leading edge).
	float slew = 0.2 * lean * sin(t * 2.3 + phase * 1.7);
	vec2 trunk = wind * lean + across * slew;

	// Limbs: cantilevers of their own, ringing faster than the bole.
	float reach = min(length(p.xz) * scale, TREE_LIMB_REACH_MAX);
	float limb_ring = 0.78 + 0.22 * sin(t * 7.3 + dot(p, vec3(1.3, 0.9, 1.1)) + phase);
	float limb = TREE_LIMB_BEND * q * reach * reach * stiffness * limb_ring
		* (0.35 + 0.65 * flex);
	vec2 branch = wind * limb + across * limb * 0.3 * sin(t * 4.1 + phase * 2.3 + p.x);

	// Twigs: the quick shiver only thin shoots take.
	float phase_p = phase + dot(p, vec3(0.7, 0.5, 0.6));
	float osc = 0.6 * sin(t * 1.7 + phase_p) + 0.4 * sin(t * 3.3 + phase_p * 1.9);
	osc *= wind_flutter_scale();
	vec2 twig = (wind * (1.0 + osc) + across * osc * 0.35)
		* TREE_TWIG_BEND * pow(q, 0.8) * stiffness * flex * flex;

	vec2 total = trunk + branch + twig;
	// Arc: horizontal travel of the bole shortens its vertical reach.
	float drop = -dot(trunk, trunk) / (2.0 * max(hw, 1.5));
	return vec3(total.x, drop, total.y);
}
