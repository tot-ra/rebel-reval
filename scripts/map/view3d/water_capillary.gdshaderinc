// Shared, band-limited wind ripples for shallow water and puddles. No textures,
// no simulation grid. Wavelengths are metres, slopes are dimensionless.
global uniform vec2 wind_dir_g;
global uniform float wind_strength_g;

vec2 water_wind_slope(vec2 xz, float t, float footprint) {
	vec2 w = length(wind_dir_g) > 0.001 ? normalize(wind_dir_g) : vec2(1.0, 0.0);
	vec2 cross_wind = vec2(-w.y, w.x);
	float strength = clamp(wind_strength_g, 0.0, 1.0);
	float gust = 0.72 + 0.28 * sin(dot(xz, w) * 0.13 - t * 0.8);
	// Fade each frequency before it becomes subpixel; distant pools stay stable.
	float a = 1.0 - smoothstep(0.025, 0.10, footprint);
	float b = 1.0 - smoothstep(0.012, 0.05, footprint);
	vec2 d = normalize(w * 0.8 + cross_wind * 0.6);
	return strength * gust * (
		w * cos(dot(xz, w) * 22.0 - t * 5.3) * 0.065 * a
		+ d * cos(dot(xz, d) * 41.0 - t * 8.1) * 0.035 * b
	);
}
