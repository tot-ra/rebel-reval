// Shared R-1433 whole-tree deformation. WindField supplies the travelling gust;
// species flexibility controls response, not a separate wind for each material.
#include "res://scripts/map/view3d/wind_field.gdshaderinc"

const float TREE_TRUNK_BEND = 0.23;
const float TREE_MAX_LEAN = 0.523598776; // 30 degrees root-to-crown, not tip tangent.
const float TREE_LIMB_BEND = 0.02;
const float TREE_LIMB_REACH_MAX = 5.0;
const float TREE_TWIG_BEND = 0.12;
const float TREE_Q_MAX = 3.0;

// Flexible foliage streamlines under load; saturation prevents runaway bending.
float tree_wind_load(float strength, float push) {
	float q = pow(max(strength * push, 0.0), 1.4);
	return q / (1.0 + q / TREE_Q_MAX);
}

// Integral of the cantilever slope profile. Retained for diagnostics/tests.
float tree_cantilever_shape(float h, float L) {
	float hc = min(max(h, 0.0), L);
	return hc * hc * (3.0 * L - hc) / (2.0 * L * L * L)
		+ max(h - L, 0.0) * 1.5 / L;
}

float tree_slope_shape(float u) {
	u = clamp(u, 0.0, 1.0);
	return 3.0 * u - 1.5 * u * u;
}

// Root-to-crown lean in radians. Tall trees ring more slowly; neighbouring
// trees have different phases. Cross-wind ringing moves to both sides of the
// mean heading. This is a bounded modal approximation, not a structural solver.
vec2 tree_wind_tilt(vec2 origin, float L, float slender, float strength, float push, float t) {
	float phase = dot(origin, vec2(0.11, 0.17));
	float q = tree_wind_load(strength, push);
	float veer = wind_turbulence_g * (0.5 * sin(t * 0.37 + phase * 3.0)
		+ 0.25 * sin(t * 0.91 + phase * 5.0));
	vec2 mean_wind = wind_dir();
	vec2 wind = vec2(cos(veer) * mean_wind.x - sin(veer) * mean_wind.y,
		sin(veer) * mean_wind.x + cos(veer) * mean_wind.y);
	vec2 across = vec2(-wind.y, wind.x);
	float ring = t * 3.1 * 9.0 / max(L, 3.0);
	float top = TREE_TRUNK_BEND * slender * q;
	vec2 tilt = top * (wind * (1.0 + 0.45 * min(q, 1.5) * sin(ring + phase))
		+ across * 0.5 * min(q, 1.5) * sin(ring * 0.73 + phase * 1.7));
	return tilt * min(1.0, TREE_MAX_LEAN / max(length(tilt), 0.00001));
}

// Rotate a section/leaf around the local bent trunk tangent (Rodrigues).
vec3 tree_wind_rotate(vec3 v, vec2 tilt) {
	float angle = length(tilt);
	vec3 axis = vec3(tilt.y, 0.0, -tilt.x) / max(angle, 0.00001);
	return v * cos(angle) + cross(axis, v) * sin(angle)
		+ axis * dot(axis, v) * (1.0 - cos(angle));
}

// World-metre offset. Integrate unit tangents rather than translate rings:
// the root stays fixed, the bole curves, and the crown drops without stretching
// the centreline. Three-point Gauss quadrature is accurate at the bounded angle.
vec3 tree_wind_offset(vec2 origin, vec3 p, float flex, float scale, float tree_top,
		float slender, float strength, float push, float t) {
	float L = max(tree_top * scale, 2.0);
	float hw = max(p.y, 0.0) * scale;
	vec2 tilt = tree_wind_tilt(origin, L, slender, strength, push, t);
	float angle = length(tilt);
	vec2 heading = tilt / max(angle, 0.00001);
	float hc = min(hw, L);
	float u = hc / L;
	float a = angle * tree_slope_shape(u * 0.112701665);
	float b = angle * tree_slope_shape(u * 0.5);
	float c = angle * tree_slope_shape(u * 0.887298335);
	vec2 arc = hc * (vec2(sin(a), cos(a)) * 0.277777778
		+ vec2(sin(b), cos(b)) * 0.444444444
		+ vec2(sin(c), cos(c)) * 0.277777778);
	arc += max(hw - L, 0.0) * vec2(sin(angle * 1.5), cos(angle * 1.5));
	vec3 section = vec3(p.x, 0.0, p.z) * scale;
	vec3 rotated = tree_wind_rotate(section, tilt * tree_slope_shape(hw / L));
	vec3 trunk = vec3(heading.x * arc.x, arc.y - hw, heading.y * arc.x)
		+ rotated - section;

	// Smaller cantilevers: limbs heave and twigs shiver, with zero response at
	// ground level. Their endpoint phase is shared by the bark and leaf anchors.
	float q = tree_wind_load(strength, push);
	float phase = dot(origin, vec2(0.11, 0.17));
	vec2 wind = wind_dir();
	vec2 across = vec2(-wind.y, wind.x);
	float reach = min(length(p.xz) * scale, TREE_LIMB_REACH_MAX);
	float limb_ring = 0.78 + 0.22 * sin(t * 7.3 + dot(p, vec3(1.3, 0.9, 1.1)) + phase);
	float limb = TREE_LIMB_BEND * slender * q * reach * reach * limb_ring
		* (0.35 + 0.65 * flex);
	vec2 branch = wind * limb + across * limb * 0.3 * sin(t * 4.1 + phase * 2.3 + p.x);
	float phase_p = phase + dot(p, vec3(0.7, 0.5, 0.6));
	float osc = (0.6 * sin(t * 1.7 + phase_p) + 0.4 * sin(t * 3.3 + phase_p * 1.9))
		* wind_flutter_scale();
	vec2 twig = (wind * (1.0 + osc) + across * osc * 0.35)
		* TREE_TWIG_BEND * pow(q, 0.8) * flex * flex;
	vec2 small = (branch + twig) * smoothstep(0.0, 1.0, hw);
	return trunk + vec3(small.x, 0.0, small.y);
}
