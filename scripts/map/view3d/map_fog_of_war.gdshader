shader_type canvas_item;
render_mode unshaded;

// The gameplay camera is orthographic, so a ground point is an affine function
// of screen UV. Runtime projection vectors keep the effect correct under orbit
// and zoom without coupling it to the 3D depth buffer.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D occlusion_mask : repeat_disable, filter_nearest;
uniform vec2 map_world_size = vec2(1.0);
uniform vec2 ground_origin;
uniform vec2 ground_uv_x;
uniform vec2 ground_uv_y;
uniform vec2 player_world;
uniform vec2 fov_origin_world;
uniform vec2 facing_world = vec2(0.0, 1.0);
uniform float clear_radius = 9.0;
uniform float memory_radius = 18.0;
uniform float half_fov_cos = 0.5;
uniform float soft_fov_cos = 0.422618;

const int OCCLUSION_STEPS = 32;

bool blocked(vec2 world) {
	vec2 uv = world / map_world_size;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return false;
	}
	return texture(occlusion_mask, uv).r > 0.5;
}

bool hidden_behind_mass(vec2 from, vec2 to) {
	// The wall/building itself remains visible. Only samples whose sight line
	// crossed a blocking footprint before reaching them become hidden.
	if (blocked(from) || blocked(to)) {
		return false;
	}
	for (int index = 1; index < OCCLUSION_STEPS; index++) {
		float progress = float(index) / float(OCCLUSION_STEPS);
		if (blocked(mix(from, to, progress))) {
			return true;
		}
	}
	return false;
}

void fragment() {
	vec2 world = ground_origin + ground_uv_x * SCREEN_UV.x + ground_uv_y * SCREEN_UV.y;
	vec2 radial_offset = world - player_world;
	float distance_to_player = length(radial_offset);
	vec2 fov_offset = world - fov_origin_world;
	float distance_to_fov_origin = length(fov_offset);
	vec2 sight_direction = distance_to_fov_origin > 0.0001 ? fov_offset / distance_to_fov_origin : facing_world;

	float facing_dot = dot(normalize(facing_world), sight_direction);
	float in_fov = smoothstep(soft_fov_cos, half_fov_cos, facing_dot);
	float radial_fog = smoothstep(clear_radius, memory_radius, distance_to_player);
	float occluded = hidden_behind_mass(player_world, world) ? 1.0 : 0.0;

	float memory = max(1.0 - in_fov, radial_fog);
	float blur_lod = clamp(radial_fog * 3.0 + (1.0 - in_fov) * 2.0 + occluded * 4.0, 0.0, 5.5);
	vec4 color = textureLod(screen_texture, SCREEN_UV, blur_lod);
	float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	float gray_amount = max(memory * 0.9, occluded * 0.72);
	color.rgb = mix(color.rgb, vec3(luminance), clamp(gray_amount, 0.0, 1.0));
	color.rgb *= 1.0 - occluded * 0.52 - radial_fog * 0.12;
	COLOR = color;
}
