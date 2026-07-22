class_name SkyWeatherResources
extends RefCounted

## Procedural rendering resources used by SkyWeather3D. Keeping texture baking and
## particle construction outside the weather controller lets that node focus on
## simulation state, while this factory remains deterministic and scene-tree free.

const STAR_MAP_WIDTH := 2048
const STAR_MAP_HEIGHT := 1024
const LUNAR_ALBEDO_MAP_SIZE := 512


## Deterministic seamless FBM noise used only to erode cloud edges and add
## surface texture. Authored in code so no runtime art assets are required.
static func build_cloud_noise(seed: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.03
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	return texture


## Cellular (Worley) noise supplies the puffy body of cumulus heaps. FBM alone
## reads as fluid smoke under thresholding, so the cloud silhouette starts here.
static func build_cloud_shape(seed: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed + 7
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.018
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	return texture


## Bakes a near-side lunar albedo disk in code so the sky shader can sample
## maria, craters, and rays without frozen pipeline texture assets.
## WHY alpha stays 1 inside the disk: packing height into A made mipmaps and
## filtering premultiply RGB and turned the Moon into a dark blotchy disk.
static func build_lunar_albedo_map(seed: int) -> ImageTexture:
	var size := LUNAR_ALBEDO_MAP_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var crater_fine := FastNoiseLite.new()
	crater_fine.seed = seed + 101
	crater_fine.noise_type = FastNoiseLite.TYPE_CELLULAR
	crater_fine.frequency = 0.14
	crater_fine.cellular_jitter = 0.85
	crater_fine.cellular_return_type = FastNoiseLite.RETURN_DISTANCE

	var crater_mid := FastNoiseLite.new()
	crater_mid.seed = seed + 102
	crater_mid.noise_type = FastNoiseLite.TYPE_CELLULAR
	crater_mid.frequency = 0.055
	crater_mid.cellular_jitter = 0.9
	crater_mid.cellular_return_type = FastNoiseLite.RETURN_DISTANCE

	var crater_large := FastNoiseLite.new()
	crater_large.seed = seed + 103
	crater_large.noise_type = FastNoiseLite.TYPE_CELLULAR
	crater_large.frequency = 0.022
	crater_large.cellular_jitter = 0.8
	crater_large.cellular_return_type = FastNoiseLite.RETURN_DISTANCE

	var regolith := FastNoiseLite.new()
	regolith.seed = seed + 104
	regolith.frequency = 0.08
	regolith.fractal_type = FastNoiseLite.FRACTAL_FBM
	regolith.fractal_octaves = 5

	var highland := FastNoiseLite.new()
	highland.seed = seed + 105
	highland.frequency = 0.035
	highland.fractal_type = FastNoiseLite.FRACTAL_FBM
	highland.fractal_octaves = 3

	# Major near-side maria in normalized disk space (center 0,0; radius 1).
	const MARIA: Array[Dictionary] = [
		{"c": Vector2(-0.44, 0.02), "r": Vector2(0.32, 0.26), "a": 0.18, "d": 0.38},
		{"c": Vector2(-0.24, 0.36), "r": Vector2(0.22, 0.18), "a": -0.28, "d": 0.34},
		{"c": Vector2(0.08, 0.40), "r": Vector2(0.15, 0.13), "a": 0.10, "d": 0.28},
		{"c": Vector2(0.16, 0.14), "r": Vector2(0.17, 0.12), "a": -0.12, "d": 0.26},
		{"c": Vector2(0.30, -0.18), "r": Vector2(0.13, 0.11), "a": 0.22, "d": 0.22},
		{"c": Vector2(0.54, 0.34), "r": Vector2(0.10, 0.09), "a": 0.0, "d": 0.20},
		{"c": Vector2(-0.08, -0.22), "r": Vector2(0.12, 0.10), "a": 0.35, "d": 0.18},
		{"c": Vector2(0.36, 0.02), "r": Vector2(0.11, 0.09), "a": -0.15, "d": 0.17},
	]

	for y in size:
		for x in size:
			var nx := (float(x) + 0.5) / float(size) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(size) * 2.0 - 1.0
			var disk_r2 := nx * nx + ny * ny
			# Fill slightly past the unit disk so linear filtering at the limb
			# never samples transparent black and paints a dark sticker outline.
			if disk_r2 > 1.06:
				continue
			var uv := Vector2(nx, ny)
			var sample_uv := uv / maxf(sqrt(disk_r2), 1e-4) * minf(sqrt(disk_r2), 1.0)
			if disk_r2 > 1.0:
				uv = sample_uv
			var regolith_n := regolith.get_noise_2d(uv.x * 14.0, uv.y * 14.0)
			var highland_n := highland.get_noise_2d(uv.x * 5.5, uv.y * 5.5)

			# Bright highland crust; maria carve much darker basins (high contrast
			# is what reads at the tiny on-sky disk size).
			var albedo := 0.78 + highland_n * 0.07
			var mare_amount := 0.0
			for mare in MARIA:
				var darkness := _lunar_mare_darkness(uv, mare, regolith_n)
				mare_amount = maxf(mare_amount, darkness / maxf(float(mare["d"]), 1e-4))
				albedo -= darkness

			var fine := _lunar_cellular_distance(crater_fine.get_noise_2d(uv.x * 52.0, uv.y * 52.0))
			var mid := _lunar_cellular_distance(crater_mid.get_noise_2d(uv.x * 21.0, uv.y * 21.0))
			var large := _lunar_cellular_distance(crater_large.get_noise_2d(uv.x * 9.0, uv.y * 9.0))
			var crater := _lunar_crater_albedo(fine, 0.10, 0.22)
			crater += _lunar_crater_albedo(mid, 0.16, 0.26)
			crater += _lunar_crater_albedo(large, 0.24, 0.32)
			# Fewer sharp bowls inside deep maria; highlands keep denser cratering.
			crater *= lerpf(1.0, 0.22, clampf(mare_amount, 0.0, 1.0))
			albedo += crater

			albedo += regolith_n * 0.07
			albedo += _lunar_tycho_rays(uv)

			# Mild center brightening only; keep the disk from reading as a flat sticker.
			var limb := sqrt(maxf(1.0 - disk_r2, 0.0))
			albedo *= 0.94 + 0.06 * limb
			albedo = clampf(albedo, 0.22, 0.96)
			# Neutral-warm regolith (brownish grey), not cool blue-grey.
			image.set_pixel(
				x,
				y,
				Color(albedo * 1.03, albedo * 0.995, albedo * 0.92, 1.0)
			)

	return ImageTexture.create_from_image(image)


static func _lunar_mare_darkness(uv: Vector2, mare: Dictionary, edge_noise: float) -> float:
	var center: Vector2 = mare["c"]
	var radii: Vector2 = mare["r"]
	var angle: float = mare["a"]
	var depth: float = mare["d"]
	var offset := uv - center
	var ca := cos(angle)
	var sa := sin(angle)
	var rotated := Vector2(offset.x * ca + offset.y * sa, -offset.x * sa + offset.y * ca)
	# Noise-warped coastlines so maria are not hard geometric ellipses.
	var warp := 1.0 + edge_noise * 0.18
	var normalized := (
		(rotated.x * rotated.x) / maxf(radii.x * radii.x * warp, 1e-4)
		+ (rotated.y * rotated.y) / maxf(radii.y * radii.y * warp, 1e-4)
	)
	if normalized >= 1.05:
		return 0.0
	var interior := 1.0 - smoothstep(0.35, 1.05, normalized)
	var mottling := 0.88 + 0.12 * sin(uv.x * 17.0 + uv.y * 13.0)
	return depth * interior * mottling


## FastNoiseLite cellular distance is encoded in roughly [-1, 1], with values
## near -1 at feature centers. Map that to 0..1 before crater shaping.
static func _lunar_cellular_distance(raw: float) -> float:
	return clampf(raw * 0.5 + 0.5, 0.0, 1.0)


## Dark bowl + bright rim from a 0..1 cellular distance field (0 at centers).
static func _lunar_crater_albedo(cell_distance: float, strength: float, rim_start: float) -> float:
	var d := clampf(cell_distance, 0.0, 1.0)
	if d > rim_start:
		return 0.0
	var rim := smoothstep(rim_start, rim_start * 0.70, d) * (1.0 - smoothstep(rim_start * 0.70, rim_start * 0.42, d))
	var floor_t := 1.0 - smoothstep(0.0, rim_start * 0.48, d)
	return rim * strength * 0.65 - floor_t * strength * 0.9


static func _lunar_tycho_rays(uv: Vector2) -> float:
	# Soft southern bright ejecta, not a hard geometric starburst. A few wide
	# angular lobes + noise read as rays at sky scale without a wagon-wheel look.
	var tycho := Vector2(0.05, -0.53)
	var from_tycho := uv - tycho
	var dist := from_tycho.length()
	if dist > 0.58 or dist < 0.03:
		return 0.0
	var angle := atan2(from_tycho.y, from_tycho.x)
	var lobes := pow(maxf(sin(angle * 3.0), 0.0), 2.4)
	lobes += 0.35 * pow(maxf(sin(angle * 3.0 + 2.1), 0.0), 2.8)
	var grit := 0.55 + 0.45 * sin(uv.x * 37.0 + uv.y * 29.0)
	var falloff := 1.0 - dist / 0.58
	return lobes * falloff * falloff * grit * 0.07


## Bakes a star catalog into an equatorial equirectangular map. A texture keeps
## the sky shader to one sample per pixel while retaining catalog photometry.
static func build_star_map(
	stars: Array[Vector4],
	catalog_epoch: float,
	target_epoch: float,
	limiting_magnitude: float
) -> ImageTexture:
	var image := Image.create(STAR_MAP_WIDTH, STAR_MAP_HEIGHT, false, Image.FORMAT_RGBAH)
	image.fill(Color.TRANSPARENT)
	for j2000_star in stars:
		var star := precess_equatorial(j2000_star, catalog_epoch, target_epoch)
		var x := wrapi(roundi(star.x / 360.0 * float(STAR_MAP_WIDTH)), 0, STAR_MAP_WIDTH)
		var y := clampi(roundi((90.0 - star.y) / 180.0 * float(STAR_MAP_HEIGHT - 1)), 0, STAR_MAP_HEIGHT - 1)
		var luminosity := magnitude_to_luminance(star.z, limiting_magnitude)
		var color := bv_to_rgb(star.w) * luminosity
		_set_star_texel(image, x, y, color)
		if star.z <= 2.5:
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				_set_star_texel(image, x + offset.x, y + offset.y, color * 0.28)
	return ImageTexture.create_from_image(image)


static func _set_star_texel(image: Image, x: int, y: int, color: Color) -> void:
	var wrapped_x := wrapi(x, 0, STAR_MAP_WIDTH)
	var clamped_y := clampi(y, 0, STAR_MAP_HEIGHT - 1)
	var existing := image.get_pixel(wrapped_x, clamped_y)
	image.set_pixel(wrapped_x, clamped_y, Color(
		maxf(existing.r, color.r),
		maxf(existing.g, color.g),
		maxf(existing.b, color.b),
		1.0
	))


static func magnitude_to_luminance(magnitude: float, limiting_magnitude: float) -> float:
	# Pogson's relation: five magnitudes equal a factor of 100 in brightness.
	return clampf(pow(10.0, -0.4 * (magnitude - limiting_magnitude)), 1.0, 180.0)


static func bv_to_rgb(bv: float) -> Color:
	# Ballesteros temperature approximation followed by a black-body RGB fit.
	# This preserves blue Rigel/Vega and warm Betelgeuse/Arcturus at a glance.
	var clamped_bv := clampf(bv, -0.4, 2.0)
	var temperature := 4600.0 * (
		1.0 / (0.92 * clamped_bv + 1.7) + 1.0 / (0.92 * clamped_bv + 0.62)
	)
	var scaled := temperature / 100.0
	var red: float
	var green: float
	var blue: float
	if scaled <= 66.0:
		red = 1.0
		green = clampf((99.4708025861 * log(scaled) - 161.1195681661) / 255.0, 0.0, 1.0)
	else:
		red = clampf(329.698727446 * pow(scaled - 60.0, -0.1332047592) / 255.0, 0.0, 1.0)
		green = clampf(288.1221695283 * pow(scaled - 60.0, -0.0755148492) / 255.0, 0.0, 1.0)
	if scaled >= 66.0:
		blue = 1.0
	elif scaled <= 19.0:
		blue = 0.0
	else:
		blue = clampf((138.5177312231 * log(scaled - 10.0) - 305.0447927307) / 255.0, 0.0, 1.0)
	return Color(red, green, blue)


## IAU 1976 precession is sufficiently accurate across the 657-year offset and
## moves the entire constellation pattern together from J2000 to spring 1343.
static func precess_equatorial(star: Vector4, from_epoch: float, to_epoch: float) -> Vector4:
	var centuries := (to_epoch - from_epoch) / 100.0
	var zeta := deg_to_rad((
		2306.2181 * centuries
		+ 0.30188 * centuries * centuries
		+ 0.017998 * centuries * centuries * centuries
	) / 3600.0)
	var z := deg_to_rad((
		2306.2181 * centuries
		+ 1.09468 * centuries * centuries
		+ 0.018203 * centuries * centuries * centuries
	) / 3600.0)
	var theta := deg_to_rad((
		2004.3109 * centuries
		- 0.42665 * centuries * centuries
		- 0.041833 * centuries * centuries * centuries
	) / 3600.0)
	var right_ascension := deg_to_rad(star.x)
	var declination := deg_to_rad(star.y)
	var a := cos(declination) * sin(right_ascension + zeta)
	var b := (
		cos(theta) * cos(declination) * cos(right_ascension + zeta)
		- sin(theta) * sin(declination)
	)
	var c := (
		sin(theta) * cos(declination) * cos(right_ascension + zeta)
		+ cos(theta) * sin(declination)
	)
	return Vector4(
		wrapf(rad_to_deg(atan2(a, b) + z), 0.0, 360.0),
		rad_to_deg(asin(clampf(c, -1.0, 1.0))),
		star.z,
		star.w
	)


static func build_rain() -> GPUParticles3D:
	var rain := GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 2200
	rain.lifetime = 1.1
	# World-space particles so camera motion does not drag the rain volume along.
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-36.0, -20.0, -36.0), Vector3(72.0, 40.0, 72.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(26.0, 0.5, 26.0)
	process.direction = Vector3(0.06, -1.0, 0.02)
	process.spread = 2.0
	process.initial_velocity_min = 15.0
	process.initial_velocity_max = 19.0
	process.gravity = Vector3(0.0, -10.0, 0.0)
	process.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	rain.process_material = process
	# Stretched unshaded streaks; built from primitives, no texture assets.
	var streak := BoxMesh.new()
	streak.size = Vector3(0.018, 0.5, 0.018)
	var streak_material := StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.albedo_color = Color(0.68, 0.76, 0.88, 0.5)
	streak.material = streak_material
	rain.draw_pass_1 = streak
	rain.visible = false
	return rain
