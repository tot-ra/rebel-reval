shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Clay "monk and nun" roof tiles (Mönch und Nonne), the Hanseatic roof of
// 14th-century Reval: rows of concave nuns (channels) capped by convex monks,
// laid in courses that overlap down the slope. Fully procedural from the roof
// UVs CityBuildingBuilder writes (u along the ridge, v down the slope from the
// ridge, both in metres), so no texture plate stretches across the roof.
// Each tile gets its own fired colour (orange to brown, the odd burnt or
// replaced one), each course a lip with a shadow line, and moss gathers in
// the channels and at the overlaps on the cooler pitches.

#include "res://scripts/city/city_weathering.gdshaderinc"

uniform float moss = 0.3;
uniform float tile_pitch = 0.34; // one nun + one monk, across the slope (m)
uniform float course_len = 0.36; // visible length of a course, down the slope (m)
uniform vec3 clay_light : source_color = vec3(0.69, 0.33, 0.21);
uniform vec3 clay_dark : source_color = vec3(0.43, 0.2, 0.13);

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV;
	float course = floor(uv.y / course_len);
	float cv = fract(uv.y / course_len); // 0 at the course's top, 1 at its lip
	// Courses are laid by hand: each one wanders a little sideways.
	float u = uv.x + (wh(vec2(course, 3.1)) - 0.5) * 0.05;
	float col_id = floor(u / tile_pitch);
	float cu = fract(u / tile_pitch); // 0..0.6 nun channel, 0.6..1 monk cap
	float monk = smoothstep(0.56, 0.62, cu) * (1.0 - smoothstep(0.96, 1.0, cu));
	// Profile across the slope: channel (concave) and cap (convex) slopes.
	float nun_t = clamp(cu / 0.6, 0.0, 1.0);
	float monk_t = clamp((cu - 0.6) / 0.4, 0.0, 1.0);
	float slope_u = mix((nun_t - 0.5) * 1.6, -(monk_t - 0.5) * 2.4, monk);
	// Down the slope: each tile rises towards its lip, then drops to the next.
	float slope_v = mix(0.28, -1.2, smoothstep(0.88, 1.0, cv));
	vec3 n_ts = normalize(vec3(-slope_u, -slope_v * 0.6, 1.0));
	NORMAL_MAP = n_ts * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = mix(1.0, 0.7, wetness);

	// Per-tile clay: hashed by course and column (monks and nuns differ).
	vec2 tid = vec2(col_id * 2.0 + step(0.6, cu), course);
	float h1 = wh(tid + 17.0);
	float h2 = wh(tid * 1.7 + 4.0);
	vec3 clay = mix(clay_dark, clay_light, h1 * 0.8 + 0.2);
	clay = mix(clay, vec3(0.32, 0.18, 0.13), step(0.93, h2) * 0.7); // over-fired
	clay = mix(clay, vec3(0.74, 0.46, 0.32), step(0.97, h1) * 0.6); // newer replacement
	// Shading: channels sit in shadow, the course lip casts a line below it.
	float ao = mix(0.72, 1.0, monk) * mix(1.0, 0.55, smoothstep(0.0, 0.1, 0.1 - cv));
	ao *= mix(1.0, 0.85, smoothstep(0.92, 1.0, cv));
	vec3 col = clay * ao * COLOR.rgb;
	if (!FRONT_FACING) {
		col = vec3(0.32, 0.22, 0.17) * 0.6; // underside: battens and tile backs
	}
	// Weathering: soot and dust darken the old roof; moss in the channels and
	// at overlaps, more on cool north pitches; lichen rosettes on the caps.
	float patch = wfbm(w_pos.xz * 0.3);
	col *= mix(0.78, 1.06, wfbm(w_pos.xz * 0.11 + 5.0)) * mix(1.0, 0.86, age);
	float north = clamp(-w_nrm.z * 0.8 + 0.3, 0.0, 1.0);
	float wet_spot = (1.0 - monk) * 0.6 + smoothstep(0.75, 1.0, cv) * 0.4;
	float m = smoothstep(0.45, 0.8, patch + north * 0.25) * wet_spot * moss * age;
	col = mix(col, vec3(0.2, 0.26, 0.11) * (0.8 + patch * 0.4), clamp(m * 1.4, 0.0, 0.85));
	float lichen = smoothstep(0.7, 0.85, wnoise(uv * 9.0 + course)) * monk;
	col = mix(col, vec3(0.66, 0.64, 0.52), lichen * 0.35 * age);
	ALBEDO = col * mix(1.0, 0.68, wetness);
	ROUGHNESS = mix(0.82, 0.3, wetness);
	SPECULAR = 0.35;
}
