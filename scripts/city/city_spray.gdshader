shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, vertex_lighting, shadows_disabled;

// Billboard for the three spray layers (CityShoreSpray, docs/SYSTEMS/CITY_SEA.md).
//
// WHY a shader and not BILLBOARD_PARTICLES: a droplet in flight is a streak along
// its velocity, which a plain particle billboard cannot draw. The emitter aligns the
// particle's Y axis with the velocity (particle_flag_align_y); this shader builds
// the quad around that axis, facing the camera, and stretches it while the drop is
// still fast. The surface stays lit (sun, sky, night ambient) so spray darkens with
// the evening instead of glowing.

// Length / width of a fresh droplet; 1 keeps mist and sheets round.
uniform float stretch = 1.0;
// How quickly the streak relaxes to a round drop over the particle's life (0 = never).
uniform float stretch_decay = 0.0;
// 1 = quad axis follows the particle velocity (droplets), 0 = camera up (mist, sheets).
uniform float velocity_aligned = 0.0;
// Edge softness 0..1 of the disc (1 = fully soft puff).
uniform float softness = 0.5;
// 0..1 ragged edge for splash sheets (torn water film instead of a clean disc).
uniform float ragged = 0.0;
uniform vec3 tint : source_color = vec3(0.93, 0.96, 1.0);

varying float v_seed;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 to_camera = CAMERA_POSITION_WORLD - centre;
	vec3 view_dir = to_camera / max(length(to_camera), 0.0001);
	vec3 axis = INV_VIEW_MATRIX[1].xyz;
	if (velocity_aligned > 0.5) {
		vec3 along = MODEL_MATRIX[1].xyz;
		axis = along / max(length(along), 0.0001);
	}
	vec3 side = cross(axis, view_dir);
	// A streak seen end-on has no width direction; fall back to the camera right.
	side = length(side) < 0.001 ? INV_VIEW_MATRIX[0].xyz : normalize(side);
	float life = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	float length_scale = mix(stretch, 1.0, clamp(life * stretch_decay, 0.0, 1.0));
	vec3 world = centre + side * VERTEX.x * size + axis * VERTEX.y * size * length_scale;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(view_dir, 0.0)).xyz);
	v_seed = fract(sin(dot(centre.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float edge = 1.0;
	if (ragged > 0.0) {
		// Angular noise tears the rim: a film breaking up, never the same twice.
		float a = atan(p.y, p.x);
		float n = 0.5 + 0.25 * sin(a * 2.0 + v_seed * 40.0) + 0.25 * sin(a * 3.0 - v_seed * 17.0 + 1.3);
		edge = 1.0 - ragged * 0.4 * n;
	}
	float alpha = 1.0 - smoothstep(max(edge - softness, 0.0), edge, r);
	ALBEDO = tint * COLOR.rgb;
	ALPHA = alpha * COLOR.a;
	ROUGHNESS = 0.35;
	SPECULAR = 0.45;
}
