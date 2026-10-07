shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.38, 0.48, 0.24);
uniform float sway_strength = 0.10;
uniform vec2 wind_direction = vec2(0.9285, 0.3714);
uniform float wind_strength = 0.22;
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

varying flat float v_cell;
varying flat float v_dry;
varying float v_atlas;

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
	vec2 wind = wind_direction / max(length(wind_direction), 0.001);
	vec2 across = vec2(-wind.y, wind.x);
	float strength = clamp(wind_strength, 0.0, 1.0);
	// Same advected broad pressure field as trees; fine flutter varies by tuft.
	float phase = dot(world.xz, wind) * 0.65 - TIME * 1.4;
	float gust = 0.55 + 0.30 * sin(phase) + 0.15 * sin(phase * 0.43 + TIME * 0.37);
	float flutter = sin(TIME * 4.1 + world.x * 3.7 + world.z * 2.3);
	float weight = UV.y * UV.y;
	vec2 displace = (wind * (0.35 + gust) + across * flutter * 0.16)
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
		vec3 albedo = tex.rgb * COLOR.rgb * 0.86;
		// Sun-cured blades fade to straw; greener clusters stay fresher.
		float greenness = clamp(tex.g - tex.r * 0.6, 0.0, 1.0);
		albedo = mix(albedo, straw_color * (0.7 + 0.5 * tex.g), v_dry * greenness);
		// Root to tip: shaded base melted into the ground plate, bright tips.
		albedo *= mix(0.62, 1.08, smoothstep(0.0, 0.85, blade));
		float root = 1.0 - smoothstep(0.0, 0.30, blade);
		albedo = mix(albedo, root_tint * COLOR.rgb, root * 0.75);
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
		ALBEDO *= 1.0 + midrib * 0.10;
		// Light-driven transmission, not emission: plants remain dark at night.
		BACKLIGHT = ALBEDO * (0.26 + blade * 0.14);
		ROUGHNESS = mix(0.94, 0.72, blade);
		SPECULAR = 0.25;
	}
}
