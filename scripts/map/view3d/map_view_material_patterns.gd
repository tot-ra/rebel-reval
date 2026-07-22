class_name MapViewMaterialPatterns
extends RefCounted

## Procedural grayscale detail textures multiplied with palette albedo tints.


static var _cache: Dictionary = {}

## The 4 m world-space terrain tile carries the same 5 x 7 stones per metre as
## the former first-person MultiMesh, but all stones are baked into two textures.
## Even counts preserve running-bond parity at both wrapping edges.
const COBBLE_STONES_X := 20
const COBBLE_STONES_Y := 28


static func reset() -> void:
	_cache.clear()


static func pattern_texture(pattern: StringName, noise_seed: int) -> ImageTexture:
	var texture_size := MapViewMaterials.TEXTURE_SIZE
	if pattern == MapViewMaterials.PATTERN_COBBLE:
		texture_size = MapViewMaterials.COBBLE_TEXTURE_SIZE
	return _pattern_texture_at_size(pattern, noise_seed, texture_size)


## Terrain splatting keeps its general-purpose array compact and binds the two
## cobble layers separately at high resolution. Explicit sizing also guarantees
## that every image inside a Texture2DArray has matching dimensions.
static func pattern_texture_at_size(pattern: StringName, noise_seed: int, texture_size: int) -> ImageTexture:
	return _pattern_texture_at_size(pattern, noise_seed, texture_size)


## Building surfaces need per-instance wear so adjacent houses do not share one
## baked albedo map. Weathering stays deterministic from the stable building ID.
static func pattern_texture_weathered(
	pattern: StringName,
	noise_seed: int,
	weathering: StringName,
	texture_size: int = MapViewMaterials.TEXTURE_SIZE
) -> ImageTexture:
	var key := "pattern:%s:%d:%s:%d" % [String(pattern), noise_seed, String(weathering), texture_size]
	if _cache.has(key):
		return _cache[key]
	var image := _pattern_image_at_size(pattern, noise_seed, texture_size)
	_apply_surface_weathering(image, weathering, noise_seed)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func _pattern_texture_at_size(pattern: StringName, noise_seed: int, texture_size: int) -> ImageTexture:
	var key := "pattern:%s:%d:%d" % [String(pattern), noise_seed, texture_size]
	if _cache.has(key):
		return _cache[key]
	var image := _pattern_image_at_size(pattern, noise_seed, texture_size)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func _pattern_image_at_size(pattern: StringName, noise_seed: int, texture_size: int) -> Image:
	var image := Image.create(texture_size, texture_size, false, Image.FORMAT_RGB8)
	match pattern:
		MapViewMaterials.PATTERN_COBBLE:
			_paint_cobble(image, noise_seed)
		MapViewMaterials.PATTERN_BRICK:
			_paint_brick(image, noise_seed)
		MapViewMaterials.PATTERN_BARK:
			_paint_bark(image, noise_seed)
		MapViewMaterials.PATTERN_BIRCH_BARK:
			_paint_birch_bark(image, noise_seed)
		MapViewMaterials.PATTERN_CHERRY_BARK:
			_paint_cherry_bark(image, noise_seed)
		MapViewMaterials.PATTERN_PLANK:
			_paint_plank(image, noise_seed)
		MapViewMaterials.PATTERN_LIMESTONE:
			_paint_limestone(image, noise_seed)
		MapViewMaterials.PATTERN_ROCK:
			_paint_rock(image, noise_seed)
		MapViewMaterials.PATTERN_ROOF_TILE:
			_paint_roof_tile(image, noise_seed)
		MapViewMaterials.PATTERN_STRAW:
			_paint_straw(image, noise_seed)
		MapViewMaterials.PATTERN_THATCH:
			_paint_thatch(image, noise_seed)
		MapViewMaterials.PATTERN_SHINGLE:
			_paint_shingle(image, noise_seed)
		MapViewMaterials.PATTERN_LOG:
			_paint_log(image, noise_seed)
		MapViewMaterials.PATTERN_SPECKLE:
			_paint_speckle(image, noise_seed)
		MapViewMaterials.PATTERN_MUD:
			_paint_mud(image, noise_seed)
		MapViewMaterials.PATTERN_PLASTER:
			_paint_plaster(image, noise_seed)
		_:
			_paint_grass(image, noise_seed)
	return image


## Post-process a painted grayscale pattern with deterministic wear, damp,
## repair, or fresh treatments. Keeps palette-led tinting in MapViewMaterials.
static func _apply_surface_weathering(image: Image, weathering: StringName, noise_seed: int) -> void:
	if weathering == MapViewMaterials.WEATHER_FRESH:
		return
	var size := image.get_width()
	for y in size:
		for x in size:
			var value := image.get_pixel(x, y).r
			match weathering:
				MapViewMaterials.WEATHER_WORN:
					value = clampf(value * 0.95 + 0.03, 0.0, 1.0)
					if _hash01(x, y, noise_seed + 401) > 0.93:
						value += 0.07
				MapViewMaterials.WEATHER_DAMP:
					value *= 0.9
					if _hash01(x / 7, y / 9, noise_seed + 503) > 0.58:
						value -= 0.07
				MapViewMaterials.WEATHER_REPAIRED:
					if _hash01(x / 11, y / 9, noise_seed + 607) > 0.78:
						value = lerpf(value, 0.94, 0.62)
				_:
					pass
			_fill_value(image, x, y, value)


static func _hash01(x: int, y: int, noise_seed: int) -> float:
	var hashed := ((x * 374761393) + (y * 668265263) + noise_seed * 69069) & 0x7fffffff
	hashed = (hashed ^ (hashed >> 13)) * 1274126177 & 0x7fffffff
	return float(hashed % 100000) / 99999.0


## Tileable smooth value noise: bilinear blend of a wrapped lattice.
static func _lattice(x: float, y: float, period: int, noise_seed: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var fx := x - float(xi)
	var fy := y - float(yi)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x0 := posmod(xi, period)
	var x1 := posmod(xi + 1, period)
	var y0 := posmod(yi, period)
	var y1 := posmod(yi + 1, period)
	var a := _hash01(x0, y0, noise_seed)
	var b := _hash01(x1, y0, noise_seed)
	var c := _hash01(x0, y1, noise_seed)
	var d := _hash01(x1, y1, noise_seed)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func _fill_value(image: Image, x: int, y: int, value: float) -> void:
	var v := clampf(value, 0.0, 1.0)
	image.set_pixel(x, y, Color(v, v, v))


static func _paint_grass(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var broad := _lattice(float(x) / 16.0, float(y) / 16.0, size / 16, noise_seed)
			var fine := _lattice(float(x) / 5.0, float(y) / 5.0, size / 5, noise_seed + 51)
			var streak := _lattice(float(x) / 3.0, float(y) / 11.0, size / 3, noise_seed + 907)
			var value := 0.82 + broad * 0.16 + fine * 0.10
			if streak > 0.78:
				value += 0.07
			elif streak < 0.2:
				value -= 0.06
			_fill_value(image, x, y, value)


## Darker, clumpy wet soil with shallow ripple troughs for mud and puddle rims.
static func _paint_mud(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var broad := _lattice(float(x) / 14.0, float(y) / 14.0, size / 14, noise_seed)
			var clump := _lattice(float(x) / 5.0, float(y) / 5.0, size / 5, noise_seed + 61)
			var trough := _lattice(float(x) / 9.0, float(y) / 11.0, size / 9, noise_seed + 907)
			var value := 0.68 + broad * 0.12 + clump * 0.10
			if trough > 0.72:
				value -= 0.14
			elif trough < 0.22:
				value += 0.08
			_fill_value(image, x, y, value)


static func _paint_speckle(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var broad := _lattice(float(x) / 20.0, float(y) / 20.0, size / 20, noise_seed)
			var fine := _hash01(x, y, noise_seed + 3)
			var value := 0.84 + broad * 0.14 + (fine - 0.5) * 0.08
			if fine > 0.965:
				value -= 0.18
			elif fine < 0.02:
				value += 0.12
			_fill_value(image, x, y, value)


## Tree bark uses organic vertical grain instead of the construction-plank grid.
static func _paint_bark(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var furrow := absf(sin(float(x) * 0.31 + _lattice(float(x) / 7.0, float(y) / 19.0, maxi(size / 7, 2), noise_seed) * 3.0))
			var grain := _lattice(float(x) / 5.0, float(y) / 24.0, maxi(size / 5, 2), noise_seed + 41)
			_fill_value(image, x, y, 0.62 + furrow * 0.27 + grain * 0.09)


## Pale birch paper bark with dark horizontal lenticels and irregular peeling.
static func _paint_birch_bark(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var paper := 0.88 + _lattice(float(x) / 18.0, float(y) / 22.0, maxi(size / 18, 2), noise_seed) * 0.10
			var band_row := posmod(y + int(_hash01(y / 5, 3, noise_seed) * 7.0), 17)
			var lenticel := band_row < 2 and _hash01(x / 7, y / 17, noise_seed + 83) > 0.43
			if lenticel:
				paper *= 0.30 + _hash01(x, y, noise_seed + 97) * 0.20
			_fill_value(image, x, y, paper)


## Cherry bark has smooth reddish bands and fine pale horizontal pores.
static func _paint_cherry_bark(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var smooth := 0.72 + _lattice(float(x) / 24.0, float(y) / 16.0, maxi(size / 24, 2), noise_seed) * 0.20
			if posmod(y + int(_hash01(y / 9, 4, noise_seed) * 5.0), 13) == 0 and _hash01(x / 5, y, noise_seed + 109) > 0.34:
				smooth += 0.16
			_fill_value(image, x, y, smooth)


static func _paint_plaster(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var broad := _lattice(float(x) / 24.0, float(y) / 24.0, size / 24, noise_seed)
			var fine := _lattice(float(x) / 6.0, float(y) / 6.0, size / 6, noise_seed + 77)
			_fill_value(image, x, y, 0.88 + broad * 0.09 + fine * 0.05)


## Dense running-bond cobbles baked into one continuous surface. Stone centers
## stay close enough that the narrow remainder reads as compacted sand/earth,
## never empty space. Low domes and chipped edges feed both albedo and a matching
## normal map, so street-level relief costs no per-stone geometry or draw calls.
static func _paint_cobble(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var sample := _cobble_surface_sample(x, y, size, noise_seed)
			var height := sample.r
			var joint := sample.g
			var stone_tone := sample.a
			var broad := _lattice(float(x) / 41.0, float(y) / 47.0, maxi(size / 47, 2), noise_seed + 47)
			var fine := _lattice(float(x) / 5.0, float(y) / 5.0, maxi(size / 5, 2), noise_seed + 83)
			# Earth-filled joints stay darker than stone faces so the shader dirt
			# veil reads as compacted mud, not bright sand between clean tiles.
			var stone := 0.58 + stone_tone * 0.14 + height * 0.08
			stone += (broad - 0.5) * 0.08 + (fine - 0.5) * 0.03
			var earth := 0.48 + broad * 0.08 + fine * 0.03
			_fill_value(image, x, y, lerpf(earth, stone, joint))


## RGBA contract used by the terrain shader:
## - RG: baked tangent-space normal XY
## - B: stone mask (0 compacted joint, 1 stone)
## - A: deterministic per-stone palette selector
static func cobble_surface_texture(noise_seed: int) -> ImageTexture:
	var key := "cobble_surface:%d:%d" % [noise_seed, MapViewMaterials.COBBLE_TEXTURE_SIZE]
	if _cache.has(key):
		return _cache[key]
	var size := MapViewMaterials.COBBLE_TEXTURE_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var sample := _cobble_surface_sample(x, y, size, noise_seed)
			var left := _cobble_surface_sample(x - 1, y, size, noise_seed).r
			var right := _cobble_surface_sample(x + 1, y, size, noise_seed).r
			var up := _cobble_surface_sample(x, y - 1, size, noise_seed).r
			var down := _cobble_surface_sample(x, y + 1, size, noise_seed).r
			# A restrained slope keeps the stones pressed into the road. The old real
			# mesh rose 7 cm; this reads closer to a worn 1-2 cm shoulder.
			var normal := Vector3((left - right) * 0.28, (up - down) * 0.28, 1.0).normalized()
			image.set_pixel(x, y, Color(
				normal.x * 0.5 + 0.5,
				normal.y * 0.5 + 0.5,
				sample.g,
				sample.b
			))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## Returns one sample from a seamless, staggered rounded-rectangle lattice.
## The signed superellipse distance makes stones flatter and less inflated than
## radial Voronoi domes, while low-frequency edge wear keeps them old and uneven.
static func _cobble_surface_sample(x: int, y: int, size: int, noise_seed: int) -> Color:
	# Neighbor reads for the baked normal map cross the image edge. Wrap them
	# before all shape/noise work so albedo and normals share the exact same seam.
	var wrapped_x := posmod(x, size)
	var wrapped_y := posmod(y, size)
	var px := (float(wrapped_x) + 0.5) / float(size) * float(COBBLE_STONES_X)
	var py := (float(wrapped_y) + 0.5) / float(size) * float(COBBLE_STONES_Y)
	var row := floori(py)
	var stagger := 0.5 if posmod(row, 2) == 1 else 0.0
	var column := floori(px - stagger)
	var local := Vector2(px - stagger - (float(column) + 0.5), py - (float(row) + 0.5))
	var wrapped_column := posmod(column, COBBLE_STONES_X)
	var wrapped_row := posmod(row, COBBLE_STONES_Y)
	var length_scale := 0.97 + _hash01(wrapped_column, wrapped_row, noise_seed + 11) * 0.04
	var width_scale := 0.95 + _hash01(wrapped_column, wrapped_row, noise_seed + 17) * 0.04
	var jitter := Vector2(
		_hash01(wrapped_column, wrapped_row, noise_seed + 23) - 0.5,
		_hash01(wrapped_column, wrapped_row, noise_seed + 29) - 0.5
	) * 0.045
	local -= jitter
	local.x /= length_scale
	local.y /= width_scale
	# A high-order superellipse gives worn rectangular stones with rounded corners.
	var shape := pow(pow(absf(local.x) / 0.5, 4.0) + pow(absf(local.y) / 0.49, 4.0), 0.25)
	var edge_wear := (_hash01(wrapped_x, wrapped_y, noise_seed + 37) - 0.5) * 0.025
	var signed_edge := 1.0 - shape + edge_wear
	var joint := smoothstep(-0.005, 0.055, signed_edge)
	# Most stone is nearly flush. Only its worn shoulder bends the normal, avoiding
	# the high, pillow-like profile that made the previous geometry look too new.
	var height := smoothstep(-0.02, 0.24, signed_edge)
	height = lerpf(0.28, 0.78, height) * joint
	var chips := _hash01(wrapped_x / 3, wrapped_y / 3, noise_seed + 43)
	if chips < 0.08 and signed_edge < 0.14:
		height *= 0.72
	var palette := _hash01(wrapped_column, wrapped_row, noise_seed + 53)
	var tone := _hash01(wrapped_column, wrapped_row, noise_seed + 59)
	return Color(height, joint, palette, tone)


static func _paint_brick(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	# Half the legacy course/brick span so each tile carries more bricks; UV
	# repeats on building faces finish the scale for typical house footprints.
	# Keep brick_w >> course so stretcher courses stay visibly horizontal.
	var course := 5
	var brick_w := 16
	for y in size:
		var row := y / course
		var in_course := y % course
		for x in size:
			var offset := (row % 2) * brick_w / 2
			var column := (x + offset) / brick_w
			var in_brick := (x + offset) % brick_w
			var tone := _hash01(column, row, noise_seed)
			var value := 0.82 + (tone - 0.5) * 0.16
			value += _lattice(float(x) / 7.0, float(y) / 7.0, size / 7, noise_seed + 5) * 0.06
			if in_course < 1 or in_brick < 1:
				value = 0.62 + _hash01(x, y, noise_seed + 9) * 0.06
			_fill_value(image, x, y, value)


static func _paint_plank(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	var plank := 16
	for y in size:
		var row := y / plank
		var in_plank := y % plank
		for x in size:
			var grain := _lattice(float(x) / 4.0, float(y) / 18.0, size / 4, noise_seed + row * 131)
			var value := 0.80 + grain * 0.18
			value += sin(float(x) * 0.35 + float(row) * 2.1) * 0.02
			if in_plank < 1:
				value = 0.52
			elif in_plank == 1:
				value -= 0.10
			# Occasional butt joint inside a course.
			if posmod(x + int(_hash01(row, 0, noise_seed) * 100.0), 96) < 1:
				value = 0.55
			_fill_value(image, x, y, value)


## Weathered coastal boulder: mottled grain, lichen flecks, and diagonal
## fissures without ashlar courses or brick-like horizontal bands.
static func _paint_rock(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var broad := _lattice(float(x) / 18.0, float(y) / 18.0, size / 18, noise_seed)
			var medium := _lattice(float(x) / 7.0, float(y) / 7.0, size / 7, noise_seed + 31)
			var fine := _lattice(float(x) / 2.5, float(y) / 2.5, size / 3, noise_seed + 67)
			var speckle := _hash01(x, y, noise_seed + 11)
			var value := 0.70 + broad * 0.14 + medium * 0.10 + fine * 0.06
			value += (speckle - 0.5) * 0.08
			if speckle > 0.93:
				value += 0.10
			elif speckle < 0.04:
				value -= 0.12
			var fissure := _lattice(float(x + y) / 5.0, float(x - y) / 8.0, size / 5, noise_seed + 103)
			if fissure > 0.88:
				value -= 0.14
			_fill_value(image, x, y, value)


## Irregular ashlar courses: Tallinn's grey limestone masonry. Keep block width
## well above course height so tall fortification walls read horizontal courses.
static func _paint_limestone(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	var courses := 16
	var course_h := size / courses
	for y in size:
		var row := y / course_h
		var in_course := y % course_h
		for x in size:
			var width := 16 + int(_hash01(row, 3, noise_seed) * 12.0)
			var offset := int(_hash01(row, 7, noise_seed + 3) * 24.0)
			var column := (x + offset) / width
			var in_block := (x + offset) % width
			var tone := _hash01(column, row, noise_seed + 17)
			var value := 0.80 + (tone - 0.5) * 0.18
			value += _lattice(float(x) / 9.0, float(y) / 9.0, size / 9, noise_seed + 23) * 0.08
			if in_course < 1 or in_block < 1:
				value = 0.58 + _hash01(x, y, noise_seed + 31) * 0.05
			_fill_value(image, x, y, value)


## Overlapping tile courses: each row shades darker toward its lower edge and
## staggers its vertical joints, reading as hand-laid clay tiles.
static func _paint_roof_tile(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	var course := 10
	var tile_w := 10
	for y in size:
		var row := y / course
		var in_course := y % course
		for x in size:
			var offset := (row % 2) * tile_w / 2
			var column := (x + offset) / tile_w
			var in_tile := (x + offset) % tile_w
			var tone := _hash01(column, row, noise_seed)
			# Curved tile profile: brighter crown at tile center.
			var profile := sin(float(in_tile) / float(tile_w) * PI)
			var value := 0.72 + profile * 0.20 + (tone - 0.5) * 0.14
			# Overlap shadow at the bottom of each course.
			value -= clampf(1.0 - float(in_course) / 5.0, 0.0, 1.0) * 0.22
			if in_tile < 1:
				value -= 0.12
			_fill_value(image, x, y, value)


static func _paint_straw(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var strand := _lattice(float(x) / 2.0, float(y) / 14.0, size / 2, noise_seed)
			var broad := _lattice(float(x) / 20.0, float(y) / 20.0, size / 20, noise_seed + 41)
			_fill_value(image, x, y, 0.74 + strand * 0.20 + broad * 0.08)


## Reed/straw thatch courses for roofs: layered bundles with vertical reed
## strands, soft drip shadows at each course edge, and irregular bindings so
## coastal huts read as bundled reed rather than flat hay terrain.
static func _paint_thatch(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	var course := 12
	for y in size:
		var row := y / course
		var in_course := y % course
		# Wobble the course seam so thatch layers do not read as machine rows.
		var seam_wobble := int(_hash01(row, 3, noise_seed + 11) * 3.0) - 1
		var local_y := posmod(in_course - seam_wobble, course)
		for x in size:
			var tone := _hash01(x / 5, row, noise_seed)
			# Tight vertical reed strands within each course.
			var strand := _lattice(float(x) / 1.6, float(y) / 10.0, size / 2, noise_seed + 7)
			var clump := _lattice(float(x) / 7.0, float(row), maxi(size / 7, 1), noise_seed + 29)
			var value := 0.68 + strand * 0.24 + (tone - 0.5) * 0.12 + clump * 0.06
			# Overlap shadow where the course above hangs over this one.
			var drip := clampf(1.0 - float(local_y) / 4.5, 0.0, 1.0)
			value -= drip * 0.26
			# Occasional dark binding / weathered patch across a course.
			if local_y < 1:
				value -= 0.08 + _hash01(x, row, noise_seed + 53) * 0.05
			# Sparse reed tips catching light near the mid-course crown.
			if local_y > course / 2 and strand > 0.72:
				value += 0.06
			_fill_value(image, x, y, value)


## Wooden shingle courses: staggered small rectangles with dark drip seams.
## The dominant historic roof cover of 1343 Reval's timber town.
static func _paint_shingle(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	var course := 8
	var shingle_w := 7
	for y in size:
		var row := y / course
		var in_course := y % course
		for x in size:
			var offset := (row % 2) * shingle_w / 2
			var column := (x + offset) / shingle_w
			var in_shingle := (x + offset) % shingle_w
			var tone := _hash01(column, row, noise_seed)
			# Weathered wood: gentle vertical grain per shingle.
			var value := 0.78 + (tone - 0.5) * 0.22
			value += _lattice(float(x) / 3.0, float(y) / 9.0, size / 3, noise_seed + 19) * 0.06
			# Overlap shadow at the bottom edge of each course.
			value -= clampf(1.0 - float(in_course) / 3.0, 0.0, 1.0) * 0.18
			if in_shingle < 1:
				value -= 0.10
			_fill_value(image, x, y, value)


## Horizontal log courses (rõhtpalk): domed log profile with staggered butt
## joints - the vernacular wall of Estonian and poorer burgher houses.
static func _paint_log(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	var course := 12
	for y in size:
		var row := y / course
		var in_course := y % course
		for x in size:
			# Rounded log profile: brightest at the course center.
			var profile := sin(float(in_course) / float(course) * PI)
			var value := 0.62 + profile * 0.30
			value += _lattice(float(x) / 5.0, float(y) / 16.0, size / 5, noise_seed + row * 57) * 0.10
			# Dark seam between logs.
			if in_course < 1:
				value = 0.38 + _hash01(x, row, noise_seed + 7) * 0.06
			# Occasional butt joint where two log ends meet inside a course.
			var joint_x := int(_hash01(row, 0, noise_seed + 13) * float(size))
			if abs(x - joint_x) < 1:
				value -= 0.16
			_fill_value(image, x, y, value)
