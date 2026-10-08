shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://scripts/map/view3d/wind_field.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.38, 0.48, 0.24);
uniform float sway_strength = 0.10;
uniform vec2 interact_center = vec2(0.0);
uniform float interact_strength = 0.0;
uniform float interact_radius = 0.65;
uniform vec2 interact_push = vec2(0.0);
// R-1103: 2x2 blade-cluster atlas (fine meadow, timothy, sedge, dry straw).
uniform sampler2D blade_atlas : source_color, filter_linear_mipmap, repeat_disable;
// Average of the grass ground plate; roots blend into it so no seam shows.
uniform vec3 root_tint : source_color = vec3(0.30, 0.33, 0.17);
uniform vec3 straw_color : source_color = vec3(0.62, 0.54, 0.30);
uniform float max_dryness = 0.42;
// Distance fade: tufts shrink into the ground between fade_start and fade_end
// (measured like visibility ranges, from the camera), so the per-layer range
// cull happens after they are already invisible instead of popping a whole
// chunk in and out as the camera moves. fade_end <= 0 disables it.
uniform float fade_start = 0.0;
uniform float fade_end = 0.0;

varying flat float v_cell;
varying flat float v_dry;
varying float v_atlas;
varying vec2 v_variety;
// R-1321: how far the passing gust front lays this tuft over (0 in a lull).
varying float v_sheen;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Per-tuft hash from the planted position: rotates which atlas cell each
	// card shows and how sun-cured the tuft is, so neighbours never repeat.
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float h2 = fract(h * 7.31 + 0.37);
	// Cards 0-1 stay leafy (fine meadow, sedge); only card 3 may carry timothy
	// spikes or dry straw, so seed heads read as accents, not a wheat field.
	float card = floor(UV2.x + 0.5);
	v_cell = card < 0.5 ? 0.0 : (card < 1.5 ? 2.0 : (card < 2.5 ? (h < 0.5 ? 0.0 : 2.0)
		: (h < 0.55 ? 1.0 : (h < 0.85 ? 0.0 : 3.0))));
	v_dry = h2 * h2 * max_dryness;
	v_atlas = UV2.y;
	// Per-tuft size and tint variety from the planted position, so neighbours
	// differ in height, width and hue instead of repeating one big stamp.
	float h3 = fract(h * 3.17 + h2 * 5.91);
	float size = mix(0.62, 1.22, h3);
	VERTEX.xz *= size * mix(0.85, 1.2, h2);
	VERTEX.y *= mix(0.55, 1.3, fract(h2 * 4.13 + h));
	v_variety = vec2(mix(0.82, 1.12, h), h3);
	if (fade_end > 0.0) {
		float dist = distance(origin, CAMERA_POSITION_WORLD);
		VERTEX *= 1.0 - smoothstep(fade_start, fade_end, dist);
	}
	vec2 wind = wind_dir();
	vec2 across = vec2(-wind.y, wind.x);
	float strength = wind_strength();
	// R-1321: the shared gust front, sampled once per tuft so a whole tuft bends
	// together and the wave rolls across the meadow; fine flutter varies by tuft.
	float push = wind_pressure(origin.xz, TIME);
	float flutter = sin(TIME * 4.1 + world.x * 3.7 + world.z * 2.3) * wind_flutter_scale();
	float weight = UV.y * UV.y;
	// Bent blades turn their paler flanks to the sky: this sheen, not the lean
	// alone, is what makes a front readable from across a field.
	v_sheen = clamp((push - 0.48) * strength, 0.0, 1.0);
	vec2 displace = (wind * push + across * flutter * 0.16)
		* strength * sway_strength * weight;
	vec3 world_displace = vec3(displace.x, -length(displace) * 0.18, displace.y);
	if (interact_strength > 0.001 && interact_radius > 0.001) {
		vec2 offset = world.xz - interact_center;
		float dist = length(offset);
		float falloff = 1.0 - smoothstep(0.0, interact_radius, dist);
		falloff *= falloff;
		vec2 radial = dist > 0.001 ? offset / dist : vec2(0.0, 1.0);
		vec2 interact_disp = radial * 0.9 + interact_push * 0.55;
		float tip = interact_strength * weight * falloff;
		world_displace += vec3(interact_disp.x * tip, -tip * 0.22, interact_disp.y * tip);
	}
	// MultiMeshes rotate each tuft. Convert a world-space push back to local
	// space so adjacent plants bend downwind rather than following their yaw.
	VERTEX += inverse(mat3(MODEL_MATRIX)) * world_displace;
}

void fragment() {
	float blade = clamp(UV.y, 0.0, 1.0);
	if (v_atlas > 0.5) {
		float cell = mod(v_cell, 4.0);
		vec2 origin = vec2(mod(cell, 2.0), floor(cell / 2.0)) * 0.5;
		// Atlas rows run top-down while UV.y runs root-up; the inset keeps
		// mip filtering from pulling in the neighbouring cluster.
		vec2 cell_uv = vec2(clamp(UV.x, 0.01, 0.99), clamp(1.0 - UV.y, 0.01, 0.99));
		vec4 tex = texture(blade_atlas, origin + cell_uv * 0.5);
		ALPHA = tex.a;
		ALPHA_SCISSOR_THRESHOLD = 0.42;
		vec3 albedo = tex.rgb * COLOR.rgb * 0.86 * v_variety.x;
		albedo = mix(albedo, albedo * vec3(1.14, 1.04, 0.78), smoothstep(0.55, 1.0, v_variety.y) * 0.5);
		// Sun-cured blades fade to straw; greener clusters stay fresher.
		float greenness = clamp(tex.g - tex.r * 0.6, 0.0, 1.0);
		albedo = mix(albedo, straw_color * (0.7 + 0.5 * tex.g), v_dry * greenness);
		// Root to tip: shaded base melted into the ground plate, bright tips.
		albedo *= mix(0.62, 1.08, smoothstep(0.0, 0.85, blade));
		float root = 1.0 - smoothstep(0.0, 0.30, blade);
		albedo = mix(albedo, root_tint * COLOR.rgb, root * 0.75);
		albedo = mix(albedo, albedo * vec3(1.32, 1.30, 1.12), v_sheen * 0.8 * blade);
		ALBEDO = albedo;
		// Soft sky-lit shading: lean normals toward up so cards do not flip dark.
		NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.55));
		BACKLIGHT = ALBEDO * (0.24 + blade * 0.14);
		ROUGHNESS = mix(0.94, 0.74, blade);
		SPECULAR = 0.22;
	} else {
		// Procedural blade (seed heads and any untextured tuft mesh).
		float midrib = 1.0 - smoothstep(0.025, 0.025 + max(fwidth(UV.x), 0.035), abs(UV.x - 0.5));
		ALBEDO = base_color * COLOR.rgb * mix(0.58, 1.12, sqrt(blade));
		ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.32, 1.30, 1.12), v_sheen * 0.8 * blade);
		ALBEDO *= 1.0 + midrib * 0.10;
		// Light-driven transmission, not emission: plants remain dark at night.
		BACKLIGHT = ALBEDO * (0.26 + blade * 0.14);
		ROUGHNESS = mix(0.94, 0.72, blade);
		SPECULAR = 0.25;
	}
}
