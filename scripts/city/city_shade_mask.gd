class_name CityShadeMask
extends RefCounted

## Where the ground stays in shade long enough for moss (R-1661), as an RG
## texture over the plan bounds (the splat rect) for city_ground.gdshader.
## R: the strip north (world -Z) of every building, where the low northern sun
## never reaches; strongest at the wall foot, fading over about one wall height.
## G: canopy shade of the woods, from the density of forest trees (orchard
## trees stand in mown yards and do not count).
##
## Why baked: the ground shader has no notion of buildings or crowns, and a
## per-pixel shadow lookup would cost every ground fragment. Two passes over the
## plan at load are cheap: buildings touch only their own bounding boxes, and
## the canopy is splatted on a coarse grid and smoothed by a native resize.

const CELL := 2.0  ## world units per mask pixel
const CANOPY_CELL := 12.0  ## world units per canopy density cell
## Forest trees in one canopy cell that count as closed canopy.
const CANOPY_FULL := 5.0
## North strip length as a share of the wall height, and its clamp in world units.
const STRIP_SHARE := 0.9
const STRIP_MIN := 2.0
const STRIP_MAX := 8.0
const OPEN_GROUND_TREES := [&"apple", &"cherry", &"plum", &"pear", &"juniper"]


static func build_image(plan: CityPlan) -> Image:
	var size := Vector2i(
		maxi(int(ceil(plan.bounds.size.x / CELL)), 1), maxi(int(ceil(plan.bounds.size.y / CELL)), 1)
	)
	var red := PackedByteArray()
	red.resize(size.x * size.y)
	for i in plan.buildings.size():
		_building_strip(plan, i, size, red)
	var canopy := canopy_image(plan)
	canopy.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	var data := PackedByteArray()
	data.resize(size.x * size.y * 2)
	var green := canopy.get_data()
	for i in red.size():
		data[i * 2] = red[i]
		data[i * 2 + 1] = green[i]
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_RG8, data)


static func texture(plan: CityPlan) -> ImageTexture:
	return ImageTexture.create_from_image(build_image(plan))


## Coarse canopy density (FORMAT_L8): 255 where a cell holds CANOPY_FULL forest trees.
static func canopy_image(plan: CityPlan) -> Image:
	var size := Vector2i(
		maxi(int(ceil(plan.bounds.size.x / CANOPY_CELL)), 1),
		maxi(int(ceil(plan.bounds.size.y / CANOPY_CELL)), 1)
	)
	var counts := PackedFloat32Array()
	counts.resize(size.x * size.y)
	for t: Array in plan.data.get("trees", []):
		if OPEN_GROUND_TREES.has(StringName(t[2])):
			continue
		var c := Vector2i(
			floori((float(t[0]) - plan.bounds.position.x) / CANOPY_CELL),
			floori((float(t[1]) - plan.bounds.position.y) / CANOPY_CELL)
		)
		if c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y:
			counts[c.y * size.x + c.x] += 1.0
	var bytes := PackedByteArray()
	bytes.resize(counts.size())
	for i in counts.size():
		bytes[i] = int(clampf(counts[i] / CANOPY_FULL, 0.0, 1.0) * 255.0)
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_L8, bytes)


## Shade value (0..1) of the R channel at a world point; for tests and tools.
static func strip_at(image: Image, plan: CityPlan, world_xz: Vector2) -> float:
	var p := Vector2i(((world_xz - plan.bounds.position) / CELL).floor())
	if p.x < 0 or p.y < 0 or p.x >= image.get_width() or p.y >= image.get_height():
		return 0.0
	return image.get_pixelv(p).r


static func _building_strip(
	plan: CityPlan, index: int, size: Vector2i, red: PackedByteArray
) -> void:
	var ring := plan.footprint(index)
	if ring.size() < 3:
		return
	var b: Dictionary = plan.buildings[index]
	var strip := clampf(float(b.get("wall_h", 4.0)) * STRIP_SHARE, STRIP_MIN, STRIP_MAX)
	var strip_px := maxi(int(ceil(strip / CELL)), 1)
	var lo := ring[0]
	var hi := ring[0]
	for p in ring:
		lo = lo.min(p)
		hi = hi.max(p)
	var x0 := maxi(floori((lo.x - plan.bounds.position.x) / CELL), 0)
	var x1 := mini(floori((hi.x - plan.bounds.position.x) / CELL), size.x - 1)
	var y0 := maxi(floori((lo.y - plan.bounds.position.y) / CELL), 0)
	var y1 := mini(floori((hi.y - plan.bounds.position.y) / CELL), size.y - 1)
	for x in range(x0, x1 + 1):
		# The northmost (lowest z) pixel of the footprint in this column casts the strip.
		var wx := plan.bounds.position.x + (float(x) + 0.5) * CELL
		var north_row := -1
		for y in range(y0, y1 + 1):
			var wz := plan.bounds.position.y + (float(y) + 0.5) * CELL
			if Geometry2D.is_point_in_polygon(Vector2(wx, wz), ring):
				north_row = y
				break
		if north_row < 0:
			continue
		for k in range(0, strip_px + 1):
			var y := north_row - k
			if y < 0:
				break
			var v := int(255.0 * (1.0 - float(k) / float(strip_px + 1)))
			var at := y * size.x + x
			red[at] = maxi(red[at], v)
