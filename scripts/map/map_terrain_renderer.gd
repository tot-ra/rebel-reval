class_name MapTerrainRenderer
extends Node2D

## Streams fixed-size terrain draw nodes around a global camera/player focus.

const DEFAULT_LOAD_RADIUS_CHUNKS := 2

var grid: MapTerrainGrid
var visual_target: StringName
var time_of_day: StringName
var load_radius_chunks := DEFAULT_LOAD_RADIUS_CHUNKS
var debug_chunk_bounds := false
var _loaded_chunks: Dictionary = {}
var _focus_source: Node2D
var _last_focus_chunk := Vector2i(2147483647, 2147483647)


func _init(
	terrain_grid: MapTerrainGrid,
	target: StringName = MapVisualStyle.TARGET_CLEAN_PAINTED,
	day_phase: StringName = MapVisualStyle.TIME_DAY
) -> void:
	grid = terrain_grid
	visual_target = target
	time_of_day = day_phase
	z_index = 0


func _ready() -> void:
	if grid != null and _loaded_chunks.is_empty():
		# Compatibility behavior draws the complete terrain until a focus source is
		# supplied. Large maps call update_active_chunks before entering the tree.
		load_all_chunks()
	set_process(_focus_source != null)


func _process(_delta: float) -> void:
	if _focus_source == null or not is_instance_valid(_focus_source):
		set_process(false)
		return
	var focus_chunk := chunk_for_world_position(_focus_source.global_position)
	if focus_chunk != _last_focus_chunk:
		update_active_chunks(_focus_source.global_position)


func load_chunk(coordinates: Vector2i) -> MapTerrainChunkRenderer:
	if grid == null or grid.get_chunk(coordinates) == null:
		return null
	if _loaded_chunks.has(coordinates):
		return _loaded_chunks[coordinates] as MapTerrainChunkRenderer
	var chunk_renderer := MapTerrainChunkRenderer.new()
	chunk_renderer.name = "Chunk_%d_%d" % [coordinates.x, coordinates.y]
	chunk_renderer.configure(grid, coordinates, visual_target, time_of_day, debug_chunk_bounds)
	add_child(chunk_renderer)
	_loaded_chunks[coordinates] = chunk_renderer
	return chunk_renderer


func unload_chunk(coordinates: Vector2i) -> bool:
	var chunk_renderer := _loaded_chunks.get(coordinates) as MapTerrainChunkRenderer
	if chunk_renderer == null:
		return false
	_loaded_chunks.erase(coordinates)
	remove_child(chunk_renderer)
	chunk_renderer.free()
	return true


func unload_all_chunks() -> void:
	for coordinates in loaded_chunk_coordinates():
		unload_chunk(coordinates)


func load_all_chunks() -> void:
	if grid == null:
		return
	for coordinates in grid.chunk_coordinates():
		load_chunk(coordinates)


func update_active_chunks(global_position: Vector2, radius_chunks: int = load_radius_chunks) -> void:
	if grid == null:
		return
	assert(radius_chunks >= 0)
	var focus_chunk := chunk_for_world_position(global_position)
	_last_focus_chunk = focus_chunk
	var wanted: Dictionary = {}
	for y in range(focus_chunk.y - radius_chunks, focus_chunk.y + radius_chunks + 1):
		for x in range(focus_chunk.x - radius_chunks, focus_chunk.x + radius_chunks + 1):
			var coordinates := Vector2i(x, y)
			if grid.get_chunk(coordinates) != null:
				wanted[coordinates] = true
	for coordinates in loaded_chunk_coordinates():
		if not wanted.has(coordinates):
			unload_chunk(coordinates)
	var ordered: Array[Vector2i] = []
	ordered.assign(wanted.keys())
	ordered.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		var left_distance := maxi(absi(left.x - focus_chunk.x), absi(left.y - focus_chunk.y))
		var right_distance := maxi(absi(right.x - focus_chunk.x), absi(right.y - focus_chunk.y))
		if left_distance != right_distance:
			return left_distance < right_distance
		return left.y < right.y or (left.y == right.y and left.x < right.x)
	)
	for coordinates in ordered:
		load_chunk(coordinates)


func chunk_for_world_position(global_position: Vector2) -> Vector2i:
	if grid == null:
		return Vector2i.ZERO
	var focus_cell := Vector2i(
		floori(global_position.x / float(grid.cell_size)),
		floori(global_position.y / float(grid.cell_size))
	)
	return grid.chunk_for_cell(focus_cell)


func follow(source: Node2D, radius_chunks: int = DEFAULT_LOAD_RADIUS_CHUNKS) -> void:
	assert(radius_chunks >= 0)
	_focus_source = source
	load_radius_chunks = radius_chunks
	if source != null:
		update_active_chunks(source.global_position, load_radius_chunks)
	set_process(source != null)


func stop_following() -> void:
	_focus_source = null
	set_process(false)


func update_from_camera(camera: Camera2D, radius_chunks: int = load_radius_chunks) -> void:
	if camera != null:
		update_active_chunks(camera.global_position, radius_chunks)


func update_from_player(player: Node2D, radius_chunks: int = load_radius_chunks) -> void:
	if player != null:
		update_active_chunks(player.global_position, radius_chunks)


func loaded_chunk_coordinates() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_loaded_chunks.keys())
	result.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		return left.y < right.y or (left.y == right.y and left.x < right.x)
	)
	return result


func loaded_chunk_count() -> int:
	return _loaded_chunks.size()


func loaded_cell_bounds() -> Rect2i:
	var result := Rect2i()
	var first := true
	for coordinates in loaded_chunk_coordinates():
		var bounds := grid.chunk_bounds(coordinates)
		result = bounds if first else result.merge(bounds)
		first = false
	return result


func set_debug_chunk_bounds(enabled: bool) -> void:
	debug_chunk_bounds = enabled
	for chunk_renderer: MapTerrainChunkRenderer in _loaded_chunks.values():
		chunk_renderer.set_debug_bounds_enabled(enabled)
