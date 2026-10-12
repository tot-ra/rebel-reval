class_name GraphicsPresets
extends RefCounted

## One row of renderer costs per user quality (low / mid / high). Every consumer reads
## this table so the three tiers move together: viewport scale, shadow atlas, texture
## filtering, the sky/weather/water tier (SkyWeatherQuality) and the god-ray march.
## Measured on the continuous city in docs/PERFORMANCE_REPORT.md ("Quality tiers").
##
## Targets: low = Switch 1 class and Steam Deck, mid = Apple M5 Pro class, high = discrete
## GPUs with 16 GB of video memory. Gameplay, weather state and seeded events are
## identical on every row; only renderer cost changes.

const LOW := "low"
const MID := "mid"
const HIGH := "high"

const PRESETS := {
	LOW: {
		# The 3D scene renders at this fraction of the window per axis and is upscaled.
		"render_scale": 0.67,
		"shadow_atlas_size": 2048,
		"shadow_filter_quality": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"anisotropy": Viewport.ANISOTROPY_2X,
		"sky_tier": &"minimum",
		# God-ray march: samples along the view ray, toward the sun, and far to the horizon.
		"god_ray_view_steps": 6,
		"god_ray_shadow_steps": 3,
		"god_ray_far_steps": 4,
		"god_ray_cloud_stride": 3,
		# Fractions of CityTreeLod's near / macro crown radii (0 = no macro crowns).
		# Sun shadow cascades: every split draws the casters again (a forest paid 56 ms for four).
		"sun_shadow_mode": DirectionalLight3D.SHADOW_ORTHOGONAL,
		# Dome cloud march (SkyWeather3D.set_cell_march): volume steps, fine steps, sun samples,
		# ray samples. Any ray sample count above 0 doubles the dome's sky-beam march (14 steps
		# through every cell), which cost ~25 ms looking at a cloudy sky: only 0 is affordable.
		"sky_cell_steps": 6,
		"sky_cell_fine_steps": 5,
		"sky_cell_light_samples": 1,
		"sky_cell_ray_samples": 0,
		"tree_near_scale": 0.55,
		"tree_macro_scale": 0.0,
		# R-1748 screen-space AO taps per ring (contact ~0.35 m, area ~2.4 m); 0 + 0 = pass off.
		# Sun angular diameter in degrees: wider = softer PCSS penumbra, dearer blocker search.
		"ao_contact_samples": 0,
		"ao_area_samples": 0,
		"sun_angular_distance": 0.5,
	},
	MID: {
		"render_scale": 0.85,
		"shadow_atlas_size": 4096,
		"shadow_filter_quality": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"anisotropy": Viewport.ANISOTROPY_4X,
		"sky_tier": &"recommended",
		"god_ray_view_steps": 8,
		"god_ray_shadow_steps": 4,
		"god_ray_far_steps": 6,
		"god_ray_cloud_stride": 3,
		"sun_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		"sky_cell_steps": 6,
		"sky_cell_fine_steps": 5,
		"sky_cell_light_samples": 1,
		"sky_cell_ray_samples": 0,
		"tree_near_scale": 0.7,
		"tree_macro_scale": 0.2,
		"ao_contact_samples": 4,
		"ao_area_samples": 4,
		"sun_angular_distance": 1.0,
	},
	HIGH: {
		"render_scale": 1.0,
		# project.godot ships 8192 / SOFT_HIGH (4); high must not exceed what the project looked like.
		"shadow_atlas_size": 8192,
		"shadow_filter_quality": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		"anisotropy": Viewport.ANISOTROPY_4X,
		# R-1873: the ray-marched cumulus slab (~0.4-0.7 ms at 1280x720 on M-series).
		"sky_tier": &"high",
		"god_ray_view_steps": 12,
		"god_ray_shadow_steps": 6,
		"god_ray_far_steps": 8,
		"god_ray_cloud_stride": 2,
		"sun_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
		"sky_cell_steps": 10,
		"sky_cell_fine_steps": 8,
		"sky_cell_light_samples": 2,
		"sky_cell_ray_samples": 0,
		"tree_near_scale": 0.8,
		"tree_macro_scale": 0.25,
		"ao_contact_samples": 6,
		"ao_area_samples": 6,
		"sun_angular_distance": 1.5,
	},
}


## The row for `quality`; unknown names fall back to mid, like GraphicsSettings.normalize().
static func row(quality: String) -> Dictionary:
	return PRESETS.get(quality, PRESETS[MID])


## Applies the viewport and rendering-server parts to the root window. The sky tier and
## god-ray steps are read by their own owners (city view, GodRayPass) through `row()`.
static func apply_to(window: Window, quality: String) -> void:
	var r := row(quality)
	var scale := float(r["render_scale"])
	# FSR 1.0 exists only on Forward+; the Mobile renderer (the project default) upscales bilinearly.
	var fsr := scale < 1.0 and RenderingServer.get_current_rendering_method() == "forward_plus"
	window.scaling_3d_mode = (
		Viewport.SCALING_3D_MODE_FSR if fsr else Viewport.SCALING_3D_MODE_BILINEAR
	)
	window.scaling_3d_scale = scale
	window.anisotropic_filtering_level = r["anisotropy"]
	# The atlas is the largest single GPU allocation of the shadow pass; resizing frees it.
	RenderingServer.directional_shadow_atlas_set_size(int(r["shadow_atlas_size"]), false)
	RenderingServer.directional_soft_shadow_filter_set_quality(r["shadow_filter_quality"])


## The cascade count and shadow softness of the sun follow the quality (a light, not a
## window setting).
static func apply_to_sun(sun: DirectionalLight3D, quality: String) -> void:
	var mode: DirectionalLight3D.ShadowMode = row(quality)["sun_shadow_mode"]
	if sun != null and sun.directional_shadow_mode != mode:
		sun.directional_shadow_mode = mode
	if sun != null:
		sun.light_angular_distance = float(row(quality)["sun_angular_distance"])


## Sets the dome's cloud march from the quality row (the sky tier covers the rest).
static func apply_to_sky(sky: Node, quality: String) -> void:
	var r := row(quality)
	if sky != null and sky.has_method(&"set_cell_march"):
		sky.set_cell_march(
			int(r["sky_cell_steps"]),
			int(r["sky_cell_fine_steps"]),
			int(r["sky_cell_light_samples"]),
			int(r["sky_cell_ray_samples"])
		)
