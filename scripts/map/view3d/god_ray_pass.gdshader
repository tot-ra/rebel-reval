shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, blend_add;

// Volumetric crepuscular rays (god rays) ray-marched through the street air.
// GL Compatibility has no volumetric fog, and screen/depth hints are unreliable on
// this pipeline (see cloud_shadow_pass.gdshader and the underwater pass notes), so
// the pass carries its own scene description: a max-height raster of building and
// landmark masses (god_ray_pass.gd). Each pixel walks its eye ray through the air
// slab between the ground and the roofline, stops where the ray enters architecture,
// and at every sample marches toward the sun/moon through the same raster. Only
// samples that see the light scatter, so shafts start at real roof edges and gaps,
// buildings cut them like shadows, and air in a building's shade stays dark.
// A Henyey-Greenstein phase keeps the haze bright only when the camera looks toward
// the light; from straight above, the forward-scattered light does not reach the eye.
uniform sampler2D height_map : filter_nearest, repeat_disable;
// World XZ of the raster's (0, 0) corner and the world size of one texel.
uniform vec2 map_origin = vec2(0.0);
uniform float texel_size = 1.0;
// Air slab the march covers: ground floor to just above the tallest roof.
uniform float floor_y = 0.0;
uniform float volume_top = 12.0;
// Unit vector toward the light, world space.
uniform vec3 light_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 ray_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float strength : hint_range(0.0, 2.0) = 0.0;
// Soft ceiling of the added light: linear for faint haze, saturating toward the cap.
uniform float intensity_cap = 0.6;
uniform float anisotropy : hint_range(0.0, 0.95) = 0.6;
// Share of isotropic scatter mixed into the phase (light that reaches any view).
uniform float isotropic_share : hint_range(0.0, 1.0) = 0.0;
// Scatter per world unit of lit air; the beam saturates along long lit paths.
uniform float density = 0.05;
uniform float max_march = 90.0;
uniform float shadow_reach = 60.0;
uniform int view_steps = 16;
uniform int shadow_steps = 8;

float height_at(vec2 xz) {
	ivec2 size = textureSize(height_map, 0);
	ivec2 cell = ivec2(floor((xz - map_origin) / texel_size));
	if (cell.x < 0 || cell.y < 0 || cell.x >= size.x || cell.y >= size.y) {
		return floor_y;
	}
	return texelFetch(height_map, cell, 0).r;
}

// 1 when the point sees the light through the height raster, 0 when a mass blocks it.
// Samples are packed toward the point (squared spacing): nearby roof edges shape the
// shaft, far ones only need to catch tall towers.
float sun_visibility(vec3 p, float jitter) {
	float reach = min((volume_top - p.y) / max(light_dir.y, 0.02), shadow_reach);
	for (int k = 0; k < shadow_steps; k++) {
		float f = (float(k) + jitter) / float(shadow_steps);
		vec3 q = p + light_dir * (reach * f * f + texel_size * 0.5);
		if (q.y < height_at(q.xz)) {
			return 0.0;
		}
	}
	return 1.0;
}

// Henyey-Greenstein normalised to 1 when looking straight at the light.
float phase(float cos_theta) {
	float g = anisotropy;
	float ratio = (1.0 - g) * (1.0 - g) / max(1.0 + g * g - 2.0 * g * cos_theta, 1e-4);
	return mix(ratio * sqrt(ratio), 1.0, isotropic_share);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	// Eye ray from two unprojected points on the pixel. Works for the orthographic
	// gameplay lens and the perspective close cameras, on both depth conventions.
	vec2 ndc = SCREEN_UV * 2.0 - 1.0;
	vec4 a = INV_PROJECTION_MATRIX * vec4(ndc, 0.25, 1.0);
	vec4 b = INV_PROJECTION_MATRIX * vec4(ndc, 0.75, 1.0);
	a.xyz /= a.w;
	b.xyz /= b.w;
	vec3 dir_view = normalize(b.xyz - a.xyz);
	if (dir_view.z > 0.0) {
		dir_view = -dir_view;
	}
	// Slide the point back to the camera plane (view z = 0): the eye for perspective,
	// the pixel's spot on the lens for orthographic.
	vec3 origin_view = a.xyz - dir_view * (a.z / dir_view.z);
	vec3 origin = (INV_VIEW_MATRIX * vec4(origin_view, 1.0)).xyz;
	vec3 dir = normalize(mat3(INV_VIEW_MATRIX) * dir_view);

	float t0 = 0.0;
	float t1 = max_march;
	if (abs(dir.y) > 1e-4) {
		float t_top = (volume_top - origin.y) / dir.y;
		float t_floor = (floor_y - origin.y) / dir.y;
		t0 = max(min(t_top, t_floor), 0.0);
		t1 = max(t_top, t_floor);
	} else if (origin.y > volume_top || origin.y < floor_y) {
		t1 = 0.0;
	}
	t1 = min(t1, t0 + max_march);

	float lit = 0.0;
	if (t1 > t0) {
		// Interleaved gradient noise: per-pixel step offset turns banding into fine grain.
		float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		float dt = (t1 - t0) / float(view_steps);
		for (int i = 0; i < view_steps; i++) {
			vec3 p = origin + dir * (t0 + (float(i) + jitter) * dt);
			if (p.y <= height_at(p.xz)) {
				break;
			}
			lit += sun_visibility(p, jitter) * dt;
		}
	}
	float scatter = 1.0 - exp(-density * lit);
	float beam = strength * phase(dot(dir, light_dir)) * scatter;
	ALBEDO = ray_color * intensity_cap * (1.0 - exp(-beam / intensity_cap));
	ALPHA = 1.0;
}
