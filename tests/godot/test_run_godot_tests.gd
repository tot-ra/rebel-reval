extends "res://tests/godot/test_case.gd"

const Harness := preload("res://tools/run_godot_tests.gd")
const DISCOVERED_FILES: Array[String] = [
	"res://tests/godot/test_map.gd",
	"res://tests/godot/test_map_view.gd",
	"res://tests/godot/nested/test_map.gd",
]


func test_empty_filter_preserves_all_discovered_files() -> void:
	assert_eq(Harness._filter_test_files(DISCOVERED_FILES, ""), DISCOVERED_FILES)


func test_filter_matches_exact_filename_stem() -> void:
	assert_eq(
		Harness._filter_test_files(DISCOVERED_FILES, "test_map"),
		["res://tests/godot/test_map.gd", "res://tests/godot/nested/test_map.gd"],
	)


func test_filter_rejects_filename_prefix_matches() -> void:
	assert_eq(Harness._filter_test_files(DISCOVERED_FILES, "test_map_view_3d"), [])


func test_filter_accepts_multiple_exact_filename_stems() -> void:
	assert_eq(
		Harness._filter_test_files(DISCOVERED_FILES, "test_map_view,test_map"),
		[
			"res://tests/godot/test_map.gd",
			"res://tests/godot/test_map_view.gd",
			"res://tests/godot/nested/test_map.gd",
		],
	)
