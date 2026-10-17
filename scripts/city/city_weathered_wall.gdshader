shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://scripts/city/city_weathering.gdshaderinc"

uniform float rot = 0.0; // R-1931: 1 on plank and log walls (rot at the foot)
// R-2281: 1 on the inner faces of smoke dwellings (log walls, heap oven). No
// weather grows indoors (no damp foot, rain streaks, moss or lichen); the oven
// smoke that hangs under the roof blackens the upper logs and stones instead.
uniform float indoor = 0.0;
// Height (m over the ground) where the indoor soot glaze begins: the walls
// blacken from about shoulder height, the heap oven from just over its mouth.
uniform float soot_low = 1.1;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// World triplanar, the same plates the district buildings use.
	vec3 an = pow(abs(w_nrm), vec3(4.0));
	an /= (an.x + an.y + an.z);
	vec3 p = w_pos * uv_scale;
	vec3 col = texture(albedo_tex, p.zy).rgb * an.x + texture(albedo_tex, p.xz).rgb * an.y
		+ texture(albedo_tex, p.xy).rgb * an.z;
	vec3 nm = texture(normal_tex, p.zy).rgb * an.x + texture(normal_tex, p.xz).rgb * an.y
		+ texture(normal_tex, p.xy).rgb * an.z;
	col *= base_tint * COLOR.rgb;

	float above = w_pos.y - ground_at(w_pos.xz);
	if (indoor > 0.5) {
		// Soot: from about shoulder height the smoke layer has glazed the wood
		// and stone a tarry black-brown, with a ragged lower edge; a faint film
		// below. Old soot is slightly glossy (creosote), so it is less matte.
		float s_along = dot(w_pos.xz, vec2(1.0, 0.7));
		float edge = soot_low + 0.45 * wfbm(vec2(s_along * 1.3, w_pos.y * 0.6) + 2.7);
		float soot = smoothstep(edge - 0.35, edge + 0.55, above);
		float patchy = mix(0.8, 1.0, wfbm(w_pos.xz * 2.3 + w_pos.y * 1.9));
		vec3 tar = vec3(0.12, 0.09, 0.07) * dot(col, vec3(0.3, 0.59, 0.11)) * 1.8;
		col = mix(col * 0.82, tar, soot * 0.9 * patchy);
		ALBEDO = col;
		ROUGHNESS = mix(roughness_base, 0.6, soot * 0.6);
		NORMAL_MAP = nm;
	} else {
		float ragged = wfbm(w_pos.xz * 1.7 + w_pos.y * 0.3);
		// Rising damp: a soft dark, slightly green gradient on the shaded (north)
		// side; its top is so soft it draws no line.
		float damp = 1.0 - smoothstep(0.15, 0.9 + ragged * 0.9, above);
		vec3 dirt = mix(vec3(0.42, 0.37, 0.30), vec3(0.33, 0.37, 0.27), clamp(-w_nrm.z, 0.0, 1.0) * 0.7);
		col = mix(col, col * dirt * 1.6, damp * 0.5 * age);
		// Rain streaks: narrow vertical runs, strongest high on the wall.
		vec2 along = vec2(dot(w_pos.xz, vec2(w_nrm.z, -w_nrm.x)) * 6.0, w_pos.y * 0.35);
		float streak = smoothstep(0.62, 0.9, wnoise(along)) * smoothstep(0.4, 0.9, wnoise(along * vec2(0.3, 1.0) + 9.0));
		col *= 1.0 - streak * 0.22 * age;
		// Patchy weathering so no two stretches of wall match.
		col *= mix(0.88, 1.06, wfbm(w_pos.xz * 0.21 + w_pos.y * 0.13));
		float rough = roughness_base;
		// R-1931: ragged splash, damp and rot band at the foot (shared helper).
		float foot = wall_foot(col, rough, w_pos, w_nrm, above, max(age, 0.6), rot);
		col = shade_growth(col, nm, rough, w_pos, w_nrm, above, age);
		float wet = clamp(wetness * (0.6 + max(damp, foot) * 0.4), 0.0, 1.0);
		ALBEDO = col * mix(1.0, 0.7, wet);
		ROUGHNESS = mix(rough, 0.45, wet);
		NORMAL_MAP = nm;
	}
}
