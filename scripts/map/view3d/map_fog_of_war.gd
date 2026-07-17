extends CanvasLayer

## Player-facing memory overlay for the active orthographic 3D map. Visibility
## is evaluated on the logic ground plane against the same declarative building
## footprints used by collision and rendering.

const FOG_SHADER := preload("res://scripts/map/view3d/map_fog_of_war.gdshader")
const FIELD_OF_VIEW_DEGREES := 120.0
const CLEAR_RADIUS_WORLD := 9.0
const MEMORY_RADIUS_WORLD := 18.0
const OCCLUSION_MASK_PIXELS_PER_CELL := 4

var _material: ShaderMaterial
var _camera: Camera3D
var _definition: MapDefinition
var _occluders: Array[Rect2] = []


func configure(camera: Camera3D, definition: MapDefinition) -> void:
	name = "FogOfWar"
	layer = 10
	_camera = camera
	_definition = definition
	_occluders = occluder_rects_for_definition(definition)
	_assemble()


func update_view(player_position: Vector3, facing: Vector2) -> void:
	if _material == null or _camera == null:
		return
	var normalized_facing := facing.normalized() if not facing.is_zero_approx() else Vector2.DOWN
	_material.set_shader_parameter("player_world", Vector2(player_position.x, player_position.z))
	_material.set_shader_parameter("facing_world", normalized_facing)
	_update_ground_projection()


func visibility_at(world_position: Vector2, player_position: Vector2, facing: Vector2) -> float:
	var offset := world_position - player_position
	var distance := offset.length()
	if distance > MEMORY_RADIUS_WORLD:
		return 0.0
	if not offset.is_zero_approx():
		var normalized_facing := facing.normalized() if not facing.is_zero_approx() else Vector2.DOWN
		if normalized_facing.dot(offset / distance) < cos(deg_to_rad(FIELD_OF_VIEW_DEGREES * 0.5)):
			return 0.0
	for rect in _occluders:
		if segment_crosses_rect(player_position, world_position, rect):
			return 0.0
	return 1.0


static func segment_crosses_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	# The blocking structure is visible; only content beyond its footprint is not.
	if rect.has_point(from) or rect.has_point(to):
		return false
	var delta := to - from
	var enter := 0.0
	var exit := 1.0
	for axis in 2:
		var origin := from[axis]
		var direction := delta[axis]
		var minimum := rect.position[axis]
		var maximum := rect.end[axis]
		if is_zero_approx(direction):
			if origin < minimum or origin > maximum:
				return false
			continue
		var first := (minimum - origin) / direction
		var second := (maximum - origin) / direction
		enter = maxf(enter, minf(first, second))
		exit = minf(exit, maxf(first, second))
		if exit < enter:
			return false
	return exit > 0.0 and enter > 0.0 and enter < 0.985


static func occluder_rects_for_definition(definition: MapDefinition) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var scale := MapViewBridge.world_scale(definition.cell_size)
	for building in definition.buildings:
		var footprint: Rect2 = building.get("footprint", Rect2())
		if not footprint.size.is_zero_approx():
			rects.append(Rect2(footprint.position * scale, footprint.size * scale))
	return rects


func _assemble() -> void:
	_material = ShaderMaterial.new()
	_material.shader = FOG_SHADER
	_material.set_shader_parameter("clear_radius", CLEAR_RADIUS_WORLD)
	_material.set_shader_parameter("memory_radius", MEMORY_RADIUS_WORLD)
	_material.set_shader_parameter("half_fov_cos", cos(deg_to_rad(FIELD_OF_VIEW_DEGREES * 0.5)))
	_material.set_shader_parameter("soft_fov_cos", cos(deg_to_rad(FIELD_OF_VIEW_DEGREES * 0.5 + 5.0)))
	_material.set_shader_parameter("map_world_size", Vector2(_definition.size_cells))
	_material.set_shader_parameter("occlusion_mask", _build_occlusion_mask())

	var overlay := ColorRect.new()
	overlay.name = "MemoryOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.material = _material
	add_child(overlay)


func _build_occlusion_mask() -> Texture2D:
	var size := _definition.size_cells * OCCLUSION_MASK_PIXELS_PER_CELL
	var image := Image.create(size.x, size.y, false, Image.FORMAT_R8)
	image.fill(Color.BLACK)
	var world_size := Vector2(_definition.size_cells)
	for rect in _occluders:
		var from := Vector2i(floor(rect.position.x / world_size.x * size.x), floor(rect.position.y / world_size.y * size.y))
		var to := Vector2i(ceil(rect.end.x / world_size.x * size.x), ceil(rect.end.y / world_size.y * size.y))
		for y in range(clampi(from.y, 0, size.y), clampi(to.y, 0, size.y)):
			for x in range(clampi(from.x, 0, size.x), clampi(to.x, 0, size.x)):
				image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)


func _update_ground_projection() -> void:
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var top_left := _ground_at_screen(Vector2.ZERO)
	var top_right := _ground_at_screen(Vector2(viewport_size.x, 0.0))
	var bottom_left := _ground_at_screen(Vector2(0.0, viewport_size.y))
	_material.set_shader_parameter("ground_origin", top_left)
	_material.set_shader_parameter("ground_uv_x", top_right - top_left)
	_material.set_shader_parameter("ground_uv_y", bottom_left - top_left)


func _ground_at_screen(screen_position: Vector2) -> Vector2:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if is_zero_approx(direction.y):
		return Vector2(origin.x, origin.z)
	var distance := -origin.y / direction.y
	var hit := origin + direction * distance
	return Vector2(hit.x, hit.z)
