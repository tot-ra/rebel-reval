shader_type spatial;
render_mode cull_disabled;

#include "res://scripts/map/view3d/wind_field.gdshaderinc"

// Rope of the cog's rig. Mesh contract (CogParts.rope): UV.x = 0..1 along the
// rope, UV.y = slack, the sag in metres at mid span. Both ends stay pinned, so a
// taut shroud (slack 0) does not move and a loose sheet or halyard hangs in a
// curve, belly-ing downwind and shivering in the gusts of the shared wind field.

void vertex() {
	float t = UV.x;
	float slack = UV.y;
	float arch = 4.0 * t * (1.0 - t);
	vec2 wd = wind_dir();
	vec3 wl = (inverse(MODEL_MATRIX) * vec4(wd.x, 0.0, wd.y, 0.0)).xyz;
	float p = wind_strength() * (0.6 + 0.4 * wind_gust_signed(MODEL_MATRIX[3].xz, TIME));
	float phase = dot(VERTEX, vec3(1.7, 2.3, 1.1));
	float shiver = sin(TIME * (2.0 + p * 5.0) + phase * 2.0 + t * 6.0) * wind_flutter_scale();
	// Gravity sag, eased as the wind lifts the line; downwind belly; a slow side shiver.
	vec3 sag = vec3(0.0, -slack * arch * (1.0 - 0.45 * p), 0.0);
	vec3 belly = vec3(wl.x, 0.0, wl.z) * slack * arch * (0.4 + 1.6 * p);
	vec3 side = vec3(wl.z, 0.0, -wl.x) * shiver * slack * arch * 0.2 * p;
	VERTEX += sag + belly + side;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
