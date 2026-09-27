extends "res://tests/godot/test_case.gd"

## R-1025: headless Texture2D.get_image() aliases the stored Image. Plate
## readers must copy before resize so imported sources stay at native size.

const GRASS_PATH := "res://assets/materials/pbr/grass/grass_albedo.png"
const MUD_PATH := "res://assets/materials/pbr/mud/mud_albedo.png"
const HAY_PATH := "res://assets/materials/pbr/hay/hay_albedo.png"
const TIMBER_PATH := "res://assets/materials/pbr/timber_floor/timber_floor_albedo.png"
const SMITHY_PATH := "res://assets/materials/pbr/smithy_floor/smithy_floor_albedo.png"
const LIMESTONE_PATH := (
	"res://assets/materials/pbr/limestone_rubble/limestone_rubble_albedo.png"
)


func after_each() -> void:
	MapViewMaterials.reset()
	super.after_each()


func test_blended_ground_leaves_authored_plate_images_at_imported_size() -> void:
	var paths: Array[String] = [GRASS_PATH, TIMBER_PATH, SMITHY_PATH]
	if ResourceLoader.exists(MUD_PATH):
		paths.append(MUD_PATH)
	if ResourceLoader.exists(HAY_PATH):
		paths.append(HAY_PATH)
	if ResourceLoader.exists(LIMESTONE_PATH):
		paths.append(LIMESTONE_PATH)
	var before: Dictionary = {}
	for path in paths:
		before[path] = _image_size(path)
		assert_true(
			(before[path] as Vector2i).x > MapViewMaterials.TEXTURE_SIZE,
			"%s should be larger than the 128 px family copy" % path
		)
	MapViewMaterials.blended_ground(731)
	MapViewMaterials.terrain_pattern_array(731)
	MapViewMaterials.smithy_floor_albedo_image()
	if ResourceLoader.exists(LIMESTONE_PATH):
		MapViewMaterialPatterns.pattern_texture_at_size(
			MapViewMaterials.PATTERN_LIMESTONE, 17, MapViewMaterials.TEXTURE_SIZE
		)
	for path in paths:
		assert_eq(_image_size(path), before[path], path)


func _image_size(path: String) -> Vector2i:
	var texture := load(path) as Texture2D
	assert_true(texture != null, path)
	var image := texture.get_image()
	assert_true(image != null, "%s get_image" % path)
	return Vector2i(image.get_width(), image.get_height())
