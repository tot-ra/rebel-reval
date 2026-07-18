shader_type canvas_item;

uniform float feather : hint_range(0.0, 0.1) = 0.004;

void fragment() {
	vec2 centered := UV - vec2(0.5);
	float dist := length(centered);
	if (dist > 0.5) {
		discard;
	}

	vec4 tex_color := texture(TEXTURE, UV);
	float edge_alpha := 1.0 - smoothstep(0.5 - feather, 0.5, dist);
	COLOR = vec4(tex_color.rgb, tex_color.a * edge_alpha);
}
