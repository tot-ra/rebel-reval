shader_type spatial;
render_mode cull_disabled, specular_disabled;

// Fallen leaves or needles under a city tree (CityVegetationBuilder.litter_mesh).
// UVs already point at the species cell of the leaf atlas. Vertex colour is the
// leaf's weathered brown; COLOR.a is a per-leaf hash. Each autumn a share of the
// leaves (`fresh`, VegetationPhenology.fresh_litter_share) shows this year's
// species colour instead (yellow birch, red maple, tan oak) and browns out over
// the winter; lying snow hides the litter leaf by leaf.

uniform sampler2D leaf_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 autumn_a = vec3(0.94, 0.70, 0.18);
uniform vec3 autumn_b = vec3(0.80, 0.44, 0.12);
uniform float fresh = 0.0;
uniform float snow_cover = 0.0;

void fragment() {
	float h = COLOR.a;
	if (h < snow_cover * 1.05) {
		discard;
	}
	vec4 leaf = texture(leaf_atlas, UV);
	vec3 tint = COLOR.rgb;
	if (fract(h * 3.17) < fresh) {
		tint = mix(autumn_a, autumn_b, step(0.5, fract(h * 7.31))) * mix(0.7, 1.0, fract(h * 13.1));
	}
	ALBEDO = tint * leaf.rgb;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
}
