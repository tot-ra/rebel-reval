class_name CitySnow
extends RefCounted

## Snow lying on the city ground: how deep, where. One baked map (`bake`) holds a
## relative depth FACTOR per 8 m texel (wind drifts from layered noise, deeper in
## woods where it is sheltered, bare on paving, steep slopes, water and under
## roofs). The ground shader lifts the terrain by the same map, and the CPU reads
## it for walking drag, footprints and the crunch, so what you see, what slows
## you and what you hear agree. Depth in world units (1 unit = 1 m here):
##
##   depth = max(cover * MAX_DEPTH_M * factor - EDGE, 0)
##
## `cover` is the season's settled-snow share (0..1). Factor runs 0..~1.7: a drift
## at full cover is over half a metre, knee-deep and more in the woods.
## Presentation and walking drag only; the map is derived data, never saved.

## Settled depth at factor 1 and full cover.
const MAX_DEPTH_M := 0.5
## Depth lost to settling/thin cover: below it the ground shows through.
const EDGE := 0.04
const TEXEL := 8.0
## Factor is stored as value / FACTOR_SCALE in an 8-bit channel.
const FACTOR_SCALE := 2.0
## Above this lying value (depth over 2 cm) a foot is in snow, not on the ground.
const LYING := 0.45
const LYING_DEPTH := 0.05
## Walking: knee depth slows to a crawl; past this, only a trodden road is passable.
const DRAG_START := 0.06
const DRAG_KNEE := 0.35
const DRAG_DEEP := 0.5
const DRAG_KNEE_SPEED := 0.45
const DRAG_DEEP_SPEED := 0.08
## Trees within this of a texel count towards the wood.
const FOREST_TREES_FULL := 5.0

static var _grid := PackedFloat32Array()
static var _cols := 0
static var _rows := 0
static var _origin := Vector2.ZERO


static func _fract(x: float) -> float:
	return x - floorf(x)


static func hash12(p: Vector2) -> float:
	var a := _fract(p.x * 0.1031)
	var b := _fract(p.y * 0.1031)
	var c := _fract(p.x * 0.1031)
	var dot_value := a * (b + 33.33) + b * (c + 33.33) + c * (a + 33.33)
	a += dot_value
	b += dot_value
	c += dot_value
	return _fract((a + b) * c)


static func value_noise(p: Vector2) -> float:
	var i := Vector2(floorf(p.x), floorf(p.y))
	var f := Vector2(p.x - i.x, p.y - i.y)
	var u := Vector2(f.x * f.x * (3.0 - 2.0 * f.x), f.y * f.y * (3.0 - 2.0 * f.y))
	var bottom := lerpf(hash12(i), hash12(i + Vector2(1.0, 0.0)), u.x)
	var top := lerpf(hash12(i + Vector2(0.0, 1.0)), hash12(i + Vector2(1.0, 1.0)), u.x)
	return lerpf(bottom, top, u.y)


## The wind-drift part of the factor, from noise alone: long dunes and short
## ridges. Used for every texel of the baked map and as the fallback without one.
static func drift_factor(p: Vector2) -> float:
	var dunes := value_noise(p * 0.022 + Vector2(17.0, 53.0))
	var ridges := value_noise(p * 0.085 + Vector2(91.0, 7.0))
	return maxf(0.12 + 1.35 * pow(dunes, 1.35) + 0.6 * (ridges - 0.5), 0.0)


static func has_map() -> bool:
	return _cols > 0


## Bakes the factor map for the plan and returns it as a texture for the ground
## shader (rect: origin xz, size xz in world units). `paving_at` is the splat
## lookup (Color, r = paving); `water` the CityWorld3D swim records
## [a, b, surface_a, surface_b, half_width]; `trees` the plan's tree rows.
static func bake(
	plan: CityPlan, paving_at: Callable, trees: Array, water: Array
) -> ImageTexture:
	# Locals throughout: static-variable access in a 40 000-texel loop is the cost.
	var origin := plan.bounds.position
	var cols := int(ceil(plan.bounds.size.x / TEXEL))
	var rows := int(ceil(plan.bounds.size.y / TEXEL))
	var forest := PackedFloat32Array()
	forest.resize(cols * rows)
	for t: Array in trees:
		var cx0 := floori((float(t[0]) - origin.x) / TEXEL)
		var cy0 := floori((float(t[1]) - origin.y) / TEXEL)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var cx := cx0 + dx
				var cy := cy0 + dy
				if cx >= 0 and cy >= 0 and cx < cols and cy < rows:
					forest[cy * cols + cx] += 1.0 if (dx == 0 and dy == 0) else 0.5
	var wet := PackedByteArray()
	wet.resize(cols * rows)
	for rec: Array in water:
		var a: Vector2 = rec[0]
		var b: Vector2 = rec[1]
		var reach := int(ceil((float(rec[4]) + 3.0) / TEXEL))
		var steps := maxi(int(a.distance_to(b) / (TEXEL * 0.6)), 1)
		for k in steps + 1:
			var at := a.lerp(b, float(k) / float(steps))
			var cx0 := floori((at.x - origin.x) / TEXEL)
			var cy0 := floori((at.y - origin.y) / TEXEL)
			for dy in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var cx := cx0 + dx
					var cy := cy0 + dy
					if cx >= 0 and cy >= 0 and cx < cols and cy < rows:
						wet[cy * cols + cx] = 1
	var grid := PackedFloat32Array()
	grid.resize(cols * rows)
	var data := PackedByteArray()
	data.resize(cols * rows)
	for cy in rows:
		for cx in cols:
			var index := cy * cols + cx
			var p := origin + Vector2((cx + 0.5) * TEXEL, (cy + 0.5) * TEXEL)
			var f := 0.0
			# Cheapest exclusions first; only live texels pay for the noise and the plan.
			if wet[index] == 0 and plan.ground_height(p) >= 0.4 and plan.building_at(p) < 0:
				f = drift_factor(p)
				f *= 1.0 + 0.45 * clampf(forest[index] / FOREST_TREES_FULL, 0.0, 1.0)
				f *= 1.0 - 0.95 * smoothstep(0.25, 0.7, (paving_at.call(p) as Color).r)
				f *= 1.0 - smoothstep(0.35, 0.8, plan.slope_at(p))
				if f > 0.0 and plan.site_at(p) != null:
					f = 0.0
			grid[index] = f
			data[index] = int(clampf(f / FACTOR_SCALE, 0.0, 1.0) * 255.0 + 0.5)
	_origin = origin
	_cols = cols
	_rows = rows
	_grid = grid
	var image := Image.create_from_data(cols, rows, false, Image.FORMAT_R8, data)
	return ImageTexture.create_from_image(image)


## World rect the baked texture covers: origin xz, size xz.
static func map_rect() -> Vector4:
	return Vector4(
		_origin.x, _origin.y, float(_cols) * TEXEL, float(_rows) * TEXEL
	)


static func clear_map() -> void:
	_grid = PackedFloat32Array()
	_cols = 0
	_rows = 0


## Relative depth at `p`, bilinear over the baked map (noise alone without one).
static func factor_at(p: Vector2) -> float:
	if _cols == 0:
		return drift_factor(p)
	var f := (p - _origin) / TEXEL - Vector2(0.5, 0.5)
	var x0 := clampi(floori(f.x), 0, _cols - 1)
	var y0 := clampi(floori(f.y), 0, _rows - 1)
	var x1 := mini(x0 + 1, _cols - 1)
	var y1 := mini(y0 + 1, _rows - 1)
	var tx := clampf(f.x - float(x0), 0.0, 1.0)
	var ty := clampf(f.y - float(y0), 0.0, 1.0)
	var top := lerpf(_grid[y0 * _cols + x0], _grid[y0 * _cols + x1], tx)
	var bottom := lerpf(_grid[y1 * _cols + x0], _grid[y1 * _cols + x1], tx)
	return lerpf(top, bottom, ty)


## Settled snow depth in metres at `world_xz` for a season cover of 0..1.
static func depth_at(world_xz: Vector2, cover: float) -> float:
	if cover <= 0.001:
		return 0.0
	return maxf(cover * MAX_DEPTH_M * factor_at(world_xz) - EDGE, 0.0)


## 0..1 "snow lies here", for footsteps and prints.
static func patch(world_xz: Vector2, cover: float) -> float:
	return clampf(depth_at(world_xz, cover) / LYING_DEPTH, 0.0, 1.0)


## Walking speed multiplier for snow `depth` deep: free on a dusting, a crawl at the
## knee, close to stuck above half a metre (a trodden road stays clear in the map).
static func walk_drag(depth: float) -> float:
	if depth <= DRAG_START:
		return 1.0
	if depth <= DRAG_KNEE:
		return lerpf(1.0, DRAG_KNEE_SPEED, smoothstep(DRAG_START, DRAG_KNEE, depth))
	return lerpf(DRAG_KNEE_SPEED, DRAG_DEEP_SPEED, smoothstep(DRAG_KNEE, DRAG_DEEP, depth))
