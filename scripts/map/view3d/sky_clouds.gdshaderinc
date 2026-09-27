// Shared cloud-field functions for the sky dome and the WS-12 ground-shadow
// pass. Inputs are parameters so both callers keep their own uniforms/globals.
// Maths match the pre-extract sky_weather_3d.gdshader bodies exactly.

float sky_cloud_remap(float v, float lo, float hi, float nlo, float nhi) {
	return nlo + (clamp(v, lo, hi) - lo) / max(hi - lo, 1e-4) * (nhi - nlo);
}


float sky_cloud_local_storm_at(
	vec2 uv, sampler2D shape_tex, float storm_amt, float storm_loc
) {
	float cell = 1.0 - texture(shape_tex, uv * 0.12 + vec2(0.37, 0.71)).r;
	float mask = mix(1.0, smoothstep(0.48, 0.8, cell), storm_loc);
	return storm_amt * mask;
}


float sky_cloud_bulk(vec2 uv, float cover, sampler2D shape_tex) {
	float banks = 1.0 - texture(shape_tex, uv * 0.42 + vec2(0.13, 0.61)).r;
	float heaps = 1.0 - texture(shape_tex, uv).r;
	float bank_mask = smoothstep(0.30, 0.72, banks);
	float base = heaps * mix(0.45, 1.0, bank_mask);
	float floor_thr = mix(0.66, 0.04, cover);
	return clamp(sky_cloud_remap(base, floor_thr, floor_thr + 0.58, 0.0, 1.0), 0.0, 1.0);
}


float sky_cloud_opacity(
	vec2 uv,
	float cover,
	sampler2D shape_tex,
	sampler2D noise_tex,
	vec2 detail_offset,
	float chaos
) {
	float cloud = sky_cloud_bulk(uv, cover, shape_tex);
	float detail = texture(noise_tex, uv * 1.9 + detail_offset).r * 0.5
		+ texture(noise_tex, uv * 4.6 - detail_offset * 0.6).r * 0.32
		+ texture(noise_tex, uv * 9.4 + detail_offset * 0.3).r * 0.18;
	cloud = sky_cloud_remap(cloud, detail * mix(0.18, 0.42, chaos), 1.0, 0.0, 1.0);
	return clamp(cloud, 0.0, 1.0);
}


vec2 sky_cloud_uv(vec3 dir, float altitude, vec2 offset) {
	float distance_to_layer = altitude / sqrt(dir.y * dir.y + 0.012);
	return dir.xz * distance_to_layer * 0.12 - offset;
}


// One-sample minimum-tier ground shadow (heaps only).
float sky_cloud_shadow_cheap(vec2 uv, float cover, sampler2D shape_tex) {
	float heaps = 1.0 - texture(shape_tex, uv).r;
	float floor_thr = mix(0.66, 0.04, cover);
	return clamp(sky_cloud_remap(heaps, floor_thr, floor_thr + 0.58, 0.0, 1.0), 0.0, 1.0);
}


// Recommended soft variant: cellular bulk plus one erosion octave and a mip
// bias. Three texture samples, matching the WS-12 recommended budget.
float sky_cloud_shadow_soft(
	vec2 uv,
	float cover,
	sampler2D shape_tex,
	sampler2D noise_tex,
	vec2 detail_offset,
	float chaos,
	float mip_bias
) {
	float cloud = sky_cloud_bulk(uv, cover, shape_tex);
	float detail = textureLod(noise_tex, uv * 1.9 + detail_offset, mip_bias).r;
	cloud = sky_cloud_remap(cloud, detail * mix(0.18, 0.42, chaos), 1.0, 0.0, 1.0);
	return clamp(cloud, 0.0, 1.0);
}
