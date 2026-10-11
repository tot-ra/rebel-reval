// Shared cloud-field functions for the sky dome and the WS-12 ground-shadow
// pass. Inputs are parameters so both callers keep their own uniforms/globals.
// Maths match the pre-extract sky_weather_3d.gdshader bodies exactly.

float sky_cloud_remap(float v, float lo, float hi, float nlo, float nhi) {
	return nlo + (clamp(v, lo, hi) - lo) / max(hi - lo, 1e-4) * (nhi - nlo);
}


float sky_cloud_local_storm_at(
	vec2 uv, sampler2D shape_tex, float storm_amt, float storm_loc
) {
	float cell = 1.0 - texture(shape_tex, uv * 0.12 + vec2(0.37, 0.71)).r;
	float mask = mix(1.0, smoothstep(0.48, 0.8, cell), storm_loc);
	// R-1400: an isolated storm is drawn as discrete CloudCells cumulonimbus, so the
	// dome deck keeps only the widespread share; otherwise dark dome cells would
	// sit apart from the real thunderheads that carry the lightning and shadows.
	return storm_amt * mask * (1.0 - storm_loc);
}


// R-1495: even at cover 0 the brightest heaps cleared the 0.66 floor, so the deck
// never left the sky. Below ~0.16 cover it fades out; the `cloudless` profile
// (0.05) keeps only faint wisps, while `clear` (0.30) and above are unchanged.
float sky_cloud_clear_fade(float cover) {
	return smoothstep(0.02, 0.16, cover);
}


float sky_cloud_bulk(vec2 uv, float cover, sampler2D shape_tex) {
	float banks = 1.0 - texture(shape_tex, uv * 0.42 + vec2(0.13, 0.61)).r;
	float heaps = 1.0 - texture(shape_tex, uv).r;
	float bank_mask = smoothstep(0.30, 0.72, banks);
	float base = heaps * mix(0.45, 1.0, bank_mask);
	float floor_thr = mix(0.66, 0.04, cover);
	return clamp(sky_cloud_remap(base, floor_thr, floor_thr + 0.58, 0.0, 1.0), 0.0, 1.0)
		* sky_cloud_clear_fade(cover);
}


float sky_cloud_opacity(
	vec2 uv,
	float cover,
	sampler2D shape_tex,
	sampler2D noise_tex,
	vec2 detail_offset,
	float chaos
) {
	float cloud = sky_cloud_bulk(uv, cover, shape_tex);
	// Fade the two fine octaves where the layer UV is minified (low sky angles,
	// the layer stretches toward the horizon): the hard threshold remap below
	// turns their sub-pixel variation into grain. Fallback is the mean (0.5).
	float texel_rate = max(fwidth(uv.x), fwidth(uv.y));
	float fine_w = 1.0 - smoothstep(0.02, 0.08, texel_rate);
	float mid_w = 1.0 - smoothstep(0.05, 0.2, texel_rate);
	float detail = texture(noise_tex, uv * 1.9 + detail_offset).r * 0.5
		+ mix(0.5, texture(noise_tex, uv * 4.6 - detail_offset * 0.6).r, mid_w) * 0.32
		+ mix(0.5, texture(noise_tex, uv * 9.4 + detail_offset * 0.3).r, fine_w) * 0.18;
	cloud = sky_cloud_remap(cloud, detail * mix(0.18, 0.42, chaos), 1.0, 0.0, 1.0);
	return clamp(cloud, 0.0, 1.0);
}


vec2 sky_cloud_uv(vec3 dir, float altitude, vec2 offset) {
	float distance_to_layer = altitude / sqrt(dir.y * dir.y + 0.012);
	return dir.xz * distance_to_layer * 0.12 - offset;
}


// One-sample minimum-tier ground shadow (heaps only).
float sky_cloud_shadow_cheap(vec2 uv, float cover, sampler2D shape_tex) {
	float heaps = 1.0 - texture(shape_tex, uv).r;
	float floor_thr = mix(0.66, 0.04, cover);
	return clamp(sky_cloud_remap(heaps, floor_thr, floor_thr + 0.58, 0.0, 1.0), 0.0, 1.0)
		* sky_cloud_clear_fade(cover);
}


// Recommended soft variant: cellular bulk plus one erosion octave and a mip
// bias. Three texture samples, matching the WS-12 recommended budget.
float sky_cloud_shadow_soft(
	vec2 uv,
	float cover,
	sampler2D shape_tex,
	sampler2D noise_tex,
	vec2 detail_offset,
	float chaos,
	float mip_bias
) {
	float cloud = sky_cloud_bulk(uv, cover, shape_tex);
	float detail = textureLod(noise_tex, uv * 1.9 + detail_offset, mip_bias).r;
	cloud = sky_cloud_remap(cloud, detail * mix(0.18, 0.42, chaos), 1.0, 0.0, 1.0);
	return clamp(cloud, 0.0, 1.0);
}



// R-1768 lit 2.5D deck (recommended tier; the minimum tier keeps the flat deck).
// Lobes come from the same cellular shape texture at a finer scale (bright = puff
// centre), sliding with the detail offset, so every caller that has the deck's
// textures (dome, ground-shadow pass, CPU mirror) can erode the deck identically.
const float SKY_CLOUD_LOBE_SCALE = 1.7;
// One lobe across in deck uv (the shape texture holds ~6 cells per tile).
const float SKY_CLOUD_LOBE_WIDTH = 0.17 / SKY_CLOUD_LOBE_SCALE;
// Mean of sky_cloud_lobes over the baked shape texture, so erosion keeps coverage.
const float SKY_CLOUD_LOBE_MEAN = 0.72;

float sky_cloud_lobes(vec2 uv, sampler2D shape_tex, vec2 detail_offset) {
	float d = texture(shape_tex, uv * SKY_CLOUD_LOBE_SCALE + detail_offset * 0.35).r;
	// 1 - d^2, not 1 - d: a cell distance is a cone, which shades as facets; the
	// parabola gives each lobe a rounded crown and keeps the creases between lobes.
	return 1.0 - d * d;
}


// Rounded, lobed silhouettes: an edge bulges out where a lobe sits and is bitten
// in between lobes. Roughly coverage-neutral (centred on the lobe mean), so fair-weather
// puffs do not vanish; open sky (cloud 0) stays open and dense cores are untouched.
float sky_cloud_lobe_erode(float cloud, float lobes) {
	float edge = smoothstep(0.0, 0.2, cloud) * (1.0 - cloud);
	return clamp(cloud + (lobes - SKY_CLOUD_LOBE_MEAN) * 1.6 * edge, 0.0, 1.0);
}


// Height of the heaped deck top: square-root dome over the bulk (thin edges rise
// steeply, thick centres are rounded crowns), bumped by the lobes.
float sky_cloud_lobe_height(vec2 uv, float cover, sampler2D shape_tex, vec2 detail_offset) {
	float bulk = sky_cloud_bulk(uv, cover, shape_tex);
	float lobes = sky_cloud_lobes(uv, shape_tex, detail_offset);
	return sqrt(bulk) * (0.45 + 0.55 * lobes);
}


// Lit share 0..1 of a deck pixel. `sun` is the world sun direction (deck xz = world
// xz, y up), `view_up` the eye ray's y, `texel` the uv footprint of the pixel.
// Overhead the eye sees the flat base, lit through the cloud (thin rims bright,
// thick cores grey); toward the horizon it sees the heaped sides, shaded by the
// bump normal and by heaps that rise between the point and the sun (two steps of
// a height-field shadow march).
float sky_cloud_lit_share(
	vec2 uv, float cover, sampler2D shape_tex, vec2 detail_offset, vec3 sun, float view_up, float texel
) {
	float e = max(texel, 0.004);
	float h = sky_cloud_lobe_height(uv, cover, shape_tex, detail_offset);
	float hx = sky_cloud_lobe_height(uv + vec2(e, 0.0), cover, shape_tex, detail_offset);
	float hz = sky_cloud_lobe_height(uv + vec2(0.0, e), cover, shape_tex, detail_offset);
	// A lobe rises about one height unit over its width.
	vec3 n = normalize(vec3(-(hx - h) / e, 1.0, -(hz - h) / e) * vec3(SKY_CLOUD_LOBE_WIDTH, 1.0, SKY_CLOUD_LOBE_WIDTH));
	float sun_up = max(sun.y, 0.06);
	vec2 to_sun = normalize(sun.xz + vec2(1e-5));
	float occ = 0.0;
	for (int i = 1; i <= 2; i++) {
		float d = 0.7 * SKY_CLOUD_LOBE_WIDTH * float(i);
		float hs = sky_cloud_lobe_height(uv + to_sun * d, cover, shape_tex, detail_offset);
		// The sun ray from this crown climbs d * slope; a higher heap there shades it.
		occ += max(hs - h - d / SKY_CLOUD_LOBE_WIDTH * sun_up * 0.5, 0.0);
	}
	float self_shadow = exp(-occ * 3.0);
	float wrap = clamp((dot(n, sun) + 0.3) / 1.3, 0.0, 1.0);
	float sides = wrap * self_shadow;
	// Base seen from below: light diffuses through the thickness, so cores go grey.
	float base = mix(1.0, 0.25, smoothstep(0.2, 0.9, h)) * mix(0.6, 1.0, self_shadow);
	return mix(sides, base, smoothstep(0.15, 0.6, view_up) * 0.4);
}
