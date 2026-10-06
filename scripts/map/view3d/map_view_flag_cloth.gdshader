shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Hoist-fixed flags and pennants (tower roofs, the town hall gable, mastheads).
//
// WHY: the shared sail shader only pushed vertices along the wind vector, so a
// pennant stretched and sheared sideways instead of flying. Real flag cloth
// does three things this shader models:
//   1. weathervanes - the whole cloth turns about the staff to stream downwind;
//   2. droops - gravity beats drag in a light breeze, so the fly sags toward
//      the staff and lifts toward horizontal as the wind rises;
//   3. flutters - a travelling wave runs from hoist to fly, pinned at the hoist,
//      growing toward the free edge, faster and tighter in strong wind.
// The deformation is length-preserving to first order (the fly pulls in as the
// wave deepens), and normals are rebuilt from the deformed surface so folds
// catch the light.
//
// Mesh contract: rest pose flat in local XY, hoist edge on x = 0 (the staff
// axis), fly toward +X, UV.x = x / fly length. Vertex COLOR carries heraldry.

uniform vec3 base_color : source_color = vec3(0.97, 0.96, 0.94);
// 0.42 is the reference flutter; boats and towers share the same scale.
uniform float sway_strength = 0.42;
uniform vec2 wind_direction = vec2(0.9285, 0.3714);
uniform float wind_strength = 0.22;
// Kept for API parity with map_view_cloth.gdshader; the fly axis is UV.x.
uniform vec2 free_edge = vec2(1.0, 0.0);
// 1.0 when vertex colors are authored in sRGB (town hall cloth).
uniform float vertex_color_srgb = 0.0;
// Wool lets some daylight through; shows when the sun is behind the cloth.
uniform float translucency = 0.32;

varying float fold_shade;

// Effective wind after slow, per-flag gusting so neighbours never flap in sync.
float gusted_wind(float wind, float t, float seed) {
	float gust = sin(t * 0.37 + seed) * sin(t * 0.23 + seed * 1.7);
	return clamp(wind * (0.85 + 0.35 * gust), 0.0, 1.0);
}

// Deformed position for a rest-pose point. `s` is the distance from the hoist,
// `y` the height along the hoist edge, `len` the fly length.
vec3 flag_pose(float s, float y, float len, float w, float t, float seed, out float wave) {
	float u = clamp(s / len, 0.0, 1.0);
	float y_rel = y / len;
	float scale = sway_strength / 0.42;

	// Travelling wave: about one wavelength along the cloth in a breeze, closer
	// to two in a gale; the front lags with height so the fly edge twists.
	float waves = mix(0.9, 1.7, w);
	float k = TAU * waves;
	float omega = mix(2.6, 12.5, w);
	float ph = k * u - omega * t + seed - y_rel * 1.1;
	float env = pow(u, 1.25);
	float amp = len * scale * mix(0.10, 0.14, w);
	wave = sin(ph) + 0.32 * sin(2.13 * ph + 1.3 + y_rel * 2.4);
	float z = amp * env * wave;
	// The free corners snap at a higher harmonic.
	z += len * scale * 0.035 * u * u * u * sin(omega * 2.7 * t + k * 2.2 * u + seed * 3.1);

	// Cloth does not stretch: the deeper the wave, the closer the fly to the staff.
	float slope = amp * k / len;
	float pull_in = clamp(0.22 * slope * slope, 0.0, 0.3);
	float along = s * (1.0 - pull_in * u);

	// Gravity versus drag: constant-curvature sag that lifts as wind rises and
	// briefly deepens in the lulls between gusts.
	float lull = 0.5 - 0.5 * sin(t * 0.61 + seed * 2.3);
	float droop = mix(1.4, 0.1, smoothstep(0.0, 0.6, w)) * (1.0 + 0.2 * lull);
	float bend = droop / len;
	float x;
	float sag;
	if (bend > 0.0001) {
		x = sin(along * bend) / bend;
		sag = (cos(along * bend) - 1.0) / bend;
	} else {
		x = along;
		sag = 0.0;
	}
	float ripple_y = 0.18 * amp * env * cos(ph * 0.5 + y_rel);
	return vec3(x, y + sag + ripple_y, z);
}

void vertex() {
	float t = TIME;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float seed = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453) * TAU;
	float w = gusted_wind(clamp(wind_strength, 0.0, 1.0), t, seed);

	// Fly length from the rest pose (UV.x = x / len), so one material serves
	// pennants and flags of any size.
	float len = UV.x > 0.02 ? max(VERTEX.x / UV.x, 0.05) : 1.0;

	float wave;
	vec3 posed = flag_pose(VERTEX.x, VERTEX.y, len, w, t, seed, wave);
	float e = len * 0.02;
	float wave_unused;
	vec3 along_s = flag_pose(VERTEX.x + e, VERTEX.y, len, w, t, seed, wave_unused) - posed;
	vec3 along_y = flag_pose(VERTEX.x, VERTEX.y + e, len, w, t, seed, wave_unused) - posed;
	// Duplicate back-face quads keep their own winding: follow the rest normal.
	vec3 deformed_normal = normalize(cross(along_s, along_y)) * (NORMAL.z < 0.0 ? -1.0 : 1.0);
	fold_shade = wave * smoothstep(0.0, 0.35, UV.x);

	// Weathervane about the staff (local Y): +X turns to point downwind, with a
	// little hunting that grows in light air.
	vec2 wind = normalize(wind_direction);
	vec3 local_wind = (inverse(MODEL_MATRIX) * vec4(wind.x, 0.0, wind.y, 0.0)).xyz;
	float heading = 0.0;
	if (dot(local_wind.xz, local_wind.xz) > 0.000001) {
		heading = atan(-local_wind.z, local_wind.x);
	}
	heading += sin(t * 0.83 + seed) * mix(0.22, 0.06, w);
	float c = cos(heading);
	float sn = sin(heading);
	mat3 yaw = mat3(vec3(c, 0.0, -sn), vec3(0.0, 1.0, 0.0), vec3(sn, 0.0, c));

	VERTEX = yaw * posed;
	NORMAL = normalize(yaw * deformed_normal);
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 tint = COLOR.rgb;
	if (vertex_color_srgb > 0.5) {
		tint = mix(
			tint / 12.92,
			pow((tint + vec3(0.055)) / 1.055, vec3(2.4)),
			step(vec3(0.04045), tint)
		);
	}
	vec3 albedo = base_color * tint;
	ALBEDO = albedo;
	// Troughs of the wave sit in their own shadow.
	AO = 1.0 - 0.22 * clamp(-fold_shade, 0.0, 1.0);
	ROUGHNESS = 0.9;
	SPECULAR = 0.3;
	BACKLIGHT = albedo * translucency;
}
