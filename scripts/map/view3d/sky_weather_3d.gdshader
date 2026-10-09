shader_type sky;

// Sky dome for the 3D map view (ADR 0007 view layer): WS-10 physical sky from
// the Hillaire sky-view LUT (gradient fallback when the LUT is unavailable),
// Hipparcos stars positioned for Reval in 1343, sun disk with halo, moon,
// procedural clouds, and a warm horizon band for sunrise/sunset. All dynamics
// are script-driven uniforms (no TIME), so the sky stays deterministic and
// testable like the rest of the view.

uniform vec4 day_top_color : source_color = vec4(0.18, 0.38, 0.65, 1.0);
uniform vec4 day_horizon_color : source_color = vec4(0.67, 0.75, 0.81, 1.0);
uniform vec4 night_top_color : source_color = vec4(0.020, 0.045, 0.130, 1.0);
uniform vec4 night_horizon_color : source_color = vec4(0.050, 0.100, 0.220, 1.0);
uniform vec4 sunset_color : source_color = vec4(0.98, 0.45, 0.18, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.92, 0.74, 1.0);
uniform vec4 moon_color : source_color = vec4(0.88, 0.86, 0.82, 1.0);

// 0 = midnight, 1 = noon (matches DayNightCycle.day_blend).
uniform float day_blend : hint_range(0.0, 1.0) = 1.0;
// 1 while the sun sits on the horizon, 0 once it climbs or fully sets.
uniform float sunset_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, 1.0, 0.0);
// Kept for earthshine strength; the lit crescent itself follows sun_direction.
// 0 = new, 0.25 = first quarter, 0.5 = full, 0.75 = last quarter.
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;

// cloud_noise is FBM used only to erode edges; cloud_shape is cellular (Worley)
// noise whose rounded cells form the puffy cumulus body. The silhouette must
// come from the cellular texture: FBM thresholds swirl like marbled ink.
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_shape : filter_linear_mipmap, repeat_enable;
// Baked near-side albedo disk generated in SkyWeather3D at configure time.
uniform sampler2D lunar_albedo_map : filter_linear_mipmap, repeat_disable;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.22;
uniform float cloud_darken : hint_range(0.0, 1.0) = 0.0;
// Primary bank drift. Detail offset advances faster so edges churn while
// whole cloud masses still cross the dome from one horizon to the other.
uniform vec2 cloud_offset = vec2(0.0);
uniform vec2 cloud_detail_offset = vec2(0.0);
// Domain-warp strength. Clear weather keeps mild chaos; storms tear harder.
uniform float cloud_chaos : hint_range(0.0, 1.0) = 0.35;
// Compatibility uniform: quality selects twice this many cloud depth samples.
uniform int cloud_shadow_samples : hint_range(1, 4) = 4;
// Quality tier controls the fixed upper bound of the distant rain march.
uniform int rain_shaft_samples : hint_range(1, 6) = 6;
// Missing procedural textures fail closed to the readable gradient instead of
// sampling an invalid resource. Normal minimum quality still keeps cloud shape.
uniform bool cloud_fallback = false;
// Minimum quality reduces visible lightning cost without changing strike timing.
uniform float lightning_density : hint_range(0.0, 1.0) = 1.0;
// Cumulonimbus development: 0 = fair-weather heaps, 1 = towering anvil storm.
// Drives the squall wall, darkened bases, sunlit anvil crowns, and rain curtains.
uniform float storm_intensity : hint_range(0.0, 1.0) = 0.0;
// How concentrated the storm is across the sky. 0 spreads it over the whole deck
// (a rain front); 1 isolates it into a few heavy convective cells that tower and
// rain while the sky around them stays open — the "one raining cloud" look.
uniform float storm_locality : hint_range(0.0, 1.0) = 0.0;
// Lightning flash level and the ground bearing (x = east, y = north) of the cell
// currently striking, so the flash lights that cloud rather than the whole dome.
uniform float lightning : hint_range(0.0, 1.0) = 0.0;
uniform vec2 lightning_dir = vec2(1.0, 0.0);
// R-1400: every strike is born in a CloudCells storm cell. `lightning_origin` is the
// charge centre inside that cell (world units, wrapped into the cell domain);
// `lightning_kind` 0 is an in-cloud flash that lights the cell from inside, 1 a
// cloud-to-ground stroke drawn as a 3D channel from the cell base to
// `lightning_ground`.
uniform vec3 lightning_origin = vec3(0.0, 600.0, 0.0);
uniform vec3 lightning_ground = vec3(0.0);
uniform float lightning_kind = 0.0;
// Quality tier costs for the discrete cells (0 disables a feature).
uniform int cell_steps : hint_range(0, 16) = 12;
uniform int cell_fine_steps : hint_range(1, 12) = 10;
// 3D Worley-FBM noise that shapes the cells (SkyWeatherResources.build_cell_noise_3d).
uniform sampler3D cell_noise : filter_linear, repeat_enable;
uniform int cell_light_samples : hint_range(0, 2) = 2;
uniform int cell_ray_samples : hint_range(0, 10) = 8;
// Prevailing wind on the ground plane, used to comb cirrus streaks and to lean
// the storm wall into the upwind quarter so the front reads as approaching.
uniform vec2 wind_dir = vec2(0.928, 0.371);
// 0..1: how much of the sky is a closing deck. Cumulus that are still there then
// darken toward rain-bearing grey instead of staying fair-weather white.
uniform float cloud_gloom : hint_range(0.0, 1.0) = 0.0;

// Hipparcos stars live in equatorial coordinates in this nearest-filtered map,
// one texel per star (read with texelFetch in sky_stars.gdshaderinc).
// The observer transform below turns each sky ray into right ascension and
// declination for Reval's latitude and the canonical 23 April 1343 sidereal sky.
uniform sampler2D star_map : filter_nearest, repeat_enable;
uniform float observer_latitude = 1.0371;
uniform float sidereal_angle = 3.8101;

// WS-10 physical sky. SkyAtmosphereLut renders the Hillaire sky-view LUT every (other) frame;
// when it or the WS-09 transmittance LUT is missing, sky_lut_available stays false and the
// hand-tuned gradient above is used unchanged (fail closed, like cloud_fallback).
#include "res://scripts/map/view3d/atmosphere_common.gdshaderinc"
uniform bool sky_lut_available = false;
uniform sampler2D sky_view_lut : filter_linear, repeat_disable;
uniform sampler2D atmosphere_transmittance_lut : filter_linear, repeat_disable;
uniform vec2 sky_lut_size = vec2(192.0, 108.0);
// Art direction wins over physics (ADR 0018): exposure and tint scale the LUT radiance.
// 0.7 puts the 60-degree-sun horizon at the old day_horizon_color luminance.
uniform float sky_exposure : hint_range(0.0, 4.0) = 0.7;
uniform vec4 sky_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Partial eye adaptation: the fixed scene grade would leave the physical dusk sky ~10x dimmer
// than noon. Gain = clamp((reference / zenith luminance)^sky_adaptation, 1, max_gain), where
// the reference is the raw LUT zenith luminance at a 60-degree sun (gain 1 at the calibration
// point). Computed per pixel from one azimuth-independent LUT fetch; no CPU readback.
uniform float sky_adaptation : hint_range(0.0, 1.0) = 0.6;
uniform float sky_adaptation_max_gain : hint_range(1.0, 16.0) = 4.0;
uniform float sky_adaptation_reference = 0.155;
// Share of the old art sunset band (sunset_color * sunset_factor) kept on top of the LUT.
uniform float sunset_boost : hint_range(0.0, 1.0) = 0.25;
// Must match SkyAtmosphereLut.SUN_ILLUMINANCE (the LUT is already multiplied by it).
uniform float sun_illuminance = 11.0;
// Disk radiance = sun_illuminance * T(ground, mu_sun) * scale; 0.218 keeps the noon disk at
// the old 2.4 peak so glow and AgX see the same highlight.
uniform float sun_disk_scale : hint_range(0.0, 1.0) = 0.218;
// Cloud sunlight = sun_illuminance * T(cloud base, mu_sun) * scale; 0.08 keeps noon cloud tops
// near the old near-white sun_lit tone once the LUT ambient is added.
uniform float cloud_sun_scale : hint_range(0.0, 0.5) = 0.08;

// Cloud base altitude used for the physical cloud sun colour (contract: R_ground + 1.5 km).
const float CLOUD_HEIGHT_KM = 1.5;
// Art-scaled angular radii (chord on the unit sphere). Real bodies are ~0.0047, which
// reads as a pinprick at game FOV; the sun is ~2.5x and the moon ~1.7x that.
// Stylised, not physical (real: sun 0.0047, moon 0.0045 rad); enlarged so the
// disk reads at game zoom. Sun stays clearly larger than the moon.
const float SUN_DISK_R = 0.0200;
const float MOON_DISK_R = 0.0110;

#include "res://scripts/map/view3d/sky_clouds.gdshaderinc"
#include "res://scripts/map/view3d/cloud_cells.gdshaderinc"


float remap(float v, float lo, float hi, float nlo, float nhi) {
	return sky_cloud_remap(v, lo, hi, nlo, nhi);
}


float local_storm_at(vec2 uv) {
	return sky_cloud_local_storm_at(uv, cloud_shape, storm_intensity, storm_locality);
}


float cloud_bulk(vec2 uv, float cover) {
	return sky_cloud_bulk(uv, cover, cloud_shape);
}


float cloud_opacity(vec2 uv, float cover) {
	return sky_cloud_opacity(
		uv, cover, cloud_shape, cloud_noise, cloud_detail_offset, cloud_chaos
	);
}


vec2 cloud_uv(vec3 dir, float altitude) {
	return sky_cloud_uv(dir, altitude, cloud_offset);
}

// bank_mask lives in sky_clouds.gdshaderinc (open sky between cloud masses).


// R-941: share WS-11 atmosphere_sky_view_uv so the dome and water reflections cannot drift.
vec3 sky_lut_radiance(vec3 dir) {
	return texture(sky_view_lut, atmosphere_sky_view_uv(dir, sun_direction, sky_lut_size)).rgb;
}


vec3 sun_transmittance_at(float altitude_km) {
	float r = ATMO_RG + altitude_km;
	return texture(atmosphere_transmittance_lut, transmittance_uv(r, sun_direction.y)).rgb;
}


vec3 cloud_field(vec3 dir) {
	if (cloud_fallback || dir.y < -0.025) {
		return vec3(0.0);
	}
	vec2 uv = cloud_uv(dir, 1.0);
	float local_storm = local_storm_at(uv);
	float cover = clamp(cloud_coverage + local_storm * 0.38, 0.0, 1.0);
	// Integrate through a finite cloud slab. Height-dependent erosion gives
	// broad bases and rounded tops, rather than opaque cutouts on one plane.
	int steps = cloud_shadow_samples * 2;
	float step_length = 1.0 / float(steps);
	float optical_step = step_length * mix(9.0, 15.0, local_storm)
		/ max(sqrt(max(dir.y, 0.0)), 0.38);
	float transmittance = 1.0;
	float illumination = 0.0;
	vec2 light_dir = sun_direction.xz;
	float sun_up = smoothstep(-0.08, 0.18, sun_direction.y);
	for (int i = 0; i < 8; i++) {
		if (i >= steps) { break; }
		float h = (float(i) + 0.5) * step_length;
		vec2 sample_uv = cloud_uv(dir, 1.0 + h * mix(0.14, 0.32, local_storm));
		// Height shear adds depth without animation noise or temporal jitter.
		sample_uv += wind_dir * h * 0.008;
		float body = cloud_opacity(sample_uv, cover);
		float profile = smoothstep(0.0, 0.16, h)
			* (1.0 - smoothstep(0.48, 1.0, h));
		float billows = texture(cloud_noise, sample_uv * 5.2 + cloud_detail_offset + h * 0.12).r;
		float density = max(body - h * h * 0.38, 0.0) * profile
			* mix(0.55, 1.25, billows);
		// Stratiform decks stay closed even between convective heaps.
		density += smoothstep(0.84, 0.98, cover) * profile * 0.32;
		float alpha = 1.0 - exp(-density * optical_step);
		float obstruction = cloud_bulk(sample_uv + light_dir * (0.07 + h * 0.05), cover);
		float self_shadow = exp(-obstruction * (0.4 + billows * 2.0)
			* (1.0 - h) * mix(3.0, 5.0, local_storm));
		float light = mix(0.20 + h * 0.20, 1.0, self_shadow * sun_up);
		illumination += transmittance * alpha * light;
		transmittance *= 1.0 - alpha;
	}
	float density = 1.0 - transmittance;
	float light = illumination / max(density, 0.001);
	// High thin cloud lies behind the low deck and uses a sheared wind.
	vec2 high_uv = cloud_uv(dir, 2.1) + cloud_offset * 0.65;
	vec2 high_wind = vec2(wind_dir.x * 0.825 - wind_dir.y * 0.565,
		wind_dir.x * 0.565 + wind_dir.y * 0.825);
	vec2 across = vec2(-high_wind.y, high_wind.x);
	float cirrus = texture(cloud_noise,
		vec2(dot(high_uv, high_wind) * 0.45, dot(high_uv, across) * 1.8)).r;
	cirrus = smoothstep(0.58, 0.85, cirrus) * 0.20
		* smoothstep(0.25, 0.65, cloud_coverage) * (1.0 - local_storm);
	light = mix(light, 0.8, cirrus * (1.0 - density));
	density += cirrus * (1.0 - density);
	density *= smoothstep(-0.025, 0.055, dir.y);
	return vec3(density, light, local_storm);
}


// Distant rain: soft vertical curtains that hang *below* a raining cell, drifting
// with the wind. Returns a 0..1 veil strength that later greys (and, when lit,
// brightens) the sky. Rain falls beneath its cloud, so the curtain is anchored by
// marching a little way up this same bearing and only appears where a storm cell
// actually sits overhead — never floating in open sky the way a fixed horizon
// band did. The caller also keeps it out of the opaque cloud body itself.
float rain_shafts(vec3 dir) {
	if (cloud_fallback || storm_intensity < 0.05 || dir.y > 0.6 || dir.y < 0.01) {
		return 0.0;
	}
	// March up the bearing to find the raining cell overhead AND how far below its
	// base this ray sits. Keeping x and z fixed while raising y and renormalising
	// holds the azimuth, so this samples the cloud directly overhead — what the
	// rain hangs from. `base_gap` is the distance up to the nearest cloud.
	float source = 0.0;
	float base_gap = 1.0;
	for (int i = 1; i <= rain_shaft_samples; i++) {
		float offset = float(i) * 0.07;
		vec3 up = normalize(vec3(dir.x, dir.y + offset, dir.z));
		vec2 up_uv = cloud_uv(up, 1.0);
		float ls = local_storm_at(up_uv);
		float cover = clamp(cloud_coverage + ls * 0.5, 0.0, 1.0);
		float hit = smoothstep(0.45, 0.95, ls) * cloud_bulk(up_uv, cover);
		source = max(source, hit);
		if (hit > 0.15 && offset < base_gap) {
			base_gap = offset;
		}
	}
	if (source < 0.05) {
		return 0.0;
	}
	// Vertical streaks, drifting with the wind.
	float azimuth = atan(dir.x, -dir.z);
	vec2 suv = vec2(azimuth * 2.4 + cloud_offset.x * 8.0, dir.y * 1.6 - cloud_detail_offset.y * 2.0);
	float streak = texture(cloud_noise, vec2(suv.x * 1.3, suv.y * 0.35)).r;
	float fall = texture(cloud_noise, vec2(suv.x * 3.1, suv.y * 0.18) + vec2(0.4, 0.0)).r;
	streak = smoothstep(0.44, 0.85, streak * 0.6 + fall * 0.4);
	// Soft top: the curtain fades IN over the first stretch below the cloud base
	// (larger base_gap = further below = denser), so rain emerges gradually from
	// the cloud instead of starting at a hard horizontal edge. Fades out at the
	// horizon too. A little vertical noise breaks up any residual banding.
	float base_noise = texture(cloud_noise, vec2(azimuth * 3.0 + cloud_offset.x * 6.0, 0.5)).r * 0.05;
	float top_fade = smoothstep(0.04, 0.30, base_gap + base_noise);
	float hang = smoothstep(0.01, 0.09, dir.y);
	return streak * source * hang * top_fade;
}


// A visible cloud-to-ground strike (R-1400). The channel is a real 3D polyline
// from the charged cell's base to the ground point, so it hangs under its own
// thundercloud, moves with parallax and can never appear in open sky. Only drawn
// near the flash peak so it reads as a bolt, not a steady line.
float lightning_bolt(vec3 ro, vec3 dir, vec3 top, vec3 ground) {
	if (cloud_fallback || lightning < 0.35 || lightning_kind < 0.5) {
		return 0.0;
	}
	float seed = fract(top.x * 0.0131 + top.z * 0.0071);
	float flash_gate = smoothstep(0.35, 0.9, lightning);
	return cell_bolt(ro, dir, top, ground, seed) * flash_gate;
}


// Interleaved gradient noise: fixed per-pixel march offset (no TIME, deterministic).
float cell_jitter(vec2 frag) {
	return fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
}


// Discrete clouds (R-1400), ray-marched as real volumes from the camera. Returns
// premultiplied colour and coverage; `body_cover` is the cloud body alone (rain
// excluded) so a bolt is hidden only by cloud. `lit_col` / `shade_col` are the
// dome's own sun-lit and skylit cloud tones so cells and the deck share a palette.
//
// A cumulus is optically thick: light dies within tens of metres of its surface.
// A uniform march through a translucent blob averaged several heights per pixel
// and smeared the billows into radial fringes, so each cell is marched in two
// phases: a cheap coarse search for the surface, then a short fine march with
// full density and lighting from just before it. Storm cells add an analytic
// rain curtain (chord through a cylinder under the base) behind the body.
vec4 cells_volume(
	vec3 ro, vec3 rd, vec3 lit_col, vec3 shade_col, vec3 haze_col, vec3 rain_col,
	vec3 flash_at, float flash, float jitter, out float body_cover
) {
	vec3 acc = vec3(0.0);
	float trans = 1.0;
	float body_trans = 1.0;
	float sun_up = smoothstep(-0.08, 0.18, sun_direction.y);
	float sun_fwd = pow(max(dot(rd, sun_direction), 0.0), 8.0);
	for (int i = 0; i < CELL_SLOTS; i++) {
		vec4 a = cloud_cells[i * 2];
		vec4 b = cloud_cells[i * 2 + 1];
		if (b.y <= 0.001) {
			continue;
		}
		vec2 c = ro.xz + cell_wrap_delta(a.xz, ro.xz, b.z);
		// Fade out before the periodic seam at half a domain.
		float domain = cell_domain(b.z);
		float fade = 1.0 - smoothstep(0.36 * domain, 0.5 * domain, length(c - ro.xz));
		if (fade <= 0.0) {
			continue;
		}
		float reach = a.w * mix(1.7, 1.9, b.z);
		vec3 cell_acc = vec3(0.0);
		float cell_trans = 1.0;
		float hit_t = 1e9;
		vec2 hit = cell_box_hit(
			ro, rd, vec3(c.x - reach, a.y, c.y - reach), vec3(c.x + reach, a.y + b.x, c.y + reach)
		);
		if (hit.y > hit.x) {
			// Phase 1: coarse search for the first sample inside the body.
			float dt = (hit.y - hit.x) / float(cell_steps);
			float t_enter = -1.0;
			for (int s = 0; s < 16; s++) {
				if (s >= cell_steps) {
					break;
				}
				float t = hit.x + (float(s) + 0.5 + (jitter - 0.5) * 0.0) * dt;
				vec3 p = ro + rd * t;
				if (cell_density(vec3(p.x - c.x, 0.0, p.z - c.y), p.y, a, b, cell_noise, p, wind_dir) > 0.02) {
					// Bisect to the true surface so every pixel starts its fine march at the
						// same optical depth: a fixed-step entry showed as contour terraces
						// (and a per-pixel jitter of it as dither grain).
						float lo = max(t - dt, hit.x);
						float hi = t;
						for (int k = 0; k < 5; k++) {
							float mid = 0.5 * (lo + hi);
							vec3 pm = ro + rd * mid;
							if (cell_density(vec3(pm.x - c.x, 0.0, pm.z - c.y), pm.y, a, b, cell_noise, pm, wind_dir) > 0.02) {
								hi = mid;
							} else {
								lo = mid;
							}
						}
						t_enter = lo;
					break;
				}
			}
			if (t_enter >= 0.0) {
				hit_t = t_enter;
				// Phase 2: fine march through the surface layer.
				float fine = min(dt, a.w * 0.1);
				float sigma = mix(0.06, 0.08, b.z);
				for (int s = 0; s < 12; s++) {
					if (s >= cell_fine_steps) {
						break;
					}
					// Jitter is damped: the full +-0.5 step offset showed as a static dither
						// grain on the cloud surface; a small one still hides step banding.
						float t = t_enter + (float(s) + 0.5 + (jitter - 0.5) * 0.0) * fine;
					if (t > hit.y) {
						break;
					}
					vec3 p = ro + rd * t;
					vec3 local = vec3(p.x - c.x, 0.0, p.z - c.y);
					float dens = cell_density(local, p.y, a, b, cell_noise, p, wind_dir);
					if (dens < 0.002) {
						continue;
					}
					float alpha = 1.0 - exp(-dens * sigma * fine);
					float tau = 0.0;
					for (int l = 1; l <= 2; l++) {
						if (l > cell_light_samples) {
							break;
						}
						vec3 lp = p + sun_direction * (a.w * 0.22 * float(l * l));
						tau += cell_density(vec3(lp.x - c.x, 0.0, lp.z - c.y), lp.y, a, b, cell_noise, lp, wind_dir);
					}
					float h = clamp((p.y - a.y) / max(b.x, 1.0), 0.0, 1.0);
					// Beer-Lambert toward the sun plus a weaker, longer octave for the
					// light that scatters many times inside the cloud (keeps cores from
					// going black the way a single-scatter march does).
					float k = mix(1.4, 2.2, b.z);
					float light = max(exp(-tau * k), 0.35 * exp(-tau * k * 0.25)) * sun_up;
					// Powder: thin edges and wisps stay darker than the sunlit core face.
					light *= mix(0.7, 1.0, 1.0 - exp(-dens * 3.0));
					// A thunderhead's lower body sits in its own shade.
					light *= mix(1.0, smoothstep(0.0, 0.45, h), b.z * 0.8);
						light *= 1.0 - 0.55 * cloud_gloom * (1.0 - b.z);
					// Grey flat bases lit by skylight; storm towers darken hard toward the base.
					float gloom = cloud_gloom * (1.0 - b.z);
						float ambient = mix(0.62, 1.0, h) * mix(1.0, 0.4, b.z * (1.0 - h)) * mix(1.0, 0.62, gloom);
					vec3 skylit = mix(shade_col, lit_col, 0.35) * ambient;
					vec3 col = mix(skylit, lit_col, light);
					// Silver lining where the thin edge sits in front of the sun.
					col += lit_col * sun_fwd * exp(-dens * 3.0) * 0.8 * sun_up;
					if (flash > 0.0) {
						// Lightning floods the cloud from inside: light scatters through the
						// whole body, brightest round the channel.
						col += vec3(0.9, 0.94, 1.1) * flash * 3.0 * exp(-length(p - flash_at) / (a.w * 0.9));
					}
					cell_acc += cell_trans * alpha * col;
					cell_trans *= 1.0 - alpha;
					if (cell_trans < 0.02) {
						break;
					}
				}
			}
		}
		float body = (1.0 - cell_trans) * fade;
		// Rain curtain under a storm base: chord length through a cylinder.
		float rain = 0.0;
		float rain_t = 1e9;
		if (b.z > 0.5) {
			vec2 o = ro.xz - c;
			float r = a.w * 0.4;
			float qa = dot(rd.xz, rd.xz);
			float qb = dot(o, rd.xz);
			float qc = dot(o, o) - r * r;
			float disc = qb * qb - qa * qc;
			if (disc > 0.0 && qa > 1e-6) {
				float sq = sqrt(disc);
				float t0 = max((-qb - sq) / qa, 0.0);
				float t1 = (-qb + sq) / qa;
				// Clip the chord to the air between the ground and the cloud base.
				if (abs(rd.y) > 1e-5) {
					float tg = (0.0 - ro.y) / rd.y;
					float tb = (a.y - ro.y) / rd.y;
					t0 = max(t0, min(tg, tb));
					t1 = min(t1, max(tg, tb));
				} else if (ro.y > a.y || ro.y < 0.0) {
					t1 = t0;
				}
				if (t1 > t0) {
					vec3 mid = ro + rd * (0.5 * (t0 + t1));
					float streak = textureLod(
						cloud_noise, vec2((mid.x - mid.z * 0.4) / 160.0 + b.w * 3.0, mid.y / 3000.0), 0.0
					).r;
					// Thickest in the middle of the shaft, thinning toward its sides.
					float core = 1.0 - smoothstep(0.2, 1.0, length(mid.xz - c) / r);
					rain = (1.0 - exp(-(t1 - t0) * 0.0016 * mix(0.55, 1.2, streak))) * b.y * core * fade;
					rain_t = t0;
				}
			}
		}
		vec3 body_col = cell_trans < 1.0 ? cell_acc / max(1.0 - cell_trans, 1e-4) : vec3(0.0);
		// Aerial perspective: a distant thunderhead still reads as a solid body.
		body_col = mix(body_col, haze_col, (1.0 - exp(-min(hit_t, 2e4) / 16000.0)) * 0.6);
		// Some storms carry hail: a whiter, greenish-tinged core in the shaft.
		vec3 shaft_col = mix(rain_col, vec3(0.78, 0.86, 0.82), step(0.55, fract(b.w * 9.1)) * 0.5) + vec3(0.9, 0.94, 1.1) * flash * 0.6;
		shaft_col = mix(shaft_col, haze_col, (1.0 - exp(-min(rain_t, 2e4) / 9000.0)) * 0.6);
		// Cloud body over its own rain, then this cell over what lies behind it.
		vec3 cell_col = body_col * body + shaft_col * rain * (1.0 - body);
		float cover = body + rain * (1.0 - body);
		acc += trans * cell_col;
		trans *= 1.0 - cover;
		body_trans *= 1.0 - body;
	}
	body_cover = 1.0 - body_trans;
	return vec4(acc, 1.0 - trans);
}


// R-1444: crepuscular rays from the clouds the player actually sees. The old
// R-1400 march only asked the sparse discrete cells, so the dome deck - most of
// the visible cloud - never cut a beam. Light reaching the air along this pixel
// comes from the sun's side of the sky, so walk the great circle from the sun to
// the pixel (samples packed toward the sun, glow-weighted) and ask how open the
// deck and the cells are there: the light-scattering post-process of GPU Gems 3
// ch. 13, done analytically in direction space (no screen texture). Gaps around
// a hidden sun fan out as bright shafts and cloud edges throw dark columns that
// converge on the sun, at noon and with the sun on the horizon alike.
// Returns the glow-weighted share of the path toward the sun that is open (1 = no
// cloud in the way), or -1 when this pixel is too far from the sun to bother.
// How much the discrete cells hide direction `d` from the camera at `ro`, matched to
// what cells_volume draws: the copy of each cell nearest the camera, faded out before
// the periodic seam, hit where the ray crosses the cell's shadow-casting layer.
// WHY not cells_ground_shadow(ro, d): it clamps the slope to 0.15 and takes the copy
// nearest the projected point, so low sky directions were hidden by far copies the
// dome never draws, printing straight-edged dark blocks into the beams.
float cells_toward(vec3 ro, vec3 d) {
	if (d.y < 0.01) {
		return 0.0;
	}
	float lit = 1.0;
	for (int i = 0; i < CELL_SLOTS; i++) {
		vec4 a = cloud_cells[i * 2];
		vec4 b = cloud_cells[i * 2 + 1];
		if (b.y <= 0.001) {
			continue;
		}
		vec2 c = ro.xz + cell_wrap_delta(a.xz, ro.xz, b.z);
		float domain = cell_domain(b.z);
		float fade = 1.0 - smoothstep(0.36 * domain, 0.5 * domain, length(c - ro.xz));
		if (fade <= 0.0) {
			continue;
		}
		float layer = a.y + b.x * mix(0.35, 0.25, b.z);
		vec2 q = ro.xz + d.xz * ((layer - ro.y) / d.y);
		float r = a.w * mix(CELL_CU_FOOTPRINT, CELL_CB_FOOTPRINT, b.z);
		vec2 off = q - c;
		if (dot(off, off) > r * r * 1.7) {
			continue;
		}
		vec2 nuv = q / CELL_BILLOW_SCALE + b.w * 7.13;
		float n = textureLod(cloud_noise, nuv, 1.0).r * 0.65
			+ textureLod(cloud_noise, nuv * 2.7 + 0.31, 1.0).r * 0.35;
		float dist = length(off) / max(r, 1.0) + (n - 0.5) * 0.38;
		lit *= 1.0 - smoothstep(1.0, 0.8, dist) * b.y * fade
			* mix(CELL_CU_OPACITY, CELL_CB_OPACITY, b.z);
	}
	return 1.0 - lit;
}

// Darkening of a fully shaded path and brightening of a fully open one, at the
// phase peak in the hazy air of broken cloud.
const float SUNBEAM_SHADE = 0.85;
const float SUNBEAM_LIGHT = 1.5;

float sky_sunbeams(vec3 ro, vec3 dir, float jitter) {
	float c = dot(dir, sun_direction);
	if (cloud_fallback || sun_direction.y < -0.04 || c < 0.15) {
		return -1.0;
	}
	int steps = cell_ray_samples > 0 ? 14 : 7;
	float span = acos(clamp(c, -1.0, 1.0));
	float open_sum = 0.0;
	float glow_sum = 0.0;
	for (int i = 0; i < 14; i++) {
		if (i >= steps) {
			break;
		}
		float f = (float(i) + jitter) / float(steps);
		vec3 d = normalize(mix(sun_direction, dir, f));
		// Two ends matter: the sun's neighbourhood (a hidden sun dims every path) and
		// the stretch just sunward of this pixel, where a cloud's shadow column starts
		// and trails away from the sun. The middle of a long path counts less.
		float glow = exp(-span * f * 5.0) + exp(-span * (1.0 - f) * 4.0);
		float occ = 1.0;
		if (d.y > -0.01) {
			vec2 uv = cloud_uv(d, 1.0);
			float cover = clamp(cloud_coverage + local_storm_at(uv) * 0.38, 0.0, 1.0);
			// The dome integrates a thick slab, so a modest single-layer density is
			// already an opaque cloud on screen (same thresholds as god_ray_pass).
			float body = sky_cloud_shadow_soft(
				uv, cover, cloud_shape, cloud_noise, cloud_detail_offset, cloud_chaos, 1.0
			);
			occ = smoothstep(0.2, 0.55, body) * smoothstep(-0.01, 0.06, d.y);
			if (cell_ray_samples > 0) {
				occ = 1.0 - (1.0 - occ) * (1.0 - cells_toward(ro, d));
			}
		}
		open_sum += (1.0 - occ) * glow;
		glow_sum += glow;
	}
	return open_sum / max(glow_sum, 1e-4);
}

// Convert an ENU horizon ray to equatorial coordinates. World -Z is map north,
// +X east, and +Y zenith. The latitude makes Polaris sit 59.4 degrees above the
// north horizon and removes stars that can never rise over Estonia.
vec2 equatorial_uv(vec3 dir) {
	float north = -dir.z;
	float east = dir.x;
	float up = dir.y;
	float sin_lat = sin(observer_latitude);
	float cos_lat = cos(observer_latitude);
	float sin_dec = clamp(up * sin_lat + north * cos_lat, -1.0, 1.0);
	float declination = asin(sin_dec);
	float hour_angle = atan(-east, up * cos_lat - north * sin_lat);
	float right_ascension = sidereal_angle - hour_angle;
	return vec2(fract(right_ascension / TAU), 0.5 - declination / PI);
}


#include "res://scripts/map/view3d/sky_stars.gdshaderinc"


void sky() {
	vec3 dir = EYEDIR;
	float height = dir.y;

	float sun_amount = max(dot(dir, sun_direction), 0.0);
	// Longer optical paths desaturate the horizon; forward scattering is
	// concentrated toward the sun rather than a uniform blue gradient.
	float air_mass = 1.0 / max(height + 0.12, 0.12);
	float haze = 1.0 - exp(-air_mass * (0.10 + cloud_darken * 0.12));
	vec3 horizon;
	vec3 color;
	// Physical sky only: LUT ambient for cloud shadows (zenith + horizon average).
	vec3 cloud_ambient = vec3(0.0);
	if (sky_lut_available) {
		// Background radiance straight from the sky-view LUT: blue zenith, hazy horizon,
		// Mie glow around the sun, and the Earth shadow with its pink band at twilight.
		vec3 lut_zenith = sky_lut_radiance(vec3(0.0, 1.0, 0.0));
		float zenith_luminance = dot(lut_zenith, vec3(0.2126, 0.7152, 0.0722));
		float adaptation = clamp(
			pow(sky_adaptation_reference / max(zenith_luminance, 1e-6), sky_adaptation),
			1.0, sky_adaptation_max_gain);
		vec3 art = sky_exposure * sky_tint.rgb * adaptation;
		lut_zenith *= art;
		vec3 lut_horizon = sky_lut_radiance(normalize(vec3(dir.x, 0.0, dir.z) + vec3(0.0, 0.0, 1e-5))) * art;
		cloud_ambient = 0.5 * (lut_zenith + lut_horizon);
		// The sun-lit sky goes to ~0 below civil twilight; the old night gradient stays
		// as the moonlit/airglow floor so nights look as before.
		float night = 1.0 - day_blend;
		horizon = lut_horizon + night_horizon_color.rgb * night;
		color = sky_lut_radiance(dir) * art

			+ mix(night_top_color.rgb, night_horizon_color.rgb, haze) * night;
		// Art-controlled warm band on the sun side, now a small boost over the LUT sunset.
		color += sunset_color.rgb * sunset_factor * pow(sun_amount, 2.0) * haze * sunset_boost;
	} else {
		vec3 top = mix(night_top_color.rgb, day_top_color.rgb, day_blend);
		horizon = mix(night_horizon_color.rgb, day_horizon_color.rgb, day_blend);
		// Warm dusk/dawn band hugging the horizon on the sun side.
		horizon = mix(horizon, sunset_color.rgb, sunset_factor * pow(sun_amount, 2.0) * 0.8);
		color = mix(top, horizon, haze);
		float forward_scatter = pow(sun_amount, 12.0) * (0.06 + haze * 0.20);
		color += mix(sun_color.rgb, sunset_color.rgb, sunset_factor)
			* forward_scatter * day_blend * (1.0 - cloud_darken * 0.8);
	}
	color = mix(color, horizon * vec3(0.83, 0.87, 0.93), cloud_darken * 0.38);
	// Below the horizon fade into darker haze so the map edge reads as ground fog.
	color = mix(color, horizon * 0.55, clamp(-height * 3.0, 0.0, 1.0));

	vec3 cloud_sample = cloud_field(dir);
	float clouds = cloud_sample.x;
	float cloud_light = cloud_sample.y;
	float local_storm = cloud_sample.z;

	// Real stars fade with twilight and are occluded by the procedural weather.
	// R-1443: catalog texels are drawn as round twinkling point sources and the
	// Milky Way glows behind them (sky_stars.gdshaderinc). The radiance cubemap
	// skips both: their ambient contribution is negligible and the star search
	// needs screen-space derivatives.
	if (!AT_CUBEMAP_PASS) {
		vec2 star_uv = equatorial_uv(dir);
		float pixel_angle = max(length(dFdx(dir)), length(dFdy(dir)));
		vec3 stars = star_field(star_uv, height, pixel_angle);
		float star_visibility = pow(1.0 - day_blend, 3.0) * smoothstep(-0.01, 0.05, height);
		color += stars * star_visibility * (1.0 - clouds) * 0.32;
		color += milky_way(star_uv) * milky_way_visibility(height) * (1.0 - clouds) * 0.25;
	}

	// Sun disk plus halo, hidden once the sun dips below the horizon.
	float sun_visibility = smoothstep(-0.05, 0.05, sun_direction.y);
	vec3 sun_tint = mix(sun_color.rgb, sunset_color.rgb, sunset_factor * 0.55);
	float sun_distance = length(dir - sun_direction);
	float disk = 1.0 - smoothstep(SUN_DISK_R - 0.0011, SUN_DISK_R, sun_distance);
	float halo = pow(sun_amount, 120.0) * 0.18;
	if (sky_lut_available) {
		// Same disk and halo, coloured by the air mass: sun_illuminance * T(ground, mu_sun)
		// turns the disk orange-red at the horizon without an art ramp. Divided by the old
		// 2.4 peak so the disk * 2.4 + halo weighting below stays unchanged.
		sun_tint = sun_illuminance * sun_transmittance_at(ATMO_SKY_VIEW_HEIGHT_KM - ATMO_RG)
			* sun_disk_scale / 2.4;
		// Limb darkening 1 - 0.6 * (1 - sqrt(1 - (d/r)^2)).
		float d_over_r = clamp(sun_distance / SUN_DISK_R, 0.0, 1.0);
		disk *= 1.0 - 0.6 * (1.0 - sqrt(1.0 - d_over_r * d_over_r));
	}
	color += sun_tint * (disk * 2.4 + halo) * sun_visibility * (1.0 - clouds * 0.95);

	// Moon: opaque shaded sphere sampled from a NASA near-side albedo photo.
	// WHY: Additive `color += surface` lets the bright blue night sky leak through
	// the disk and reads as a cyan moon. The lunar body is optically thick, so
	// the surface must replace the background inside the disk mask.
	float moon_dot = dot(dir, moon_direction);
	float moon_radius = MOON_DISK_R;
	float moon_edge = cos(moon_radius);
	// Thin AA only. A wide outer skirt used to sample empty black albedo and
	// read as a dark sticker outline against the night sky.
	float moon_disk = 1.0 - smoothstep(moon_radius - 0.0006, moon_radius + 0.0006, length(dir - moon_direction));
	// WHY: The NASA near-side mosaic is north-up / west-left. Align the disk to
	// celestial north (same ENU frame as the star map) instead of world zenith so
	// maria keep the familiar Earth orientation and pick up the correct
	// parallactic tilt as the moon crosses the sky. Zenith-up made the skin look
	// sideways whenever the moon was off the meridian.
	vec3 celestial_north = vec3(0.0, sin(observer_latitude), -cos(observer_latitude));
	vec3 moon_north = celestial_north - moon_direction * dot(celestial_north, moon_direction);
	// Near the celestial pole the projection collapses; fall back to ground north.
	if (dot(moon_north, moon_north) < 1e-8) {
		vec3 ground_north = vec3(0.0, 0.0, -1.0);
		moon_north = ground_north - moon_direction * dot(ground_north, moon_direction);
	}
	vec3 moon_up = normalize(moon_north);
	// cross(north_axis, moon_direction) points celestial west on the southern
	// meridian, matching selenographic east (Mare Crisium) on the right of the
	// NASA disk once +U follows moon_right.
	vec3 moon_right = normalize(cross(moon_up, moon_direction));
	vec2 moon_uv = vec2(dot(dir, moon_right), dot(dir, moon_up)) / sin(moon_radius);
	float moon_r2 = dot(moon_uv, moon_uv);
	float moon_z = sqrt(max(1.0 - moon_r2, 0.0));
	vec3 moon_normal = normalize(vec3(moon_uv, moon_z));
	// WHY: Moon phases are sunlight on a sphere. moon_normal is in a disk frame
	// where +Z faces the camera (along -moon_direction in world), so project the
	// live sun the same way. That keeps the terminator locked to solar position
	// and consistent with lunar_direction vs solar_direction, instead of a
	// phase-only fake light vector.
	vec3 moon_light = normalize(vec3(
		dot(sun_direction, moon_right),
		dot(sun_direction, moon_up),
		-dot(sun_direction, moon_direction)
	));
	// Keep the signed cosine so the terminator can soften across the dark side.
	// Clamping first made smoothstep(...) collapse into a flat lit fill.
	float moon_ndotl = dot(moon_normal, moon_light);
	float moon_lit = max(moon_ndotl, 0.0);
	// WHY inset 0.485: unit-disk UV lands inside the authored crust, while the
	// opaque filter-safe skirt outside r~1 keeps bilinear taps off black.
	// WHY flip V: sky sampler2D has V=0 at the top of the image (north on the
	// mosaic). Disk +Y is lunar north, so +moon_uv.y must sample decreasing V.
	// Without the flip the skin renders upside-down / sideways on the sky disk.
	// WHY flip both U and V (180° rotation): The NASA near-side mosaic is oriented
	// north-up / west-left. From Estonia's latitude (~59°N) the moon's near side
	// appears rotated 180° compared to that default, so we flip both UV axes.
	vec2 lunar_uv = clamp(vec2(-moon_uv.x, -moon_uv.y) * 0.485 + 0.5, vec2(0.002), vec2(0.998));
	vec3 lunar_albedo = texture(lunar_albedo_map, lunar_uv).rgb;
	// Mild relief from photo luminance slopes. Keep taps inside the disk so the
	// limb never differences against the exterior skirt and darkens into a rim.
	float texel = 1.0 / max(float(textureSize(lunar_albedo_map, 0).x), 1.0);
	vec2 relief_uv_x = clamp(lunar_uv + vec2(texel, 0.0), vec2(0.002), vec2(0.998));
	vec2 relief_uv_nx = clamp(lunar_uv - vec2(texel, 0.0), vec2(0.002), vec2(0.998));
	vec2 relief_uv_y = clamp(lunar_uv + vec2(0.0, texel), vec2(0.002), vec2(0.998));
	vec2 relief_uv_ny = clamp(lunar_uv - vec2(0.0, texel), vec2(0.002), vec2(0.998));
	float h_c = dot(lunar_albedo, vec3(0.333333));
	float h_x = dot(texture(lunar_albedo_map, relief_uv_x).rgb, vec3(0.333333))
		- dot(texture(lunar_albedo_map, relief_uv_nx).rgb, vec3(0.333333));
	float h_y = dot(texture(lunar_albedo_map, relief_uv_y).rgb, vec3(0.333333))
		- dot(texture(lunar_albedo_map, relief_uv_ny).rgb, vec3(0.333333));
	float relief_fade = smoothstep(0.08, 0.35, moon_z);
	// +h_y: lunar_uv.y increases toward south after the V flip, so the texture
	// Y slope is opposite moon_uv.y (lunar north).
	vec3 moon_shaded_n = normalize(moon_normal + vec3(-h_x, h_y, 0.0) * (1.1 * relief_fade));
	float relief_lit = max(dot(moon_shaded_n, moon_light), 0.0);
	float terminator = smoothstep(-0.10, 0.05, moon_ndotl);
	// Lommel-Seeliger approximates dusty regolith better than a Lambertian disk.
	float cos_i = max(mix(moon_lit, relief_lit, 0.40 * relief_fade), 1e-4);
	float cos_e = max(moon_z, 1e-4);
	float lommel = cos_i / (cos_i + cos_e);
	float opposition = 1.0 + 0.22 * pow(moon_lit, 10.0);
	// Keep limb nearly flat - strong geometric darkening plus photo limb read as
	// a black border on the small sky disk.
	float moon_limb = mix(0.94, 1.0, pow(moon_z, 0.35));
	// WHY: A daytime moon is still fully sunlit rock and appears pale silver
	// against blue sky. Fading to 0.42 made sunlight_col darker than
	// day_top_color and read as a muddy sticker. Keep near-full photometry by
	// day; soft haze below only reduces crater contrast the way real air does.
	float day_moon_fade = mix(1.0, 1.08, day_blend);
	// Earthshine is faint, barely cool, and only meaningful at night near new moon.
	float earthshine_strength = 0.014
		* (0.55 + 0.45 * cos(moon_phase * TAU))
		* (1.0 - day_blend);
	vec3 earthshine_col = lunar_albedo * vec3(0.62, 0.64, 0.68);
	vec3 sunlight_col = lunar_albedo * moon_color.rgb
		* (0.58 + 1.25 * lommel * opposition)
		* moon_limb
		* day_moon_fade;
	vec3 moon_surface = mix(earthshine_col * earthshine_strength, sunlight_col, terminator);
	moon_surface *= 0.96 + 0.10 * h_c;
	// Soft daytime haze lifts dark maria toward a pale sky-adjacent tone without
	// crushing overall luminance back below the blue dome.
	moon_surface = mix(
		moon_surface,
		mix(moon_surface, vec3(0.86, 0.87, 0.90), 0.42),
		day_blend * 0.38
	);
	float moon_visibility = smoothstep(-0.04, 0.03, moon_direction.y) * (1.0 - clouds);
	float moon_opacity = moon_disk * moon_visibility;
	// WHY: The unlit nightside is effectively invisible against daytime sky.
	// Opaque black replacement would leave a dark round sticker beside the lit
	// crescent; fade that nightside out as day_blend rises.
	moon_opacity *= mix(1.0, terminator * terminator, day_blend * 0.92);
	// WHY: Near new moon the crescent sits close to the sun. Drawing a solid
	// disk there reads as "moon stuck behind the sun". Real daytime glare hides
	// that conjunction; fade hard inside ~16 deg and restore by ~35 deg.
	float sun_moon_align = max(dot(normalize(moon_direction), normalize(sun_direction)), 0.0);
	float solar_glare_fade = 1.0 - smoothstep(0.82, 0.96, sun_moon_align);
	moon_opacity *= mix(0.55 + 0.45 * solar_glare_fade, solar_glare_fade, day_blend);
	color = mix(color, moon_surface, moon_opacity);
	// Thin aureole from atmospheric forward scatter; much subtler than a glowy disk.
	// Daytime air is already bright, so keep most of the aureole nocturnal.
	float moon_halo = smoothstep(cos(moon_radius * 3.0), moon_edge, moon_dot) * (1.0 - moon_disk);
	color += vec3(0.82, 0.83, 0.86) * moon_halo * moon_visibility
		* (0.018 + moon_lit * 0.028) * mix(1.0, 0.35, day_blend);

	// Cloud layer. By day the lit tone carries the sun's colour; at dawn and dusk
	// it becomes a warm ramp — gold where it points at the sun, cooling through
	// orange to a pink-violet away from it — while shadowed sides turn a dusky
	// violet lit by skylight, and the sun-facing rim flares hottest. That
	// graduation is what makes a real sunset glow instead of tinting every cloud
	// the same flat orange.
	vec3 sun_lit = mix(vec3(1.0, 1.0, 1.0), sun_color.rgb, 0.3);
	vec3 cloud_sun_color = sun_color.rgb;
	// Share of the art dusk ramp below; the physical sky keeps only part of it.
	float dusk_ramp = sunset_factor;
	if (sky_lut_available) {
		// Physical sun at cloud height plus LUT skylight replaces the constant sun_color mix.
		cloud_sun_color = sun_illuminance * sun_transmittance_at(CLOUD_HEIGHT_KM) * cloud_sun_scale;
		sun_lit = cloud_sun_color + cloud_ambient;
		dusk_ramp = sunset_factor * clamp(sunset_boost * 2.0, 0.0, 1.0);
	}
	float sun_prox = pow(sun_amount, 1.5);
	vec3 dusk_hot = vec3(1.15, 0.92, 0.60);
	vec3 dusk_far = vec3(0.74, 0.44, 0.56);
	vec3 dusk_lit = mix(dusk_far, sunset_color.rgb, smoothstep(0.12, 0.5, sun_prox));
	dusk_lit = mix(dusk_lit, dusk_hot, smoothstep(0.55, 0.95, sun_prox));
	sun_lit = mix(sun_lit, dusk_lit * 1.15, dusk_ramp);
	vec3 cloud_top = mix(vec3(0.09, 0.11, 0.16), sun_lit, day_blend);
	// Shadowed sides: cool blue by day, dusky violet at sunset (skylight, not sun).
	// Storm cells darken further so a heavy raining cell reads dark under the sky.
	vec3 day_shadow = cloud_top * mix(0.6, 0.26, local_storm) * vec3(0.88, 0.95, 1.12);
	vec3 dusk_shadow = mix(vec3(0.30, 0.26, 0.40), vec3(0.46, 0.40, 0.52), day_blend) * mix(1.0, 0.5, local_storm);
	vec3 cloud_shadow = mix(day_shadow, dusk_shadow, sunset_factor);
	vec3 cloud_col = mix(cloud_shadow, cloud_top, cloud_light);
	// Hot rim where a lit cloud faces the low sun — the fiery sunset edge.
	vec3 rim = mix(cloud_sun_color, dusk_hot, sunset_factor);
	cloud_col += rim * pow(sun_amount, 5.0) * cloud_light * (0.12 + 0.40 * sunset_factor) * sun_visibility;
	// Anvil crown: the icy top of a tall storm cell catches light as a bright,
	// cool-white cap high over its dark base — the giveaway of a thunderhead.
	float anvil = local_storm * smoothstep(0.32, 0.62, dir.y) * cloud_light * smoothstep(0.25, 0.6, clouds);
	cloud_col = mix(cloud_col, vec3(1.05, 1.08, 1.16), anvil * 0.18 * sun_visibility * day_blend);
	// Overcast fronts flatten the heaps toward a dim, cool, uniform sheet; storm
	// decks go darker and a touch bluer than a plain grey overcast.
	vec3 overcast = cloud_top * mix(0.5, 0.4, local_storm) * vec3(0.94, 0.98, 1.06);
	cloud_col = mix(cloud_col, overcast, cloud_darken * 0.28);
	// Distant banks dissolve into the same air as the horizon, preserving depth.
	float cloud_haze = (1.0 - exp(-0.07 / max(height + 0.03, 0.03)));
	cloud_col = mix(cloud_col, horizon * mix(1.0, 0.65, cloud_darken), cloud_haze);
	color = mix(color, cloud_col, clouds);

	// Distant rain curtains hanging under a heavy cell. They grey the low sky, but
	// catch sunlight — brighter and a touch warm toward the sun — so a sunlit
	// distant shower glows as a luminous wall of water rather than flat grey.
	float shafts = rain_shafts(dir);
	float veil_sun = max(dot(normalize(dir), sun_direction), 0.0);
	vec3 rain_veil = mix(vec3(0.34, 0.38, 0.46), vec3(0.60, 0.64, 0.72), day_blend);
	rain_veil = mix(rain_veil, sun_color.rgb * 1.15, veil_sun * 0.45 * sun_visibility);
	rain_veil = mix(rain_veil, sunset_color.rgb * 1.1, sunset_factor * veil_sun * 0.6);
	// Only in the clear air under the cloud, not painted over the opaque cloud body.
	color = mix(color, rain_veil, shafts * 0.6 * (1.0 - clouds));

	// R-1400 discrete clouds: world-space cumulus and cumulonimbus cells drawn over
	// the dome deck with real parallax. They hide the sun and stars behind them,
	// and are the same objects that shade the ground and cut god rays.
	// The radiance cubemap skips them: it only feeds ambient light, and a march per
	// cubemap texel every frame would cost more than the whole visible dome.
	vec3 ro = POSITION;
	vec3 flash_col = vec3(0.90, 0.94, 1.10);
	vec2 strike_shift = cell_wrap_delta(lightning_origin.xz, ro.xz, 1.0) + ro.xz - lightning_origin.xz;
	vec3 strike_top = lightning_origin + vec3(strike_shift.x, 0.0, strike_shift.y);
	vec3 strike_ground = lightning_ground + vec3(strike_shift.x, 0.0, strike_shift.y);
	float flash = lightning * lightning_density;
	float cell_cover = 0.0;
	if (!cloud_fallback && cell_steps > 0 && !AT_CUBEMAP_PASS) {
		vec3 haze_col = horizon * mix(1.0, 0.65, cloud_darken);
		vec3 cell_rain = mix(cloud_shadow, rain_veil, 0.35) * 0.85;
		vec4 cells = cells_volume(
			ro, dir, cloud_top, cloud_shadow, haze_col, cell_rain, strike_top, flash,
			cell_jitter(FRAGCOORD.xy), cell_cover
		);
		color = color * (1.0 - cells.a) + cells.rgb;
	}
	// R-1444 sunbeams: air shaded by a cloud loses the forward glow the clear-air
	// LUT assumed, open paths gain the extra haze of broken weather, so shafts fan
	// out from the cloud gaps and dark columns from the cloud edges. Strongest with
	// broken cover (a clear sky has nothing to cut, overcast hides the sun) and wider
	// at dawn and dusk, when the low sun's rays sweep across much of the sky.
	if (!AT_CUBEMAP_PASS) {
		float open_path = sky_sunbeams(ro, dir, cell_jitter(FRAGCOORD.xy));
		if (open_path >= 0.0) {
			float cos_sun = dot(dir, sun_direction);
			float g = mix(0.55, 0.35, sunset_factor);
			float ratio = (1.0 - g) * (1.0 - g) / max(1.0 + g * g - 2.0 * g * cos_sun, 1e-4);
			float hg = ratio * sqrt(ratio) * sun_visibility * smoothstep(0.15, 0.35, cos_sun);
			float broken = 1.0 - abs(clamp(cloud_coverage, 0.0, 1.0) * 2.0 - 1.0);
			float haze = clamp(0.1 + broken * 0.7 + storm_intensity * 0.2, 0.0, 1.0);
			// A closed rain or overcast sheet (darken 0.82 / 0.72) has no gaps to fan beams;
			// broken cloud (0.40) and an open storm sky (0.34) keep them.
			haze *= 1.0 - smoothstep(0.45, 0.7, cloud_darken);
			// Beams sit in the air in front of the clouds, so they also cross cloud
			// bodies, a little weaker than over open sky. Deck only: `cell_cover` is
			// non-zero across a cell's whole bounding box and printed its edges.
			float in_front = 1.0 - clouds * 0.3;
			float amount = clamp(hg * haze * in_front, 0.0, 1.0);
			// Scale the sky's own radiance rather than add the sun colour: the in-scattered
			// beam has the hue of the glow around the sun, which at dawn is the warm band
			// the LUT already draws (the sun_tint seen through the horizon air is dim red).
			color *= mix(1.0 - SUNBEAM_SHADE * amount, 1.0 + SUNBEAM_LIGHT * amount, open_path);
		}
	}

	// Lightning only ever comes from a storm cell (R-1400): the sky glows on that
	// cell's bearing, the cell lights from inside (cells_volume), and a
	// cloud-to-ground stroke draws its channel under the cell's base.
	if (lightning > 0.001) {
		vec2 bearing = normalize(vec2(dir.x, -dir.z) + vec2(0.0001));
		float aim = max(dot(bearing, lightning_dir), 0.0);
		float near_strike = pow(aim, 6.0) * smoothstep(0.75, 0.0, dir.y);
		color += flash_col * flash
			* (near_strike * (0.2 + clouds * 1.2 + shafts * 1.0 + cell_cover * 0.6) + 0.02);
		// The bolt itself, a searing white-blue channel drawn over the flash.
		color += vec3(0.95, 0.97, 1.25) * lightning_bolt(ro, dir, strike_top, strike_ground)
			* 4.0 * lightning_density * (1.0 - cell_cover * 0.85);
	}

	COLOR = color;
}
