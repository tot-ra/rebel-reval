class_name SkyWeatherQuality
extends RefCounted

## Renderer-cost quality tiers for the sky/weather view layer. Weather state,
## profile transitions, cloud offsets, and seeded event scheduling stay identical
## across tiers; only shader and particle budgets change.

const SKY_RESOURCES := preload("res://scripts/map/view3d/sky_weather_resources.gd")
const SkyAtmosphereLutScript := preload("res://scripts/map/view3d/sky_atmosphere_lut.gd")

## Quality tiers change renderer cost only. Weather state, profile transitions, cloud
## offsets, and seeded event scheduling stay identical across tiers.
const QUALITY_MINIMUM: StringName = &"minimum"
const QUALITY_RECOMMENDED: StringName = &"recommended"
## R-1873: recommended plus the ray-marched cloud slab; only the high graphics preset.
const QUALITY_HIGH: StringName = &"high"
const QUALITY_AUTO: StringName = &"auto"
const QUALITY_TIER_IDS: Array[StringName] = [QUALITY_MINIMUM, QUALITY_RECOMMENDED, QUALITY_HIGH]
const QUALITY_TIERS: Dictionary = {
	QUALITY_MINIMUM: {
		"cloud_noise_resolution": SKY_RESOURCES.CLOUD_NOISE_RESOLUTION_MINIMUM,
		"cloud_shape_resolution": SKY_RESOURCES.CLOUD_SHAPE_RESOLUTION_MINIMUM,
		"cloud_shadow_samples": 2,
		# R-1768: flat dome deck (0); recommended draws the lit 2.5D deck (1);
		# R-1873: high draws the ray-marched slab (2).
		"cloud_deck_mode": 0,
		# R-1873: steps of the ray-marched slab; 0 = no slab pass.
		"cloud_slab_steps": 0,
		# WS-12 ground pass. Sky raymarch keeps 2 so the dome stays identical.
		"cloud_shadow_ground_samples": 1,
		"cloud_shadow_enabled": true,
		"rain_shaft_samples": 3,
		"rain_particles": SKY_RESOURCES.RAIN_PARTICLES_MINIMUM,
		# This scales rendered flash intensity, not deterministic strike timing.
		"lightning_density": 0.65,
		"fog_quality": 0.65,
		"fallback_behavior": &"gradient_only_if_resource_missing",
		"frame_time_budget_ms": 1.50,
		"memory_budget_mib": 8.0,
		"particle_budget": 700,
		"shader_sample_budget": 80,
		# WS-04: C2 slopes off; the procedural detail normal covers the ripples.
		"ocean_fft_cascades": 2,
		# WS-10: half-size sky-view LUT rendered every second frame.
		"sky_lut_size": SkyAtmosphereLutScript.SIZE_MINIMUM,
		"sky_lut_every_n_frames": 2,
		# WS-15: interactive ripple sim off; water keeps the FFT and detail normals.
		"ripple_sim_size": 0,
		# R-1400 discrete clouds: half the volume steps, one sun sample, no sky beams.
		"cloud_cell_steps": 6,
		"cloud_cell_noise_size": 32,
		"cloud_cell_fine_steps": 5,
		"cloud_cell_light_samples": 1,
		"cloud_cell_ray_samples": 0,
	},
	QUALITY_RECOMMENDED: {
		"cloud_noise_resolution": SKY_RESOURCES.CLOUD_NOISE_RESOLUTION_RECOMMENDED,
		"cloud_shape_resolution": SKY_RESOURCES.CLOUD_SHAPE_RESOLUTION_RECOMMENDED,
		"cloud_shadow_samples": 4,
		"cloud_deck_mode": 1,
		"cloud_slab_steps": 0,
		"cloud_shadow_ground_samples": 3,
		"cloud_shadow_enabled": true,
		"rain_shaft_samples": 6,
		"rain_particles": SKY_RESOURCES.RAIN_PARTICLES_RECOMMENDED,
		"lightning_density": 1.0,
		"fog_quality": 1.0,
		"fallback_behavior": &"gradient_only_if_resource_missing",
		"frame_time_budget_ms": 2.50,
		"memory_budget_mib": 24.0,
		"particle_budget": 2200,
		"shader_sample_budget": 140,
		"ocean_fft_cascades": 3,
		# WS-10: the compressed day moves the sun ~6 deg/s, so the LUT renders every frame.
		"sky_lut_size": SkyAtmosphereLutScript.SIZE_RECOMMENDED,
		"sky_lut_every_n_frames": 1,
		# WS-15: 256^2 texels over the 64 x 64-unit ripple window (0.25 units per texel).
		"ripple_sim_size": 256,
		"cloud_cell_steps": 12,
		"cloud_cell_noise_size": 48,
		"cloud_cell_fine_steps": 10,
		"cloud_cell_light_samples": 2,
		"cloud_cell_ray_samples": 8,
	},
	# R-1873: recommended plus the ray-marched cumulus slab (CloudSlabEffect). Every
	# other key matches recommended so only the dome deck changes cost.
	QUALITY_HIGH: {
		"cloud_noise_resolution": SKY_RESOURCES.CLOUD_NOISE_RESOLUTION_RECOMMENDED,
		"cloud_shape_resolution": SKY_RESOURCES.CLOUD_SHAPE_RESOLUTION_RECOMMENDED,
		"cloud_shadow_samples": 4,
		"cloud_deck_mode": 2,
		"cloud_slab_steps": 32,
		"cloud_shadow_ground_samples": 3,
		"cloud_shadow_enabled": true,
		"rain_shaft_samples": 6,
		"rain_particles": SKY_RESOURCES.RAIN_PARTICLES_RECOMMENDED,
		"lightning_density": 1.0,
		"fog_quality": 1.0,
		"fallback_behavior": &"gradient_only_if_resource_missing",
		# Recommended budget plus the <= 2 ms slab pass at 1280x720.
		"frame_time_budget_ms": 4.50,
		# Three 16-bit RGBA slab targets at half resolution (~5.3 MiB at 1080p).
		"memory_budget_mib": 30.0,
		"particle_budget": 2200,
		"shader_sample_budget": 140,
		"ocean_fft_cascades": 3,
		"sky_lut_size": SkyAtmosphereLutScript.SIZE_RECOMMENDED,
		"sky_lut_every_n_frames": 1,
		"ripple_sim_size": 256,
		"cloud_cell_steps": 12,
		"cloud_cell_noise_size": 48,
		"cloud_cell_fine_steps": 10,
		"cloud_cell_light_samples": 2,
		"cloud_cell_ray_samples": 8,
	},
}




## Maps user-facing tier requests to a named minimum/recommended row. Auto and
## unknown values fall back to recommended so headless tests and save payloads
## stay deterministic until a runtime probe chooses otherwise.
static func resolve_quality_tier(requested: Variant) -> StringName:
	var normalized := StringName(String(requested))
	if normalized == QUALITY_AUTO:
		return QUALITY_RECOMMENDED
	if normalized in QUALITY_TIERS:
		return normalized
	return QUALITY_RECOMMENDED


static func quality_settings(requested: Variant) -> Dictionary:
	var tier := resolve_quality_tier(requested)
	return (QUALITY_TIERS[tier] as Dictionary).duplicate(true)
