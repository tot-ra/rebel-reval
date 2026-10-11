shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, blend_mix;

// R-1748: screen-space ambient occlusion from scene depth alone. The Mobile renderer
// (ADR 0043) has no built-in SSAO and no normal-roughness buffer, so the pass rebuilds
// view-space positions and a face normal from the depth texture and asks, for a few
// neighbours on screen, how much of the hemisphere above the point they block.
// Two rings: a contact ring (~0.35 m) grounds feet, barrels and wall bases; an area
// ring (~2.4 m) shades alleys, courtyards and the wall under an eave.
// Like cloud_shadow_pass it mixes black over the live frame (dest * (1 - ALPHA)), which
// is exact under any HDR multiplier or tonemapper. It also darkens directly lit
// pixels a little (a post pass cannot tell sun from sky light); `strength` is tuned
// for that and the node lowers it in full sun.
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.6;
uniform float contact_radius = 0.35;
uniform float area_radius = 2.4;
uniform int contact_samples = 4;
uniform int area_samples = 4;
// Ring weights: the contact ring is the darker, tighter one.
uniform float contact_weight = 1.0;
uniform float area_weight = 0.75;
// Fade out with distance: far depth is too coarse and the effect too small to pay for.
uniform float fade_start = 70.0;
uniform float fade_end = 160.0;

// Cosine below which an occluder does not count (rejects self-occlusion on flat ground
// from depth quantisation and the reconstructed normal's own noise).
const float COS_BIAS = 0.12;
// Largest on-screen radius as a share of the frame height: a lens right against a wall
// would otherwise scatter taps across the whole screen (cache-hostile and smeared).
const float MAX_RADIUS_UV = 0.08;
const float GOLDEN_ANGLE = 2.39996323;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

bool is_sky(float depth) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return depth >= 0.999999;
#else
	return depth <= 1e-6;
#endif
}

vec3 view_position(vec2 uv, mat4 inv_projection) {
	float depth = textureLod(depth_texture, uv, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
#endif
	vec4 v = inv_projection * vec4(ndc, 1.0);
	return v.xyz / v.w;
}

// One ring of `count` taps on a golden-angle spiral, rotated per pixel.
float ring_occlusion(
	vec3 p, vec3 n, vec2 uv, vec2 radius_uv, float radius, int count, float rotation,
	mat4 inv_projection
) {
	float occluded = 0.0;
	for (int i = 0; i < count; i++) {
		float t = (float(i) + 0.5) / float(count);
		float angle = float(i) * GOLDEN_ANGLE + rotation;
		// sqrt spreads taps evenly over the disc instead of crowding the centre.
		vec2 tap = uv + vec2(cos(angle), sin(angle)) * radius_uv * sqrt(t);
		vec3 s = view_position(clamp(tap, vec2(0.001), vec2(0.999)), inv_projection);
		vec3 v = s - p;
		float dist = length(v);
		// Occluders beyond the radius (a far wall behind a pole) fade out quadratically.
		float falloff = 1.0 - clamp(dist / radius, 0.0, 1.0);
		occluded += max(dot(n, v / max(dist, 1e-4)) - COS_BIAS, 0.0) * falloff * falloff;
	}
	return occluded / float(count);
}

void fragment() {
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	if (is_sky(depth) || strength <= 0.001) {
		discard;
	}
	vec3 p = view_position(SCREEN_UV, INV_PROJECTION_MATRIX);
	float fade = 1.0 - smoothstep(fade_start, fade_end, length(p));
	if (fade <= 0.0) {
		discard;
	}
	// Face normal from the depth neighbours; the shorter side difference on each axis
	// keeps silhouettes from bending the normal across a depth edge.
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec3 pr = view_position(SCREEN_UV + vec2(px.x, 0.0), INV_PROJECTION_MATRIX) - p;
	vec3 pl = p - view_position(SCREEN_UV - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	vec3 pu = view_position(SCREEN_UV + vec2(0.0, px.y), INV_PROJECTION_MATRIX) - p;
	vec3 pd = p - view_position(SCREEN_UV - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	vec3 dx = abs(pr.z) < abs(pl.z) ? pr : pl;
	vec3 dy = abs(pu.z) < abs(pd.z) ? pu : pd;
	vec3 n = normalize(cross(dy, dx));
	if (dot(n, p) > 0.0) {
		n = -n;
	}
	// Clip w of this point: -z for a perspective lens, 1 for an orthographic one.
	float w = PROJECTION_MATRIX[2][3] * p.z + PROJECTION_MATRIX[3][3];
	// abs(): RenderingDevice (Metal/Vulkan) projections flip Y, so [1][1] is negative there
	// and a signed radius skipped every ring.
	vec2 uv_per_unit = abs(vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1])) * 0.5 / max(abs(w), 1e-4);
	// Interleaved gradient noise rotates the spiral per pixel: grain instead of banding.
	float rotation = 6.2831853 * fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float occlusion = 0.0;
	vec2 contact_uv = min(uv_per_unit * contact_radius, vec2(MAX_RADIUS_UV));
	// Skip a ring that covers less than two pixels: it cannot resolve anything.
	if (contact_samples > 0 && contact_uv.y * VIEWPORT_SIZE.y > 2.0) {
		occlusion += contact_weight * ring_occlusion(
			p, n, SCREEN_UV, contact_uv, contact_radius, contact_samples, rotation,
			INV_PROJECTION_MATRIX
		);
	}
	vec2 area_uv = min(uv_per_unit * area_radius, vec2(MAX_RADIUS_UV));
	if (area_samples > 0 && area_uv.y * VIEWPORT_SIZE.y > 2.0) {
		occlusion += area_weight * ring_occlusion(
			p, n, SCREEN_UV, area_uv, area_radius, area_samples, rotation + 1.7,
			INV_PROJECTION_MATRIX
		);
	}
	ALBEDO = vec3(0.0);
	ALPHA = clamp(occlusion * 1.6, 0.0, 1.0) * strength * fade;
}
