shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Cereal clumps of the strip fields (CityGrainMeshes, R-2112). Vertex contract:
// COLOR.rgb albedo (linear, times the per-plant MultiMesh tint), COLOR.a light
// transmitted, UV.x flex (0 rigid root .. 1 free top), UV.y ear weight (1 on
// ears, awns and panicles).

#include "res://scripts/map/view3d/wind_field.gdshaderinc"

uniform float sway_strength = 0.16;
// Seconds the heavy head trails the stalk: a gust lays the stalks over first and
// the ears follow and overshoot, so a wave rolling over the field reads as grain.
uniform float ear_lag = 0.4;
uniform float ear_overshoot = 1.3;
// Mid-tier fade: clumps shrink into the ground between fade_start and fade_end,
// measured on the ground from the player (lod_focus) when one drives the view.
uniform float fade_start = 0.0;
uniform float fade_end = 0.0;
uniform vec2 lod_focus = vec2(0.0);
uniform float lod_focus_on = 0.0;
// Character parting and the R-1327 footfall trail, pushed by
// MapViewWindMaterials.apply_grass_interaction like the grass.
uniform vec2 interact_center = vec2(0.0);
uniform float interact_strength = 0.0;
uniform float interact_radius = 0.65;
uniform vec2 interact_push = vec2(0.0);
uniform vec4 trail[8];

varying float v_ear;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float lod_dist = lod_focus_on > 0.5
		? distance(origin.xz, lod_focus) : distance(origin, CAMERA_POSITION_WORLD);
	if (fade_end > 0.0) {
		VERTEX *= 1.0 - smoothstep(fade_start, fade_end, lod_dist);
	}
	float flex = UV.x;
	float ear = UV.y;
	float h = max(world.y - origin.y, 0.0);
	vec2 wind = wind_dir();
	vec2 across = vec2(-wind.y, wind.x);
	// One gust sample per clump so its stalks bend together; the ears read the
	// same front ear_lag seconds earlier in its travel, i.e. they answer late.
	float push = wind_pressure(origin.xz, TIME);
	float push_late = wind_pressure(origin.xz, TIME - ear_lag) * ear_overshoot;
	float p = mix(push, push_late, ear);
	float flutter = sin(TIME * 3.1 + origin.x * 2.7 + origin.z * 1.9) * wind_flutter_scale();
	// Tall stalks swing further than short ones: scale by the height reached.
	vec2 d = (wind * p + across * flutter * 0.14) * wind_strength() * sway_strength
		* flex * flex * (0.35 + h);
	vec3 bend = vec3(d.x, -length(d) * 0.3, d.y);
	if (interact_strength > 0.001 && interact_radius > 0.001) {
		vec2 offset = world.xz - interact_center;
		float dist = length(offset);
		float reach = interact_radius + h * 0.5;
		float falloff = (1.0 - smoothstep(0.0, reach, dist)) * flex * flex;
		vec2 radial = dist > 0.001 ? offset / dist : vec2(0.0, 1.0);
		vec2 away = radial * 0.9 + interact_push * 0.5;
		float lean = interact_strength * (1.0 + 4.0 * h);
		bend += vec3(away.x * falloff * lean, -falloff * h * 0.3, away.y * falloff * lean);
	}
	// Trodden lane: stalks part sideways of the path and are pressed along it.
	for (int i = 0; i < 8; i++) {
		float press = trail[i].w;
		if (press < 0.01) {
			continue;
		}
		vec2 offset = world.xz - trail[i].xy;
		float dist = length(offset);
		float reach = interact_radius + 0.3 + h * 0.5;
		if (dist > reach) {
			continue;
		}
		float falloff = (1.0 - smoothstep(0.0, reach, dist)) * press * flex * flex;
		vec2 radial = dist > 0.001 ? offset / dist : vec2(0.0, 1.0);
		vec2 heading = vec2(cos(trail[i].z), sin(trail[i].z));
		vec2 away = radial * 0.9 + heading * 0.35;
		bend += vec3(away.x * falloff * h * 0.9, -falloff * h * 0.6, away.y * falloff * h * 0.9);
	}
	// MultiMeshes rotate and scale each clump: push in world space.
	VERTEX += inverse(mat3(MODEL_MATRIX)) * bend;
	v_ear = ear;
}

void fragment() {
	// Shaded inside the stand: the lower stalks and leaves are darker than the
	// sunlit heads, as the grass blades are (and the city's outdoor gain would
	// otherwise bleach the straw to cream).
	ALBEDO = COLOR.rgb * mix(0.42, 0.92, smoothstep(0.0, 0.85, max(UV.x, UV.y)));
	// Lean toward the sky so a stalk seen edge-on never flips dark.
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.35));
	BACKLIGHT = ALBEDO * COLOR.a * 0.5;
	// Ripe glumes have a dull sheen; leaves and stalks stay matt.
	ROUGHNESS = mix(0.82, 0.62, v_ear);
	SPECULAR = mix(0.12, 0.22, v_ear);
}
