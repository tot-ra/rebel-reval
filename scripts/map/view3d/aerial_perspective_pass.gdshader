shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, blend_mix;

// R-1482 aerial perspective for perspective cameras (aerial_perspective_pass.gd): the
// air between the eye and a surface scatters skylight into the view (blue by day, warm
// at low sun) and smears it slightly, so far land reads hazy and soft while the street
// at the player's feet stays sharp. On hot clear days the far ground also wavers (heat
// shimmer). GL Compatibility has no engine DOF or aerial perspective, so this pass
// does it from the scene depth and the pre-transparent screen copy.
//
// Pipeline notes (agents/rebel-dev/playbook.md):
// - Samplers are read only inside fragment(); passing them to a function binds a
//   default texture in Godot 4.7.
// - Drawn first among the transparent screen passes (render_priority below the cloud
//   shadow pass): the screen copy is the opaque frame, so writing it back does not
//   erase overlays drawn before this pass.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

// Haze in-scatter colour and extinction per metre beyond the clear radius.
uniform vec3 haze_color : source_color = vec3(0.7, 0.78, 0.9);
uniform float haze_density = 0.0006;
uniform float haze_max = 0.7;
// Distance from the eye that stays untouched: the player and the street around them.
uniform float clear_radius = 25.0;
// Blur radius in pixels at full distance, and the distances where it starts and peaks.
uniform float blur_pixels = 0.0;
uniform float blur_start = 30.0;
uniform float blur_full = 500.0;
// Heat shimmer amplitude in pixels at the far horizon (0 = off).
uniform float shimmer_pixels = 0.0;
uniform float shimmer_start = 90.0;
uniform float shimmer_full = 600.0;
// Rays over the sea hit no depth (water is transparent); they end on this plane.
uniform float water_plane_y = 0.0;
// Sky and distances beyond the camera's reach count as this far.
uniform float far_distance = 2000.0;
// 0 = normal, 1 = show haze factor, 2 = show blur factor, 3 = screen passthrough.
uniform int debug_mode = 0;

// Poisson disc, unit radius, 12 taps.
const vec2 TAPS[12] = vec2[](
	vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457),
	vec2(-0.203, 0.621), vec2(0.962, -0.195), vec2(0.473, -0.480),
	vec2(0.519, 0.767), vec2(0.185, -0.893), vec2(0.507, 0.064),
	vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598)
);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y);
}

// Eye-space distance of a depth sample; sky returns far_distance.
float view_distance(float depth, vec2 uv, mat4 inv_projection) {
	// Sky is 1.0 on the Compatibility depth range and 0.0 on reverse-Z renderers.
	if (depth <= 1e-6 || depth >= 0.999999) {
		return far_distance;
	}
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	return min(length(view.xyz / view.w), far_distance);
}

void fragment() {
	vec2 ndc_xy = SCREEN_UV * 2.0 - 1.0;
	vec4 far_view = INV_PROJECTION_MATRIX * vec4(ndc_xy, 1.0, 1.0);
	vec3 dir = normalize(mat3(INV_VIEW_MATRIX) * (far_view.xyz / far_view.w));
	vec3 eye = INV_VIEW_MATRIX[3].xyz;

	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	float dist = view_distance(depth, SCREEN_UV, INV_PROJECTION_MATRIX);
	bool sky = dist >= far_distance;
	// Over the sea the depth buffer holds the bed or nothing: end the ray on the water.
	if (dir.y < -1e-4 && eye.y > water_plane_y) {
		dist = min(dist, (eye.y - water_plane_y) / -dir.y);
		sky = false;
	}

	float haze = sky ? 0.0 : haze_max * (1.0 - exp(-max(dist - clear_radius, 0.0) * haze_density));
	float blur = blur_pixels * smoothstep(blur_start, blur_full, dist);
	// Heat shimmer lives in the thin layer of hot air along the ground, so it shows on
	// far surfaces seen nearly edge-on and on the horizon line itself.
	float edge_on = 1.0 - smoothstep(0.0, 0.06, abs(dir.y));
	float shimmer = shimmer_pixels * smoothstep(shimmer_start, shimmer_full, dist) * edge_on;

	// Debug views exit early through discard-free branches (fragment() cannot return).
	if (debug_mode == 0 && haze < 0.002 && blur < 0.25 && shimmer < 0.1) {
		discard;
	}

	vec2 pixel = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	if (shimmer >= 0.1) {
		// Rising, wavering refraction: mostly vertical wobble, a little sideways drift.
		vec2 cell = SCREEN_UV * VIEWPORT_SIZE / vec2(14.0, 3.0);
		float n = value_noise(vec2(cell.x, cell.y + TIME * 2.2)) * 2.0 - 1.0;
		float m = value_noise(vec2(cell.x * 0.5 + 17.0, cell.y * 0.7 - TIME * 1.3)) * 2.0 - 1.0;
		uv += vec2(m * 0.35, n) * shimmer * pixel;
	}

	vec3 color = textureLod(screen_texture, uv, 0.0).rgb;
	if (blur >= 0.25) {
		// Depth-aware gather: taps closer than the centre would bleed a sharp foreground
		// silhouette into the soft background, so only taps at least as far count.
		vec3 sum = color;
		float weight = 1.0;
		for (int i = 0; i < 12; i++) {
			vec2 tap_uv = clamp(uv + TAPS[i] * blur * pixel, vec2(0.0), vec2(1.0));
			float tap_dist = view_distance(
				textureLod(depth_texture, tap_uv, 0.0).r, tap_uv, INV_PROJECTION_MATRIX);
			float w = smoothstep(0.6, 0.85, tap_dist / max(dist, 1.0));
			sum += textureLod(screen_texture, tap_uv, 0.0).rgb * w;
			weight += w;
		}
		color = sum / weight;
	}
	ALBEDO = mix(color, haze_color, haze);
	if (debug_mode == 1) {
		ALBEDO = vec3(haze / max(haze_max, 1e-4));
	} else if (debug_mode == 2) {
		ALBEDO = vec3(blur / max(blur_pixels, 1e-4));
	} else if (debug_mode == 3) {
		ALBEDO = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	}
	ALPHA = 1.0;
}
