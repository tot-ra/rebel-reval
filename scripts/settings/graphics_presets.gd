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
		# FSR 1.0 upscales from this fraction of the window per axis.
		"render_scale": 0.67,
		"shadow_atlas_size": 2048,
		"shadow_filter_quality": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"anisotropy": Viewport.ANISOTROPY_2X,
		"sky_tier": &"minimum",
		# God-ray march: samples along the view ray, toward the sun, and far to the horizon.
		"god_ray_view_steps": 6,
		"god_ray_shadow_steps": 3,
		"god_ray_far_steps": 4,
	},
	MID: {
		"render_scale": 0.85,
		"shadow_atlas_size": 4096,
		"shadow_filter_quality": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"anisotropy": Viewport.ANISOTROPY_4X,
		"sky_tier": &"recommended",
		"god_ray_view_steps": 10,
		"god_ray_shadow_steps": 5,
		"god_ray_far_steps": 8,
	},
	HIGH: {
		"render_scale": 1.0,
		# project.godot ships 8192 / SOFT_HIGH (4); high must not exceed what the project looked like.
		"shadow_atlas_size": 8192,
		"shadow_filter_quality": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		"anisotropy": Viewport.ANISOTROPY_4X,
		"sky_tier": &"recommended",
		"god_ray_view_steps": 16,
		"god_ray_shadow_steps": 8,
		"god_ray_far_steps": 12,
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
	window.scaling_3d_mode = (
		Viewport.SCALING_3D_MODE_BILINEAR if scale >= 1.0 else Viewport.SCALING_3D_MODE_FSR
	)
	window.scaling_3d_scale = scale
	window.anisotropic_filtering_level = r["anisotropy"]
	# The atlas is the largest single GPU allocation of the shadow pass; resizing frees it.
	RenderingServer.directional_shadow_atlas_set_size(int(r["shadow_atlas_size"]), false)
	RenderingServer.directional_soft_shadow_filter_set_quality(r["shadow_filter_quality"])
