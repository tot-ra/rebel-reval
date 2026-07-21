shader_type sky;

// Sky dome for the 3D map view (ADR 0007 view layer): day/night gradient,
// Hipparcos stars positioned for Reval in 1343, sun disk with halo, moon,
// procedural clouds, and a warm horizon band for sunrise/sunset. All dynamics
// are script-driven uniforms (no TIME), so the sky stays deterministic and
// testable like the rest of the view.

uniform vec4 day_top_color : source_color = vec4(0.24, 0.51, 0.88, 1.0);
uniform vec4 day_horizon_color : source_color = vec4(0.62, 0.78, 0.93, 1.0);
uniform vec4 night_top_color : source_color = vec4(0.020, 0.045, 0.130, 1.0);
uniform vec4 night_horizon_color : source_color = vec4(0.050, 0.100, 0.220, 1.0);
uniform vec4 sunset_color : source_color = vec4(0.98, 0.45, 0.18, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.92, 0.74, 1.0);
uniform vec4 moon_color : source_color = vec4(0.82, 0.84, 0.86, 1.0);

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
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.22;
uniform float cloud_darken : hint_range(0.0, 1.0) = 0.0;
// Primary bank drift. Detail offset advances faster so edges churn while
// whole cloud masses still cross the dome from one horizon to the other.
uniform vec2 cloud_offset = vec2(0.0);
uniform vec2 cloud_detail_offset = vec2(0.0);
// Domain-warp strength. Clear weather keeps mild chaos; storms tear harder.
uniform float cloud_chaos : hint_range(0.0, 1.0) = 0.35;
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
// Prevailing wind on the ground plane, used to comb cirrus streaks and to lean
// the storm wall into the upwind quarter so the front reads as approaching.
uniform vec2 wind_dir = vec2(0.928, 0.371);

// Hipparcos stars live in equatorial coordinates in this nearest-filtered map.
// The observer transform below turns each sky ray into right ascension and
// declination for Reval's latitude and the canonical 23 April 1343 sidereal sky.
uniform sampler2D star_map : filter_nearest, repeat_enable;
uniform float observer_latitude = 1.0371;
uniform float sidereal_angle = 3.8101;


float remap(float v, float lo, float hi, float nlo, float nhi) {
	return nlo + (clamp(v, lo, hi) - lo) / max(hi - lo, 1e-4) * (nhi - nlo);
}


// Storm strength at a projected cloud point. A large-scale cell field marks where
// convection sits; storm_locality blends between spreading the storm evenly over
// the whole deck (0) and packing it into a few high-cell cores (1). That single
// field lets one storm read as a solid rain front or as an isolated raining cell
// in open sky, and lets rain curtains hang under exactly those cells.
float local_storm_at(vec2 uv) {
	float cell = 1.0 - texture(cloud_shape, uv * 0.16 + vec2(0.37, 0.71)).r;
	float mask = mix(1.0, smoothstep(0.5, 0.82, cell), storm_locality);
	return storm_intensity * mask;
}


// Coarse cumulus body from rounded cellular heaps, before edge erosion. The
// silhouette must come from cellular noise: FBM thresholds swirl like marbled
// ink, cellular gives lumpy cauliflower. Cheap enough to march for self-shadow.
float cloud_bulk(vec2 uv, float cover) {
	// Two cellular scales: large discrete banks with open sky between them, and
	// the smaller heaps that pile up inside each bank.
	float banks = 1.0 - texture(cloud_shape, uv * 0.42 + vec2(0.13, 0.61)).r;
	float heaps = 1.0 - texture(cloud_shape, uv).r;
	float bank_mask = smoothstep(0.30, 0.72, banks);
	float base = heaps * mix(0.45, 1.0, bank_mask);

	// Coverage raises the cloud floor: low coverage keeps only the densest cores,
	// high coverage lets the whole heap field become solid overcast.
	float floor_thr = mix(0.66, 0.04, cover);
	return clamp(remap(base, floor_thr, floor_thr + 0.30, 0.0, 1.0), 0.0, 1.0);
}


// Full opacity: the cellular body with its edges eroded by a few FBM octaves so
// heap boundaries are torn and lumpy. cloud_chaos widens the erosion so storms
// shred harder than clear skies.
float cloud_opacity(vec2 uv, float cover) {
	float cloud = cloud_bulk(uv, cover);
	float detail = texture(cloud_noise, uv * 1.9 + cloud_detail_offset).r * 0.5
		+ texture(cloud_noise, uv * 4.6 - cloud_detail_offset * 0.6).r * 0.32
		+ texture(cloud_noise, uv * 9.4 + cloud_detail_offset * 0.3).r * 0.18;
	cloud = remap(cloud, detail * mix(0.32, 0.72, cloud_chaos), 1.0, 0.0, 1.0);
	return clamp(cloud, 0.0, 1.0);
}


// Cloud field sampled per view ray. Returns:
//   x = opacity of cloud along this ray (0..1),
//   y = light factor (0 = shadowed underside, 1 = sunlit top / anvil crown),
//   z = local storm strength here (drives shadow depth and rain association).
vec3 cloud_field(vec3 dir) {
	if (dir.y < 0.02) {
		return vec3(0.0);
	}
	float horizon_fade = smoothstep(0.02, 0.20, dir.y);

	// Planar projection of the view ray onto an overhead cumulus layer.
	vec2 uv = dir.xz / (dir.y + 0.26) * 0.30 + cloud_offset;

	// Storm strength here can be an isolated cell or a full front (storm_locality).
	// A cell towers and darkens: it raises coverage locally so a heavy raining
	// cloud can stand in an otherwise open sky, and it stacks a wall toward the
	// upwind horizon so widespread storms read as marching in.
	float local_storm = local_storm_at(uv);
	vec2 ground = normalize(vec2(dir.x, -dir.z) + vec2(0.0001));
	float upwind = 0.5 + 0.5 * dot(ground, -wind_dir);
	float storm_wall = local_storm * smoothstep(0.55, 0.05, dir.y) * mix(0.55, 1.0, upwind);
	float cover = clamp(cloud_coverage + local_storm * 0.5 + storm_wall * 0.2, 0.0, 1.0);

	float density = cloud_opacity(uv, cover);

	// Thin cirrus veil combed along the wind on a farther plane, so wispy high
	// cloud parallaxes behind the cumulus at moderate coverage.
	vec2 high_uv = dir.xz / (dir.y + 0.05) * 0.55 + cloud_detail_offset * 0.3;
	vec2 wind_perp = vec2(-wind_dir.y, wind_dir.x);
	float cirrus = texture(cloud_noise, vec2(dot(high_uv, wind_dir) * 0.4, dot(high_uv, wind_perp) * 2.4)).r;
	cirrus = smoothstep(0.62, 0.92, cirrus) * smoothstep(0.4, 0.75, cloud_coverage)
		* (1.0 - storm_intensity * 0.7) * 0.4;
	density = max(density, cirrus) * horizon_fade;

	// Volumetric self-shadow by a short light-march toward the sun. Accumulate the
	// cloud body along a few steps and apply Beer's law: the sun-facing flank of
	// each heap stays bright while light falls off smoothly deeper into its body.
	// Because the march direction comes from the sun, the bright side tracks the
	// sun across the day. Unlike a local-gradient normal this leaves no dark
	// emboss rim, and unlike a single tap it is a smooth gradient, not two tones.
	vec2 sun_xz = vec2(sun_direction.x, -sun_direction.z);
	vec2 light_dir = length(sun_xz) > 0.001 ? normalize(sun_xz) : vec2(1.0, 0.0);
	float march = cloud_bulk(uv + light_dir * 0.02, cover)
		+ cloud_bulk(uv + light_dir * 0.05, cover) * 0.7
		+ cloud_bulk(uv + light_dir * 0.09, cover) * 0.45
		+ cloud_bulk(uv + light_dir * 0.15, cover) * 0.25;
	float self_shadow = exp(-march * 1.25);
	// Ambient fill stops shadowed sides crushing to black; storm cells sit darker.
	float ambient = mix(0.46, 0.22, local_storm);
	float light = mix(ambient, 1.0, self_shadow);

	// Anvil crown / silver lining: thin sun-facing edges flare, hardest on storms.
	float edge = clamp(density * (1.0 - density) * 4.0, 0.0, 1.0);
	float sun_facing = max(dot(normalize(dir), sun_direction), 0.0);
	light = clamp(light + edge * pow(sun_facing, 3.0) * (0.35 + 0.65 * local_storm), 0.0, 1.0);

	return vec3(density, light, local_storm);
}


// Distant rain: soft vertical curtains that hang *below* a raining cell, drifting
// with the wind. Returns a 0..1 veil strength that later greys (and, when lit,
// brightens) the sky. Rain falls beneath its cloud, so the curtain is anchored by
// marching a little way up this same bearing and only appears where a storm cell
// actually sits overhead — never floating in open sky the way a fixed horizon
// band did. The caller also keeps it out of the opaque cloud body itself.
float rain_shafts(vec3 dir) {
	if (storm_intensity < 0.05 || dir.y > 0.6 || dir.y < 0.01) {
		return 0.0;
	}
	// March up the bearing: is there a heavy raining cell above this ray? Keeping
	// x and z fixed while raising y and renormalising holds the azimuth, so this
	// samples the cloud directly overhead, which is what the rain hangs from.
	float source = 0.0;
	for (int i = 1; i <= 3; i++) {
		vec3 up = normalize(vec3(dir.x, dir.y + float(i) * 0.13, dir.z));
		vec2 up_uv = up.xz / (up.y + 0.26) * 0.30 + cloud_offset;
		float ls = local_storm_at(up_uv);
		float cover = clamp(cloud_coverage + ls * 0.5, 0.0, 1.0);
		source = max(source, smoothstep(0.45, 0.95, ls) * cloud_bulk(up_uv, cover));
	}
	if (source < 0.02) {
		return 0.0;
	}
	// Vertical streaks, drifting with the wind, fading out at the very horizon.
	float azimuth = atan(dir.x, -dir.z);
	vec2 suv = vec2(azimuth * 2.4 + cloud_offset.x * 8.0, dir.y * 1.6 - cloud_detail_offset.y * 2.0);
	float streak = texture(cloud_noise, vec2(suv.x * 1.3, suv.y * 0.35)).r;
	float fall = texture(cloud_noise, vec2(suv.x * 3.1, suv.y * 0.18) + vec2(0.4, 0.0)).r;
	streak = smoothstep(0.44, 0.85, streak * 0.6 + fall * 0.4);
	float hang = smoothstep(0.01, 0.09, dir.y);
	return streak * source * hang;
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


void sky() {
	vec3 dir = EYEDIR;
	float height = dir.y;

	vec3 top = mix(night_top_color.rgb, day_top_color.rgb, day_blend);
	vec3 horizon = mix(night_horizon_color.rgb, day_horizon_color.rgb, day_blend);
	// Warm dusk/dawn band hugging the horizon on the sun side.
	float sun_amount = max(dot(dir, sun_direction), 0.0);
	horizon = mix(horizon, sunset_color.rgb, sunset_factor * pow(sun_amount, 2.0) * 0.8);

	vec3 color = mix(horizon, top, pow(clamp(height, 0.0, 1.0), 0.55));
	// Below the horizon fade into darker haze so the map edge reads as ground fog.
	color = mix(color, horizon * 0.55, clamp(-height * 3.0, 0.0, 1.0));

	vec3 cloud_sample = cloud_field(dir);
	float clouds = cloud_sample.x;
	float cloud_light = cloud_sample.y;
	float local_storm = cloud_sample.z;

	// Real stars fade with twilight and are occluded by the procedural weather.
	// Nearest sampling keeps each catalog texel crisp in the sky dome.
	vec3 stars = texture(star_map, equatorial_uv(dir)).rgb;
	float star_visibility = pow(1.0 - day_blend, 3.0) * smoothstep(-0.01, 0.05, height);
	color += stars * star_visibility * (1.0 - clouds) * 0.32;

	// Sun disk plus halo, hidden once the sun dips below the horizon.
	float sun_visibility = smoothstep(-0.05, 0.05, sun_direction.y);
	vec3 sun_tint = mix(sun_color.rgb, sunset_color.rgb, sunset_factor * 0.55);
	float disk = smoothstep(0.99930, 0.99972, sun_amount);
	float halo = pow(sun_amount, 90.0) * 0.4;
	color += sun_tint * (disk * 2.4 + halo) * sun_visibility * (1.0 - clouds * 0.95);

	// Moon: a softly glowing sphere with a stable procedural albedo map. Project
	// the disk onto a local tangent plane so maria and craters follow its surface
	// instead of looking like screen-space noise pasted over a white circle.
	float moon_dot = dot(dir, moon_direction);
	float moon_radius = 0.031;
	float moon_edge = cos(moon_radius);
	float moon_disk = smoothstep(moon_edge - 0.00006, moon_edge + 0.000025, moon_dot);
	vec3 moon_up_axis = abs(moon_direction.y) > 0.96 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	vec3 moon_right = normalize(cross(moon_up_axis, moon_direction));
	vec3 moon_up = normalize(cross(moon_direction, moon_right));
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
	float moon_lit = max(dot(moon_normal, moon_light), 0.0);
	// Soft earthshine on the night side; stronger near new moon when sunlight
	// leaves only the Earth-lit face visible from Reval.
	float earthshine = 0.045 * (0.5 + 0.5 * cos(moon_phase * TAU));
	float moon_lighting = max(moon_lit, earthshine);
	float moon_limb = 0.72 + 0.28 * moon_z;
	float maria = 0.0;
	maria += (1.0 - smoothstep(0.04, 0.34, length(moon_uv - vec2(-0.28, 0.20)))) * 0.24;
	maria += (1.0 - smoothstep(0.03, 0.29, length(moon_uv - vec2(0.24, 0.12)))) * 0.18;
	maria += (1.0 - smoothstep(0.03, 0.24, length(moon_uv - vec2(-0.02, -0.30)))) * 0.15;
	maria += (1.0 - smoothstep(0.02, 0.17, length(moon_uv - vec2(0.42, -0.22)))) * 0.10;
	float craters = 0.0;
	craters += (1.0 - smoothstep(0.07, 0.10, abs(length(moon_uv - vec2(-0.42, -0.20)) - 0.10))) * 0.14;
	craters += (1.0 - smoothstep(0.045, 0.065, abs(length(moon_uv - vec2(0.18, 0.42)) - 0.065))) * 0.10;
	craters += (1.0 - smoothstep(0.028, 0.045, abs(length(moon_uv - vec2(0.47, 0.28)) - 0.045))) * 0.08;
	float lunar_noise = texture(cloud_noise, moon_uv * 0.17 + vec2(0.31, 0.73)).r;
	float lunar_albedo = clamp((1.0 - maria - craters) * mix(0.90, 1.04, lunar_noise), 0.55, 1.0);
	float moon_visibility = smoothstep(-0.04, 0.03, moon_direction.y) * (1.0 - clouds);
	color += moon_color.rgb * lunar_albedo * moon_lighting * moon_limb * moon_disk * moon_visibility * 0.90;
	float moon_halo = smoothstep(cos(moon_radius * 4.0), moon_edge, moon_dot) * (1.0 - moon_disk);
	color += moon_color.rgb * moon_halo * moon_visibility * moon_lighting * 0.08;

	// Cloud layer. The lit tone carries the sun's own colour and warms toward the
	// horizon, so clouds are gilded at dawn/dusk and cool white at noon; the
	// bright flank (from the light-march in cloud_light) tracks the sun's bearing.
	vec3 sun_lit = mix(vec3(1.0, 1.0, 1.0), sun_color.rgb, 0.3);
	sun_lit = mix(sun_lit, sunset_color.rgb * 1.2, sunset_factor * 0.75);
	vec3 cloud_top = mix(vec3(0.09, 0.11, 0.16), sun_lit, day_blend);
	// Shadowed sides are darker, cooler, and bluer; storm cells darken further
	// still, so a heavy raining cell reads dark even in an otherwise bright sky.
	vec3 cloud_shadow = cloud_top * mix(0.6, 0.26, local_storm) * vec3(0.88, 0.95, 1.12);
	vec3 cloud_col = mix(cloud_shadow, cloud_top, cloud_light);
	// Warm directional rim where a lit cloud faces the low sun (sunrise/sunset).
	vec3 sun_glow = mix(sun_color.rgb, sunset_color.rgb, sunset_factor);
	cloud_col += sun_glow * pow(sun_amount, 6.0) * cloud_light * (0.35 + 0.9 * sunset_factor) * sun_visibility;
	// Overcast fronts flatten the heaps toward a dim, cool, uniform sheet; storm
	// decks go darker and a touch bluer than a plain grey overcast.
	vec3 overcast = cloud_top * mix(0.5, 0.4, local_storm) * vec3(0.94, 0.98, 1.06);
	cloud_col = mix(cloud_col, overcast, cloud_darken * 0.72);
	color = mix(color, cloud_col, clouds * 0.96);

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

	// Lightning: a strike lights its own cell and rains, glows the nearby sky, and
	// throws a faint flicker across the whole dome. Localised to lightning_dir so
	// a single thundercloud flashes on its side of the sky, not everywhere.
	if (lightning > 0.001) {
		vec2 strike_ground = normalize(vec2(dir.x, -dir.z) + vec2(0.0001));
		float aim = max(dot(strike_ground, lightning_dir), 0.0);
		float near_strike = pow(aim, 3.0) * smoothstep(0.75, 0.0, dir.y);
		vec3 flash_col = vec3(0.90, 0.94, 1.10);
		color += flash_col * lightning * (near_strike * (0.5 + clouds * 1.6 + shafts * 1.3) + 0.03);
	}

	COLOR = color;
}
