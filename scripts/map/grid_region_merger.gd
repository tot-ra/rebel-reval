class_name GridRegionMerger
extends RefCounted

## Converts a cell predicate into an exact, deterministic set of non-overlapping
## rectangles. Horizontal runs are extended only across rows with the same span,
## so holes, one-cell passages, and diagonal separation remain unchanged.


static func merge_matching_cells(size_cells: Vector2i, matches: Callable) -> Array[Rect2i]:
	var merged: Array[Rect2i] = []
	if size_cells.x <= 0 or size_cells.y <= 0 or not matches.is_valid():
		return merged

	var active_by_span: Dictionary = {}
	for y in range(size_cells.y):
		var next_by_span: Dictionary = {}
		var x := 0
		while x < size_cells.x:
			if not bool(matches.call(Vector2i(x, y))):
				x += 1
				continue

			var run_start := x
			while x < size_cells.x and bool(matches.call(Vector2i(x, y))):
				x += 1
			var span := Vector2i(run_start, x - run_start)
			if active_by_span.has(span):
				var rect: Rect2i = active_by_span[span]
				rect.size.y += 1
				next_by_span[span] = rect
			else:
				next_by_span[span] = Rect2i(run_start, y, span.y, 1)

		_append_finished_rectangles(merged, active_by_span, next_by_span)
		active_by_span = next_by_span

	_append_finished_rectangles(merged, active_by_span, {})
	merged.sort_custom(_rect_before)
	return merged


static func _append_finished_rectangles(
	output: Array[Rect2i],
	active_by_span: Dictionary,
	continued_by_span: Dictionary
) -> void:
	for span: Vector2i in active_by_span:
		if not continued_by_span.has(span):
			output.append(active_by_span[span])


static func _rect_before(first: Rect2i, second: Rect2i) -> bool:
	if first.position.y != second.position.y:
		return first.position.y < second.position.y
	if first.position.x != second.position.x:
		return first.position.x < second.position.x
	if first.size.y != second.size.y:
		return first.size.y < second.size.y
	return first.size.x < second.size.x
