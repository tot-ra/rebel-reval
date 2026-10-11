shader_type canvas_item;

uniform float feather : hint_range(0.0, 0.1) = 0.004;
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform float view_cells = 56.0;
uniform vec2 map_cells = vec2(1.0, 1.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	if (dist > 0.5) {
		discard;
	}

	// Player-centered follow: the circular diameter spans view_cells in world
	// cells so the texture pans under a fixed marker. Full district overview
	// stays on the M local-map overlay.
	float edge_alpha = 1.0 - smoothstep(0.5 - feather, 0.5, dist);
	vec2 safe_cells = max(map_cells, vec2(1.0, 1.0));
	vec2 map_uv = center_uv + (centered * view_cells) / safe_cells;
	bool outside_map = map_uv.x < 0.0 || map_uv.x > 1.0 || map_uv.y < 0.0 || map_uv.y > 1.0;
	vec4 tex_color = texture(TEXTURE, clamp(map_uv, vec2(0.0, 0.0), vec2(1.0, 1.0)));
	vec4 outside_color = vec4(0.03, 0.02, 0.015, 0.92);
	vec4 sample_color = mix(tex_color, outside_color, float(outside_map));
	COLOR = vec4(sample_color.rgb, sample_color.a * edge_alpha);
}
