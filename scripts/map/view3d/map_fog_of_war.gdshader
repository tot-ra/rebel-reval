shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

// The spatial full-screen pass can read scene depth, unlike CanvasItem. This
// keeps the fog attached to actual visible surfaces instead of projecting every
// pixel onto the ground plane and accidentally covering heads, roofs, or walls.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D occlusion_mask : repeat_disable, filter_nearest;
uniform vec2 map_world_size = vec2(1.0);
uniform vec2 ground_origin;
uniform vec2 ground_uv_x;
uniform vec2 ground_uv_y;
uniform vec2 player_world;
uniform vec2 fov_origin_world;
uniform vec2 facing_world = vec2(0.0, 1.0);
uniform float player_clear_radius = 1.5;
uniform float clear_radius = 18.0;
uniform float memory_radius = 36.0;
uniform float occlusion_target_grace = 0.75;
uniform float occlusion_surface_padding = 0.25;
uniform float half_fov_cos = 0.5;
uniform float soft_fov_cos = 0.309017;

const int OCCLUSION_STEPS = 64;

bool blocked(vec2 world) {
	vec2 uv = world / map_world_size;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return false;
	}
	return texture(occlusion_mask, uv).r > 0.5;
}

bool on_blocking_surface(vec2 world) {
	// A reconstructed facade point can sit just outside its ground footprint due
	// to depth precision and wall height. A 3x3 neighborhood makes that decision
	// stable without extending the actual sight-line blocker.
	if (blocked(world)) {
		return true;
	}
	vec2 padding = vec2(occlusion_surface_padding);
	return blocked(world + vec2(padding.x, 0.0))
		|| blocked(world - vec2(padding.x, 0.0))
		|| blocked(world + vec2(0.0, padding.y))
		|| blocked(world - vec2(0.0, padding.y))
		|| blocked(world + padding)
		|| blocked(world - padding)
		|| blocked(world + vec2(padding.x, -padding.y))
		|| blocked(world + vec2(-padding.x, padding.y));
}

bool hidden_behind_mass(vec2 from, vec2 to) {
	// Buildings stay visible, including raised facade/roof pixels whose world XZ
	// can land just outside the footprint. Only blockers with enough clear space
	// between their far edge and the target produce memory fog.
	if (blocked(from) || on_blocking_surface(to)) {
		return false;
	}
	float sight_length = distance(from, to);
	if (sight_length <= occlusion_target_grace) {
		return false;
	}
	bool crossed_mass = false;
	for (int index = 1; index < OCCLUSION_STEPS; index++) {
		float progress = float(index) / float(OCCLUSION_STEPS);
		float distance_to_target = (1.0 - progress) * sight_length;
		if (blocked(mix(from, to, progress)) && distance_to_target > occlusion_target_grace) {
			crossed_mass = true;
		}
	}
	return crossed_mass;
}

void vertex() {
	// Draw the quad directly in clip space so it follows every camera without
	// changing transforms or introducing perspective interpolation artifacts.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	// GL Compatibility stores depth in OpenGL's -1..1 NDC range, while the
	// other Godot renderers use 0..1. CURRENT_RENDERER keeps both paths valid.
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#endif
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_position.xyz /= view_position.w;
	vec3 scene_world_position = (INV_VIEW_MATRIX * vec4(view_position.xyz, 1.0)).xyz;
	vec2 scene_world = scene_world_position.xz;

	// Background has no useful scene depth. Preserve the old ground projection
	// there so the map border still fades consistently instead of flashing clear.
	float has_scene_depth = step(depth, 0.999999);
	vec2 ground_world = ground_origin + ground_uv_x * SCREEN_UV.x + ground_uv_y * SCREEN_UV.y;
	vec2 world = mix(ground_world, scene_world, has_scene_depth);

	vec2 radial_offset = world - player_world;
	float distance_to_player = length(radial_offset);
	vec2 fov_offset = world - fov_origin_world;
	float distance_to_fov_origin = length(fov_offset);
	vec2 sight_direction = distance_to_fov_origin > 0.0001 ? fov_offset / distance_to_fov_origin : facing_world;

	float facing_dot = dot(normalize(facing_world), sight_direction);
	float in_fov = smoothstep(soft_fov_cos, half_fov_cos, facing_dot);
	float player_clear = 1.0 - smoothstep(player_clear_radius * 0.72, player_clear_radius, distance_to_player);
	in_fov = max(in_fov, player_clear);

	// A quintic remap removes the visible acceleration change at each end of the
	// already doubled transition range, making distant blur build progressively.
	float radial_progress = smoothstep(clear_radius, memory_radius, distance_to_player);
	float radial_fog = radial_progress * radial_progress * radial_progress * (radial_progress * (radial_progress * 6.0 - 15.0) + 10.0);
	float occluded = hidden_behind_mass(player_world, world) ? 1.0 : 0.0;
	occluded *= 1.0 - player_clear;

	float memory = max(1.0 - in_fov, radial_fog);
	float blur_lod = clamp(radial_fog * 3.0 + (1.0 - in_fov) * 2.0 + occluded * 4.0, 0.0, 5.5);
	vec4 color = textureLod(screen_texture, SCREEN_UV, blur_lod);
	float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	float gray_amount = max(memory * 0.9, occluded * 0.72);
	color.rgb = mix(color.rgb, vec3(luminance), clamp(gray_amount, 0.0, 1.0));
	color.rgb *= 1.0 - occluded * 0.52 - radial_fog * 0.12;
	ALBEDO = color.rgb;
	ALPHA = 1.0;
}
