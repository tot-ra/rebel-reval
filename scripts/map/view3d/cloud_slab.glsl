#[versions]

march = "#define MODE_MARCH";
resolve = "#define MODE_RESOLVE";

#[compute]

#version 450

VERSION_DEFINES

// R-1873 high sky tier: ray-marched cumulus slab (Nubis / Horizon style) drawn at a
// quarter of the screen pixels (half width x half height) by CloudSlabEffect.
//
// march   - one jittered ray per texel through the slab between deck altitude 1.0 and
//           SLAB_TOP, written to `cur_image` as (opacity, premultiplied light share).
// resolve - reprojects last frame's result into this frame's view, clamps it to the
//           current 3x3 neighbourhood and blends, so the jitter noise averages out over
//           ~10 frames without ghosting. The sky shader samples `out_image`.
//
// Texels are indexed by world direction through the camera basis and tangents in the
// params block, the same mapping the sky shader uses to look them up (slab_world_to_view
// / slab_tan), so the framebuffer's y orientation never matters.
//
// The cloud field mirrors sky_clouds.gdshaderinc: coverage at the slab base is the lit
// deck opacity (bulk, detail erosion, lobes), so the slab footprint is the field the
// ground-shadow pass and SkyWeather3D.celestial_cloud_clear() already use. Keep the two
// in step (and SkyWeather3D._cloud_volume_density for the CPU mirror).

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std140) uniform Params {
	mat4 view_to_world;       // camera basis (columns x, y, z), this frame
	mat4 prev_world_to_view;  // transposed basis of the frame in the history buffer
	vec4 tan_size;            // tan half fov x, y; texture width, height
	vec4 prev_tan;            // last frame tan half fov x, y; history valid (0/1); frame
	vec4 cloud;               // coverage, chaos, storm intensity, storm locality
	vec4 offsets;             // cloud offset xy, detail offset xy
	vec4 sun;                 // world sun direction xyz, march steps
	vec4 misc;                // wind xy, full-res pixel angle, history blend
	vec4 tex_sizes;           // shape size, noise size, cell noise size, unused
} params;

#ifdef MODE_MARCH
layout(set = 0, binding = 1) uniform sampler2D shape_tex;
layout(set = 0, binding = 2) uniform sampler2D noise_tex;
layout(set = 0, binding = 3) uniform sampler3D cell_noise_tex;
layout(rgba16f, set = 0, binding = 4) uniform restrict writeonly image2D cur_image;
#endif

#ifdef MODE_RESOLVE
layout(set = 0, binding = 1) uniform sampler2D cur_tex;
layout(set = 0, binding = 2) uniform sampler2D hist_tex;
layout(rgba16f, set = 0, binding = 3) uniform restrict writeonly image2D out_image;
#endif

// Texel centre -> world direction (texture row 0 = top of the view).
vec3 texel_dir(vec2 uv) {
	vec3 v = vec3((uv.x * 2.0 - 1.0) * params.tan_size.x, (1.0 - uv.y * 2.0) * params.tan_size.y, -1.0);
	return normalize(mat3(params.view_to_world) * v);
}

#ifdef MODE_MARCH

// --- mirrors sky_clouds.gdshaderinc (uv mapping, bulk, opacity, lobes) ---
const float EARTH_R = 1600.0;
const float LOBE_SCALE = 1.7;
const float LOBE_MEAN = 0.72;
// Slab between deck altitude 1.0 (the cumulus base, ~1.5 km) and SLAB_TOP: heaps rise
// about a third of the way, towers over the densest cores reach the top (~1.5 km more).
const float SLAB_BASE = 1.0;
const float SLAB_TOP = 2.0;
// Extinction per deck unit at density 1: a 500 m heap core is nearly opaque, a thin
// edge lets the sun through.
const float SIGMA = 22.0;

float remap01(float v, float lo, float hi) {
	return clamp((v - lo) / max(hi - lo, 1e-4), 0.0, 1.0);
}

float layer_distance(float dir_y, float altitude) {
	float ry = EARTH_R * dir_y;
	return sqrt(ry * ry + altitude * (2.0 * EARTH_R + altitude)) - ry;
}

float shape_at(vec2 uv, float lod) {
	return textureLod(shape_tex, uv, lod).r;
}

float noise_at(vec2 uv, float lod) {
	return textureLod(noise_tex, uv, lod).r;
}

float clear_fade(float cover) {
	return smoothstep(0.02, 0.16, cover);
}

float cloud_bulk(vec2 uv, float cover, float lod) {
	float banks = 1.0 - shape_at(uv * 0.42 + vec2(0.13, 0.61), lod);
	float heaps = 1.0 - shape_at(uv, lod);
	float base = heaps * mix(0.45, 1.0, smoothstep(0.30, 0.72, banks));
	float floor_thr = mix(0.66, 0.04, cover);
	return remap01(base, floor_thr, floor_thr + 0.58) * clear_fade(cover);
}

// Lit deck opacity at `uv`: bulk, three detail octaves (fine ones faded where a texel
// covers much of the pattern, as the dome's fwidth fade does), then lobe erosion.
float deck_coverage(vec2 uv, float cover, float texel_rate, float shape_lod, float noise_lod) {
	float cloud = cloud_bulk(uv, cover, shape_lod);
	if (cloud <= 0.0) {
		return 0.0;
	}
	vec2 detail_offset = params.offsets.zw;
	float fine_w = 1.0 - smoothstep(0.02, 0.08, texel_rate);
	float mid_w = 1.0 - smoothstep(0.05, 0.2, texel_rate);
	float detail = noise_at(uv * 1.9 + detail_offset, noise_lod) * 0.5
		+ mix(0.5, noise_at(uv * 4.6 - detail_offset * 0.6, noise_lod + 1.3), mid_w) * 0.32
		+ mix(0.5, noise_at(uv * 9.4 + detail_offset * 0.3, noise_lod + 2.3), fine_w) * 0.18;
	cloud = remap01(cloud, detail * mix(0.18, 0.42, params.cloud.y), 1.0);
	float d = shape_at(uv * LOBE_SCALE + detail_offset * 0.35, shape_lod + 0.8);
	float lobes = 1.0 - d * d;
	float edge = smoothstep(0.0, 0.2, cloud) * (1.0 - cloud);
	return clamp(cloud + (lobes - LOBE_MEAN) * 1.6 * edge, 0.0, 1.0);
}

// Share of the slab height a column reaches: heaps a third, dense cores under a tower
// cell up to the top; the storm lift raises everything (mirrored on the CPU).
float column_top(vec2 uv, float coverage, float storm, float shape_lod) {
	float tower = 1.0 - shape_at(uv * 0.31 + vec2(0.71, 0.23), shape_lod);
	float reach = mix(0.32, 1.0, smoothstep(0.45, 0.85, tower));
	return clamp(coverage * reach * (1.0 + storm * 0.8), 0.0, 1.0);
}

// Column profile 0..1 at height share `hf`: full coverage at the flat base, narrowing
// toward the column top so each heap rounds into a dome.
float column_density(float coverage, float top, float hf) {
	if (coverage <= 0.0 || hf >= top) {
		return 0.0;
	}
	float base = smoothstep(0.0, 0.05, hf);
	float crown = remap01(top - hf, 0.0, max(top * 0.6, 0.04));
	return coverage * base * sqrt(crown);
}

float altitude_of(vec3 p) {
	return length(p + vec3(0.0, EARTH_R, 0.0)) - EARTH_R;
}

vec2 deck_uv_of(vec3 p) {
	return p.xz * 0.12 - params.offsets.xy;
}

// Henyey-Greenstein relative to isotropic (1 = isotropic).
float hg_rel(float cos_theta, float g) {
	float g2 = g * g;
	return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cos_theta, 1.5);
}

// Interleaved gradient noise (Jimenez 2014): a cheap blue-noise-like dither whose
// error is high-frequency in screen space, so the 3x3 resolve clamp and the history
// blend average it out quickly. Shifted by a golden-ratio step per frame.
float ign(vec2 pixel, float frame) {
	float n = fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
	return fract(n + frame * 0.61803399);
}

void main() {
	ivec2 size = ivec2(params.tan_size.zw);
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= size.x || px.y >= size.y) {
		return;
	}
	vec2 uv = (vec2(px) + 0.5) / vec2(size);
	vec3 dir = texel_dir(uv);
	// The dome deck also stops just under the horizon (cloud_field).
	if (dir.y < -0.025) {
		imageStore(cur_image, px, vec4(0.0));
		return;
	}
	float coverage_in = params.cloud.x;
	float storm_amt = params.cloud.z;
	float storm_loc = params.cloud.w;
	float t0 = layer_distance(dir.y, SLAB_BASE);
	float t1 = layer_distance(dir.y, SLAB_TOP);
	// Local storm lift sampled once at the slab base, as the dome deck does.
	vec2 base_uv = dir.xz * t0 * 0.12 - params.offsets.xy;
	float cell = 1.0 - textureLod(shape_tex, base_uv * 0.12 + vec2(0.37, 0.71), 0.0).r;
	float local_storm = storm_amt * mix(1.0, smoothstep(0.48, 0.8, cell), storm_loc) * (1.0 - storm_loc);
	float cover = clamp(coverage_in + local_storm * 0.38, 0.0, 1.0);
	// Overcast: the deck closes into a stratiform sheet between the heaps.
	float strat = smoothstep(0.84, 0.98, cover) * 0.32;

	int steps = int(params.sun.w);
	float seg = t1 - t0;
	float dt = seg / float(steps);
	float jitter = ign(vec2(px), params.prev_tan.w);
	vec3 sun = params.sun.xyz;
	float sun_up = smoothstep(-0.08, 0.18, sun.y);
	float cos_sun = dot(dir, sun);
	// Forward lobe (silver lining through thin edges toward the sun) plus a weak back lobe.
	float phase = mix(hg_rel(cos_sun, 0.6), hg_rel(cos_sun, -0.25), 0.35);
	float phase_boost = mix(1.0, phase, 0.12);
	vec2 to_sun = normalize(sun.xz + vec2(1e-5));
	float sun_rise = max(sun.y, 0.06);
	float pixel_angle = params.misc.z;
	float shape_size = params.tex_sizes.x;
	float noise_size = params.tex_sizes.y;
	float cell_size = params.tex_sizes.z;
	vec3 cell_drift = vec3(params.offsets.z, 0.0, params.offsets.w) * 4.0;

	float transmittance = 1.0;
	float light_acc = 0.0;
	for (int i = 0; i < 64; i++) {
		if (i >= steps || transmittance < 0.01) {
			break;
		}
		float t = t0 + (float(i) + jitter) * dt;
		vec3 p = dir * t;
		float hf = clamp((altitude_of(p) - SLAB_BASE) / (SLAB_TOP - SLAB_BASE), 0.0, 1.0);
		vec2 suv = deck_uv_of(p);
		// uv footprint of one full-res pixel at this distance, stretched at grazing angles.
		float graze = max(dir.y + t / EARTH_R, 0.02);
		float texel_rate = pixel_angle * t * 0.12 / graze;
		float shape_lod = max(log2(texel_rate * shape_size), 0.0);
		float noise_lod = max(log2(texel_rate * noise_size * 1.9), 0.0);
		float coverage = deck_coverage(suv, cover, texel_rate, shape_lod, noise_lod);
		float top = column_top(suv, coverage, local_storm, shape_lod);
		float density = column_density(coverage, top, hf);
		density += strat * (1.0 - smoothstep(0.12, 0.3, hf));
		if (density <= 0.002) {
			continue;
		}
		// Billows: 3D cellular noise eats the edges (more toward the crown), fading to
		// its mean where a voxel is smaller than a pixel so the far deck does not sparkle.
		// Two octaves (~170 m and ~60 m cells), squashed vertically into flat-bottomed puffs.
		vec3 np = p * vec3(1.0, 1.6, 1.0) + cell_drift;
		float cell_lod = max(log2(pixel_angle * t * 3.0 * cell_size), 0.0);
		float worley = (1.0 - textureLod(cell_noise_tex, np * 3.0, cell_lod).r) * 0.625
			+ (1.0 - textureLod(cell_noise_tex, np * 8.5, cell_lod + 1.5).r) * 0.375;
		float erode_w = 1.0 - smoothstep(2.0, 4.0, cell_lod);
		density = remap01(density, (1.0 - worley) * mix(0.35, 0.70, hf) * erode_w, 1.0);
		if (density <= 0.002) {
			continue;
		}
		// Short march toward the sun through the column field (no billow noise).
		float od = 0.0;
		// ~40, 70, 120, 220 m: the light that reaches a visible skin has crossed only
		// the first few hundred metres of cloud toward the sun.
		float d_step = 0.025;
		vec3 lp = p;
		for (int j = 0; j < 4; j++) {
			lp += sun * d_step;
			float lhf = clamp((altitude_of(lp) - SLAB_BASE) / (SLAB_TOP - SLAB_BASE), 0.0, 1.0);
			vec2 luv = deck_uv_of(lp);
			float lcov = cloud_bulk(luv, cover, shape_lod + 1.0);
			float ld = column_density(lcov, column_top(luv, lcov, local_storm, shape_lod + 1.0), lhf);
			// The first two light samples see the billows too, so each puff shades the
			// next one and the sunlit side reads as lumps instead of one smooth gradient.
			if (j < 2 && ld > 0.0) {
				vec3 lnp = lp * vec3(1.0, 1.6, 1.0) + cell_drift;
				float lw = 1.0 - textureLod(cell_noise_tex, lnp * 3.0, cell_lod).r;
				ld = remap01(ld, (1.0 - lw) * mix(0.35, 0.70, lhf) * erode_w, 1.0);
			}
			od += ld * d_step;
			d_step *= 1.8;
		}
		// Light is mostly scattered forward, so the sun path sees under half the extinction.
		od = od * SIGMA * 0.45 + strat * 0.5;
		// Multiple scattering (Wrenninge octaves a = b = 0.5, normalised to 1 at od 0):
		// thick cores go grey instead of black while thin sun-side skins stay bright.
		float beer = (exp(-od) + 0.5 * exp(-od * 0.5) + 0.25 * exp(-od * 0.25)) / 1.75;
		// Powder: the sun-facing skin of a dense heap is darker than its interior glow.
		float powder = 1.0 - 0.45 * exp(-density * SIGMA * 0.35);
		float sun_light = beer * powder * phase_boost;
		float ambient = 0.22 + 0.45 * hf;
		float light = mix(ambient, max(sun_light, ambient), sun_up);
		float alpha = 1.0 - exp(-density * SIGMA * dt);
		light_acc += transmittance * alpha * light;
		transmittance *= 1.0 - alpha;
	}
	// Silver lining can lift the light share above 1 (brighter than a lit crown).
	imageStore(cur_image, px, vec4(1.0 - transmittance, min(light_acc, 1.6), 0.0, 1.0));
}
#endif

#ifdef MODE_RESOLVE
void main() {
	ivec2 size = ivec2(params.tan_size.zw);
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= size.x || px.y >= size.y) {
		return;
	}
	// 3x3 neighbourhood statistics of this frame's jittered result (variance clip).
	vec2 m1 = vec2(0.0);
	vec2 m2 = vec2(0.0);
	vec2 centre = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 s = texelFetch(cur_tex, clamp(px + ivec2(x, y), ivec2(0), size - 1), 0).rg;
			m1 += s;
			m2 += s * s;
			if (x == 0 && y == 0) {
				centre = s;
			}
		}
	}
	m1 /= 9.0;
	vec2 sigma = sqrt(max(m2 / 9.0 - m1 * m1, vec2(0.0)));
	vec2 lo = m1 - sigma;
	vec2 hi = m1 + sigma;

	vec2 result = m1;
	if (params.prev_tan.z > 0.5) {
		// Reproject: this texel's world direction in last frame's view.
		vec2 uv = (vec2(px) + 0.5) / vec2(size);
		vec3 dir = texel_dir(uv);
		vec3 v = mat3(params.prev_world_to_view) * dir;
		if (v.z < -1e-4) {
			vec2 prev_uv = vec2(
				0.5 + v.x / -v.z / params.prev_tan.x * 0.5,
				0.5 - v.y / -v.z / params.prev_tan.y * 0.5);
			if (all(greaterThanEqual(prev_uv, vec2(0.0))) && all(lessThanEqual(prev_uv, vec2(1.0)))) {
				vec2 hist = clamp(textureLod(hist_tex, prev_uv, 0.0).rg, lo, hi);
				result = mix(hist, centre, params.misc.w);
			}
		}
	}
	imageStore(out_image, px, vec4(result, 0.0, 1.0));
}
#endif
