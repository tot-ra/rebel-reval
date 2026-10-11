shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://scripts/map/view3d/wind_field.gdshaderinc"

// Indoor / courtyard wall hangings: pinned along the top rod (UV.y free toward
// the hem). Optional albedo replaces vertex COLOR so embroidered faction plates
// stay sharp; outdoor hoist pennants keep map_view_cloth.gdshader instead.
uniform vec3 base_color : source_color = vec3(0.97, 0.96, 0.94);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float use_albedo_texture = 0.0;
uniform float sway_strength = 0.04;
// Share of the world wind that reaches a wall hanging (R-1321). The old fixed
// 0.08 strength equals 0.36 of the default 0.22 breeze.
uniform float wind_scale = 0.36;
uniform vec2 free_edge = vec2(0.0, 1.0);
// 1.0 when vertex colors are authored in sRGB (town hall cloth).
uniform float vertex_color_srgb = 0.0;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 1.1 + world.z * 0.85;
	float local_wind = clamp(wind_strength() * wind_scale, 0.0, 1.0);
	float power = mix(0.2, 0.9, local_wind);
	float free_t = clamp(UV.x * free_edge.x + UV.y * free_edge.y, 0.0, 1.0);
	float weight = free_t * free_t;
	float gust = wind_gust_signed(MODEL_MATRIX[3].xz, TIME);
	float ripple = sin(TIME * 2.4 + phase * 1.6 + UV.x * 4.0) * 0.45
		+ sin(TIME * 3.8 + phase * 1.1 + UV.y * 3.2) * 0.25;
	vec2 wind = wind_dir();
	vec2 across = vec2(-wind.y, wind.x);
	vec2 displace = wind * (power * (0.55 + 0.2 * gust) + ripple * 0.2)
		+ across * ripple * 0.35;
	vec3 world_delta = vec3(displace.x, ripple * 0.08 * power, displace.y)
		* sway_strength * weight;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(world_delta, 0.0)).xyz;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 tint = COLOR.rgb;
	if (vertex_color_srgb > 0.5) {
		tint = mix(
			tint / 12.92,
			pow((tint + vec3(0.055)) / 1.055, vec3(2.4)),
			step(vec3(0.04045), tint)
		);
	}
	vec3 vertex_tint = base_color * tint;
	vec3 tex = texture(albedo_texture, UV).rgb;
	ALBEDO = mix(vertex_tint, tex, clamp(use_albedo_texture, 0.0, 1.0));
	ROUGHNESS = 0.94;
}
