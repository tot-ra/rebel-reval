extends "res://tests/godot/test_case.gd"

const GridRegionMerger := preload("res://scripts/map/grid_region_merger.gd")


func test_merges_around_hole_without_filling_it() -> void:
	var cells := _cells_from_rows([
		"#####",
		"#...#",
		"#...#",
		"#####",
	])
	var rects := _merge(Vector2i(5, 4), cells)
	assert_eq(rects, [
		Rect2i(0, 0, 5, 1),
		Rect2i(0, 1, 1, 2),
		Rect2i(4, 1, 1, 2),
		Rect2i(0, 3, 5, 1),
	])
	assert_true(_coverage_is_exact(Vector2i(5, 4), cells, rects))


func test_preserves_thin_causeway_through_region() -> void:
	var cells := _cells_from_rows([
		"###.###",
		"###.###",
		"###.###",
		"###.###",
	])
	var rects := _merge(Vector2i(7, 4), cells)
	assert_eq(rects, [Rect2i(0, 0, 3, 4), Rect2i(4, 0, 3, 4)])
	assert_true(_coverage_is_exact(Vector2i(7, 4), cells, rects))


func test_keeps_diagonally_touching_cells_separate() -> void:
	var cells := _cells_from_rows([
		"#.",
		".#",
	])
	var rects := _merge(Vector2i(2, 2), cells)
	assert_eq(rects, [Rect2i(0, 0, 1, 1), Rect2i(1, 1, 1, 1)])
	assert_true(_coverage_is_exact(Vector2i(2, 2), cells, rects))


func test_merges_regions_touching_all_map_boundaries() -> void:
	var cells := _cells_from_rows([
		"####",
		"####",
		"####",
	])
	var rects := _merge(Vector2i(4, 3), cells)
	assert_eq(rects, [Rect2i(0, 0, 4, 3)])
	assert_true(_coverage_is_exact(Vector2i(4, 3), cells, rects))


func test_output_is_deterministic_and_row_major() -> void:
	var cells := _cells_from_rows([
		".##..#",
		".##..#",
		"#...##",
	])
	var expected := [
		Rect2i(1, 0, 2, 2),
		Rect2i(5, 0, 1, 2),
		Rect2i(0, 2, 1, 1),
		Rect2i(4, 2, 2, 1),
	]
	for ignored in 5:
		assert_eq(_merge(Vector2i(6, 3), cells), expected)
	assert_true(_coverage_is_exact(Vector2i(6, 3), cells, expected))


func _merge(size_cells: Vector2i, cells: Dictionary) -> Array[Rect2i]:
	return GridRegionMerger.merge_matching_cells(
		size_cells,
		func(cell: Vector2i) -> bool:
			return cells.has(cell)
	)


func _cells_from_rows(rows: Array[String]) -> Dictionary:
	var cells: Dictionary = {}
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "#":
				cells[Vector2i(x, y)] = true
	return cells


func _coverage_is_exact(size_cells: Vector2i, expected_cells: Dictionary, rects: Array[Rect2i]) -> bool:
	var covered: Dictionary = {}
	for rect in rects:
		if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > size_cells.x or rect.end.y > size_cells.y:
			return false
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if covered.has(cell):
					return false
				covered[cell] = true
	return covered == expected_cells
