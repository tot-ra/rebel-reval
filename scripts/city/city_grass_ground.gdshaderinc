// City grass ground from twelve seamless plates (R-1103, VEG-4).
// Included by city_ground.gdshader after hash12/value_noise.
//
// Why: one grass plate repeated every 1.6 m showed as a grid from any height,
// and its texels were twice real size next to Kalev. Here every plate covers
// ~1.3 m (grass_ground_scale), and the ground is cut into a warped lattice of
// ~4.5 m cells. Each lattice corner picks its own plate, rotation and offset;
// a pixel blends its four corners with height-aware weights (bright blade tips
// win over dark gaps), so patches of clover, hay meadow, moss or dry grass meet
// in ragged natural edges instead of straight seams. Four array fetches per
// pixel replace the old two-sample detiling.
//
// Slice order (tools/assets/build_vegetation_plates.py GRASS):
//   0-7 green meadows, 8 dry summer, 9 moss in shade, 10 leaf litter, 11 trodden.

uniform sampler2DArray grass_ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray grass_ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grass_ground_scale = 0.75; // plate repeats per world unit (1 wu = 1 m)
uniform float grass_ground_cell = 4.5; // lattice cell in world units
// Brings the plates' mean colour halfway to the old single plate so the
// city's overall tone does not jump; grass_tint still grades on top.
uniform vec3 grass_ground_grade = vec3(0.87, 0.70, 1.30);

struct GrassGround {
	vec3 albedo;
	vec2 normal_xy;
};

// Variant for a lattice corner. Rough pasture (lush meadow, hay meadow, yarrow,
// sedge: slices 1, 3, 5, 6) dominates a 1343 town common; short turf, clover,
// spring grass and flowers (0, 2, 4, 7) come up now and then, and dry, mossy
// or leaf-strewn patches are rare accents.
float grass_ground_variant(float r) {
	if (r < 0.60) {
		int rough[4] = int[](1, 3, 5, 6);
		return float(rough[min(int(r / 0.60 * 4.0), 3)]);
	}
	if (r < 0.88) {
		int short_turf[4] = int[](0, 2, 4, 7);
		return float(short_turf[min(int((r - 0.60) / 0.28 * 4.0), 3)]);
	}
	if (r < 0.94) {
		return 8.0;
	}
	if (r < 0.98) {
		return 9.0;
	}
	return 10.0;
}

GrassGround grass_ground(vec2 p, float trodden) {
	// Domain warp keeps the lattice from reading as rows of squares.
	vec2 warp = vec2(value_noise(p * 0.09), value_noise(p * 0.09 + vec2(31.7, 11.3))) - 0.5;
	vec2 q = p / grass_ground_cell + warp * 1.4;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec3 acc = vec3(0.0);
	vec2 nacc = vec2(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 corner = cell + vec2(float(i & 1), float(i >> 1));
		float wx = (i & 1) == 1 ? u.x : 1.0 - u.x;
		float wy = (i >> 1) == 1 ? u.y : 1.0 - u.y;
		float r0 = hash12(corner + vec2(3.1, 7.7));
		float r1 = hash12(corner + vec2(17.3, 1.9));
		float r2 = hash12(corner + vec2(5.9, 23.1));
		float layer = grass_ground_variant(r0);
		float a = r1 * 6.2831853;
		mat2 rot = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
		vec2 uv = rot * (p * grass_ground_scale) + vec2(r1, r2) * 7.0;
		vec3 c = texture(grass_ground_albedo, vec3(uv, layer)).rgb;
		vec2 n = texture(grass_ground_normal, vec3(uv, layer)).rg * 2.0 - 1.0;
		// Normals were authored in plate space; turn them back to world space.
		n = transpose(rot) * n;
		float lum = dot(c, vec3(0.3, 0.59, 0.11));
		float w = wx * wy;
		w = pow(w, 1.6) * (0.25 + lum * 2.5);
		acc += c * w;
		nacc += n * w;
		wsum += w;
	}
	vec3 col = acc / wsum;
	vec2 nrm = nacc / wsum;
	// Grass worn thin round packed earth and paths: the trodden plate fades in
	// where the blades are darkest first, so bare soil shows between tufts.
	if (trodden > 0.001) {
		vec2 tuv = p * grass_ground_scale * 0.93 + vec2(0.31, 0.57);
		vec3 tc = texture(grass_ground_albedo, vec3(tuv, 11.0)).rgb;
		vec2 tn = texture(grass_ground_normal, vec3(tuv, 11.0)).rg * 2.0 - 1.0;
		float lum = dot(col, vec3(0.3, 0.59, 0.11));
		float t = smoothstep(0.0, 1.0, clamp(trodden * 1.6 - lum * 1.2 + 0.1, 0.0, 1.0));
		col = mix(col, tc, t);
		nrm = mix(nrm, tn, t);
	}
	GrassGround g;
	g.albedo = col * grass_ground_grade;
	g.normal_xy = nrm;
	return g;
}
