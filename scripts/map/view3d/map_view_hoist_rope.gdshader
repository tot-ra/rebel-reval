shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Hoist ropes with an iron hook hanging from a gable beam (R-1200).
//
// WHY: the kit baked the rope as a rigid six-sided cylinder, so it read as a
// grey stick next to flags that fly in the wind. A loaded hoist rope is a
// pendulum: the hook mass keeps it nearly straight, it leans downwind as the
// wind rises, swings slowly with a period set by its length, traces a loose
// ellipse rather than a line, and the rope itself bows a little between the
// sheave and the hook from drag. The hook rides the rope end rigidly and turns
// slowly as the laid rope twists and untwists.
//
// Mesh contract (MapViewHoistRope.build_mesh): anchor at the origin, the rope
// hangs along -Y. UV.y = s / L for rope vertices (s = distance below the
// anchor). UV2.x = 1 marks hook vertices, UV2.y = L for every vertex. Hook
// vertices are authored at their rest place below y = -L. The node must not be
// scaled: wind is resolved in local space and lengths are metres.

uniform vec3 base_color : source_color = vec3(0.50, 0.41, 0.25);
uniform float roughness_value = 0.95;
uniform float metallic_value = 0.0;
uniform float specular_value = 0.3;
// Pendulum response; 1.0 is the reference loaded hook.
uniform float sway_strength = 1.0;
uniform vec2 wind_direction = vec2(0.9285, 0.3714);
uniform float wind_strength = 0.22;
// 1.0 draws the three-strand hemp lay; 0.0 for the iron hook.
uniform float lay_pattern = 0.0;
// One strand returns to the same side of the rope every `lay_pitch` metres.
uniform float lay_pitch = 0.11;

varying float rope_len;

const float GRAVITY = 9.81;

float gusted_wind(float wind, float t, float seed) {
	float gust = sin(t * 0.37 + seed) * sin(t * 0.23 + seed * 1.7);
	return clamp(wind * (0.85 + 0.35 * gust), 0.0, 1.0);
}

// Rotation taking the rest hang direction (0, -1, 0) onto unit vector `d`.
mat3 hang_basis(vec3 d) {
	vec3 down = vec3(0.0, -1.0, 0.0);
	vec3 axis = cross(down, d);
	float s = length(axis);
	float c = dot(down, d);
	if (s < 0.00001) {
		return mat3(1.0);
	}
	axis /= s;
	float ic = 1.0 - c;
	return mat3(
		vec3(c + axis.x * axis.x * ic, axis.y * axis.x * ic + axis.z * s, axis.z * axis.x * ic - axis.y * s),
		vec3(axis.x * axis.y * ic - axis.z * s, c + axis.y * axis.y * ic, axis.z * axis.y * ic + axis.x * s),
		vec3(axis.x * axis.z * ic + axis.y * s, axis.y * axis.z * ic - axis.x * s, c + axis.z * axis.z * ic)
	);
}

mat3 yaw(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

void vertex() {
	float t = TIME;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float seed = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453) * TAU;
	float w = gusted_wind(clamp(wind_strength, 0.0, 1.0), t, seed);
	float len = max(UV2.y, 0.1);
	bool hook = UV2.x > 0.5;
	rope_len = len;
	float s = hook ? len : clamp(-VERTEX.y, 0.0, len);
	float u = s / len;

	vec2 wind = normalize(wind_direction);
	vec3 local_wind = (inverse(MODEL_MATRIX) * vec4(wind.x, 0.0, wind.y, 0.0)).xyz;
	vec2 down_wind = dot(local_wind.xz, local_wind.xz) > 0.000001 ? normalize(local_wind.xz) : vec2(1.0, 0.0);
	vec2 cross_wind = vec2(-down_wind.y, down_wind.x);
	float scale = sway_strength;

	// Simple pendulum: omega = sqrt(g / L). A 4.5 m rope swings in ~4 s.
	float omega = sqrt(GRAVITY / len);
	// Steady lean downwind (drag on rope and hook against the hook weight) that
	// sags back in the lulls between gusts.
	float lull = 0.5 - 0.5 * sin(t * 0.61 + seed * 2.3);
	float lean = scale * w * w * 0.13 * (1.0 - 0.25 * lull);
	// Swing along the wind and a weaker, detuned swing across it: the hook traces
	// a slowly precessing ellipse. Amplitude follows the gusts.
	float gust = 0.6 + 0.4 * sin(t * 0.29 + seed * 0.7);
	float swing = scale * mix(0.018, 0.075, w) * gust;
	float along_angle = lean + swing * sin(omega * t + seed);
	float across_angle = swing * 0.45 * sin(omega * 1.07 * t + seed * 1.9);
	vec2 tilt = down_wind * along_angle + cross_wind * across_angle;
	vec3 chord = normalize(vec3(tilt.x, -1.0, tilt.y));

	// Drag bows the free rope downwind between the pinned sheave and the hook;
	// a short travelling ripple runs down the rope in stronger wind.
	float bow_shape = sin(PI * u);
	float bow = scale * len * (0.012 * w + 0.004) * (0.7 + 0.3 * sin(t * 1.3 + seed * 3.1));
	float ripple = scale * len * 0.004 * w * sin(TAU * 1.5 * u - t * mix(3.0, 7.0, w) + seed) * u * (1.0 - u);
	vec2 lateral = down_wind * bow * bow_shape + cross_wind * ripple;

	// Centre line and tangent at s.
	vec3 centre = chord * s + vec3(lateral.x, 0.0, lateral.y);
	vec2 lateral_d = down_wind * bow * PI / len * cos(PI * u);
	vec3 tangent = normalize(chord + vec3(lateral_d.x, 0.0, lateral_d.y));

	// Lay twist: the hook turns slowly; the rope winds up toward it.
	float twist = scale * (0.35 + 0.25 * w) * sin(t * 0.43 + seed * 2.7) * u;
	mat3 frame = hang_basis(tangent) * yaw(twist);

	if (hook) {
		vec3 rest = VERTEX - vec3(0.0, -len, 0.0);
		VERTEX = centre + frame * rest;
	} else {
		vec3 radial = VERTEX - vec3(0.0, -s, 0.0);
		VERTEX = centre + frame * radial;
	}
	NORMAL = normalize(frame * NORMAL);
}

void fragment() {
	float shade = 1.0;
	float ao = 1.0;
	if (lay_pattern > 0.5) {
		// Right-hand lay: three strands spiral down the rope. Drawn per pixel
		// because geometry rings far apart enough to bend cheaply would alias.
		float s = UV.y * rope_len;
		float lay = TAU * 3.0 * (UV.x - s / lay_pitch);
		float crest = 0.5 + 0.5 * cos(lay);
		// Fibres run along each strand: a fine hash streak across the lay.
		float fibre = fract(sin(floor(UV.x * 90.0 + s * 260.0) * 91.7) * 4375.85);
		// Fade the lay out once a stripe is narrower than a couple of pixels.
		float detail = 1.0 - smoothstep(1.2, 3.0, fwidth(lay));
		shade = mix(1.0, mix(0.62, 1.06, sqrt(crest)) * (0.92 + 0.12 * fibre), detail);
		ao = mix(1.0, mix(0.7, 1.0, crest), detail);
	}
	ALBEDO = base_color * COLOR.rgb * shade;
	AO = ao;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	SPECULAR = specular_value;
}
