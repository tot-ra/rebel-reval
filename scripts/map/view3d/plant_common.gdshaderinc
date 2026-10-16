// R-2131 (FLORA-11): one material response for low vegetation (forbs now;
// grass and crops adopt it by including this file). Trees keep their own
// canopy shader (R-1211) and ground tint stays in R-1192 - not duplicated here.
//
// State comes from two shader globals (no sampler, no instance uniform, so the
// R-1690 limits are untouched); PlantMaterial (plant_material.gd) is the only
// writer. Per-plant variety comes from the world position hash.
//   plant_weather_g: x wetness (rain + puddles), y frost/dew, z snow cover, w drought
//   plant_season_g:  x autumn progress 0..1 (before the per-group offset)
// cloud_sun_dir is the shared sun direction (sky_weather_3d.gd).

global uniform vec4 plant_weather_g;
global uniform vec4 plant_season_g;
global uniform vec3 cloud_sun_dir;

// Per-material, set once per plant group: when its autumn starts relative to
// the shared curve (grasses turn early, late forbs hold green) and its colours.
uniform float autumn_offset = 0.0;
uniform vec3 autumn_tint : source_color = vec3(0.78, 0.58, 0.20);
uniform vec3 dry_tint : source_color = vec3(0.62, 0.55, 0.32);

float plant_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Autumn yellowing then browning, shifted per instance so a meadow does not
// turn in one step (also the per-instance age variation of R-1625).
float plant_autumn(vec2 seed_pos) {
	float age = plant_hash(floor(seed_pos * 0.5));
	return clamp(plant_season_g.x * 1.5 + autumn_offset - age * 0.45, 0.0, 1.0);
}

// Returns the seasonal albedo; `snow_up` is the top-facing mask (0..1).
vec3 plant_albedo(vec3 base, vec2 seed_pos, float snow_up) {
	float autumn = plant_autumn(seed_pos);
	float luma = dot(base, vec3(0.2126, 0.7152, 0.0722));
	vec3 aut = mix(autumn_tint, dry_tint * 0.7, smoothstep(0.6, 1.0, autumn));
	vec3 col = mix(base, aut * (0.55 + luma * 1.4), autumn);
	// Dry summer: straw-coloured and a little duller.
	col = mix(col, dry_tint * (0.5 + luma * 1.2), plant_weather_g.w * 0.55);
	// Rain darkens the leaf.
	col *= mix(1.0, 0.72, plant_weather_g.x);
	// Dew/frost speckle: fine grains, whiter with cold, only on upward faces.
	float grain = plant_hash(floor(seed_pos * 90.0));
	float frost = plant_weather_g.y * smoothstep(0.45, 0.8, grain) * snow_up;
	col = mix(col, vec3(0.86, 0.9, 0.94), frost * 0.7);
	// Snow dusting settles on top-facing surfaces only.
	float dust = plant_weather_g.z * smoothstep(0.35, 0.8, snow_up);
	return mix(col, vec3(0.9, 0.93, 0.97), dust * 0.85);
}

// Backlight that grows as the sun drops toward the horizon and fades when the
// leaf is wet-flat, dried out or covered; autumn leaves glow warmer.
vec3 plant_backlight(vec3 albedo, float transmitted, float autumn) {
	float low_sun = 1.0 - clamp(abs(cloud_sun_dir.y), 0.0, 1.0);
	float gain = (0.45 + 0.9 * low_sun) * (1.0 - plant_weather_g.z * 0.8) * (1.0 - plant_weather_g.w * 0.4);
	return albedo * transmitted * gain * (1.0 + autumn * 0.25);
}

// Wet leaves get a sheen; snow and frost are matte.
float plant_roughness(float dry_roughness) {
	return mix(dry_roughness, 0.38, plant_weather_g.x * (1.0 - plant_weather_g.z));
}

float plant_specular(float dry_specular) {
	return mix(dry_specular, 0.5, plant_weather_g.x * (1.0 - plant_weather_g.z));
}
