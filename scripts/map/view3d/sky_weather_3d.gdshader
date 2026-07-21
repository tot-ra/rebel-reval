shader_type sky;

// Sky dome for the 3D map view (ADR 0007 view layer): day/night gradient,
// Hipparcos stars positioned for Reval in 1343, sun disk with halo, moon,
// procedural clouds, and a warm horizon band for sunrise/sunset. All dynamics
// are script-driven uniforms (no TIME), so the sky stays deterministic and
// testable like the rest of the view.

uniform vec4 day_top_color : source_color = vec4(0.24, 0.51, 0.88, 1.0);
uniform vec4 day_horizon_color : source_color = vec4(0.62, 0.78, 0.93, 1.0);
uniform vec4 night_top_color : source_color = vec4(0.010, 0.016, 0.045, 1.0);
uniform vec4 night_horizon_color : source_color = vec4(0.045, 0.060, 0.105, 1.0);
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

uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.22;
uniform float cloud_darken : hint_range(0.0, 1.0) = 0.0;
// Primary bank drift. Detail offset advances faster so edges churn while
// whole cloud masses still cross the dome from one horizon to the other.
uniform vec2 cloud_offset = vec2(0.0);
uniform vec2 cloud_detail_offset = vec2(0.0);
// Domain-warp strength. Clear weather keeps mild chaos; storms tear harder.
uniform float cloud_chaos : hint_range(0.0, 1.0) = 0.35;
// Cumulonimbus development: 0 = fair-weather heaps, 1 = towering anvil storm.
// Drives the horizon squall wall, darkened bases, and sunlit anvil crowns.
uniform float storm_intensity : hint_range(0.0, 1.0) = 0.0;
// Prevailing wind on the ground plane, used to comb cirrus streaks and to lean
// the storm wall into the upwind quarter so the front reads as approaching.
uniform vec2 wind_dir = vec2(0.928, 0.371);

// Hipparcos stars live in equatorial coordinates in this nearest-filtered map.
// The observer transform below turns each sky ray into right ascension and
// declination for Reval's latitude and the canonical 23 April 1343 sidereal sky.
uniform sampler2D star_map : filter_nearest, repeat_enable;
uniform float observer_latitude = 1.0371;
uniform float sidereal_angle = 3.8101;


// Layered cloud field sampled per view ray. Returns:
//   x = opacity of cloud along this ray (0..1),
//   y = sunlit "crown" amount for anvil tops and silver linings (0..1).
// Three strata are projected onto overhead planes at different virtual
// altitudes so they parallax against each other instead of reading as one
// fluid sheet: low storm wall, mid cumulus banks, and high cirrus streaks.
vec2 cloud_field(vec3 dir) {
	if (dir.y < 0.02) {
		return vec2(0.0);
	}
	float horizon_fade = smoothstep(0.02, 0.24, dir.y);

	// A storm stacks a dark wall of cloud toward the horizon rather than thinning
	// out like fair-weather cumulus, and leans into the upwind quarter so the
	// squall line reads as marching in. This raises the effective coverage the
	// cumulus thresholds see, filling the lower sky as the anvil approaches.
	vec2 ground = normalize(vec2(dir.x, -dir.z) + vec2(0.0001));
	float upwind = 0.5 + 0.5 * dot(ground, -wind_dir);
	float storm_wall = storm_intensity * smoothstep(0.55, 0.05, dir.y) * mix(0.55, 1.0, upwind);
	float cover = clamp(cloud_coverage + storm_wall * 0.4, 0.0, 1.0);

	// --- Mid layer: puffy cumulus banks (the main body) ---
	// Planar projection of the view ray onto an overhead cloud layer.
	vec2 uv = dir.xz / (dir.y + 0.22) * 0.32 + cloud_offset;
	// WHY: domain warp breaks the regular FBM lattice so banks look like
	// torn weather fronts instead of a uniform noise threshold across the sky.
	vec2 warp_sample = texture(cloud_noise, uv * 0.62 + cloud_detail_offset * 0.45).rg;
	vec2 warped_uv = uv + (warp_sample - vec2(0.5)) * (0.18 + cloud_chaos * 0.42);

	// Large-scale bank mask: open blue gaps between discrete cloud masses so
	// "clear" and mid coverage read as partly cloudy, not a thin haze.
	float banks = texture(cloud_noise, warped_uv * 0.34 + cloud_offset * 0.28).r;
	float bank_edge = mix(0.62, 0.12, cover);
	float bank_mask = smoothstep(bank_edge, bank_edge + 0.24, banks);

	float base = texture(cloud_noise, warped_uv * 1.05).r;
	float detail = texture(
		cloud_noise,
		warped_uv * 3.1 + vec2(0.37, 0.71) + cloud_detail_offset
	).r;
	float filament = texture(
		cloud_noise,
		warped_uv * 5.4 + vec2(0.81, 0.19) - cloud_detail_offset * 0.65
	).r;
	// Ridged octave: 1 - |2n-1| folds the noise into cauliflower billows so heap
	// tops bulge instead of smearing into the fluid look they had before.
	float billow = 1.0 - abs(2.0 * detail - 1.0);
	float body = base * 0.5 + detail * 0.22 + billow * 0.18 + filament * 0.10;
	float body_edge = mix(0.6, 0.12, cover);
	float cumulus = smoothstep(body_edge, body_edge + 0.26, body) * bank_mask;
	// Sharpen: crisp puff edges at low coverage, softening as the sky closes over.
	cumulus = pow(cumulus, mix(1.7, 0.85, cover));

	// --- High layer: thin cirrus, combed into streaks along the wind ---
	// A farther plane (smaller y bias) compresses it toward the horizon and it
	// drifts slower, so it parallaxes behind the cumulus. Sampling low-frequency
	// along the wind and high-frequency across it yields long parallel filaments.
	vec2 high_uv = dir.xz / (dir.y + 0.05) * 0.55 + cloud_detail_offset * 0.3;
	vec2 wind_perp = vec2(-wind_dir.y, wind_dir.x);
	float along = dot(high_uv, wind_dir);
	float across = dot(high_uv, wind_perp);
	float cirrus_noise = texture(cloud_noise, vec2(along * 0.4, across * 2.4)).r;
	float cirrus = smoothstep(0.58, 0.9, cirrus_noise)
		* smoothstep(0.32, 0.68, cloud_coverage)
		* (1.0 - storm_intensity * 0.6) * 0.55;

	float density = max(cumulus, cirrus) * horizon_fade;

	// Anvil crown / silver lining: cloud edges facing the sun catch light. The
	// effect peaks where the cloud is thinning (density near 0.5) and is far
	// stronger on towering storm cells, giving the classic bright anvil rim.
	float edge = clamp(density * (1.0 - density) * 4.0, 0.0, 1.0);
	float sun_facing = max(dot(normalize(dir), sun_direction), 0.0);
	float crown = edge * pow(sun_facing, 1.5) * (0.3 + 0.7 * storm_intensity);

	return vec2(density, crown);
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

	vec2 cloud_sample = cloud_field(dir);
	float clouds = cloud_sample.x;
	float cloud_crown = cloud_sample.y;

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

	// Cloud layer: bright by day, dark at night, warm around the low sun.
	vec3 cloud_base = mix(vec3(0.055, 0.065, 0.095), vec3(1.0, 1.0, 1.0), day_blend);
	cloud_base = mix(cloud_base, sunset_color.rgb * 1.05, sunset_factor * pow(sun_amount, 2.0) * 0.75);
	// Storm bases are far darker and flatter than a fair-weather cloud underside.
	float base_darkness = mix(0.42, 0.18, storm_intensity);
	vec3 cloud_shaded = mix(cloud_base, cloud_base * base_darkness, cloud_darken);
	// Sunlit anvil crown / silver lining rimming the cloud toward the sun.
	vec3 crown_color = mix(cloud_base, sun_color.rgb * 1.25, 0.7);
	cloud_shaded = mix(cloud_shaded, crown_color, clamp(cloud_crown, 0.0, 1.0) * sun_visibility);
	color = mix(color, cloud_shaded, clouds * 0.94);

	COLOR = color;
}
