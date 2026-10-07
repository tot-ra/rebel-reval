shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://scripts/city/city_weathering.gdshaderinc"

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
	float ragged = wfbm(w_pos.xz * 1.7 + w_pos.y * 0.3);
	// Rising damp and splash dirt: dark, slightly green on the shaded (north) side.
	float damp = 1.0 - smoothstep(0.15, 0.9 + ragged * 0.9, above);
	vec3 dirt = mix(vec3(0.42, 0.37, 0.30), vec3(0.33, 0.37, 0.27), clamp(-w_nrm.z, 0.0, 1.0) * 0.7);
	col = mix(col, col * dirt * 1.6, damp * 0.75 * age);
	// Rain streaks: narrow vertical runs, strongest high on the wall.
	vec2 along = vec2(dot(w_pos.xz, vec2(w_nrm.z, -w_nrm.x)) * 6.0, w_pos.y * 0.35);
	float streak = smoothstep(0.62, 0.9, wnoise(along)) * smoothstep(0.4, 0.9, wnoise(along * vec2(0.3, 1.0) + 9.0));
	col *= 1.0 - streak * 0.22 * age;
	// Patchy weathering so no two stretches of wall match.
	col *= mix(0.88, 1.06, wfbm(w_pos.xz * 0.21 + w_pos.y * 0.13));
	float wet = clamp(wetness * (0.6 + damp * 0.4), 0.0, 1.0);
	ALBEDO = col * mix(1.0, 0.7, wet);
	ROUGHNESS = mix(roughness_base, 0.45, wet);
	NORMAL_MAP = nm;
}
