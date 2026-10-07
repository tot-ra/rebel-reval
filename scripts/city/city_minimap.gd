class_name CityMinimap
extends CanvasLayer

## Seamless-city minimap (ADR 0031): a circular map turned so the camera looks
## up the screen, a north mark on the rim, Kalev's arrow in the middle, and the
## district, street and building he is in underneath.

const SHADER := preload("res://scripts/city/city_minimap.gdshader")
const MAP_PATH := "res://content/world/reval_city/minimap.png"
const SIZE := 220.0
## Shared slim bronze rim (see MinimapHud). Drawn so its inner edge sits on the map circle.
const RIM_TEXTURE_PATH := "res://assets/UI/minimap/minimap_rim.png"
const RIM_DISPLAY_SIZE := 303.0
const MARGIN := 24.0
## World units across the circle.
const VIEW_UNITS := 150.0

var plan: CityPlan
var _map: ColorRect
var _material: ShaderMaterial
var _north: Label
var _arrow: Polygon2D
var _district: Label
var _street: Label
var _building: Label


static func create(city_plan: CityPlan) -> CityMinimap:
	var node := CityMinimap.new()
	node.name = "CityMinimap"
	node.plan = city_plan
	node.layer = 20
	return node


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	root.position = Vector2(-SIZE - MARGIN, MARGIN)
	root.size = Vector2(SIZE, SIZE + 90)
	add_child(root)
	_map = ColorRect.new()
	_map.size = Vector2(SIZE, SIZE)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var texture: Texture2D = load(MAP_PATH)
	_material.set_shader_parameter("map_texture", texture)
	_material.set_shader_parameter("view_uv", VIEW_UNITS / plan.bounds.size.x)
	_map.material = _material
	root.add_child(_map)
	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array(
		[Vector2(0, -11), Vector2(7, 8), Vector2(0, 4), Vector2(-7, 8)]
	)
	_arrow.color = Color(0.98, 0.86, 0.35)
	_arrow.position = Vector2(SIZE, SIZE) * 0.5
	root.add_child(_arrow)
	var rim := TextureRect.new()
	rim.name = "Rim"
	rim.texture = load(RIM_TEXTURE_PATH) as Texture2D
	rim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rim.stretch_mode = TextureRect.STRETCH_SCALE
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.size = Vector2(RIM_DISPLAY_SIZE, RIM_DISPLAY_SIZE)
	rim.position = (Vector2(SIZE, SIZE) - rim.size) * 0.5
	root.add_child(rim)
	_north = _label(root, 16, Color(0.95, 0.9, 0.78))
	_north.text = "N"
	_district = _label(root, 17, Color(0.97, 0.92, 0.8))
	_district.position = Vector2(0, SIZE + 6)
	_street = _label(root, 15, Color(0.9, 0.85, 0.72))
	_street.position = Vector2(0, SIZE + 30)
	_building = _label(root, 14, Color(0.82, 0.78, 0.68))
	_building.position = Vector2(0, SIZE + 52)


func _label(parent: Control, size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(SIZE, 22)
	parent.add_child(label)
	return label


## `yaw` is the camera yaw (CityScene): the camera looks along -(sin, cos).
func update_view(world_xz: Vector2, facing: Vector2, yaw: float, inside: int) -> void:
	var uv := (world_xz - plan.bounds.position) / plan.bounds.size
	_material.set_shader_parameter("center_uv", uv)
	# Screen up = camera forward (-sin yaw, -cos yaw) in map space.
	_material.set_shader_parameter("angle", -yaw)
	var r := SIZE * 0.5 - 12.0
	var north := Vector2(0, -1).rotated(yaw)
	_north.position = Vector2(SIZE, SIZE) * 0.5 + north * r - Vector2(SIZE * 0.5, 11)
	var heading := facing if not facing.is_zero_approx() else Vector2(0, -1)
	_arrow.rotation = heading.angle() + PI * 0.5 + yaw
	var where := plan.location_at(world_xz, inside)
	_district.text = where["district"]
	_street.text = where["street"]
	_building.text = where["building"]
