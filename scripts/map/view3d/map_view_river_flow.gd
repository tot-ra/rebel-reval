extends RefCounted

## R-1160 follow-up: the per-reach current of an authored river channel.
##
## WHY: the water shader drove every river fragment with one global downstream
## heading, so on a meandering channel like the Pirita the ripples, sheen and
## foam filaments ran across the banks instead of following the water. This
## module reduces the authored TERRAIN_RIVER_WATER cells to a short centreline
## (world XZ plus the local half width) that the shader turns into a local flow
## direction and an across-channel speed profile. It is a pure function of the
## terrain grid, so it runs on a worker beside the shore field bake.
##
## World units are cells here: the map view places cell (x, y) over world XZ
## [x, x+1] x [y, y+1], the same convention the WS-08 shore field uses.

## Shader uniform capacity (map_view_water.gdshader river_path). The shader loops
## over the whole array, so keep this small; a channel is downsampled to fit.
const MAX_POINTS := 24
## A channel narrower than this many cells is treated as decoration, not a river.
const MIN_SPAN_CELLS := 1
## Half widths below this would make the bank drag profile collapse to a step.
const MIN_HALF_WIDTH := 0.75


## Downstream-ordered channel centreline of the map's river cells, or an empty
## array when the map has no usable channel (no river terrain, or a basin too
## wide and short to read as a reach). Each entry is (world_x, world_z,
## half_width). `downstream` only chooses which end is the source; the heading
## itself comes from the authored cell geometry.
static func channel_centreline(
	grid: MapTerrainGrid, downstream: Vector2
) -> PackedVector3Array:
	if grid == null or grid.size_cells.x <= 0 or grid.size_cells.y <= 0:
		return PackedVector3Array()
	var columns := grid.size_cells.x
	var rows := grid.size_cells.y
	# One pass over the grid collects both candidate scan axes at once.
	var row_min := PackedInt32Array()
	var row_max := PackedInt32Array()
	var column_min := PackedInt32Array()
	var column_max := PackedInt32Array()
	row_min.resize(rows)
	row_max.resize(rows)
	column_min.resize(columns)
	column_max.resize(columns)
	row_min.fill(columns)
	row_max.fill(-1)
	column_min.fill(rows)
	column_max.fill(-1)
	var cells := 0
	for y in rows:
		for x in columns:
			if grid.get_terrain(Vector2i(x, y)) != MapTypes.TERRAIN_RIVER_WATER:
				continue
			cells += 1
			row_min[y] = mini(row_min[y], x)
			row_max[y] = maxi(row_max[y], x)
			column_min[x] = mini(column_min[x], y)
			column_max[x] = maxi(column_max[x], y)
	if cells <= 0:
		return PackedVector3Array()
	# Scan across the channel, not along it: a north-south river must be sampled
	# row by row, because each row holds one narrow span, while a column would
	# hold a span as long as the whole river. So the scan axis is the one the
	# channel spans further - rows here, counted as lines that hold river cells.
	var along_rows := _axis_extent(row_min, row_max) >= _axis_extent(column_min, column_max)
	var samples := (
		_samples_along_rows(row_min, row_max)
		if along_rows
		else _samples_along_columns(column_min, column_max)
	)
	if samples.size() < 2:
		return PackedVector3Array()
	if (samples[samples.size() - 1] - samples[0]).dot(Vector3(downstream.x, downstream.y, 0.0)) < 0.0:
		samples.reverse()
	return _smoothed(_downsampled(samples))


## Number of scan lines that hold river cells, used to pick the longer axis.
static func _axis_extent(line_min: PackedInt32Array, line_max: PackedInt32Array) -> int:
	var first := -1
	var last := -1
	for index in line_min.size():
		if line_max[index] < line_min[index]:
			continue
		if first < 0:
			first = index
		last = index
	if first < 0:
		return 0
	return last - first + 1


## (world_x, world_z, half_width) per grid row that holds river cells.
static func _samples_along_rows(
	row_min: PackedInt32Array, row_max: PackedInt32Array
) -> Array[Vector3]:
	var samples: Array[Vector3] = []
	for y in row_min.size():
		var span := row_max[y] - row_min[y] + 1
		if row_max[y] < row_min[y] or span < MIN_SPAN_CELLS:
			continue
		samples.append(
			Vector3(
				(float(row_min[y]) + float(row_max[y]) + 1.0) * 0.5,
				float(y) + 0.5,
				maxf(float(span) * 0.5, MIN_HALF_WIDTH)
			)
		)
	return samples


## (world_x, world_z, half_width) per grid column that holds river cells.
static func _samples_along_columns(
	column_min: PackedInt32Array, column_max: PackedInt32Array
) -> Array[Vector3]:
	var samples: Array[Vector3] = []
	for x in column_min.size():
		var span := column_max[x] - column_min[x] + 1
		if column_max[x] < column_min[x] or span < MIN_SPAN_CELLS:
			continue
		samples.append(
			Vector3(
				float(x) + 0.5,
				(float(column_min[x]) + float(column_max[x]) + 1.0) * 0.5,
				maxf(float(span) * 0.5, MIN_HALF_WIDTH)
			)
		)
	return samples


## Even stride down to MAX_POINTS, always keeping both ends so the polyline still
## covers the whole reach.
static func _downsampled(samples: Array[Vector3]) -> Array[Vector3]:
	if samples.size() <= MAX_POINTS:
		return samples
	var stride := int(ceil(float(samples.size()) / float(MAX_POINTS)))
	var kept: Array[Vector3] = []
	var index := 0
	while index < samples.size() and kept.size() < MAX_POINTS - 1:
		kept.append(samples[index])
		index += stride
	# The strided walk can already have landed on the final sample (whenever the
	# stride divides the last index). Appending it again would leave a zero-length
	# closing reach, and a reach with no length has no heading.
	var last := samples[samples.size() - 1]
	if not kept[kept.size() - 1].is_equal_approx(last):
		kept.append(last)
	return kept


## Three-tap average over the interior points. Authored cell bands step the
## centre by whole cells; without this the heading would jump at every band edge.
static func _smoothed(samples: Array[Vector3]) -> PackedVector3Array:
	var path := PackedVector3Array()
	for index in samples.size():
		if index == 0 or index == samples.size() - 1:
			path.append(samples[index])
			continue
		path.append((samples[index - 1] + samples[index] * 2.0 + samples[index + 1]) * 0.25)
	return path
