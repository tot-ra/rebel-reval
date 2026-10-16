shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Chimney smoke puff (ChimneySmoke3D, docs/SYSTEMS/SEAMLESS_CITY.md).
//
// WHY a shader and not the flat smoke billboard: a flat tinted disc reads as a
// paper cut-out. Mobile has no volumetric fog volumes, so each puff fakes a small
// volume instead:
// - density is a sphere falloff carved by animated 3D value-noise fbm, so the
//   puff has billowy lobes and wispy holes that keep evolving over its life;
// - older puffs erode (the noise eats more of the edge) and spread thinner;
// - the puff is lit as a soft sphere (wrapped sun term) plus forward scattering,
//   so the sunlit side is bright, the far side grey and backlit edges glow;
// - thick cores are darker than thin edges (cheap self-shadowing);
// - soft-particle fade against the depth buffer hides the hard line where a puff
//   cuts through a roof or wall.

// World size of the noise cells relative to the puff (higher = finer lobes).
uniform float noise_scale = 2.4;
// How strongly noise carves the puff (0 = smooth balls, 1 = very ragged).
uniform float erosion = 0.62;
// Extra erosion by the end of life: old smoke frays into wisps.
uniform float age_erosion = 0.2;
// Density near the core becomes this much darker (self-shadowing).
uniform float self_shadow = 0.45;
// How strongly noise lobes tilt the lighting normal.
uniform float relief = 0.35;
// Forward-scattering strength (silver lining when looking toward the sun).
uniform float scatter = 0.55;
// Soft-particle fade distance in metres.
uniform float soft_distance = 0.6;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying float v_seed;
varying float v_life;
varying float v_angle;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
		mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
		u.z
	);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 3; i++) {
		sum += amp * value_noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		amp *= 0.48;
	}
	return sum / 0.9;
}

void vertex() {
	// Camera-facing quad around the particle; size from the particle scale.
	vec3 centre = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_seed = float(INSTANCE_ID) * 0.6180339 + fract(sin(dot(centre.xz, vec2(12.9898, 78.233))) * 43.7);
	v_life = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	// ParticleProcessMaterial keeps the spin angle (radians) in CUSTOM.x.
	v_angle = INSTANCE_CUSTOM.x;
}

// Puff noise at quad point `p`, spun by the particle angle so the puff turns
// slowly as it rises (the noise turns, not the quad).
float puff_noise(vec2 p) {
	float c = cos(v_angle);
	float s = sin(v_angle);
	vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	vec3 np = vec3(q * noise_scale, v_seed * 7.13 + v_life * 1.6);
	return fbm(np + vec3(v_seed * 3.1, v_seed * 5.7, 0.0));
}

void fragment() {
	// Quad point with +y up (UV.y runs down the quad), to match view space.
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r2 = dot(p, p);
	if (r2 >= 1.0) {
		discard;
	}
	float n = puff_noise(p);
	// Sphere density, carved by noise: the edge threshold rises with age.
	float sphere = 1.0 - r2;
	float carve = erosion + age_erosion * v_life;
	float density = clamp(sphere * 1.6 - carve * (1.0 - n) * 1.25, 0.0, 1.0);
	density = density * density * (3.0 - 2.0 * density);

	// Soft particles: fade where the puff meets opaque geometry.
	float scene_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	scene_view.xyz /= scene_view.w;
	float soft = clamp((VERTEX.z - scene_view.z) / soft_distance, 0.0, 1.0);

	// Lobes: treat the noise as relief on a soft sphere and light its slope,
	// so each billow has a sunlit and a shaded side (the "cauliflower" look).
	float eps = 0.06;
	vec2 grad = vec2(puff_noise(p + vec2(eps, 0.0)) - n, puff_noise(p + vec2(0.0, eps)) - n) / eps;
	float z = sqrt(max(1.0 - r2, 0.0));
	NORMAL = normalize(vec3(p * 0.85 - grad * relief, z * 0.8 + 0.3));

	// The ramp is authored in sRGB like the city's other colours; light in linear.
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	// Thick parts and the hollows between lobes are darker (self-shadowing).
	float hollow = clamp(0.6 - n, 0.0, 0.6);
	vec3 tint = base * mix(1.0, 1.0 - self_shadow, clamp(density * (1.0 - v_life * 0.5) + hollow, 0.0, 1.0));
	ALBEDO = tint;
	ALPHA = density * COLOR.a * soft;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	// Wrapped diffuse: smoke scatters, so the dark side never goes fully black.
	float wrap = clamp((dot(NORMAL, LIGHT) + 0.6) / 1.6, 0.0, 1.0);
	// Henyey-Greenstein-ish forward peak toward the light (silver lining).
	float cos_theta = dot(-VIEW, LIGHT);
	float g = 0.55;
	float hg = (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * cos_theta, 1.5) * 0.08;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (wrap + scatter * hg) / PI;
}
