class_name MapViewMaterialPatterns
extends RefCounted

## Procedural grayscale detail textures multiplied with palette albedo tints.


static var _cache: Dictionary = {}


static func reset() -> void:
	_cache.clear()


static func pattern_texture(pattern: StringName, noise_seed: int) -> ImageTexture:
	var key := "pattern:%s:%d" % [String(pattern), noise_seed]
	if _cache.has(key):
		return _cache[key]
	var image := Image.create(MapViewMaterials.TEXTURE_SIZE, MapViewMaterials.TEXTURE_SIZE, false, Image.FORMAT_RGB8)
	match pattern:
		MapViewMaterials.PATTERN_COBBLE:
			_paint_cobble(image, noise_seed)
		MapViewMaterials.PATTERN_BRICK:
			_paint_brick(image, noise_seed)
		MapViewMaterials.PATTERN_PLANK:
			_paint_plank(image, noise_seed)
		MapViewMaterials.PATTERN_LIMESTONE:
			_paint_limestone(image, noise_seed)
		MapViewMaterials.PATTERN_ROOF_TILE:
			_paint_roof_tile(image, noise_seed)
		MapViewMaterials.PATTERN_STRAW:
			_paint_straw(image, noise_seed)
		MapViewMaterials.PATTERN_SPECKLE:
			_paint_speckle(image, noise_seed)
		MapViewMaterials.PATTERN_PLASTER:
			_paint_plaster(image, noise_seed)
		_:
			_paint_grass(image, noise_seed)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


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


static func _paint_plaster(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var broad := _lattice(float(x) / 24.0, float(y) / 24.0, size / 24, noise_seed)
			var fine := _lattice(float(x) / 6.0, float(y) / 6.0, size / 6, noise_seed + 77)
			_fill_value(image, x, y, 0.88 + broad * 0.09 + fine * 0.05)


## Rounded field stones packed on a jittered grid with dark seams (Worley-ish).
static func _paint_cobble(image: Image, noise_seed: int) -> void:
	var size := image.get_width()
	var stones := 8
	var cell := float(size) / float(stones)
	for y in size:
		for x in size:
			var best := 10.0
			var tone := 0.0
			var gx := floori(float(x) / cell)
			var gy := floori(float(y) / cell)
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var sx := posmod(gx + ox, stones)
					var sy := posmod(gy + oy, stones)
					var jx := (float(gx + ox) + 0.25 + _hash01(sx, sy, noise_seed) * 0.5) * cell
					var jy := (float(gy + oy) + 0.25 + _hash01(sx, sy, noise_seed + 13) * 0.5) * cell
					var distance := Vector2(x - jx, y - jy).length() / cell
					if distance < best:
						best = distance
						tone = _hash01(sx, sy, noise_seed + 29)
			var dome := clampf(1.0 - best * best * 1.4, 0.0, 1.0)
			var value := 0.55 + dome * 0.42 + (tone - 0.5) * 0.14
			_fill_value(image, x, y, value)


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
