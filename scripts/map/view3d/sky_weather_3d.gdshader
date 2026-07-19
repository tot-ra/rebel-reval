shader_type sky;

// Sky dome for the 3D map view (ADR 0007 view layer): day/night gradient,
// sun disk with halo, moon, procedural cloud layer, and a warm horizon band
// for sunrise/sunset. All dynamics are script-driven uniforms (no TIME), so
// the sky stays deterministic and testable like the rest of the view.

uniform vec4 day_top_color : source_color = vec4(0.24, 0.51, 0.88, 1.0);
uniform vec4 day_horizon_color : source_color = vec4(0.62, 0.78, 0.93, 1.0);
uniform vec4 night_top_color : source_color = vec4(0.010, 0.016, 0.045, 1.0);
uniform vec4 night_horizon_color : source_color = vec4(0.045, 0.060, 0.105, 1.0);
uniform vec4 sunset_color : source_color = vec4(0.98, 0.45, 0.18, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.92, 0.74, 1.0);
uniform vec4 moon_color : source_color = vec4(0.78, 0.84, 0.95, 1.0);

// 0 = midnight, 1 = noon (matches DayNightCycle.day_blend).
uniform float day_blend : hint_range(0.0, 1.0) = 1.0;
// 1 while the sun sits on the horizon, 0 once it climbs or fully sets.
uniform float sunset_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, 1.0, 0.0);

uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.22;
uniform float cloud_darken : hint_range(0.0, 1.0) = 0.0;
uniform vec2 cloud_offset = vec2(0.0);


float cloud_density(vec3 dir) {
	if (dir.y < 0.02) {
		return 0.0;
	}
	// Planar projection of the view ray onto an overhead cloud layer.
	vec2 uv = dir.xz / (dir.y + 0.22) * 0.32 + cloud_offset;
	float base = texture(cloud_noise, uv).r;
	float detail = texture(cloud_noise, uv * 2.7 + vec2(0.37, 0.71)).r;
	float noise_value = base * 0.68 + detail * 0.32;
	float horizon_fade = smoothstep(0.02, 0.28, dir.y);
	float edge = 1.0 - cloud_coverage;
	return smoothstep(edge, edge + 0.28, noise_value) * horizon_fade;
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

	float clouds = cloud_density(dir);

	// Sun disk plus halo, hidden once the sun dips below the horizon.
	float sun_visibility = smoothstep(-0.05, 0.05, sun_direction.y);
	vec3 sun_tint = mix(sun_color.rgb, sunset_color.rgb, sunset_factor * 0.55);
	float disk = smoothstep(0.99930, 0.99972, sun_amount);
	float halo = pow(sun_amount, 90.0) * 0.4;
	color += sun_tint * (disk * 2.4 + halo) * sun_visibility * (1.0 - clouds * 0.95);

	// Moon: simple pale disk shown while the night blend dominates.
	float moon_amount = max(dot(dir, moon_direction), 0.0);
	float moon_disk = smoothstep(0.99955, 0.99985, moon_amount);
	color += moon_color.rgb * moon_disk * (1.0 - day_blend) * 1.6 * (1.0 - clouds);

	// Cloud layer: bright by day, dark at night, warm around the low sun.
	vec3 cloud_base = mix(vec3(0.055, 0.065, 0.095), vec3(1.0, 1.0, 1.0), day_blend);
	cloud_base = mix(cloud_base, sunset_color.rgb * 1.05, sunset_factor * pow(sun_amount, 2.0) * 0.75);
	vec3 cloud_shaded = mix(cloud_base, cloud_base * 0.42, cloud_darken);
	color = mix(color, cloud_shaded, clouds * 0.92);

	COLOR = color;
}
