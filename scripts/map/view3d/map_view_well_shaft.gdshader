shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// Fake-depth well opening (interior mapping). The well sits on terrain that is
// opaque at y = 0, so real geometry below the curb would be hidden. This disc
// covers the shaft mouth and ray-traces a virtual cylinder below it instead:
// coursed limestone that darkens with depth, then still black water at the
// bottom that mirrors the bright disc of sky seen through the mouth.
// Everything is in model space, so prop yaw and scale are respected, and it
// works for both the perspective preview and the orthographic map camera.

uniform float shaft_radius = 0.41;
uniform float water_depth = 3.1;
uniform float course_height = 0.17;
uniform float stones_per_course = 10.0;
uniform vec3 stone_color : source_color = vec3(0.56, 0.53, 0.47);
uniform vec3 mortar_color : source_color = vec3(0.33, 0.31, 0.27);
uniform vec3 damp_color : source_color = vec3(0.20, 0.24, 0.16);
uniform vec3 water_color : source_color = vec3(0.012, 0.018, 0.02);
uniform vec3 sky_color : source_color = vec3(0.62, 0.66, 0.68);
uniform float depth_falloff = 2.6;
// Only sky through the mouth lights the shaft, so even the top course sits in
// shade compared with the sunlit curb.
uniform float shaft_shade = 0.28;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
	vec3 view_ray = ortho ? vec3(0.0, 0.0, -1.0) : normalize(VERTEX);
	vec3 world_ray = mat3(INV_VIEW_MATRIX) * view_ray;
	vec3 d = normalize(inverse(mat3(MODEL_MATRIX)) * world_ray);
	vec3 o = local_pos;
	float down = max(-d.y, 1e-4);

	// Exit point through the shaft wall (origin is inside the cylinder).
	float a = dot(d.xz, d.xz);
	float b = dot(o.xz, d.xz);
	float c = dot(o.xz, o.xz) - shaft_radius * shaft_radius;
	float t_wall = a > 1e-6 ? (-b + sqrt(max(b * b - a * c, 0.0))) / a : 1e9;
	float t_water = (water_depth + o.y) / down;

	vec3 color;
	if (t_wall < t_water) {
		vec3 p = o + d * t_wall;
		float depth = max(-p.y, 0.0);
		float row = floor(depth / course_height);
		float fy = fract(depth / course_height);
		float s = (atan(p.x, p.z) / 6.2831853 + 0.5) * stones_per_course
			+ hash12(vec2(row, 3.0)) * 0.9;
		float stone_id = floor(s);
		float fs = fract(s);
		float stone_len = 6.2831853 * shaft_radius / stones_per_course;
		float joint_s = min(fs, 1.0 - fs) * stone_len;
		float joint_y = min(fy, 1.0 - fy) * course_height;
		float joint = 1.0 - smoothstep(0.004, 0.014, min(joint_s, joint_y));
		float tone = 0.72 + 0.4 * hash12(vec2(stone_id, row));
		vec3 wall = mix(stone_color * tone, mortar_color, joint);
		// Lower courses stay wet and green near the waterline.
		float damp = smoothstep(water_depth - 1.2, water_depth, depth);
		wall = mix(wall, damp_color * tone, damp * 0.8);
		color = wall * shaft_shade * exp(-depth * depth_falloff);
	} else {
		vec3 p = o + d * t_water;
		// Mirror the eye ray off the water; where it climbs back out through
		// the mouth the water shows the sky, otherwise the dark shaft.
		vec3 r = vec3(d.x, -d.y, d.z);
		vec2 mouth = p.xz + r.xz * ((water_depth + o.y) / max(r.y, 1e-4));
		float sky = 1.0 - smoothstep(shaft_radius * 0.8, shaft_radius * 0.98, length(mouth));
		float shore = smoothstep(shaft_radius * 0.82, shaft_radius, length(p.xz));
		color = water_color + sky_color * sky * 0.42;
		color = mix(color, water_color, shore * 0.6);
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
}
