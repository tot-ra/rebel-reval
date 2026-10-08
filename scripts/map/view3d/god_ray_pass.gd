extends Node3D

## Atmospheric god rays (crepuscular rays) from the sun or, at night, the moon.
## GL Compatibility has no volumetric fog, so this is an additive full-screen pass
## (god_ray_pass.gdshader) that ray-marches the street air against a max-height
## raster of the map's architecture: shafts only form where air sees the light past
## roofs and towers, and buildings cut them like shadows. The rays need something in
## the air to scatter (ground mist, rain haze, the gaps of broken cloud) and a camera
## looking toward the light; clear dry noon and a top-down view stay clean.

const PASS_SHADER := preload("res://scripts/map/view3d/god_ray_pass.gdshader")
const Lighting := preload("res://scripts/map/view3d/map_view_lighting.gd")
const SkyWeather := preload("res://scripts/map/view3d/sky_weather_3d.gd")

const RENDER_PRIORITY := 97
const GROUP := &"god_ray_pass"
## Dust and aerosol that always scatters a little, so a clear low sun is not bare.
const BASE_HAZE := 0.10
## Broken cloud (not overcast) opens and shuts the beam into distinct shafts.
const CLOUD_GAP_HAZE := 0.35
## R-1400: a discrete cloud's ragged edge across the sun is the classic beam maker.
const CELL_EDGE_HAZE := 0.3
const RAIN_HAZE_WEIGHT := 0.6
## Moonlight is a few percent of sunlight; keep its rays a faint veil.
const MOON_STRENGTH_SCALE := 0.3
const MAX_STRENGTH := 0.55
## Scatter gain handed to the shader. The dimetric gameplay lens looks 30 deg down, so
## its rays sit far off the forward phase peak; the shader's soft cap (`INTENSITY_CAP`)
## keeps a lens aimed straight at the sun from washing out.
const GAIN := 3.0
const INTENSITY_CAP := 0.6
## Below this on-screen strength the overlay is hidden and costs nothing.
const STRENGTH_SKIP := 0.01
const SUN_COLOR := Color(1.0, 0.86, 0.62)
const MOON_COLOR := Color(0.55, 0.65, 0.9)
## Haze phase function (mirrors the shader): forward-peaked like dust and droplets.
const ANISOTROPY := 0.6
const ISOTROPIC_SHARE := 0.0
## Height raster resolution: half a world unit, coarser on very large maps so the
## raster stays within MAX_TEXELS per side.
const HEIGHT_TEXEL := 0.5
const MAX_TEXELS := 768
## Relief maps sample the terrain on this coarser step (value noise is slow in GDScript).
const GROUND_STEP := 2.0
## Air above the tallest mass that still scatters; spires above the cap are clipped.
const VOLUME_HEADROOM := 1.0
const MIN_VOLUME_TOP := 6.0
const MAX_VOLUME_TOP := 32.0
## Water and recessed beds sit just under world zero.
const FLOOR_Y := -0.1
const REBUILD_SETTLE_SECONDS := 0.25

var strength := 0.0
var _material: ShaderMaterial
var _overlay: MeshInstance3D
var _camera: Camera3D
var _world_extent := Vector2.ZERO
var _raster_origin := Vector2.ZERO
var _occluders := Callable()
var _ground := Callable()
var _height_texture: ImageTexture
## Occluder list size plus its first and last box: a cheap "did streaming change the
## masses" check run every frame, so the raster only rebuilds after chunk finalize.
var _occluder_signature: Array = []
## Chunk finalize appends boxes in slices across frames; wait until the list has been
## stable for REBUILD_SETTLE_SECONDS so one load rebuilds the raster once, not per slice.
var _pending_signature: Array = []
var _pending_age := 0.0


static func should_create(indoor: bool) -> bool:
	return not indoor


## Scatter amount 0..1: how much the air in front of the light can show a beam.
static func haze_amount(
	presentation: SkyWeather.WeatherPresentation, enclosed_interior: bool = false
) -> float:
	var mist := Lighting.ground_mist_amount(presentation, enclosed_interior)
	var rain_haze := Lighting.ground_rain_haze(presentation, enclosed_interior)
	# Peaks at half cover: clear sky has no gaps to shape a beam, overcast hides the sun.
	var broken := 1.0 - absf(presentation.cloud_coverage * 2.0 - 1.0)
	return clampf(
		BASE_HAZE + mist + rain_haze * RAIN_HAZE_WEIGHT + broken * CLOUD_GAP_HAZE
		+ presentation.cell_sun_edge * CELL_EDGE_HAZE,
		0.0, 1.0
	)


## Beam strength before the view-dependent phase. A low sun crosses more air, so rays
## fade out as it climbs; below the horizon the moon takes over at a fraction of it.
static func light_strength(presentation: SkyWeather.WeatherPresentation) -> float:
	var sun_elevation := clampf(presentation.sun_direction.y, 0.0, 1.0)
	var sun_beam := presentation.sun_visibility * presentation.sun_cloud_clear
	sun_beam *= 1.0 - smoothstep(0.25, 0.85, sun_elevation) * 0.75
	var moon_beam := (
		presentation.lunar_light_strength
		* presentation.moon_cloud_clear
		* clampf(presentation.moon_direction.y * 4.0, 0.0, 1.0)
		* MOON_STRENGTH_SCALE
	)
	var beam := maxf(sun_beam, moon_beam)
	return clampf(beam * haze_amount(presentation), 0.0, MAX_STRENGTH)


## True when the sun (not the moon) is the dominant source for the rays.
static func uses_sun(presentation: SkyWeather.WeatherPresentation) -> bool:
	return presentation.sun_visibility * presentation.sun_cloud_clear >= (
		presentation.lunar_light_strength * presentation.moon_cloud_clear * MOON_STRENGTH_SCALE
	)


## Henyey-Greenstein phase normalised to 1 when the view ray points at the light
## (the same curve as `phase()` in the shader). `cos_theta` = dot(view ray, light dir).
static func phase(cos_theta: float) -> float:
	var g := ANISOTROPY
	var ratio := (1.0 - g) * (1.0 - g) / maxf(1.0 + g * g - 2.0 * g * cos_theta, 1e-4)
	return lerpf(ratio * sqrt(ratio), 1.0, ISOTROPIC_SHARE)


## Brightest phase any pixel of the camera can see. Orthographic rays are parallel;
## a perspective lens also has rays up to half its diagonal field off the forward axis.
static func view_phase(camera: Camera3D, light_direction: Vector3, aspect: float) -> float:
	var forward := -camera.global_transform.basis.z
	var angle := forward.angle_to(light_direction)
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		var half_tan := tan(deg_to_rad(camera.fov) * 0.5)
		angle = maxf(angle - atan(half_tan * sqrt(1.0 + aspect * aspect)), 0.0)
	return phase(cos(angle))


## Max-height raster of the masses (world units, one float per texel, `texel` units
## wide) over a map `extent` in view-local XZ. Each box fills its XZ footprint with its
## top. `ground` (optional) maps a world XZ to terrain height for relief maps.
static func rasterize_heights(
	boxes: Array[AABB], extent: Vector2, texel: float, ground: Callable = Callable()
) -> Image:
	var width := maxi(ceili(extent.x / texel), 1)
	var height := maxi(ceili(extent.y / texel), 1)
	var data := PackedFloat32Array()
	data.resize(width * height)
	data.fill(FLOOR_Y)
	if ground.is_valid():
		var block := maxi(roundi(GROUND_STEP / texel), 1)
		for by in range(0, height, block):
			for bx in range(0, width, block):
				var xz := (Vector2(bx, by) + Vector2.ONE * block * 0.5) * texel
				var ground_y := float(ground.call(xz))
				for y in range(by, mini(by + block, height)):
					for x in range(bx, mini(bx + block, width)):
						data[y * width + x] = ground_y
	for box in boxes:
		var top := box.end.y
		if top <= FLOOR_Y:
			continue
		var x0 := clampi(floori(box.position.x / texel), 0, width)
		var x1 := clampi(ceili(box.end.x / texel), 0, width)
		var y0 := clampi(floori(box.position.z / texel), 0, height)
		var y1 := clampi(ceili(box.end.z / texel), 0, height)
		for y in range(y0, y1):
			var row := y * width
			for x in range(x0, x1):
				if data[row + x] < top:
					data[row + x] = top
	return Image.create_from_data(width, height, false, Image.FORMAT_RF, data.to_byte_array())


## Top of the scattering slab: just above the tallest mass, inside sane bounds.
static func volume_top(image: Image) -> float:
	var data := image.get_data().to_float32_array()
	var tallest := 0.0
	for value in data:
		tallest = maxf(tallest, value)
	return clampf(tallest + VOLUME_HEADROOM, MIN_VOLUME_TOP, MAX_VOLUME_TOP)


## `world_extent` is the map size in world units (view-local XZ from the origin).
## `occluders` returns the view's building/landmark boxes (view-local AABBs);
## `ground` maps a world XZ to terrain height and is only passed for relief maps.
## `raster_origin` is the view-local XZ of the raster's corner for maps that do not
## start at the origin (the seamless city is centred on it, R-1400).
func configure(
	camera: Camera3D,
	world_extent: Vector2 = Vector2.ZERO,
	occluders: Callable = Callable(),
	ground: Callable = Callable(),
	raster_origin: Vector2 = Vector2.ZERO
) -> void:
	name = "GodRayPass"
	_camera = camera
	_world_extent = world_extent
	_raster_origin = raster_origin
	_occluders = occluders
	_ground = ground
	add_to_group(GROUP)
	_material = ShaderMaterial.new()
	_material.shader = PASS_SHADER
	_material.render_priority = RENDER_PRIORITY
	_material.set_shader_parameter(&"strength", 0.0)
	_material.set_shader_parameter(&"anisotropy", ANISOTROPY)
	_material.set_shader_parameter(&"isotropic_share", ISOTROPIC_SHARE)
	_material.set_shader_parameter(&"floor_y", FLOOR_Y)
	_material.set_shader_parameter(&"intensity_cap", INTENSITY_CAP)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.flip_faces = true
	quad.material = _material
	_overlay = MeshInstance3D.new()
	_overlay.name = "GodRayOverlay"
	_overlay.mesh = quad
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.ignore_occlusion_culling = true
	_overlay.extra_cull_margin = 16384.0
	_overlay.visible = false
	add_child(_overlay)
	_sync_height_map()


func _exit_tree() -> void:
	remove_from_group(GROUP)


func height_texture() -> ImageTexture:
	return _height_texture


func _sync_height_map(delta: float = 0.0) -> void:
	var boxes: Array[AABB] = []
	if _occluders.is_valid():
		boxes.assign(_occluders.call())
	if _raster_origin != Vector2.ZERO:
		var shift := Vector3(_raster_origin.x, 0.0, _raster_origin.y)
		for i in boxes.size():
			boxes[i].position -= shift
	var signature: Array = [boxes.size()]
	if not boxes.is_empty():
		signature.append_array([boxes[0], boxes[boxes.size() - 1]])
	if _height_texture != null:
		if signature == _occluder_signature:
			return
		if signature != _pending_signature:
			_pending_signature = signature
			_pending_age = 0.0
			return
		_pending_age += delta
		if _pending_age < REBUILD_SETTLE_SECONDS:
			return
	_occluder_signature = signature
	var extent := _world_extent
	for box in boxes:
		extent = extent.max(Vector2(box.end.x, box.end.z))
	var texel := maxf(HEIGHT_TEXEL, maxf(extent.x, extent.y) / float(MAX_TEXELS))
	var ground := _ground
	if ground.is_valid() and _raster_origin != Vector2.ZERO:
		var corner := _raster_origin
		var local_ground := _ground
		ground = func(xz: Vector2) -> float: return float(local_ground.call(xz + corner))
	var image := rasterize_heights(boxes, extent, texel, ground)
	if _height_texture != null and _height_texture.get_size() == Vector2(image.get_size()):
		_height_texture.update(image)
	else:
		_height_texture = ImageTexture.create_from_image(image)
	_material.set_shader_parameter(&"height_map", _height_texture)
	_material.set_shader_parameter(&"texel_size", texel)
	_material.set_shader_parameter(&"volume_top", volume_top(image))


func update(delta: float, presentation: SkyWeather.WeatherPresentation) -> void:
	if _material == null or _camera == null:
		return
	# Hosted neighbours each build a pass over the same camera; additive overlays would
	# stack, so only the first pass in the tree draws.
	var first := get_tree().get_first_node_in_group(GROUP)
	var base := light_strength(presentation) if first == self else 0.0
	var use_sun := uses_sun(presentation)
	var direction := (presentation.sun_direction if use_sun else presentation.moon_direction)
	direction = direction.normalized()
	var viewport := get_viewport().get_visible_rect().size
	var aspect := viewport.x / maxf(viewport.y, 1.0)
	# The shader reads the drawing camera's matrices; gate on that same camera (close
	# modes and capture tools can make another Camera3D current).
	var camera := get_viewport().get_camera_3d()
	strength = base * GAIN * view_phase(camera if camera != null else _camera, direction, aspect)
	_overlay.visible = strength > STRENGTH_SKIP and direction.y > 0.0
	if not _overlay.visible:
		return
	_sync_height_map(delta)
	var ray_color := SUN_COLOR if use_sun else MOON_COLOR
	if use_sun:
		# Golden hour warms the beam; the physical sun colour already carries it.
		ray_color = presentation.physical_sun_color.lerp(SUN_COLOR, 0.35)
	var origin := (get_parent() as Node3D).global_position if get_parent() is Node3D else Vector3()
	_material.set_shader_parameter(&"map_origin", Vector2(origin.x, origin.z) + _raster_origin)
	_material.set_shader_parameter(&"light_dir", direction)
	_material.set_shader_parameter(&"cloud_cells", presentation.cloud_cells)
	_material.set_shader_parameter(&"ray_color", ray_color)
	_material.set_shader_parameter(&"strength", base * GAIN)
