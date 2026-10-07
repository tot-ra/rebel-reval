shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.30, 0.42, 0.26);
uniform float sway_strength = 0.05;
uniform float shade_bottom = 0.62;
uniform vec2 wind_direction = vec2(0.9285, 0.3714);
uniform float wind_strength = 0.22;

// R-1187 living vegetation. Defaults are a full summer crown so bushes, legacy
// canopies and any material the season driver has not touched look unchanged.
// Season values come from VegetationPhenology through per-species materials.
uniform float leaf_density : hint_range(0.0, 1.0) = 1.0;
uniform float leaf_scale : hint_range(0.0, 1.0) = 1.0;
uniform float freshness : hint_range(0.0, 1.0) = 0.0;
uniform float autumn : hint_range(0.0, 1.0) = 0.0;
uniform float winter_dull : hint_range(0.0, 1.0) = 0.0;
uniform vec3 autumn_color_a : source_color = vec3(0.94, 0.70, 0.18);
uniform vec3 autumn_color_b : source_color = vec3(0.80, 0.44, 0.12);
// Shared rain state: wet leaves darken and pick up a sheen.
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
// R-1194 leaf-cluster cards (UV2 = (1, 1)): RGB is neutral-grey relative detail
// (mean 0.5), so species tint, season and autumn hue still come from the
// uniforms above. atlas_tile selects the species cluster (column, row).
// Relative brightness data, not sRGB albedo: 0.5 must sample as 0.5.
uniform sampler2D leaf_atlas : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 atlas_tile = vec2(0.0);
uniform vec2 atlas_grid = vec2(4.0, 2.0);
uniform float card_scissor : hint_range(0.0, 1.0) = 0.5;
// Cards face the sky more than folded leaves and stack several leaves of
// translucency; without this gain dense crowns read neon yellow-green.
uniform float card_gain : hint_range(0.0, 2.0) = 0.74;

varying float v_leaf_autumn;
varying float v_leaf_seed;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wind = wind_direction / max(length(wind_direction), 0.001);
	vec2 across = vec2(-wind.y, wind.x);
	float strength = clamp(wind_strength, 0.0, 1.0);
	float leaf_tag = step(0.5, UV2.x);
	v_leaf_seed = CUSTOM0.w * leaf_tag;
	v_leaf_autumn = 0.0;
	// Seasonal leaves (CUSTOM0 = petiole xyz + seed): high seeds colour first and
	// fall first, so the leaves still hanging in late autumn are the greenest.
	if (leaf_tag > 0.5) {
		float present = step(CUSTOM0.w, leaf_density);
		VERTEX = mix(CUSTOM0.xyz, VERTEX, leaf_scale * present);
		v_leaf_autumn = clamp(autumn * 1.6 - (1.0 - CUSTOM0.w) * 0.6, 0.0, 1.0);
	}
	float phase = dot(world.xz, wind) * 0.65 - TIME * 1.4;
	float gust = 0.55 + 0.30 * sin(phase) + 0.15 * sin(phase * 0.43 + TIME * 0.37);
	float flutter = sin(TIME * 5.3 + dot(world, vec3(4.1, 2.7, 3.3)) + COLOR.g * 13.0);
	// Bushes and legacy canopy primitives share this material but have no
	// leaf UV contract. Only explicitly tagged leaves use petiole pinning.
	float weight = UV2.x > 0.5 ? UV.y * UV.y : clamp(VERTEX.y * 0.4 + 0.4, 0.0, 1.0);
	// Hit shake from MultiMesh INSTANCE_CUSTOM: xy = crown-top offset in world
	// metres, z = extra leaf flutter. Written per frame by TreeLeafFall3D only for
	// recently struck trees; zero (or no custom data) leaves the crown at rest.
	float shake_flutter = clamp(INSTANCE_CUSTOM.z, 0.0, 1.0);
	vec2 displace = (wind * (0.35 + gust) + across * flutter * 0.32)
		* sway_strength * strength * weight
		+ across * flutter * shake_flutter * 0.06 * weight;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(displace.x, flutter * (sway_strength * strength + shake_flutter * 0.05) * weight * 0.18, displace.y);
	// Low-frequency branch/crown bend, rigid per leaf (petiole height), so whole
	// limbs heave in a gust instead of only leaf tips fluttering.
	if (leaf_tag > 0.5) {
		float height = clamp(CUSTOM0.y * 0.18, 0.0, 1.0);
		vec2 origin = MODEL_MATRIX[3].xz;
		float limb = sin(TIME * 0.9 + dot(origin, vec2(0.37, 0.53)) + CUSTOM0.x * 0.8)
			* 0.5 + 0.5;
		vec2 bend = wind * (gust * 0.6 + limb * 0.4) * strength * strength
			* sway_strength * 2.2 * height * height
			+ INSTANCE_CUSTOM.xy * height;
		VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(bend.x, 0.0, bend.y);
	}
}

float hash11(float p) {
	return fract(sin(p * 127.1 + 11.7) * 43758.5453);
}

void fragment() {
	// cull_disabled already orients backface normals in GL Compatibility.
	float across = abs(UV.x - 0.5);
	float pixel = max(fwidth(UV.x), 0.012);
	float midrib = 1.0 - smoothstep(0.012, 0.012 + pixel, across);
	float vein_phase = (UV.y - across * 0.65) * 9.0;
	float veins = 1.0 - smoothstep(0.04, 0.04 + max(fwidth(vein_phase), 0.08), abs(fract(vein_phase) - 0.5));
	float leaf_tag = step(0.5, UV2.x);
	float card = leaf_tag * step(0.5, UV2.y);
	// Inset reduces edge bleed at close range; coarse atlas mips can still mix tiles.
	vec2 card_uv = (atlas_tile + clamp(vec2(UV.x, 1.0 - UV.y), 0.004, 0.996)) / atlas_grid;
	// Sample outside any branch so mip selection keeps valid derivatives.
	vec4 cluster = mix(vec4(0.5, 0.5, 0.5, 1.0), texture(leaf_atlas, card_uv), card);
	cluster.rgb *= mix(1.0, card_gain, card);
	// Folded leaves draw procedural midrib and veins; cards already carry them.
	float folded = leaf_tag * (1.0 - card);
	float shade = mix(mix(1.05, shade_bottom, clamp(UV.y, 0.0, 1.0)),
		mix(shade_bottom, 1.03, smoothstep(0.0, 0.7, UV.y)), leaf_tag);
	vec3 summer = base_color * COLOR.rgb * cluster.rgb * 2.0;
	// Young leaves are lighter and yellower; per-leaf seed keeps the crown mottled.
	float fresh = freshness * leaf_tag * (0.75 + 0.25 * hash11(v_leaf_seed * 31.0));
	summer = mix(summer, summer * vec3(1.32, 1.26, 0.70), fresh);
	// Autumn: each leaf picks its own hue between the species palette entries and
	// the most advanced leaves brown, like a real mixed-colour crown.
	float luminance = dot(COLOR.rgb * cluster.rgb * 2.0, vec3(0.3, 0.5, 0.2));
	vec3 autumn_hue = mix(autumn_color_a, autumn_color_b, hash11(v_leaf_seed * 17.0));
	autumn_hue = mix(autumn_hue, vec3(0.42, 0.28, 0.12), smoothstep(0.8, 1.0, v_leaf_autumn) * 0.55);
	vec3 albedo = mix(summer, autumn_hue * luminance * 0.82, v_leaf_autumn);
	// Winter conifers: duller, slightly bluer needles.
	albedo = mix(albedo, albedo * vec3(0.78, 0.82, 0.86), winter_dull * 0.6);
	float occlusion = mix(1.0, COLOR.a, leaf_tag);
	albedo *= shade * occlusion * (1.0 + folded * (midrib * 0.14 + veins * 0.045));
	albedo *= mix(1.0, 0.70, wetness);
	ALBEDO = albedo;
	// Thin leaves transmit light; autumn leaves glow more strongly against the sun.
	BACKLIGHT = albedo * (0.42 + v_leaf_autumn * 0.22) * (1.0 - midrib * 0.4 * folded) * mix(0.6, 1.0, occlusion);
	// Card normals lean away from the crown centre; undo the automatic back-face
	// flip so both sides of a card light as the same leafy volume.
	if (card > 0.5 && !FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	// Alpha scissor keeps cards in the opaque pass: no sorting, and shadows and
	// the depth-composited underwater pass still see the cut-out.
	ALPHA = cluster.a;
	ALPHA_SCISSOR_THRESHOLD = card_scissor;
	ROUGHNESS = mix(0.76, 0.34, wetness);
	SPECULAR = mix(0.28, 0.55, wetness);
}
