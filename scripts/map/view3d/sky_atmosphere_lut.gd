class_name SkyAtmosphereLut
extends Node

## WS-10 sky-view LUT owner. Renders sky_view_lut.gdshader (Hillaire EGSR 2020 section 5.3)
## into a small SubViewport that the sky dome samples instead of its hand-tuned gradient.
##
## The LUT is azimuth-relative, so the sun zenith cosine is its only input. The compressed day
## cycle moves the sun about 6 degrees per second, so the LUT re-renders on every update frame
## (every frame on `recommended`, every second frame at half size on `minimum`) and is forced
## to re-render whenever the sun jumps (captures, save restore), never cached across big changes.
##
## Storage decision: HDR float render target, no RGBM. A non-headless probe on Godot 4.7
## (SubViewport.use_hdr_2d = true, canvas_item shader writing vec4(3.5, 0.25, 0.01, 0.4))
## read back the exact values from an RGBAF target on GL Compatibility (opengl3) and from an
## RGBAH target on Metal. Storing radiance directly keeps linear filtering correct and avoids
## the 8-bit banding RGBM would add to the twilight gradient.
##
## Sampling decision: the kernel indexes texels with FRAGCOORD (memory order on every backend).
## On GL Compatibility a sky shader sampling this ViewportTexture receives sRGB-decoded values
## (measured: stored 0.38 read back as ~0.12), so the kernel pre-encodes with the inverse curve
## there (`encode_srgb`); Metal/Vulkan read the stored radiance directly.
##
## Fail closed: if the WS-09 transmittance or multi-scattering LUT is missing, no viewport is
## created, is_available() stays false and SkyWeather3D keeps the old gradient sky.
## No CPU readback happens here (WS-11 adds one event-driven readback).

const LUT_SHADER := preload("res://scripts/map/view3d/sky_view_lut.gdshader")
const TRANSMITTANCE_PATH := "res://assets/sky/atmosphere/transmittance.exr"
const MULTISCATTER_PATH := "res://assets/sky/atmosphere/multiscatter.exr"
const SIZE_RECOMMENDED := Vector2i(192, 108)
const SIZE_MINIMUM := Vector2i(96, 54)
## Tidewater SkyParams default; art exposure is applied by the sky shader.
const SUN_ILLUMINANCE := 11.0
## Sun zenith cosine change that forces a render even inside a throttled frame (~1.1 degrees
## at the horizon). Keeps a teleported sun from showing a stale sky for a frame.
const FORCE_RENDER_MU_DELTA := 0.02

var lut_size := SIZE_RECOMMENDED
var every_n_frames := 1
## Number of renders requested since configure; lets tests observe the throttle.
var render_count := 0

var _viewport: SubViewport
var _rect: ColorRect
var _material: ShaderMaterial
var _transmittance: Texture2D
var _multiscatter: Texture2D
var _last_frame := -1
var _last_mu := INF


## Builds the viewport at `size`. Returns false (and builds nothing) when either baked LUT is
## missing; the paths are parameters only so tests can prove that fallback.
func configure(
	size: Vector2i = SIZE_RECOMMENDED,
	every_n: int = 1,
	transmittance_path: String = TRANSMITTANCE_PATH,
	multiscatter_path: String = MULTISCATTER_PATH
) -> bool:
	_transmittance = _load_texture(transmittance_path)
	_multiscatter = _load_texture(multiscatter_path)
	if _transmittance == null or _multiscatter == null:
		_transmittance = null
		_multiscatter = null
		_release_viewport()
		return false
	_material = ShaderMaterial.new()
	_material.shader = LUT_SHADER
	_material.set_shader_parameter(&"atmosphere_transmittance_lut", _transmittance)
	_material.set_shader_parameter(&"atmosphere_multiscatter_lut", _multiscatter)
	_material.set_shader_parameter(&"sun_illuminance", SUN_ILLUMINANCE)
	_material.set_shader_parameter(&"encode_srgb", decodes_viewport_srgb())
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.name = "SkyViewLut"
		_viewport.use_hdr_2d = true
		_viewport.transparent_bg = false
		_viewport.disable_3d = true
		_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		_rect = ColorRect.new()
		_rect.name = "SkyViewKernel"
		_viewport.add_child(_rect)
		add_child(_viewport)
	_rect.material = _material
	set_tier(size, every_n)
	return true


## Resizes the LUT for a quality tier and schedules a fresh render at the new size.
func set_tier(size: Vector2i, every_n: int) -> void:
	lut_size = Vector2i(maxi(size.x, 2), maxi(size.y, 2))
	every_n_frames = maxi(every_n, 1)
	if _viewport == null:
		return
	_viewport.size = lut_size
	_rect.position = Vector2.ZERO
	_rect.size = Vector2(lut_size)
	_material.set_shader_parameter(&"lut_size", Vector2(lut_size))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_last_frame = -1


## True on the GL Compatibility renderer, whose 3D shaders sRGB-decode ViewportTextures.
static func decodes_viewport_srgb() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


func is_available() -> bool:
	return _viewport != null


func viewport() -> SubViewport:
	return _viewport


func sky_view_texture() -> Texture2D:
	return _viewport.get_texture() if _viewport != null else null


func transmittance_texture() -> Texture2D:
	return _transmittance


## Schedules a LUT render for `frame` when the throttle allows it or the sun moved far.
## Returns true when a render was scheduled.
func update(sun_dir: Vector3, frame: int) -> bool:
	if _viewport == null:
		return false
	var mu := clampf(sun_dir.normalized().y, -1.0, 1.0)
	var due := _last_frame < 0 or frame < _last_frame or frame - _last_frame >= every_n_frames
	if not due and absf(mu - _last_mu) < FORCE_RENDER_MU_DELTA:
		return false
	_material.set_shader_parameter(&"sun_zenith_cos", mu)
	# UPDATE_ONCE renders on the next draw and then drops back to UPDATE_DISABLED, which is
	# exactly the manual cadence both tiers need.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_last_frame = frame
	_last_mu = mu
	render_count += 1
	return true


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _release_viewport() -> void:
	if _viewport != null:
		remove_child(_viewport)
		_viewport.free()
	_viewport = null
	_rect = null
	_material = null
