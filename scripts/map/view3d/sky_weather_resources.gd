class_name SkyWeatherResources
extends RefCounted

## Procedural rendering resources used by SkyWeather3D. Keeping texture baking and
## particle construction outside the weather controller lets that node focus on
## simulation state, while this factory remains deterministic and scene-tree free.

const STAR_MAP_WIDTH := 2048
const STAR_MAP_HEIGHT := 1024
## J2000 galactic north pole and galactic centre (IAU 1958 frame in FK5).
const GALACTIC_POLE_J2000 := Vector2(192.85948, 27.12825)
const GALACTIC_CENTER_J2000 := Vector2(266.40499, -28.93617)
const LUNAR_ALBEDO_MAP_SIZE := 1024
const CLOUD_NOISE_RESOLUTION_MINIMUM := 128
const CLOUD_NOISE_RESOLUTION_RECOMMENDED := 256
const CLOUD_SHAPE_RESOLUTION_MINIMUM := 256
const CLOUD_SHAPE_RESOLUTION_RECOMMENDED := 512
const RAIN_PARTICLES_MINIMUM := 700
const RAIN_PARTICLES_RECOMMENDED := 2200
## NASA LRO near-side mosaic, cropped to an opaque RGB disk with a filter-safe
## limb fill (no black exterior). Public-domain US Government work; see SOURCES.
const LUNAR_ALBEDO_NEAR_SIDE := preload("res://assets/sky/lunar_albedo_nearside.png")


## Deterministic seamless FBM noise used only to erode cloud edges and add
## surface texture. Authored in code so no runtime art assets are required.
static func build_cloud_noise(
	seed: int, resolution: int = CLOUD_NOISE_RESOLUTION_RECOMMENDED
) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.03
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	var clamped_resolution := clampi(
		resolution, CLOUD_NOISE_RESOLUTION_MINIMUM, CLOUD_NOISE_RESOLUTION_RECOMMENDED
	)
	texture.width = clamped_resolution
	texture.height = clamped_resolution
	texture.seamless = true
	texture.noise = noise
	return texture


## Cellular (Worley) noise supplies the puffy body of cumulus heaps. FBM alone
## reads as fluid smoke under thresholding, so the cloud silhouette starts here.
static func build_cloud_shape(
	seed: int, resolution: int = CLOUD_SHAPE_RESOLUTION_RECOMMENDED
) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed + 7
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.012
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	var texture := NoiseTexture2D.new()
	var clamped_resolution := clampi(
		resolution, CLOUD_SHAPE_RESOLUTION_MINIMUM, CLOUD_SHAPE_RESOLUTION_RECOMMENDED
	)
	texture.width = clamped_resolution
	texture.height = clamped_resolution
	texture.seamless = true
	texture.noise = noise
	return texture


## R-1400: seamless 3D Worley-FBM noise for the discrete cloud cells. Inverted
## cellular distance gives round, bulging puffs in every direction, so a cell's
## surface boils into cauliflower turrets; a 2D texture sliced by height combed the
## billows into vertical streaks. Baked in C++ by FastNoiseLite (~0.1 s at 48^3).
static func build_cell_noise_3d(seed: int, size: int) -> ImageTexture3D:
	var noise := FastNoiseLite.new()
	noise.seed = seed + 31
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 4.0 / float(size)
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.45
	var images: Array[Image] = noise.get_seamless_image_3d(size, size, size, true, 0.1, true)
	for image in images:
		image.convert(Image.FORMAT_L8)
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_L8, size, size, size, false, images)
	return texture


## Returns the authored near-side lunar albedo disk for the sky shader.
## WHY a NASA photo instead of procedural noise: real maria, Tycho rays, and
## crater layout read as the Moon at sky-disk scale. `_seed` is kept so callers
## and older bake APIs stay source-compatible after P0-079.
static func build_lunar_albedo_map(_seed: int) -> Texture2D:
	return LUNAR_ALBEDO_NEAR_SIDE


## Bakes a star catalog into an equatorial equirectangular map. A texture keeps
## the sky shader to one sample per pixel while retaining catalog photometry.
static func build_star_map(
	stars: Array[Vector4], catalog_epoch: float, target_epoch: float, limiting_magnitude: float
) -> ImageTexture:
	var image := new_star_image()
	bake_stars(image, stars, 0, stars.size(), catalog_epoch, target_epoch, limiting_magnitude)
	return ImageTexture.create_from_image(image)


static func new_star_image() -> Image:
	var image := Image.create(STAR_MAP_WIDTH, STAR_MAP_HEIGHT, false, Image.FORMAT_RGBAH)
	# R-1443: Color.TRANSPARENT is (1, 1, 1, 0), which made every empty texel a
	# white "star" and washed the whole night sky (and its water reflection).
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	return image


## R-1095: stars [from, to) of the catalog, so staged assembly can bake the map
## in slices. Stars combine with max(), so slice order does not change the image.
static func bake_stars(
	image: Image,
	stars: Array[Vector4],
	from: int,
	to: int,
	catalog_epoch: float,
	target_epoch: float,
	limiting_magnitude: float
) -> void:
	for index in range(from, mini(to, stars.size())):
		var star := precess_equatorial(stars[index], catalog_epoch, target_epoch)
		var x := wrapi(roundi(star.x / 360.0 * float(STAR_MAP_WIDTH)), 0, STAR_MAP_WIDTH)
		var y := clampi(
			roundi((90.0 - star.y) / 180.0 * float(STAR_MAP_HEIGHT - 1)), 0, STAR_MAP_HEIGHT - 1
		)
		var luminosity := magnitude_to_luminance(star.z, limiting_magnitude)
		var color := bv_to_rgb(star.w) * luminosity
		# R-1443: one texel per star. The sky shader draws a round point-spread
		# disk around it; the old '+' kernel for bright stars read as crosses.
		_set_star_texel(image, x, y, color)


static func _set_star_texel(image: Image, x: int, y: int, color: Color) -> void:
	var wrapped_x := wrapi(x, 0, STAR_MAP_WIDTH)
	var clamped_y := clampi(y, 0, STAR_MAP_HEIGHT - 1)
	var existing := image.get_pixel(wrapped_x, clamped_y)
	image.set_pixel(
		wrapped_x,
		clamped_y,
		Color(maxf(existing.r, color.r), maxf(existing.g, color.g), maxf(existing.b, color.b), 1.0)
	)


static func magnitude_to_luminance(magnitude: float, limiting_magnitude: float) -> float:
	# Pogson's relation: five magnitudes equal a factor of 100 in brightness.
	return clampf(pow(10.0, -0.4 * (magnitude - limiting_magnitude)), 1.0, 180.0)


static func bv_to_rgb(bv: float) -> Color:
	# Ballesteros temperature approximation followed by a black-body RGB fit.
	# This preserves blue Rigel/Vega and warm Betelgeuse/Arcturus at a glance.
	var clamped_bv := clampf(bv, -0.4, 2.0)
	var temperature := 4600.0 * (1.0 / (0.92 * clamped_bv + 1.7) + 1.0 / (0.92 * clamped_bv + 0.62))
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


## R-1443: galactic pole and centre as unit vectors in the star map's equatorial
## frame at `target_epoch`, so the Milky Way precesses with the stars.
## Vector convention matches sky_stars.gdshaderinc equatorial_vector().
static func galactic_frame(catalog_epoch: float, target_epoch: float) -> Dictionary:
	var pole := precess_equatorial(
		Vector4(GALACTIC_POLE_J2000.x, GALACTIC_POLE_J2000.y, 0.0, 0.0), catalog_epoch, target_epoch
	)
	var center := precess_equatorial(
		Vector4(GALACTIC_CENTER_J2000.x, GALACTIC_CENTER_J2000.y, 0.0, 0.0),
		catalog_epoch,
		target_epoch
	)
	return {
		"pole": equatorial_vector(pole.x, pole.y),
		"center": equatorial_vector(center.x, center.y),
	}


static func equatorial_vector(
	right_ascension_degrees: float, declination_degrees: float
) -> Vector3:
	var ra := deg_to_rad(right_ascension_degrees)
	var dec := deg_to_rad(declination_degrees)
	return Vector3(cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec))


## IAU 1976 precession is sufficiently accurate across the 657-year offset and
## moves the entire constellation pattern together from J2000 to spring 1343.
static func precess_equatorial(star: Vector4, from_epoch: float, to_epoch: float) -> Vector4:
	var centuries := (to_epoch - from_epoch) / 100.0
	var zeta := deg_to_rad(
		(
			(
				2306.2181 * centuries
				+ 0.30188 * centuries * centuries
				+ 0.017998 * centuries * centuries * centuries
			)
			/ 3600.0
		)
	)
	var z := deg_to_rad(
		(
			(
				2306.2181 * centuries
				+ 1.09468 * centuries * centuries
				+ 0.018203 * centuries * centuries * centuries
			)
			/ 3600.0
		)
	)
	var theta := deg_to_rad(
		(
			(
				2004.3109 * centuries
				- 0.42665 * centuries * centuries
				- 0.041833 * centuries * centuries * centuries
			)
			/ 3600.0
		)
	)
	var right_ascension := deg_to_rad(star.x)
	var declination := deg_to_rad(star.y)
	var a := cos(declination) * sin(right_ascension + zeta)
	var b := (
		cos(theta) * cos(declination) * cos(right_ascension + zeta) - sin(theta) * sin(declination)
	)
	var c := (
		sin(theta) * cos(declination) * cos(right_ascension + zeta) + cos(theta) * sin(declination)
	)
	return Vector4(
		wrapf(rad_to_deg(atan2(a, b) + z), 0.0, 360.0),
		rad_to_deg(asin(clampf(c, -1.0, 1.0))),
		star.z,
		star.w
	)


static func build_rain(amount: int = RAIN_PARTICLES_RECOMMENDED) -> GPUParticles3D:
	var rain := GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = clampi(amount, RAIN_PARTICLES_MINIMUM, RAIN_PARTICLES_RECOMMENDED)
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
	# R-1501: drops already fall at terminal speed; gravity would straighten the
	# wind slant SkyWeather3D._update_rain() sets on the direction.
	process.gravity = Vector3.ZERO
	process.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	rain.process_material = process
	# Stretched unshaded streaks; built from primitives, no texture assets.
	var streak := BoxMesh.new()
	streak.size = Vector3(0.010, 0.36, 0.010)
	var streak_material := StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.albedo_color = Color(0.68, 0.73, 0.78, 0.28)
	streak.material = streak_material
	rain.draw_pass_1 = streak
	rain.visible = false
	return rain
