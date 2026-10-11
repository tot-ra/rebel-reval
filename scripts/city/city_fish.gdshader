shader_type spatial;
render_mode cull_disabled;
global uniform float ocean_time;
// Textured herring / perch for CityFish. Mesh contract (tools/assets/fish/):
// UV = side projection of the generated illustration on both flanks and the
// midplane fin card; UV2.y = part (0 body, 1 fin). INSTANCE_CUSTOM.r = phase.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// 1 on herring: its bright silver flanks read as a metallic sheen.
uniform float silver = 0.0;

void vertex() {
	// Keep in step with test_city_water_realism (fin bounds under full swing).
	float tail = smoothstep(0.15, 0.75, -VERTEX.x);
	VERTEX.z += sin(ocean_time * 11.0 + INSTANCE_CUSTOM.r - VERTEX.x * 5.0) * tail * 0.12;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (UV2.y < 0.5) {
		float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		METALLIC = silver * 0.55 * smoothstep(0.45, 0.85, lum);
		ROUGHNESS = mix(0.45, 0.3, silver);
		SPECULAR = 0.6;
	} else {
		// Thin membranes glow when the sun is behind them.
		BACKLIGHT = tex.rgb * 0.2;
		ROUGHNESS = 0.55;
		METALLIC = 0.0;
	}
}
