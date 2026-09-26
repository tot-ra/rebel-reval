// Shared WS-07 caustic tile sampling. The water surface shader and the
// UnderwaterPass include this so the net on the bed matches the net on
// submerged surfaces and in light shafts. `_caustic_stretch` and `_caustic_tile`
// moved unchanged from map_view_water.gdshader.
//
// The includer must declare, before this include:
//   uniform sampler2D caustics_fine_tex (hint_default_white, filter_linear_mipmap, repeat);
//   uniform sampler2D caustics_broad_tex (same hint);
//   uniform vec2 caustic_min_pair_mean;
//   uniform bool caustic_full_quality;
//   uniform float caustic_pattern_scale;
//   uniform vec2 wind_direction;
//   global uniform float ocean_time;
// and include ocean_fft_common.gdshaderinc first (WATER_IOR).

// WS-07 tiles (caustics_profile.json): patch sizes in metres, resolution and the
// L8 encoding scale (byte = v / 4).
const float CAUSTIC_FINE_PATCH_M = 4.0;
const float CAUSTIC_BROAD_PATCH_M = 16.0;
const float CAUSTIC_TILE_RES = 512.0;
const float CAUSTIC_ENCODE_SCALE = 4.0;
// Share of the dispersed R/B samples mixed into the achromatic net.
const float CAUSTIC_DISPERSION_BLEND = 0.35;
// Cross-scroll speeds in whole tiles per ocean-clock wrap: ~0.23 and ~0.16 m/s on
// both tiles, about the drift of the decimetre ripples that focus the net.
const float CAUSTIC_FINE_A_TILES_PER_WRAP = 96.0;
const float CAUSTIC_FINE_B_TILES_PER_WRAP = 64.0;
const float CAUSTIC_BROAD_A_TILES_PER_WRAP = 24.0;
const float CAUSTIC_BROAD_B_TILES_PER_WRAP = 16.0;
// Same wrap and metre scale as the water shader so UV drift stays locked.
const float CAUSTIC_OCEAN_TIME_WRAP_SECONDS = 1638.4;
const float CAUSTIC_METERS_PER_UNIT = 0.87;

// Ported from Tidewater (MIT), see notice.code.tidewater: _causticsStretch. Widening
// short gradients to a mip-dependent floor keeps the anisotropic grazing-angle footprint
// from selecting a mip finer than the depth blur, which is what makes caustics shimmer.
vec2 _caustic_stretch(vec2 g, float min_len) {
	return g * max(min_len / max(length(g), 1e-9), 1.0);
}

// One caustic tile at `uv`, crossed from two layers scrolling against each other.
// Layer B is rotated 90 degrees (still exactly periodic) so min() carves moving
// lines out of two uncorrelated nets instead of doubling one. `rgb_offset` shifts
// the R and B samples for dispersion; zero skips them (2 samples instead of 6).
vec3 _caustic_tile(
	sampler2D tile, vec2 uv, vec2 drift_a, vec2 drift_b, vec2 gx, vec2 gy, vec2 rgb_offset, float min_pair_mean
) {
	vec2 uv_a = uv - drift_a;
	vec2 uv_b = vec2(-uv.y, uv.x) + vec2(0.37, 0.61) - drift_b;
	vec2 gx_b = vec2(-gx.y, gx.x);
	vec2 gy_b = vec2(-gy.y, gy.x);
	float g = min(textureGrad(tile, uv_a, gx, gy).r, textureGrad(tile, uv_b, gx_b, gy_b).r);
	vec3 c = vec3(g);
	if (rgb_offset != vec2(0.0)) {
		vec2 off_b = vec2(-rgb_offset.y, rgb_offset.x);
		float red = min(textureGrad(tile, uv_a + rgb_offset, gx, gy).r, textureGrad(tile, uv_b + off_b, gx_b, gy_b).r);
		float blue = min(textureGrad(tile, uv_a - rgb_offset, gx, gy).r, textureGrad(tile, uv_b - off_b, gx_b, gy_b).r);
		// The net's lines are 1-2 texels wide, so fully split channels separate into a
		// rainbow; a partial blend leaves the faint fringe of real caustics.
		c.rb = mix(vec2(g), vec2(red, blue), CAUSTIC_DISPERSION_BLEND);
	}
	// Stored v/4; dividing by the min-pair mean keeps the bed's average light at 1.
	return c * (CAUSTIC_ENCODE_SCALE / min_pair_mean);
}

// Decoded tile colour (mean 1) at a bed/world XZ, using the same projection,
// scroll, fine/broad focus and sample budget as the water `_bed_caustic_gain`.
// `full_quality` is the recommended 2-tile path; false is one dominant tile and
// no dispersion (minimum, and the underwater shaft march).
// `screen_grad` uses dFdx/dFdy; false feeds a mip-floor gradient so the shaft
// loop does not take derivatives of a loop-varying UV.
vec3 _caustic_tiles_at(
	vec2 bed_xz, float h_m, vec3 sun_dir, vec2 fft_slope, bool full_quality, bool screen_grad
) {
	vec3 sun = normalize(sun_dir);
	// Refracted sun ray, pointing down into the water.
	vec3 ts = refract(-sun, vec3(0.0, 1.0, 0.0), 1.0 / WATER_IOR);
	float ts_down = max(-ts.y, 0.2);
	// Walk back up the refracted ray to the surface point the light entered through, so
	// the net leans away from a low sun and sits on the bed, not on the surface.
	float h_units = h_m / CAUSTIC_METERS_PER_UNIT;
	vec2 entry_xz = bed_xz - ts.xz * (h_units / ts_down);
	// An oblique beam spreads its footprint along the sun azimuth by 1 / cos(theta_t).
	vec2 sun_az = length(sun.xz) > 1e-3 ? normalize(sun.xz) : vec2(1.0, 0.0);
	vec2 sun_perp = vec2(-sun_az.y, sun_az.x);
	vec2 p_m = (sun_az * (dot(entry_xz, sun_az) * ts_down) + sun_perp * dot(entry_xz, sun_perp))
		* CAUSTIC_METERS_PER_UNIT;
	// Passing FFT swells visibly bend the net (surface slope times depth).
	p_m += fft_slope * h_m * 0.3;
	vec2 uv_fine = p_m / (CAUSTIC_FINE_PATCH_M * caustic_pattern_scale);
	vec2 uv_broad = p_m / (CAUSTIC_BROAD_PATCH_M * caustic_pattern_scale);
	// Shallow beds get the sharp fine net, deep beds the wide soft broad one, and the
	// mip level blurs with depth.
	float broad_weight = smoothstep(0.6, 3.0, h_m);
	float lvl = log2(1.0 + h_m * 1.5);
	float min_len = exp2(lvl) / CAUSTIC_TILE_RES;
	vec2 gx_f;
	vec2 gy_f;
	vec2 gx_b;
	vec2 gy_b;
	if (screen_grad) {
		gx_f = _caustic_stretch(dFdx(uv_fine), min_len);
		gy_f = _caustic_stretch(dFdy(uv_fine), min_len);
		gx_b = _caustic_stretch(dFdx(uv_broad), min_len);
		gy_b = _caustic_stretch(dFdy(uv_broad), min_len);
	} else {
		gx_f = vec2(min_len, 0.0);
		gy_f = vec2(0.0, min_len);
		gx_b = vec2(min_len, 0.0);
		gy_b = vec2(0.0, min_len);
	}
	// Scrolls: a whole number of tiles per ocean-clock wrap, so the wrap never pops.
	vec2 wind = length(wind_direction) > 1e-3 ? normalize(wind_direction) : vec2(1.0, 0.0);
	float wrap_phase = ocean_time / CAUSTIC_OCEAN_TIME_WRAP_SECONDS;
	vec2 fine_a = wind * (wrap_phase * CAUSTIC_FINE_A_TILES_PER_WRAP);
	vec2 fine_b = -wind * (wrap_phase * CAUSTIC_FINE_B_TILES_PER_WRAP);
	vec2 broad_a = wind * (wrap_phase * CAUSTIC_BROAD_A_TILES_PER_WRAP);
	vec2 broad_b = -wind * (wrap_phase * CAUSTIC_BROAD_B_TILES_PER_WRAP);
	// Dispersion: faint colour fringes that widen with depth, along the sun azimuth.
	// The offset is physical, so it shrinks with the art magnification of the tiles.
	vec2 dispersion = full_quality ? sun_az * (h_m * 0.004 / caustic_pattern_scale) : vec2(0.0);
	vec3 c;
	if (full_quality) {
		// recommended: 4 base samples, +4 for R/B on the dominant tile (8 total).
		bool broad_dominant = broad_weight > 0.5;
		vec3 fine = _caustic_tile(
			caustics_fine_tex, uv_fine, fine_a, fine_b, gx_f, gy_f,
			broad_dominant ? vec2(0.0) : dispersion, caustic_min_pair_mean.x
		);
		vec3 broad = _caustic_tile(
			caustics_broad_tex, uv_broad, broad_a, broad_b, gx_b, gy_b,
			broad_dominant ? dispersion : vec2(0.0),
			caustic_min_pair_mean.y
		);
		c = mix(fine, broad, broad_weight);
	} else if (broad_weight > 0.5) {
		// minimum: the dominant tile only (2 samples).
		c = _caustic_tile(caustics_broad_tex, uv_broad, broad_a, broad_b, gx_b, gy_b, vec2(0.0), caustic_min_pair_mean.y);
	} else {
		c = _caustic_tile(caustics_fine_tex, uv_fine, fine_a, fine_b, gx_f, gy_f, vec2(0.0), caustic_min_pair_mean.x);
	}
	return c;
}
