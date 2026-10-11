// R-1684: photographic growth shared by masonry, roofs and wind-swayed bark.
// Albedo alpha stores cushion height / rosette mask, not surface transparency.
// Missing plates must leave the underlying material untouched.
// The weathered roof converts its finished colour with city_albedo, so its
// plates must use the same raw-input hint as the substrate on RD renderers.
#ifdef CITY_ROOF_PLATE
uniform sampler2D moss_tex : CITY_PLATE filter_linear_mipmap_anisotropic, repeat_enable, hint_default_transparent;
uniform sampler2D lichen_tex : CITY_PLATE filter_linear_mipmap_anisotropic, repeat_enable, hint_default_transparent;
#else
uniform sampler2D moss_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_transparent;
uniform sampler2D lichen_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_transparent;
#endif
uniform sampler2D moss_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

float growth_height_mask(float height, float coverage) {
	float cover = clamp(coverage, 0.0, 1.0);
	// At zero coverage even the tallest cushion must disappear; transparent
	// fallback texels must also stay absent at full coverage.
	return smoothstep(1.0 - cover - 0.06, 1.0 - cover + 0.06, height)
		* step(0.0001, cover) * step(0.0001, height);
}

// wp is surface-local metres in the tangent frame, independent of wind sway.
// Keep ecological coverage in the caller; plates supply the small-scale edges,
// colour and relief. The returned moss mask also drives rain response on bark.
float shade_growth_plates(inout vec3 col, inout vec3 nm, inout float rough,
		vec2 wp, float moss_cover, float lichen_cover, vec3 moss_tint) {
	mat2 rotation = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	vec2 uv_a = wp / 0.32;
	vec2 uv_b = rotation * wp / 0.47 + 0.37;
	vec4 ma = texture(moss_tex, uv_a);
	vec4 mb = texture(moss_tex, uv_b);
	float pick = smoothstep(-0.08, 0.08, mb.a - ma.a);
	vec4 cushion = mix(ma, mb, pick);
	vec3 na = texture(moss_normal_tex, uv_a).rgb * 2.0 - 1.0;
	vec3 nb = texture(moss_normal_tex, uv_b).rgb * 2.0 - 1.0;
	// Rotate the second sample's relief back into the mesh's tangent frame.
	nb.xy = transpose(rotation) * nb.xy;
	vec3 moss_normal = normalize(mix(na, nb, pick)) * 0.5 + 0.5;
	float moss = growth_height_mask(cushion.a, moss_cover);
	col = mix(col, cushion.rgb * moss_tint, moss);
	nm = mix(nm, moss_normal, moss);
	rough = mix(rough, 0.97, moss);

	vec4 crust = texture(lichen_tex, wp / 0.5 + vec2(0.31, 0.17));
	float lichen = growth_height_mask(crust.a, lichen_cover) * (1.0 - moss);
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	vec3 lichen_col = crust.rgb * vec3(0.95, 0.95, 0.8) * clamp(lum * 2.0, 0.55, 0.9);
	col = mix(col, lichen_col, lichen);
	// Thin crusts retain the substrate relief rather than inventing a normal plate.
	rough = mix(rough, 0.95, lichen);
	return moss;
}
