shader_type canvas_item;

uniform float feather : hint_range(0.0, 0.1) = 0.004;
uniform float map_aspect : hint_range(0.01, 100.0) = 1.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	if (dist > 0.5) {
		discard;
	}

	// Cover the square viewport without distorting rectangular maps. The excess
	// is cropped symmetrically, keeping every visible pixel inside the circle.
	vec2 map_uv = UV;
	if (map_aspect > 1.0) {
		map_uv.x = centered.x / map_aspect + 0.5;
	} else {
		map_uv.y = centered.y * map_aspect + 0.5;
	}

	vec4 tex_color = texture(TEXTURE, map_uv);
	float edge_alpha = 1.0 - smoothstep(0.5 - feather, 0.5, dist);
	COLOR = vec4(tex_color.rgb, tex_color.a * edge_alpha);
}
