shader_type canvas_item;

// Circular minimap: samples the painted city map around the player, rotated so
// the camera's forward direction points up.
uniform sampler2D map_texture : source_color, filter_linear_mipmap;
uniform vec2 center_uv = vec2(0.5);
uniform float view_uv = 0.08; // map uv spanned by the circle's diameter
uniform float angle = 0.0;
uniform vec4 rim_color : source_color = vec4(0.23, 0.19, 0.14, 1.0);

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	if (r > 0.5) {
		discard;
	}
	float c = cos(angle);
	float s = sin(angle);
	vec2 q = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
	vec4 map = texture(map_texture, center_uv + q * view_uv);
	// The painted bronze rim texture is drawn over the circle edge by CityMinimap.
	float rim = 0.0;
	COLOR = mix(map, rim_color, rim);
	COLOR.a = 1.0 - smoothstep(0.49, 0.5, r);
}
