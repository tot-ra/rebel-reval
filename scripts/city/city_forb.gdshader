shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Wild plants of the seamless city (CityForbMeshes, R-1519). Vertex contract:
// COLOR.rgb albedo (linear, times the per-plant MultiMesh tint), COLOR.a light
// transmitted, UV.x flex (0 rigid root .. 1+ free tip), UV.y underside
// paleness shown on back faces, UV2 leaf-detail atlas coordinates
// (tools/assets/generate_forb_leaf_atlas.py; neutral tile on stems and heads).

#include "res://scripts/map/view3d/wind_field.gdshaderinc"

// Veins, clover chevrons and mottling as a multiplier stored at half scale
// (0.5 = x1), so vertex colours keep the tone and the atlas adds the detail.
uniform sampler2D leaf_detail : hint_default_white, filter_linear_mipmap, repeat_disable;

uniform float sway_strength = 0.07;
// Plants shrink into the ground between fade_start and fade_end (from the
// camera) so the chunk cull happens after they are already invisible.
uniform float fade_start = 0.0;
uniform float fade_end = 0.0;
// Back faces of leaves: grey-green, as burdock's woolly underside.
uniform vec3 underside_tint : source_color = vec3(0.74, 0.78, 0.68);

varying float v_under;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (fade_end > 0.0) {
		VERTEX *= 1.0 - smoothstep(fade_start, fade_end, distance(origin, CAMERA_POSITION_WORLD));
	}
	// Same gust front as the grass, sampled once per plant so it bends as one;
	// flutter differs per part so heads nod against their stems.
	vec2 wind = wind_dir();
	vec2 across = vec2(-wind.y, wind.x);
	float push = wind_pressure(origin.xz, TIME);
	float flutter = sin(TIME * 5.3 + world.x * 9.1 + world.z * 7.7) * wind_flutter_scale();
	float flex = UV.x;
	vec2 d = (wind * push + across * flutter * 0.35) * wind_strength() * sway_strength * flex * flex;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(d.x, -length(d) * 0.25, d.y);
	v_under = UV.y;
}

void fragment() {
	vec3 albedo = COLOR.rgb * texture(leaf_detail, UV2).rgb * 2.0;
	if (!FRONT_FACING) {
		float luma = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
		// Pale whatever the upper side: hairs and wax scatter light on their own.
		albedo = mix(albedo, underside_tint * (0.42 + luma * 1.2), v_under);
	}
	ALBEDO = albedo;
	// Lean toward the sky so a leaf seen edge-on or from below never turns black.
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.3));
	BACKLIGHT = albedo * COLOR.a;
	// Low specular: at grazing angles a glossier leaf mirrors the blue sky.
	ROUGHNESS = 0.8;
	SPECULAR = 0.14;
}
